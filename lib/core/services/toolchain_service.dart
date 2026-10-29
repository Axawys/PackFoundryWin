import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/tool_status.dart';
import 'flutter_locator.dart';
import 'windows_tools.dart';

/// Reports progress of a single install step. [fraction] is 0-1, or null when
/// the running tool does not expose measurable progress.
typedef ToolProgressCallback = void Function(double? fraction, String detail);

class ToolchainService {
  ToolchainService({WindowsTools? tools}) : _tools = tools ?? WindowsTools();

  static const _androidCommandLineToolsUrl =
      'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip';
  static const _cancelledMessage = 'Installation was cancelled.';
  static final _gitPhasePattern = RegExp(
    r'(Counting objects|Compressing objects|Receiving objects|Resolving deltas|Updating files):\s+(\d+)%',
  );
  static final _percentPattern = RegExp(r'(\d+(?:\.\d+)?)\s*%');
  static final _curlMeterPattern = RegExp(
    r'^(\d{1,3})\s+[\d.]+[kMG]?\s+\d{1,3}\s+[\d.]+[kMG]?\s',
  );

  final WindowsTools _tools;
  Process? _activeProcess;
  HttpClient? _activeHttpClient;
  var _cancelRequested = false;

  bool get isCancelRequested => _cancelRequested;

  /// Clears a previous cancellation so a new installation can start.
  void beginInstall() {
    _cancelRequested = false;
  }

  /// Stops the running download or process of the current installation.
  /// winget runs are left alone: an interrupted installer can leave a broken
  /// program behind.
  Future<void> cancelActiveInstall() async {
    _cancelRequested = true;
    final process = _activeProcess;
    if (process != null) {
      await killProcessTree(process);
    }
    _activeHttpClient?.close(force: true);
  }

  File get managedFlutterExecutable => FlutterLocator().managedExecutable;

  Directory get managedAndroidSdkDirectory => _tools.managedAndroidSdk;

  File get managedSdkManager => File(
    _joinPath(
      managedAndroidSdkDirectory.path,
      'cmdline-tools/latest/bin/sdkmanager.bat',
    ),
  );

  Future<ToolAvailability> commandAvailability(
    String executable,
    List<String> arguments,
  ) async {
    try {
      final result = await Process.run(
        executable,
        arguments,
        runInShell: true,
      ).timeout(const Duration(seconds: 20));
      return result.exitCode == 0
          ? ToolAvailability.installed
          : ToolAvailability.missing;
    } on Object {
      return ToolAvailability.missing;
    }
  }

  /// Checks the same executable builds will use, so the toolchain tab never
  /// reports Flutter as installed while builds cannot start it.
  Future<ToolAvailability> flutterAvailability() async {
    final flutter = FlutterLocator().find();
    if (flutter == null) {
      return ToolAvailability.missing;
    }
    return commandAvailability(flutter.path, ['--version']);
  }

  Future<ToolAvailability> gitAvailability() async {
    return _tools.findGit() == null
        ? ToolAvailability.missing
        : ToolAvailability.installed;
  }

  Future<ToolAvailability> innoSetupAvailability() async {
    return _tools.findInnoCompiler() == null
        ? ToolAvailability.missing
        : ToolAvailability.installed;
  }

  Future<ToolAvailability> visualStudioAvailability() async {
    return await _tools.findVisualStudioWithCpp() == null
        ? ToolAvailability.missing
        : ToolAvailability.installed;
  }

  Future<ToolAvailability> developerModeAvailability() async {
    return await _tools.developerModeEnabled()
        ? ToolAvailability.installed
        : ToolAvailability.missing;
  }

  Future<ToolAvailability> androidSdkAvailability() async {
    return _tools.findAndroidSdk() == null
        ? ToolAvailability.missing
        : ToolAvailability.installed;
  }

  /// Java on PATH, in JAVA_HOME, or the runtime bundled with Android Studio,
  /// which Flutter uses for Gradle on its own.
  Future<ToolAvailability> javaAvailability() async {
    final candidates = <String>[
      if (_tools.findOnPath('java.exe') case final file?) file.path,
      if (_tools.variable('JAVA_HOME') case final home? when home.isNotEmpty)
        _joinPath(home, 'bin/java.exe'),
      for (final root in [
        _tools.variable('ProgramFiles'),
        _tools.variable('LOCALAPPDATA') == null
            ? null
            : _joinPath(_tools.variable('LOCALAPPDATA')!, 'Programs'),
      ])
        if (root != null && root.isNotEmpty)
          _joinPath(root, 'Android/Android Studio/jbr/bin/java.exe'),
    ];
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return ToolAvailability.installed;
      }
    }
    return ToolAvailability.missing;
  }

  /// Opens the Windows settings page with the Developer Mode switch, which
  /// needs administrator rights to flip and therefore stays a user action.
  Future<void> openDeveloperSettings() async {
    await Process.run('cmd.exe', const [
      '/c',
      'start',
      'ms-settings:developers',
    ]);
  }

  /// Installs a package with winget. Installers may show their own UAC
  /// prompt; their output is forwarded line by line.
  Future<ToolInstallResult> installWithWinget(
    String packageId, {
    List<String> extraArguments = const [],
    ToolProgressCallback? onProgress,
  }) async {
    final winget =
        _tools.findOnPath('winget.exe') ??
        File(
          _joinPath(
            _tools.variable('LOCALAPPDATA') ?? '',
            'Microsoft/WindowsApps/winget.exe',
          ),
        );
    if (!winget.existsSync()) {
      return const ToolInstallResult.failure(
        'winget was not found. Install "App Installer" from Microsoft Store '
        'or install the tool manually.',
      );
    }

    try {
      onProgress?.call(null, 'winget install --id $packageId');
      final result = await _runStreamed(
        winget.path,
        [
          'install',
          '--id',
          packageId,
          '--exact',
          '--source',
          'winget',
          '--accept-source-agreements',
          '--accept-package-agreements',
          '--disable-interactivity',
          ...extraArguments,
        ],
        trackForCancel: false,
        onLine: (line) {
          final percent = _percentPattern.firstMatch(line);
          onProgress?.call(
            percent == null
                ? null
                : (double.tryParse(percent.group(1)!) ?? 0) / 100,
            line,
          );
        },
      );
      // "No newer package versions are available" is not a failure.
      final alreadyInstalled =
          result.exitCode == -1978335189 ||
          result.outputTail.any(
            (line) =>
                line.contains('already installed') ||
                line.contains('No newer package versions'),
          );
      if (result.exitCode == 0 || alreadyInstalled) {
        return ToolInstallResult.success('Installed $packageId.');
      }
      return ToolInstallResult.failure(result.shortOutput);
    } on ProcessException catch (error) {
      return ToolInstallResult.failure(error.message);
    }
  }

  Future<ToolInstallResult> installFlutterSdk({
    ToolProgressCallback? onProgress,
  }) async {
    final git = _tools.findGit();
    if (git == null) {
      return const ToolInstallResult.failure(
        'Git was not found. Install Git first: ${WindowsTools.gitWinget}',
      );
    }
    try {
      final flutterExecutable = managedFlutterExecutable;
      final sdkDirectory = flutterExecutable.parent.parent;
      if (flutterExecutable.existsSync()) {
        onProgress?.call(null, 'Updating Flutter SDK.');
        final upgradeResult = await _runStreamed(git.path, [
          '-C',
          sdkDirectory.path,
          'pull',
          '--ff-only',
          '--progress',
        ], onLine: (line) => onProgress?.call(null, line));
        if (_cancelRequested) {
          return const ToolInstallResult.failure(_cancelledMessage);
        }
        if (upgradeResult.exitCode != 0) {
          return ToolInstallResult.failure(upgradeResult.shortOutput);
        }
      } else {
        // A directory without the flutter executable is a leftover from an
        // interrupted clone; git refuses to clone into it.
        if (sdkDirectory.existsSync()) {
          await sdkDirectory.delete(recursive: true);
        }
        await sdkDirectory.parent.create(recursive: true);
        onProgress?.call(0, 'Cloning Flutter SDK (stable).');
        final cloneResult = await _runStreamed(
          git.path,
          [
            'clone',
            '--progress',
            '--depth',
            '1',
            '--branch',
            'stable',
            'https://github.com/flutter/flutter.git',
            sdkDirectory.path,
          ],
          onLine: (line) {
            final fraction = _gitCloneFraction(line);
            if (fraction != null) {
              onProgress?.call(fraction, line);
            }
          },
        );
        if (_cancelRequested || cloneResult.exitCode != 0) {
          if (sdkDirectory.existsSync()) {
            await sdkDirectory.delete(recursive: true);
          }
          return ToolInstallResult.failure(
            _cancelRequested ? _cancelledMessage : cloneResult.shortOutput,
          );
        }
      }

      // The first run downloads the Dart SDK and builds the flutter tool.
      onProgress?.call(0.7, 'Downloading Dart SDK and building Flutter tool.');
      final versionResult = await _runStreamed(
        flutterExecutable.path,
        ['--version'],
        onLine: (line) {
          final percent = _downloadPercent(line);
          if (percent != null) {
            onProgress?.call(0.7 + (percent / 100).clamp(0.0, 1.0) * 0.2, line);
          } else {
            onProgress?.call(null, line);
          }
        },
      );
      if (_cancelRequested) {
        return const ToolInstallResult.failure(_cancelledMessage);
      }
      if (versionResult.exitCode != 0) {
        return ToolInstallResult.failure(versionResult.shortOutput);
      }
      onProgress?.call(1, 'Flutter SDK is ready.');
      return ToolInstallResult.success(
        'Flutter SDK is ready at ${sdkDirectory.path}.',
      );
    } on Object catch (error) {
      return ToolInstallResult.failure(
        _cancelRequested ? _cancelledMessage : error.toString(),
      );
    }
  }

  /// Reads a download percentage from a progress line: either an explicit
  /// "45%" or the first column of curl's default progress meter, which the
  /// flutter tool uses for the Dart SDK download.
  double? _downloadPercent(String line) {
    final explicit = _percentPattern.firstMatch(line);
    if (explicit != null) {
      return double.tryParse(explicit.group(1)!);
    }
    final curlMeter = _curlMeterPattern.firstMatch(line);
    if (curlMeter != null) {
      return double.tryParse(curlMeter.group(1)!);
    }
    return null;
  }

  /// Maps git clone phases onto the clone part (0-0.7) of the Flutter step.
  double? _gitCloneFraction(String line) {
    final match = _gitPhasePattern.firstMatch(line);
    if (match == null) {
      return null;
    }
    final percent = int.parse(match.group(2)!) / 100;
    final (start, end) = switch (match.group(1)) {
      'Counting objects' => (0.0, 0.01),
      'Compressing objects' => (0.01, 0.03),
      'Receiving objects' => (0.03, 0.55),
      'Resolving deltas' => (0.55, 0.62),
      _ => (0.62, 0.7),
    };
    return start + (end - start) * percent;
  }

  Future<ToolInstallResult> installAndroidSdk({
    ToolProgressCallback? onProgress,
  }) async {
    Directory? tempDirectory;
    try {
      final sdkRoot = managedAndroidSdkDirectory;
      final sdkManager = managedSdkManager;
      if (!sdkManager.existsSync()) {
        tempDirectory = await Directory.systemTemp.createTemp(
          'pack_foundry_android_tools_',
        );
        final zipFile = File(
          _joinPath(tempDirectory.path, 'cmdline-tools.zip'),
        );
        await _downloadFile(
          Uri.parse(_androidCommandLineToolsUrl),
          zipFile,
          onProgress: (fraction, detail) => onProgress?.call(
            fraction == null ? null : fraction * 0.25,
            'Android command line tools: $detail',
          ),
        );
        final extractDirectory = Directory(
          _joinPath(tempDirectory.path, 'extract'),
        );
        await extractDirectory.create(recursive: true);
        onProgress?.call(0.25, 'Extracting Android command line tools.');
        // tar.exe ships with Windows 10 1803+ and reads zip archives.
        final systemRoot = _tools.variable('SystemRoot') ?? r'C:\Windows';
        final unzipResult = await Process.run(
          _joinPath(systemRoot, 'System32/tar.exe'),
          ['-xf', zipFile.path, '-C', extractDirectory.path],
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        );
        if (unzipResult.exitCode != 0) {
          return ToolInstallResult.failure(_shortProcessOutput(unzipResult));
        }

        final latestDirectory = Directory(
          _joinPath(sdkRoot.path, 'cmdline-tools/latest'),
        );
        if (latestDirectory.existsSync()) {
          await latestDirectory.delete(recursive: true);
        }
        await latestDirectory.parent.create(recursive: true);
        final extractedTools = Directory(
          _joinPath(extractDirectory.path, 'cmdline-tools'),
        );
        await _copyDirectory(extractedTools, latestDirectory);
      }

      if (_cancelRequested) {
        return const ToolInstallResult.failure(_cancelledMessage);
      }
      onProgress?.call(0.3, 'Accepting Android SDK licenses.');
      final licenseResult = await _runSdkManagerWithYes(
        sdkManager,
        sdkRoot,
        const ['--licenses'],
      );
      if (!licenseResult.success) {
        return licenseResult;
      }

      const packages = [
        'cmdline-tools;latest',
        'platform-tools',
        'platforms;android-35',
        'build-tools;35.0.0',
      ];
      onProgress?.call(0.32, 'Installing Android SDK packages.');
      final downloads = <String>{};
      final installResult = await _runSdkManagerWithYes(
        sdkManager,
        sdkRoot,
        packages,
        onLine: (line) {
          // sdkmanager prints "[====   ] 45% Downloading x.zip..." per package.
          final downloading = RegExp(r'Downloading (\S+)').firstMatch(line);
          if (downloading != null) {
            downloads.add(downloading.group(1)!);
          }
          final match = _percentPattern.firstMatch(line);
          if (match == null) {
            onProgress?.call(null, line);
            return;
          }
          final percent = (double.tryParse(match.group(1)!) ?? 0) / 100;
          final finished = downloads.isEmpty ? 0 : downloads.length - 1;
          final packagesFraction = ((finished + percent) / packages.length)
              .clamp(0.0, 1.0);
          onProgress?.call(0.32 + packagesFraction * 0.68, line);
        },
      );
      if (!installResult.success) {
        return installResult;
      }
      onProgress?.call(1, 'Android SDK is ready.');

      return ToolInstallResult.success(
        'Android SDK is ready at ${sdkRoot.path}.',
      );
    } on Object catch (error) {
      return ToolInstallResult.failure(
        _cancelRequested ? _cancelledMessage : error.toString(),
      );
    } finally {
      if (tempDirectory != null && tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    }
  }

  Future<void> _downloadFile(
    Uri uri,
    File destination, {
    ToolProgressCallback? onProgress,
  }) async {
    final client = HttpClient();
    _activeHttpClient = client;
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Download failed with HTTP ${response.statusCode}: $uri',
        );
      }

      final total = response.contentLength;
      var received = 0;
      var lastReport = DateTime.fromMillisecondsSinceEpoch(0);
      final sink = destination.openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          final now = DateTime.now();
          if (onProgress != null &&
              now.difference(lastReport) >= const Duration(milliseconds: 200)) {
            lastReport = now;
            final size = total > 0
                ? '${_formatBytes(received)} / ${_formatBytes(total)}'
                : _formatBytes(received);
            onProgress(total > 0 ? received / total : null, size);
          }
        }
      } finally {
        await sink.close();
      }
      if (_cancelRequested) {
        throw const HttpException(_cancelledMessage);
      }
      onProgress?.call(1, _formatBytes(received));
    } finally {
      if (identical(_activeHttpClient, client)) {
        _activeHttpClient = null;
      }
      client.close(force: true);
    }
  }

  String _formatBytes(int bytes) {
    const megabyte = 1024 * 1024;
    if (bytes >= megabyte) {
      return '${(bytes / megabyte).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  /// Runs a process and reports each output line as it arrives. Progress bars
  /// redraw with carriage returns, so both \r and \n end a line.
  Future<_StreamedResult> _runStreamed(
    String executable,
    List<String> arguments, {
    void Function(String line)? onLine,
    List<String> stdinLines = const [],
    bool trackForCancel = true,
  }) async {
    final lower = executable.toLowerCase();
    final process = await Process.start(
      executable,
      arguments,
      runInShell: lower.endsWith('.bat') || lower.endsWith('.cmd'),
    );
    if (trackForCancel) {
      _activeProcess = process;
    }
    try {
      for (final line in stdinLines) {
        process.stdin.writeln(line);
      }
      await process.stdin.close();

      final tail = <String>[];
      void handle(String line) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          return;
        }
        tail.add(trimmed);
        if (tail.length > 40) {
          tail.removeAt(0);
        }
        onLine?.call(trimmed);
      }

      await Future.wait([
        _splitLines(process.stdout).forEach(handle),
        _splitLines(process.stderr).forEach(handle),
      ]);
      final exitCode = await process.exitCode;
      return _StreamedResult(exitCode, tail);
    } finally {
      if (identical(_activeProcess, process)) {
        _activeProcess = null;
      }
    }
  }

  Stream<String> _splitLines(Stream<List<int>> stream) async* {
    var buffer = '';
    await for (final chunk in stream.transform(
      const Utf8Decoder(allowMalformed: true),
    )) {
      buffer += chunk;
      final parts = buffer.split(RegExp(r'[\r\n]'));
      buffer = parts.removeLast();
      yield* Stream.fromIterable(parts);
    }
    if (buffer.isNotEmpty) {
      yield buffer;
    }
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(
      recursive: true,
      followLinks: false,
    )) {
      final relativePath = entity.path.substring(source.path.length + 1);
      final newPath = _joinPath(destination.path, relativePath);
      if (entity is Directory) {
        await Directory(newPath).create(recursive: true);
      } else if (entity is File) {
        await File(newPath).parent.create(recursive: true);
        await entity.copy(newPath);
      }
    }
  }

  Future<ToolInstallResult> _runSdkManagerWithYes(
    File sdkManager,
    Directory sdkRoot,
    List<String> arguments, {
    void Function(String line)? onLine,
  }) async {
    final result = await _runStreamed(
      sdkManager.path,
      ['--sdk_root=${sdkRoot.path}', ...arguments],
      stdinLines: List.filled(80, 'y'),
      onLine: onLine,
    );
    if (_cancelRequested) {
      return const ToolInstallResult.failure(_cancelledMessage);
    }
    if (result.exitCode == 0) {
      return ToolInstallResult.success(
        'sdkmanager ${arguments.join(' ')} completed.',
      );
    }
    return ToolInstallResult.failure(result.shortOutput);
  }

  String _shortProcessOutput(ProcessResult result) {
    final output = [
      result.stdout.toString().trim(),
      result.stderr.toString().trim(),
    ].where((part) => part.isNotEmpty).join('\n');

    if (output.isEmpty) {
      return 'Process exited with code ${result.exitCode}.';
    }

    const maxLength = 700;
    if (output.length <= maxLength) {
      return output;
    }

    return output.substring(output.length - maxLength);
  }

  String _joinPath(String first, String second) {
    if (second.isEmpty) {
      return first;
    }
    final normalizedSecond = second.replaceAll('/', Platform.pathSeparator);
    if (first.endsWith(Platform.pathSeparator)) {
      return '$first$normalizedSecond';
    }
    return '$first${Platform.pathSeparator}$normalizedSecond';
  }
}

class _StreamedResult {
  const _StreamedResult(this.exitCode, this.outputTail);

  final int exitCode;
  final List<String> outputTail;

  String get shortOutput {
    if (outputTail.isEmpty) {
      return 'Process exited with code $exitCode.';
    }
    final output = outputTail.join('\n');
    const maxLength = 700;
    if (output.length <= maxLength) {
      return output;
    }
    return output.substring(output.length - maxLength);
  }
}

class ToolInstallResult {
  const ToolInstallResult.success(this.message) : success = true;

  const ToolInstallResult.failure(this.message) : success = false;

  final bool success;
  final String message;
}
