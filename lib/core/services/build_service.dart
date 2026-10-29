import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/build_configuration.dart';
import '../models/build_log_entry.dart';
import '../models/build_target.dart';
import 'flutter_locator.dart';
import 'project_platforms.dart';
import 'windows_icon.dart';
import 'windows_installer_files.dart';
import 'windows_tools.dart';

class BuildService {
  BuildService({WindowsTools? tools}) : _tools = tools ?? WindowsTools();

  static const _stepProject = 'project';
  static const _stepWorkspace = 'workspace';
  static const _stepBuildScript = 'build-script';
  static const _stepWindowsBuild = 'windows-build';
  static const _stepInstaller = 'installer';
  static const _stepPortable = 'portable';
  static const _stepAndroidBuild = 'android-build';
  static const _stepApkExport = 'apk-export';
  static const _stepSummary = 'summary';
  static const _stepCleanup = 'cleanup';

  /// Folder inside the temporary workspace that holds copies of local `path:`
  /// dependencies living outside the project folder.
  static const _pathDependencyFolder = '.pack_foundry_path_deps';

  final WindowsTools _tools;
  final _installerFiles = const WindowsInstallerFiles();

  Stream<BuildEvent> build(BuildConfiguration configuration) async* {
    final selectedTargets = configuration.targets
        .where((target) => target.selected)
        .toList();

    if (selectedTargets.isEmpty) {
      yield const BuildEvent.log(
        BuildLogEntry(
          title: 'No targets selected',
          detail: 'Select at least one installer target before building.',
          state: BuildLogState.warning,
        ),
      );
      return;
    }

    final projectDirectory = Directory(configuration.projectPath);
    final pubspecFile = File(
      _joinPath(configuration.projectPath, 'pubspec.yaml'),
    );
    if (!projectDirectory.existsSync() || !pubspecFile.existsSync()) {
      yield BuildEvent.log(
        BuildLogEntry(
          title: 'Invalid Flutter project',
          detail: '${configuration.projectPath} does not contain pubspec.yaml.',
          state: BuildLogState.warning,
        ),
      );
      return;
    }

    final outputDirectory = Directory(
      configuration.outputPath ??
          _joinPath(configuration.projectPath, 'build/pack_foundry'),
    );
    final missingPlatformTargets = selectedTargets
        .where(
          (target) => !ProjectPlatforms.supports(
            configuration.projectPath,
            target.platform,
          ),
        )
        .toList();
    final buildableTargets = selectedTargets
        .where((target) => !missingPlatformTargets.contains(target))
        .toList();
    bool has(String platform, String artifact) => buildableTargets.any(
      (target) => target.platform == platform && target.artifact == artifact,
    );
    final hasSetup = has('Windows', BuildTarget.setupExe);
    final hasPortable = has('Windows', BuildTarget.portable);
    final hasScript = has('Windows', BuildTarget.buildScript);
    final hasApk = has('Android', BuildTarget.apk);

    yield BuildEvent.roadmapPlan(createRoadmapPlan(buildableTargets));
    for (final target in missingPlatformTargets) {
      final folder = ProjectPlatforms.folderFor(target.platform);
      yield BuildEvent.log(
        BuildLogEntry(
          title: '${target.platform} ${target.artifact} skipped',
          detail:
              'The project has no $folder/ folder, so it cannot be built for '
              '${target.platform}. Add the platform with: '
              'flutter create --platforms=$folder .',
          state: BuildLogState.warning,
        ),
      );
    }

    if (!hasSetup && !hasPortable && !hasScript && !hasApk) {
      yield const BuildEvent.log(
        BuildLogEntry(
          title: 'No supported targets selected',
          detail: 'Select setup.exe, portable, build_setup.cmd or APK.',
          state: BuildLogState.warning,
        ),
      );
      return;
    }

    Directory? buildTempDirectory;
    final failures = <String>[];

    try {
      yield const BuildEvent.roadmapUpdate(
        BuildRoadmapUpdate(
          id: _stepProject,
          state: BuildRoadmapStepState.running,
          progress: 25,
          detail: 'Checking project folder and pubspec.yaml.',
        ),
      );
      yield BuildEvent.log(
        BuildLogEntry(
          title: 'Analyzing project',
          detail: configuration.projectPath,
          state: BuildLogState.running,
        ),
      );

      await outputDirectory.create(recursive: true);
      yield const BuildEvent.roadmapUpdate(
        BuildRoadmapUpdate(
          id: _stepProject,
          state: BuildRoadmapStepState.success,
          progress: 100,
          detail: 'Project metadata and output folder are ready.',
        ),
      );
      yield BuildEvent.log(
        BuildLogEntry(
          title: 'Output folder is ready',
          detail: outputDirectory.path,
          state: BuildLogState.success,
        ),
      );
      yield const BuildEvent.progress(5);

      if (hasScript) {
        yield* _exportBuildScript(
          configuration: configuration,
          outputDirectory: outputDirectory,
        );
        yield const BuildEvent.progress(10);
      }

      if (hasSetup || hasPortable || hasApk) {
        yield const BuildEvent.roadmapUpdate(
          BuildRoadmapUpdate(
            id: _stepWorkspace,
            state: BuildRoadmapStepState.running,
            progress: 20,
            detail: 'Copying project into a disposable workspace.',
          ),
        );
        yield const BuildEvent.log(
          BuildLogEntry(
            title: 'Preparing temporary build workspace',
            detail:
                'Copying the project and applying window and icon settings without changing source files.',
            state: BuildLogState.running,
          ),
        );

        final buildWorkspaceInfo = await _createBuildWorkspace(
          projectDirectory: projectDirectory,
          configuration: configuration,
        );
        buildTempDirectory = buildWorkspaceInfo.tempDirectory;
        final workspace = buildWorkspaceInfo.workspace;
        if (buildWorkspaceInfo.vendoredDependencies.isNotEmpty) {
          yield BuildEvent.log(
            BuildLogEntry(
              title:
                  'Copied ${buildWorkspaceInfo.vendoredDependencies.length} local path dependencies',
              detail: buildWorkspaceInfo.vendoredDependencies.join('\n'),
              state: BuildLogState.success,
            ),
          );
        }
        yield const BuildEvent.roadmapUpdate(
          BuildRoadmapUpdate(
            id: _stepWorkspace,
            state: BuildRoadmapStepState.success,
            progress: 100,
            detail: 'Temporary project copy is ready.',
          ),
        );
        yield const BuildEvent.progress(15);

        if (hasSetup || hasPortable) {
          yield* _buildWindowsPackages(
            configuration: configuration,
            buildWorkspace: buildWorkspaceInfo,
            outputDirectory: outputDirectory,
            failures: failures,
            setup: hasSetup,
            portable: hasPortable,
          );
        }

        if (hasApk) {
          yield const BuildEvent.progress(60);
          yield* _createApkPackage(
            configuration: configuration,
            workspace: workspace,
            outputDirectory: outputDirectory,
            failures: failures,
          );
        }
      }

      yield BuildEvent.roadmapUpdate(
        BuildRoadmapUpdate(
          id: _stepSummary,
          state: failures.isEmpty
              ? BuildRoadmapStepState.success
              : BuildRoadmapStepState.warning,
          progress: 100,
          detail: failures.isEmpty
              ? 'Selected artifacts were written to the export folder.'
              : 'Failed: ${failures.join(', ')}.',
        ),
      );
      yield const BuildEvent.progress(100);
      yield BuildEvent.log(
        failures.isEmpty
            ? BuildLogEntry(
                title: 'Build completed',
                detail: 'Artifacts were written to ${outputDirectory.path}.',
                state: BuildLogState.success,
              )
            : BuildLogEntry(
                title: 'Build finished with errors',
                detail: 'Failed: ${failures.join(', ')}.',
                state: BuildLogState.warning,
              ),
      );
    } on ProcessException catch (error) {
      yield BuildEvent.log(
        BuildLogEntry(
          title: 'Could not run command',
          detail: error.message,
          state: BuildLogState.warning,
        ),
      );
    } on FileSystemException catch (error) {
      yield BuildEvent.log(
        BuildLogEntry(
          title: 'File system error',
          detail: '${error.message}: ${error.path ?? ''}',
          state: BuildLogState.warning,
        ),
      );
    } finally {
      if (buildTempDirectory != null && buildTempDirectory.existsSync()) {
        yield const BuildEvent.roadmapUpdate(
          BuildRoadmapUpdate(
            id: _stepCleanup,
            state: BuildRoadmapStepState.running,
            progress: 40,
            detail: 'Removing the temporary workspace.',
          ),
        );
        final cleanupResult = await _deleteTemporaryDirectory(
          buildTempDirectory,
        );
        yield BuildEvent.roadmapUpdate(
          BuildRoadmapUpdate(
            id: _stepCleanup,
            state: cleanupResult.deleted
                ? BuildRoadmapStepState.success
                : BuildRoadmapStepState.warning,
            progress: 100,
            detail: cleanupResult.message,
          ),
        );
      }
    }
  }

  List<BuildRoadmapStep> createRoadmapPlan(Iterable<BuildTarget> targets) {
    final selectedTargets = targets.where((target) => target.selected).toList();
    bool has(String platform, String artifact) => selectedTargets.any(
      (target) => target.platform == platform && target.artifact == artifact,
    );
    final hasSetup = has('Windows', BuildTarget.setupExe);
    final hasPortable = has('Windows', BuildTarget.portable);
    final hasScript = has('Windows', BuildTarget.buildScript);
    final hasApk = has('Android', BuildTarget.apk);
    if (!hasSetup && !hasPortable && !hasScript && !hasApk) {
      return const [];
    }
    final hasWindowsBuild = hasSetup || hasPortable;
    final hasWorkspace = hasWindowsBuild || hasApk;
    var number = 1;

    BuildRoadmapStep step({
      required String id,
      required String title,
      required String description,
      required int estimatedSeconds,
    }) {
      return BuildRoadmapStep(
        id: id,
        number: number++,
        title: title,
        description: description,
        state: BuildRoadmapStepState.pending,
        estimatedSeconds: estimatedSeconds,
      );
    }

    return [
      step(
        id: _stepProject,
        title: 'Project',
        description: 'Check pubspec.yaml, app metadata and export folder.',
        estimatedSeconds: 2,
      ),
      if (hasScript)
        step(
          id: _stepBuildScript,
          title: 'Build script',
          description:
              'Write build_setup.cmd, setup.iss and the icon to the export folder.',
          estimatedSeconds: 2,
        ),
      if (hasWorkspace)
        step(
          id: _stepWorkspace,
          title: 'Workspace',
          description:
              'Copy the project and apply settings without touching sources.',
          estimatedSeconds: 8,
        ),
      if (hasWindowsBuild)
        step(
          id: _stepWindowsBuild,
          title: 'Flutter build',
          description: 'Compile the Windows release runner.',
          estimatedSeconds: 150,
        ),
      if (hasSetup)
        step(
          id: _stepInstaller,
          title: 'SETUP.EXE',
          description: 'Generate setup.iss and compile it with Inno Setup.',
          estimatedSeconds: 25,
        ),
      if (hasPortable)
        step(
          id: _stepPortable,
          title: 'PORTABLE',
          description:
              'Pack the app into one exe that runs without installing.',
          estimatedSeconds: 25,
        ),
      if (hasApk) ...[
        step(
          id: _stepAndroidBuild,
          title: 'APK build',
          description: 'Compile the Android release APK with Flutter.',
          estimatedSeconds: 180,
        ),
        step(
          id: _stepApkExport,
          title: 'APK export',
          description: 'Find the generated APK and copy it to export.',
          estimatedSeconds: 5,
        ),
      ],
      step(
        id: _stepSummary,
        title: 'Export',
        description: 'Verify and report generated artifacts.',
        estimatedSeconds: 2,
      ),
      if (hasWorkspace)
        step(
          id: _stepCleanup,
          title: 'Cleanup',
          description: 'Remove the temporary workspace.',
          estimatedSeconds: 10,
        ),
    ];
  }

  Stream<BuildEvent> _exportBuildScript({
    required BuildConfiguration configuration,
    required Directory outputDirectory,
  }) async* {
    yield const BuildEvent.roadmapUpdate(
      BuildRoadmapUpdate(
        id: _stepBuildScript,
        state: BuildRoadmapStepState.running,
        progress: 30,
        detail: 'Writing build_setup.cmd and setup.iss.',
      ),
    );

    final metadata = WindowsInstallerMetadata.fromConfiguration(configuration);
    final hasIcon = await _writeSetupIcon(
      configuration: configuration,
      projectPath: configuration.projectPath,
      destination: File(
        _joinPath(outputDirectory.path, WindowsInstallerFiles.iconFileName),
      ),
    );
    final hasLicense = await _copyLicenseFile(
      projectPath: configuration.projectPath,
      destination: File(
        _joinPath(outputDirectory.path, WindowsInstallerFiles.licenseFileName),
      ),
    );
    await _writeInnoScript(
      File(_joinPath(outputDirectory.path, WindowsInstallerFiles.issFileName)),
      metadata,
      hasIcon: hasIcon,
      hasLicenseFile: hasLicense,
    );
    final script = File(
      _joinPath(outputDirectory.path, WindowsInstallerFiles.scriptFileName),
    );
    // cmd.exe reads scripts in the console code page until the script runs
    // `chcp 65001`, so no byte order mark: it would break the first line.
    await script.writeAsString(
      _installerFiles.buildScript(
        metadata,
        projectPath: configuration.projectPath,
      ),
      encoding: utf8,
    );

    yield BuildEvent.roadmapUpdate(
      BuildRoadmapUpdate(
        id: _stepBuildScript,
        state: BuildRoadmapStepState.success,
        progress: 100,
        detail: script.path,
      ),
    );
    yield BuildEvent.log(
      BuildLogEntry(
        title: 'Created build script',
        detail:
            '${script.path}\nRun it with a double-click; setup.exe is written to '
            '${_joinPath(outputDirectory.path, 'output')}.',
        state: BuildLogState.success,
      ),
    );
  }

  /// Builds the Windows runner once and packs it into the selected Inno
  /// Setup packages.
  Stream<BuildEvent> _buildWindowsPackages({
    required BuildConfiguration configuration,
    required _BuildWorkspace buildWorkspace,
    required Directory outputDirectory,
    required List<String> failures,
    required bool setup,
    required bool portable,
  }) async* {
    final workspace = buildWorkspace.workspace;
    final packages = [
      if (setup) _InnoPackage.setup,
      if (portable) _InnoPackage.portable,
    ];
    Stream<BuildEvent> failBuild(String title, String detail) async* {
      for (final package in packages) {
        failures.add(package.label);
        yield BuildEvent.roadmapUpdate(
          BuildRoadmapUpdate(
            id: package.stepId,
            state: BuildRoadmapStepState.skipped,
            progress: 100,
            detail: 'The Windows build failed.',
          ),
        );
      }
      yield BuildEvent.roadmapUpdate(
        BuildRoadmapUpdate(
          id: _stepWindowsBuild,
          state: BuildRoadmapStepState.warning,
          progress: 100,
          detail: detail,
        ),
      );
      yield BuildEvent.log(
        BuildLogEntry(
          title: title,
          detail: detail,
          state: BuildLogState.warning,
        ),
      );
    }

    yield const BuildEvent.roadmapUpdate(
      BuildRoadmapUpdate(
        id: _stepWindowsBuild,
        state: BuildRoadmapStepState.running,
        progress: 10,
        detail: 'Running flutter build windows --release.',
      ),
    );
    yield const BuildEvent.log(
      BuildLogEntry(
        title: 'Running Flutter Windows build',
        detail: 'flutter build windows --release',
        state: BuildLogState.running,
      ),
    );

    var buildOutcome = _ProcessOutcome();
    yield* _runFlutterLogged(workspace.path, const [
      'build',
      'windows',
      '--release',
    ], outcome: buildOutcome);
    if (buildOutcome.exitCode != 0 &&
        buildOutcome.output.contains('.plugin_symlinks')) {
      // CMake found a plugin link without a target. Regenerating the plugin
      // links and the CMake cache from scratch fixes stale state.
      yield const BuildEvent.log(
        BuildLogEntry(
          title: 'Retrying with fresh plugin links',
          detail: r'Removing windows\flutter\ephemeral and build\windows.',
          state: BuildLogState.running,
        ),
      );
      for (final generated in [
        r'windows\flutter\ephemeral',
        r'build\windows',
      ]) {
        final directory = Directory(_joinPath(workspace.path, generated));
        if (directory.existsSync()) {
          await directory.delete(recursive: true);
        }
      }
      buildOutcome = _ProcessOutcome();
      yield* _runFlutterLogged(workspace.path, const [
        'build',
        'windows',
        '--release',
      ], outcome: buildOutcome);
    }
    if (buildOutcome.exitCode != 0) {
      final output = buildOutcome.output.toLowerCase();
      final symlinkHint =
          output.contains('symlink support') ||
              output.contains('developer mode')
          ? '\nEnable Developer Mode: start ms-settings:developers'
          : '';
      yield* failBuild(
        'Flutter build failed',
        '${buildOutcome.output}$symlinkHint',
      );
      return;
    }

    final releaseDirectory = Directory(
      _joinPath(workspace.path, WindowsInstallerFiles.releaseFolder),
    );
    final metadata = WindowsInstallerMetadata.fromConfiguration(configuration);
    final exeName = _findRunnerExecutable(releaseDirectory, metadata.exeName);
    if (exeName == null) {
      yield* failBuild(
        'Windows runner not found',
        'Expected an .exe in ${releaseDirectory.path}.',
      );
      return;
    }

    yield const BuildEvent.progress(45);
    yield BuildEvent.roadmapUpdate(
      BuildRoadmapUpdate(
        id: _stepWindowsBuild,
        state: BuildRoadmapStepState.success,
        progress: 100,
        detail: _joinPath(releaseDirectory.path, exeName),
      ),
    );

    for (final package in packages) {
      yield* _compileInnoPackage(
        package: package,
        configuration: configuration,
        metadata: metadata,
        buildWorkspace: buildWorkspace,
        releaseDirectory: releaseDirectory,
        exeName: exeName,
        outputDirectory: outputDirectory,
        failures: failures,
      );
    }
  }

  Stream<BuildEvent> _compileInnoPackage({
    required _InnoPackage package,
    required BuildConfiguration configuration,
    required WindowsInstallerMetadata metadata,
    required _BuildWorkspace buildWorkspace,
    required Directory releaseDirectory,
    required String exeName,
    required Directory outputDirectory,
    required List<String> failures,
  }) async* {
    final stepId = package.stepId;
    Stream<BuildEvent> fail(String title, String detail) async* {
      failures.add(package.label);
      yield BuildEvent.roadmapUpdate(
        BuildRoadmapUpdate(
          id: stepId,
          state: BuildRoadmapStepState.warning,
          progress: 100,
          detail: detail,
        ),
      );
      yield BuildEvent.log(
        BuildLogEntry(
          title: title,
          detail: detail,
          state: BuildLogState.warning,
        ),
      );
    }

    final issName = package == _InnoPackage.portable
        ? WindowsInstallerFiles.portableIssFileName
        : WindowsInstallerFiles.issFileName;
    yield BuildEvent.roadmapUpdate(
      BuildRoadmapUpdate(
        id: stepId,
        state: BuildRoadmapStepState.running,
        progress: 10,
        detail: 'Generating $issName.',
      ),
    );

    final iscc = _tools.findInnoCompiler();
    if (iscc == null) {
      yield* fail(
        'Inno Setup was not found',
        'ISCC.exe is not in PATH or Program Files. Install Inno Setup 6: '
            '${WindowsTools.innoSetupWinget}',
      );
      return;
    }

    final innoDirectory = Directory(
      _joinPath(buildWorkspace.tempDirectory.path, 'inno'),
    );
    await innoDirectory.create(recursive: true);
    final iconFile = File(
      _joinPath(innoDirectory.path, WindowsInstallerFiles.iconFileName),
    );
    final workspaceIcon = buildWorkspace.icon;
    final hasIcon = workspaceIcon != null && workspaceIcon.existsSync();
    if (hasIcon && !iconFile.existsSync()) {
      await workspaceIcon.copy(iconFile.path);
    }
    final issFile = File(_joinPath(innoDirectory.path, issName));
    if (package == _InnoPackage.portable) {
      await _writeIss(
        issFile,
        _installerFiles.portableScript(metadata, hasIcon: hasIcon),
      );
    } else {
      final hasLicense = await _copyLicenseFile(
        projectPath: configuration.projectPath,
        destination: File(
          _joinPath(innoDirectory.path, WindowsInstallerFiles.licenseFileName),
        ),
      );
      await _writeInnoScript(
        issFile,
        metadata,
        hasIcon: hasIcon,
        hasLicenseFile: hasLicense,
      );
    }

    final packageFile = File(
      _joinPath(
        outputDirectory.path,
        package == _InnoPackage.portable
            ? metadata.portableFileName
            : metadata.setupFileName,
      ),
    );
    if (packageFile.existsSync()) {
      await packageFile.delete();
    }
    final arguments = [
      '/Qp',
      '/DSourceDir=${releaseDirectory.path}',
      '/DMyAppExeName=$exeName',
      '/O${_withoutTrailingSeparator(outputDirectory.path)}',
      issFile.path,
    ];
    yield BuildEvent.log(
      BuildLogEntry(
        title: package == _InnoPackage.portable
            ? 'Packing portable app with Inno Setup'
            : 'Compiling installer with Inno Setup',
        detail: '"${iscc.path}" ${arguments.join(' ')}',
        state: BuildLogState.running,
      ),
    );
    yield BuildEvent.roadmapUpdate(
      BuildRoadmapUpdate(
        id: stepId,
        state: BuildRoadmapStepState.running,
        progress: 40,
        detail: 'Running ISCC.exe.',
      ),
    );

    final isccOutcome = _ProcessOutcome();
    yield* _runLogged(
      title: 'ISCC',
      executable: iscc.path,
      arguments: arguments,
      workingDirectory: innoDirectory.path,
      outcome: isccOutcome,
    );
    if (isccOutcome.exitCode != 0 || !packageFile.existsSync()) {
      yield* fail('Inno Setup compilation failed', isccOutcome.output);
      return;
    }

    yield const BuildEvent.progress(58);
    yield BuildEvent.roadmapUpdate(
      BuildRoadmapUpdate(
        id: stepId,
        state: BuildRoadmapStepState.success,
        progress: 100,
        detail: packageFile.path,
      ),
    );
    yield BuildEvent.log(
      BuildLogEntry(
        title: 'Created ${package.label}',
        detail: packageFile.path,
        state: BuildLogState.success,
      ),
    );
  }

  Stream<BuildEvent> _createApkPackage({
    required BuildConfiguration configuration,
    required Directory workspace,
    required Directory outputDirectory,
    required List<String> failures,
  }) async* {
    Stream<BuildEvent> fail(String stepId, String title, String detail) async* {
      failures.add('APK');
      yield BuildEvent.roadmapUpdate(
        BuildRoadmapUpdate(
          id: stepId,
          state: BuildRoadmapStepState.warning,
          progress: 100,
          detail: detail,
        ),
      );
      yield BuildEvent.log(
        BuildLogEntry(
          title: title,
          detail: detail,
          state: BuildLogState.warning,
        ),
      );
    }

    yield const BuildEvent.roadmapUpdate(
      BuildRoadmapUpdate(
        id: _stepAndroidBuild,
        state: BuildRoadmapStepState.running,
        progress: 10,
        detail: 'Running flutter build apk --release.',
      ),
    );
    yield const BuildEvent.log(
      BuildLogEntry(
        title: 'Building Android APK',
        detail: 'flutter build apk --release',
        state: BuildLogState.running,
      ),
    );

    final buildOutcome = _ProcessOutcome();
    yield* _runFlutterLogged(
      workspace.path,
      const ['build', 'apk', '--release'],
      outcome: buildOutcome,
      environment: androidBuildEnvironment(_tools),
    );
    if (buildOutcome.exitCode != 0) {
      yield* fail(
        _stepAndroidBuild,
        'Android APK build failed',
        buildOutcome.output,
      );
      return;
    }

    yield const BuildEvent.progress(90);
    yield const BuildEvent.roadmapUpdate(
      BuildRoadmapUpdate(
        id: _stepAndroidBuild,
        state: BuildRoadmapStepState.success,
        progress: 100,
        detail: 'Android release APK was compiled.',
      ),
    );
    yield const BuildEvent.roadmapUpdate(
      BuildRoadmapUpdate(
        id: _stepApkExport,
        state: BuildRoadmapStepState.running,
        progress: 40,
        detail: r'Looking for build\app\outputs\flutter-apk\app-release.apk.',
      ),
    );

    final apkFile = findReleaseApk(workspace.path);
    if (apkFile == null) {
      yield* fail(
        _stepApkExport,
        'Android APK not found',
        r'Expected build\app\outputs\flutter-apk\app-release.apk.',
      );
      return;
    }

    final appName = WindowsInstallerMetadata.displayAppName(
      configuration.appName,
    );
    final version = WindowsInstallerMetadata.releaseVersion(
      configuration.releaseTag,
    );
    final outputFile = File(
      _joinPath(
        outputDirectory.path,
        '${[WindowsInstallerMetadata.safeFileName(appName), 'android', WindowsInstallerMetadata.safeFileName(version), 'universal'].join('_')}.apk',
      ),
    );
    if (outputFile.existsSync()) {
      await outputFile.delete();
    }
    await apkFile.copy(outputFile.path);

    yield BuildEvent.roadmapUpdate(
      BuildRoadmapUpdate(
        id: _stepApkExport,
        state: BuildRoadmapStepState.success,
        progress: 100,
        detail: outputFile.path,
      ),
    );
    yield BuildEvent.log(
      BuildLogEntry(
        title: 'Created Android APK',
        detail: outputFile.path,
        state: BuildLogState.success,
      ),
    );
  }

  Future<void> _writeInnoScript(
    File file,
    WindowsInstallerMetadata metadata, {
    required bool hasIcon,
    required bool hasLicenseFile,
  }) {
    return _writeIss(
      file,
      _installerFiles.innoSetupScript(
        metadata,
        hasIcon: hasIcon,
        hasLicenseFile: hasLicenseFile,
      ),
    );
  }

  Future<void> _writeIss(File file, String script) async {
    // Inno Setup reads a script as UTF-8 only when it starts with a BOM, which
    // non-Latin app names need.
    await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(script)]);
  }

  /// Writes the installer icon: the icon picked in PackFoundry converted to
  /// `.ico`, or the runner icon the project already ships.
  Future<bool> _writeSetupIcon({
    required BuildConfiguration configuration,
    required String projectPath,
    required File destination,
  }) async {
    final iconPath = configuration.iconPath;
    if (iconPath != null && iconPath.isNotEmpty) {
      final written = await const WindowsIcon().write(
        source: File(iconPath),
        destination: destination,
      );
      if (written) {
        return true;
      }
    }
    final runnerIcon = File(_joinPath(projectPath, _runnerIconPath));
    if (runnerIcon.existsSync()) {
      await destination.parent.create(recursive: true);
      await runnerIcon.copy(destination.path);
      return true;
    }
    if (destination.existsSync()) {
      await destination.delete();
    }
    return false;
  }

  static const _runnerIconPath = 'windows/runner/resources/app_icon.ico';

  Future<bool> _copyLicenseFile({
    required String projectPath,
    required File destination,
  }) async {
    for (final name in const [
      'LICENSE',
      'LICENSE.txt',
      'LICENSE.md',
      'COPYING',
    ]) {
      final file = File(_joinPath(projectPath, name));
      if (file.existsSync()) {
        await destination.parent.create(recursive: true);
        await file.copy(destination.path);
        return true;
      }
    }
    if (destination.existsSync()) {
      await destination.delete();
    }
    return false;
  }

  String? _findRunnerExecutable(Directory releaseDirectory, String expected) {
    if (!releaseDirectory.existsSync()) {
      return null;
    }
    if (File(_joinPath(releaseDirectory.path, expected)).existsSync()) {
      return expected;
    }
    for (final entity in releaseDirectory.listSync()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.exe')) {
        return _basename(entity.path);
      }
    }
    return null;
  }

  /// Environment for `flutter build apk`: points ANDROID_HOME at the SDK
  /// PackFoundry found when the user did not configure one.
  static Map<String, String>? androidBuildEnvironment(WindowsTools tools) {
    final configured =
        tools.variable('ANDROID_HOME') ?? tools.variable('ANDROID_SDK_ROOT');
    if (configured != null && configured.isNotEmpty) {
      return null;
    }
    final sdk = tools.findAndroidSdk();
    if (sdk == null) {
      return null;
    }
    return {'ANDROID_HOME': sdk.path, 'ANDROID_SDK_ROOT': sdk.path};
  }

  static File? findReleaseApk(String projectPath) {
    final separator = Platform.pathSeparator;
    final standardApk = File(
      [
        projectPath,
        'build',
        'app',
        'outputs',
        'flutter-apk',
        'app-release.apk',
      ].join(separator),
    );
    if (standardApk.existsSync()) {
      return standardApk;
    }

    final outputDirectory = Directory(
      [projectPath, 'build', 'app', 'outputs'].join(separator),
    );
    if (!outputDirectory.existsSync()) {
      return null;
    }
    for (final entity in outputDirectory.listSync(recursive: true)) {
      if (entity is File &&
          entity.path.endsWith('.apk') &&
          entity.path.contains('release')) {
        return entity;
      }
    }
    return null;
  }

  Future<_CleanupResult> _deleteTemporaryDirectory(Directory directory) async {
    // Build servers that flutter and MSBuild start can hold files for a few
    // seconds after the build, so a failed delete is retried.
    for (var attempt = 0; attempt < 5; attempt++) {
      if (!directory.existsSync()) {
        break;
      }
      try {
        await directory.delete(recursive: true);
        break;
      } on FileSystemException catch (error) {
        if (attempt == 4) {
          return _CleanupResult(
            deleted: false,
            message:
                'Build is finished, but ${directory.path} could not be removed: ${error.message}.',
          );
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    return const _CleanupResult(
      deleted: true,
      message: 'Temporary files were removed.',
    );
  }

  Future<_BuildWorkspace> _createBuildWorkspace({
    required Directory projectDirectory,
    required BuildConfiguration configuration,
  }) async {
    final tempRoot = await Directory.systemTemp.createTemp(
      'pack_foundry_build_',
    );
    final workspace = Directory(_joinPath(tempRoot.path, 'project'));
    await _copyProjectDirectory(projectDirectory, workspace);
    final vendoredDependencies = await _vendorPathDependencies(
      workspace: workspace,
      projectDirectory: projectDirectory,
    );
    await _applyWindowSizeOverride(workspace, configuration);
    final icon = File(_joinPath(tempRoot.path, 'icon/app_icon.ico'));
    final hasIcon = await _writeSetupIcon(
      configuration: configuration,
      projectPath: workspace.path,
      destination: icon,
    );
    final runnerIcon = File(_joinPath(workspace.path, _runnerIconPath));
    if (hasIcon && runnerIcon.parent.existsSync()) {
      await icon.copy(runnerIcon.path);
    }
    return _BuildWorkspace(
      tempDirectory: tempRoot,
      workspace: workspace,
      icon: hasIcon ? icon : null,
      vendoredDependencies: vendoredDependencies,
    );
  }

  /// Copies local `path:` dependencies that live outside the project folder into
  /// the workspace, so the temporary copy resolves them on its own.
  ///
  /// The workspace holds a copy of the selected folder only, so a sibling
  /// dependency such as `../shared/sync_ui` would otherwise point at a
  /// directory that was never copied and `flutter pub get` would fail with
  /// "could not find package".
  /// Every dependency is vendored flat into [_pathDependencyFolder] and its own
  /// path dependencies are rewritten to siblings inside that folder, which also
  /// covers transitive chains such as `sync_ui` -> `sync_net` -> `sync_core`.
  Future<List<String>> _vendorPathDependencies({
    required Directory workspace,
    required Directory projectDirectory,
  }) async {
    final vendored = <String>[];
    final pending = await _rewritePathDependencies(
      pubspec: File(_joinPath(workspace.path, 'pubspec.yaml')),
      sourceDirectory: projectDirectory,
      relativePrefix: _pathDependencyFolder,
    );

    while (pending.isNotEmpty) {
      final dependency = pending.removeLast();
      final destination = Directory(
        _joinPath(
          _joinPath(workspace.path, _pathDependencyFolder),
          dependency.name,
        ),
      );
      if (destination.existsSync()) {
        continue;
      }
      if (!dependency.directory.existsSync()) {
        // Leave the broken reference in place so flutter pub get reports it.
        continue;
      }

      await _copyProjectDirectory(dependency.directory, destination);
      vendored.add('${dependency.name} <- ${dependency.directory.path}');
      pending.addAll(
        await _rewritePathDependencies(
          pubspec: File(_joinPath(destination.path, 'pubspec.yaml')),
          sourceDirectory: dependency.directory,
          relativePrefix: '..',
        ),
      );
    }

    return vendored;
  }

  /// Rewrites every `path:` dependency of [pubspec] that points outside
  /// [sourceDirectory] to `$relativePrefix/<package name>` and returns the
  /// packages that have to be copied there.
  Future<List<_PathDependency>> _rewritePathDependencies({
    required File pubspec,
    required Directory sourceDirectory,
    required String relativePrefix,
  }) async {
    if (!pubspec.existsSync()) {
      return [];
    }

    const dependencySections = {
      'dependencies:',
      'dev_dependencies:',
      'dependency_overrides:',
    };
    final lines = (await pubspec.readAsString())
        .replaceAll('\r\n', '\n')
        .split('\n');
    final rewritten = <String>[];
    final dependencies = <_PathDependency>[];
    var inDependencySection = false;
    var dependencyKeyIndent = -1;
    var dependencyName = '';
    var gitIndent = -1;

    for (final line in lines) {
      final trimmed = line.trimLeft();
      final indent = line.length - trimmed.length;

      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        rewritten.add(line);
        continue;
      }
      if (indent == 0) {
        inDependencySection = dependencySections.contains(trimmed);
        dependencyKeyIndent = -1;
        dependencyName = '';
        gitIndent = -1;
        rewritten.add(line);
        continue;
      }
      if (!inDependencySection) {
        rewritten.add(line);
        continue;
      }

      if (dependencyKeyIndent < 0) {
        dependencyKeyIndent = indent;
      }
      if (indent <= dependencyKeyIndent) {
        // A dependency name such as `sync_ui:`, or the package literally named
        // `path` in `path: ^1.9.0` — never a path source.
        dependencyName = trimmed.split(':').first.trim();
        gitIndent = -1;
        rewritten.add(line);
        continue;
      }
      // A `path:` nested under `git:` names a directory inside the repository.
      if (gitIndent >= 0 && indent <= gitIndent) {
        gitIndent = -1;
      }
      if (trimmed == 'git:') {
        gitIndent = indent;
        rewritten.add(line);
        continue;
      }
      if (gitIndent >= 0 || !trimmed.startsWith('path:')) {
        rewritten.add(line);
        continue;
      }

      final rawPath = _unquotePubspecValue(
        trimmed.substring('path:'.length).trim(),
      );
      if (rawPath.isEmpty || dependencyName.isEmpty) {
        rewritten.add(line);
        continue;
      }
      final resolved = _resolvePath(sourceDirectory.path, rawPath);
      if (_isInsideDirectory(path: resolved, directory: sourceDirectory.path)) {
        // Already part of the copied tree, the relative path still holds.
        rewritten.add(line);
        continue;
      }

      dependencies.add(
        _PathDependency(name: dependencyName, directory: Directory(resolved)),
      );
      rewritten.add('${' ' * indent}path: $relativePrefix/$dependencyName');
    }

    if (dependencies.isEmpty) {
      return dependencies;
    }
    await pubspec.writeAsString(rewritten.join('\n'));
    return dependencies;
  }

  String _unquotePubspecValue(String value) {
    final withoutComment = value.startsWith('"') || value.startsWith("'")
        ? value
        : value.split('#').first;
    final trimmed = withoutComment.trim();
    if (trimmed.length >= 2 &&
        (trimmed.startsWith('"') && trimmed.endsWith('"') ||
            trimmed.startsWith("'") && trimmed.endsWith("'"))) {
      return trimmed.substring(1, trimmed.length - 1).trim();
    }
    return trimmed;
  }

  /// Resolves [target] against [base] and collapses `.` and `..` segments.
  String _resolvePath(String base, String target) {
    final normalizedTarget = target.replaceAll('\\', '/');
    final isAbsolute =
        normalizedTarget.startsWith('/') ||
        RegExp(r'^[a-zA-Z]:/').hasMatch(normalizedTarget);
    final combined = isAbsolute
        ? normalizedTarget
        : '${base.replaceAll('\\', '/')}/$normalizedTarget';

    final hasRootPrefix = combined.startsWith('/');
    final segments = <String>[];
    for (final segment in combined.split('/')) {
      if (segment.isEmpty || segment == '.') {
        continue;
      }
      if (segment == '..' && segments.isNotEmpty && segments.last != '..') {
        segments.removeLast();
        continue;
      }
      segments.add(segment);
    }

    final resolved = segments.join(Platform.pathSeparator);
    return hasRootPrefix ? '${Platform.pathSeparator}$resolved' : resolved;
  }

  bool _isInsideDirectory({required String path, required String directory}) {
    final normalizedDirectory = directory.endsWith(Platform.pathSeparator)
        ? directory
        : '$directory${Platform.pathSeparator}';
    return path.startsWith(normalizedDirectory);
  }

  Future<void> _copyProjectDirectory(
    Directory source,
    Directory destination,
  ) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(
      recursive: true,
      followLinks: false,
    )) {
      final relativePath = entity.path.substring(source.path.length + 1);
      if (_shouldSkipProjectPath(relativePath)) {
        continue;
      }

      final newPath = _joinPath(destination.path, relativePath);
      if (entity is Directory) {
        await Directory(newPath).create(recursive: true);
      } else if (entity is File) {
        await File(newPath).parent.create(recursive: true);
        await entity.copy(newPath);
      }
    }
  }

  bool _shouldSkipProjectPath(String relativePath) {
    final parts = relativePath.split(Platform.pathSeparator);
    // Plugin lists and symlinks are generated by flutter for the folder they
    // live in; stale copies can leave CMake with links to nowhere.
    if (parts.length == 1 && parts.single.startsWith('.flutter-plugins')) {
      return true;
    }
    for (var index = 1; index < parts.length; index++) {
      if (parts[index] == 'ephemeral' &&
          parts[index - 1].toLowerCase() == 'flutter') {
        return true;
      }
    }
    return parts.any((part) {
      return part == 'build' ||
          part == '.dart_tool' ||
          part == '.git' ||
          part == '.idea';
    });
  }

  Future<void> _applyWindowSizeOverride(
    Directory workspace,
    BuildConfiguration configuration,
  ) async {
    final width = configuration.windowWidth;
    final height = configuration.windowHeight;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return;
    }

    final file = File(_joinPath(workspace.path, 'windows/runner/main.cpp'));
    if (!file.existsSync()) {
      return;
    }

    final content = await file.readAsString();
    final updated = content.replaceFirst(
      RegExp(r'Win32Window::Size\s+size\s*\(\s*\d+\s*,\s*\d+\s*\)'),
      'Win32Window::Size size($width, $height)',
    );
    if (updated != content) {
      await file.writeAsString(updated);
    }
  }

  /// Runs the resolved flutter executable and streams its output into the
  /// build log.
  Stream<BuildEvent> _runFlutterLogged(
    String projectPath,
    List<String> arguments, {
    required _ProcessOutcome outcome,
    Map<String, String>? environment,
  }) async* {
    final locator = FlutterLocator();
    final flutter = locator.find();
    if (flutter == null) {
      throw ProcessException(
        'flutter',
        arguments,
        'Flutter SDK was not found. Install it in Settings → Common tools, '
            r'or add the flutter\bin folder to PATH.',
      );
    }
    yield* _runLogged(
      title: 'flutter ${arguments.take(2).join(' ')}',
      executable: flutter.path,
      arguments: arguments,
      workingDirectory: projectPath,
      environment: {...?environment, ...locator.environmentFor(flutter)},
      outcome: outcome,
    );
  }

  /// Starts [executable] and turns every output line into a log entry, so the
  /// build console shows the tool output while it runs. `.bat` files cannot be
  /// started without cmd.exe, so they run in a shell.
  Stream<BuildEvent> _runLogged({
    required String title,
    required String executable,
    required List<String> arguments,
    required String workingDirectory,
    required _ProcessOutcome outcome,
    Map<String, String>? environment,
  }) async* {
    final lower = executable.toLowerCase();
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: lower.endsWith('.bat') || lower.endsWith('.cmd'),
    );
    final tail = _OutputTail(maxLines: 40);
    await for (final line in _processLines(process)) {
      final trimmed = line.trimRight();
      if (trimmed.trim().isEmpty) {
        continue;
      }
      tail.add(trimmed);
      yield BuildEvent.log(
        BuildLogEntry(
          title: title,
          detail: trimmed,
          state: BuildLogState.running,
        ),
      );
    }
    outcome.exitCode = await process.exitCode;
    outcome.output = tail.text.isEmpty
        ? 'Process exited with code ${outcome.exitCode}.'
        : tail.text;
  }

  Stream<String> _processLines(Process process) {
    final controller = StreamController<String>();
    var openStreams = 2;

    void closeWhenReady() {
      openStreams -= 1;
      if (openStreams == 0) {
        unawaited(controller.close());
      }
    }

    void listen(Stream<List<int>> stream) {
      stream
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (!controller.isClosed) {
                controller.add(line);
              }
            },
            onError: controller.addError,
            onDone: closeWhenReady,
            cancelOnError: false,
          );
    }

    listen(process.stdout);
    listen(process.stderr);
    return controller.stream;
  }

  String _withoutTrailingSeparator(String path) {
    if (path.length > 3 && (path.endsWith(r'\') || path.endsWith('/'))) {
      return path.substring(0, path.length - 1);
    }
    return path;
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

  String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final trimmed = normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
    return trimmed.substring(trimmed.lastIndexOf('/') + 1);
  }
}

/// Inno Setup packages built from the same Windows runner.
enum _InnoPackage {
  setup('setup.exe', BuildService._stepInstaller),
  portable('portable', BuildService._stepPortable);

  const _InnoPackage(this.label, this.stepId);

  final String label;
  final String stepId;
}

class _ProcessOutcome {
  int exitCode = -1;

  /// The last lines the process printed, for failure messages.
  String output = '';
}

class _OutputTail {
  _OutputTail({required this.maxLines});

  final int maxLines;
  final List<String> _lines = [];

  void add(String line) {
    _lines.add(line);
    if (_lines.length > maxLines) {
      _lines.removeAt(0);
    }
  }

  String get text => _lines.join('\n');
}

class _CleanupResult {
  const _CleanupResult({required this.deleted, required this.message});

  final bool deleted;
  final String message;
}

class _BuildWorkspace {
  const _BuildWorkspace({
    required this.tempDirectory,
    required this.workspace,
    this.icon,
    this.vendoredDependencies = const [],
  });

  final Directory tempDirectory;
  final Directory workspace;

  /// The `.ico` used for the runner and the installer, if there is one.
  final File? icon;

  /// Local `path:` dependencies that were copied into the workspace, as
  /// `<package name> <- <source directory>` lines for the build log.
  final List<String> vendoredDependencies;
}

class _PathDependency {
  const _PathDependency({required this.name, required this.directory});

  final String name;
  final Directory directory;
}

class BuildEvent {
  const BuildEvent.log(BuildLogEntry this.logEntry)
    : progress = null,
      roadmapPlan = null,
      roadmapUpdate = null;

  const BuildEvent.progress(int this.progress)
    : logEntry = null,
      roadmapPlan = null,
      roadmapUpdate = null;

  const BuildEvent.roadmapPlan(List<BuildRoadmapStep> this.roadmapPlan)
    : logEntry = null,
      progress = null,
      roadmapUpdate = null;

  const BuildEvent.roadmapUpdate(BuildRoadmapUpdate this.roadmapUpdate)
    : logEntry = null,
      progress = null,
      roadmapPlan = null;

  final BuildLogEntry? logEntry;
  final int? progress;
  final List<BuildRoadmapStep>? roadmapPlan;
  final BuildRoadmapUpdate? roadmapUpdate;
}
