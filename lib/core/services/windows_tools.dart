import 'dart:convert';
import 'dart:io';

import 'flutter_locator.dart';

/// Locates the Windows tools a Flutter desktop build and an Inno Setup
/// installer need. Everything is looked up by file, not by name through a
/// shell, because PATH of a GUI app is often older than the one a terminal
/// sees right after an installer ran.
class WindowsTools {
  WindowsTools({Map<String, String>? environment})
    : _environment = environment ?? Platform.environment;

  final Map<String, String> _environment;

  static const innoSetupUrl = 'https://jrsoftware.org/isdl.php';
  static const visualStudioUrl =
      'https://visualstudio.microsoft.com/downloads/';
  static const gitUrl = 'https://git-scm.com/download/win';
  static const flutterUrl =
      'https://docs.flutter.dev/get-started/install/windows/desktop';

  static const innoSetupWinget = 'winget install --id JRSoftware.InnoSetup -e';
  static const gitWinget = 'winget install --id Git.Git -e';
  static const javaWinget = 'winget install --id Microsoft.OpenJDK.17 -e';
  static const visualStudioWinget =
      'winget install --id Microsoft.VisualStudio.2022.BuildTools -e '
      '--override "--wait --passive --add '
      'Microsoft.VisualStudio.Workload.VCTools --includeRecommended"';

  /// The component the "Desktop development with C++" workload brings and the
  /// flutter tool checks for.
  static const vcToolsComponent =
      'Microsoft.VisualStudio.Component.VC.Tools.x86.x64';

  String? variable(String name) {
    final direct = _environment[name];
    if (direct != null) {
      return direct;
    }
    final upper = name.toUpperCase();
    for (final entry in _environment.entries) {
      if (entry.key.toUpperCase() == upper) {
        return entry.value;
      }
    }
    return null;
  }

  /// First file called [fileName] in a PATH folder.
  File? findOnPath(String fileName) {
    final path = variable('PATH');
    if (path == null) {
      return null;
    }
    for (final directory in path.split(';')) {
      final trimmed = directory.trim().replaceAll('"', '');
      if (trimmed.isEmpty) {
        continue;
      }
      final candidate = File(_join(trimmed, fileName));
      if (candidate.existsSync()) {
        return candidate;
      }
    }
    return null;
  }

  List<String> get _programFolders => [
    for (final name in const ['ProgramFiles(x86)', 'ProgramFiles'])
      if (variable(name) case final value? when value.isNotEmpty) value,
    if (variable('LOCALAPPDATA') case final value? when value.isNotEmpty)
      _join(value, 'Programs'),
  ];

  File? findInnoCompiler() {
    final onPath = findOnPath('ISCC.exe');
    if (onPath != null) {
      return onPath;
    }
    for (final root in _programFolders) {
      for (final folder in const ['Inno Setup 6', 'Inno Setup 7']) {
        final candidate = File(_join(_join(root, folder), 'ISCC.exe'));
        if (candidate.existsSync()) {
          return candidate;
        }
      }
    }
    return null;
  }

  File? findGit() {
    final onPath = findOnPath('git.exe');
    if (onPath != null) {
      return onPath;
    }
    for (final root in _programFolders) {
      final candidate = File(_join(root, r'Git\cmd\git.exe'));
      if (candidate.existsSync()) {
        return candidate;
      }
    }
    return null;
  }

  File? findVsWhere() {
    final programFilesX86 = variable('ProgramFiles(x86)');
    if (programFilesX86 == null || programFilesX86.isEmpty) {
      return null;
    }
    final candidate = File(
      _join(programFilesX86, r'Microsoft Visual Studio\Installer\vswhere.exe'),
    );
    return candidate.existsSync() ? candidate : null;
  }

  /// Installation folder of a Visual Studio or Build Tools instance that has
  /// the C++ desktop tools, or null.
  Future<String?> findVisualStudioWithCpp() async {
    final vswhere = findVsWhere();
    if (vswhere == null) {
      return null;
    }
    try {
      final result = await Process.run(vswhere.path, const [
        '-products',
        '*',
        '-requires',
        vcToolsComponent,
        '-latest',
        '-property',
        'installationPath',
      ], stdoutEncoding: utf8).timeout(const Duration(seconds: 15));
      final path = '${result.stdout}'.trim().split(RegExp(r'[\r\n]+')).first;
      return result.exitCode == 0 && path.isNotEmpty ? path : null;
    } on Object {
      return null;
    }
  }

  /// Flutter plugins are linked with symlinks, which Windows only lets a
  /// regular user create with Developer Mode on.
  Future<bool> developerModeEnabled() async {
    try {
      final result = await Process.run('reg.exe', const [
        'query',
        r'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock',
        '/v',
        'AllowDevelopmentWithoutDevLicense',
      ]).timeout(const Duration(seconds: 5));
      return result.exitCode == 0 &&
          RegExp(r'0x0*1\b').hasMatch('${result.stdout}');
    } on Object {
      return false;
    }
  }

  /// SDK roots in the order Flutter itself would pick them.
  List<Directory> androidSdkRoots() {
    return [
      for (final name in const ['ANDROID_HOME', 'ANDROID_SDK_ROOT'])
        if (variable(name) case final value? when value.isNotEmpty)
          Directory(value),
      if (variable('LOCALAPPDATA') case final value? when value.isNotEmpty)
        Directory(_join(value, r'Android\Sdk')),
      managedAndroidSdk,
    ];
  }

  Directory get managedAndroidSdk =>
      Directory(_join(packFoundryDataDirectory(_environment), 'android-sdk'));

  /// First SDK that has platform packages installed.
  Directory? findAndroidSdk() {
    for (final root in androidSdkRoots()) {
      if (Directory(_join(root.path, 'platforms')).existsSync()) {
        return root;
      }
    }
    return null;
  }

  File? findAdb() {
    final onPath = findOnPath('adb.exe');
    if (onPath != null) {
      return onPath;
    }
    for (final root in androidSdkRoots()) {
      final candidate = File(_join(root.path, r'platform-tools\adb.exe'));
      if (candidate.existsSync()) {
        return candidate;
      }
    }
    return null;
  }

  static String _join(String first, String second) {
    return first.endsWith(r'\') ? '$first$second' : '$first\\$second';
  }
}

/// Stops [process] together with its children. `flutter.bat` runs through
/// cmd.exe, so killing the process alone would leave dart and the app running.
Future<void> killProcessTree(Process process) async {
  if (Platform.isWindows) {
    try {
      await Process.run('taskkill', ['/PID', '${process.pid}', '/T', '/F']);
      return;
    } on Object {
      // Fall back to killing the direct child below.
    }
  }
  process.kill();
}
