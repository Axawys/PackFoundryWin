import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/build_configuration.dart';
import '../../core/models/build_log_entry.dart';
import '../../core/models/build_target.dart';
import '../../core/models/chip_tone.dart';
import '../../core/models/config_preset.dart';
import '../../core/models/developer_defaults.dart';
import '../../core/models/licenses.dart';
import '../../core/models/output_file_name.dart';
import '../../core/models/project_config.dart';
import '../../core/models/tool_status.dart';
import '../../core/services/android_device_service.dart';
import '../../core/services/app_preferences.dart';
import '../../core/services/build_service.dart';
import '../../core/services/flutter_locator.dart';
import '../../core/services/project_config_service.dart';
import '../../core/services/project_icon_finder.dart';
import '../../core/services/project_platforms.dart';
import '../../core/services/toolchain_service.dart';
import '../../core/services/windows_installer_files.dart';
import '../../core/services/windows_tools.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/build_panel.dart';
import '../widgets/project_workspace.dart';
import '../widgets/settings_workspace.dart';
import '../widgets/workspace_card.dart';
import '../widgets/welcome_dialog.dart';

class PackFoundryHomePage extends StatefulWidget {
  const PackFoundryHomePage({
    required this.themeMode,
    required this.localeMode,
    required this.showWelcome,
    required this.onThemeModeChanged,
    required this.onLocaleModeChanged,
    required this.onWelcomeCompleted,
    required this.enableToolchainDiagnostics,
    super.key,
  });

  final ThemeMode themeMode;
  final AppLocaleMode localeMode;
  final bool showWelcome;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<AppLocaleMode> onLocaleModeChanged;
  final WelcomeCompleted onWelcomeCompleted;
  final bool enableToolchainDiagnostics;

  @override
  State<PackFoundryHomePage> createState() => _PackFoundryHomePageState();
}

class _PackFoundryHomePageState extends State<PackFoundryHomePage>
    with SingleTickerProviderStateMixin {
  static const _defaultAppName = 'My Flutter App';
  static const _workspaceCount = 3;

  final _buildService = BuildService();
  final _toolchainService = ToolchainService();
  final _projectConfigService = const ProjectConfigService();
  final _androidDeviceService = AndroidDeviceService();
  final _appPreferences = AppPreferences();
  final _appNameController = TextEditingController(text: _defaultAppName);
  final _projectPathController = TextEditingController();
  final _releaseTagController = TextEditingController();
  final _developerEmailController = TextEditingController();
  final _publisherNameController = TextEditingController();
  final _homepageUrlController = TextEditingController();
  final _licenseController = TextEditingController(
    text: LicenseOption.defaultId,
  );
  final _descriptionController = TextEditingController();
  final _defaultPublisherController = TextEditingController();
  final _defaultEmailController = TextEditingController();
  final _githubProfileController = TextEditingController();
  final _defaultLicenseController = TextEditingController(
    text: LicenseOption.defaultId,
  );
  final _widthController = TextEditingController(
    text: _WindowSize.packFoundryDefault.width.toString(),
  );
  final _heightController = TextEditingController(
    text: _WindowSize.packFoundryDefault.height.toString(),
  );
  final _buildLog = <BuildLogEntry>[];
  final _roadmapSteps = <BuildRoadmapStep>[];
  final _projectChecks = <ProjectCheck>[];
  final _configPresets = <ConfigPreset>[];

  /// Targets that were selected when their platform disappeared from the
  /// project; they are selected again once the platform is back.
  final _selectionsOfHiddenTargets = <BuildTarget>{};
  Timer? _metadataSaveTimer;
  Timer? _defaultsSaveTimer;
  bool _metadataListenersAttached = false;
  bool _defaultsListenersAttached = false;

  /// Release fields that show the developer defaults from the settings.
  final Set<DeveloperField> _defaultFields = DeveloperField.values.toSet();

  /// The homepage from the project's pubspec, used as the default homepage
  /// while no GitHub profile is set.
  String? _projectHomepage;

  String? _projectPath;
  String? _activeConfigPath;
  String? _iconPath;

  /// True while [_iconPath] was found in the project rather than chosen by
  /// the user or a config, so switching projects may replace it.
  bool _iconAutoDetected = false;
  String? _outputPath;
  String? _defaultOutputPath;
  Set<FileNamePart> _fileNameParts = OutputFileName.defaultParts;
  bool _isBuilding = false;
  bool _isRunningProject = false;

  /// Whether the selected project has a desktop runner. Without one there is
  /// nothing `flutter run` could launch, so the run action stays hidden.
  bool _hasDesktopRunner = false;
  bool _isSendingToDevice = false;

  /// Short progress line shown next to the send action, because its technical
  /// log lives on another workspace tab.
  String? _sendToDeviceStatus;
  Process? _sendToDeviceProcess;
  bool _sendToDeviceCancelled = false;
  ToolchainInstallTarget? _installingToolTarget;
  int _buildProgress = 0;
  bool _welcomeDialogShown = false;
  int _workspaceIndex = 1;
  late final TabController _workspaceTabController;
  ToolAvailability _flutterStatus = ToolAvailability.available;
  ToolAvailability _gitStatus = ToolAvailability.available;
  ToolAvailability _visualStudioStatus = ToolAvailability.available;
  ToolAvailability _innoSetupStatus = ToolAvailability.available;
  ToolAvailability _developerModeStatus = ToolAvailability.available;
  ToolAvailability _javaStatus = ToolAvailability.available;
  ToolAvailability _androidSdkStatus = ToolAvailability.available;
  ToolInstallProgress? _installProgress;
  bool _toolInstallCancelRequested = false;

  /// False until the first toolchain probe finishes; targets keep their
  /// optimistic defaults until then.
  bool _toolchainChecked = false;
  Process? _runningProjectProcess;

  final List<BuildTarget> _targets = [
    BuildTarget(
      platform: 'Windows',
      artifact: BuildTarget.setupExe,
      status: TargetStatus.ready,
      selected: true,
    ),
    BuildTarget(
      platform: 'Windows',
      artifact: BuildTarget.portable,
      status: TargetStatus.ready,
    ),
    BuildTarget(
      platform: 'Windows',
      artifact: BuildTarget.buildScript,
      status: TargetStatus.ready,
    ),
    BuildTarget(
      platform: 'Android',
      artifact: BuildTarget.apk,
      status: TargetStatus.installable,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _workspaceTabController = TabController(
      length: _workspaceCount,
      initialIndex: _workspaceIndex,
      vsync: this,
    );
    _workspaceTabController.addListener(_handleWorkspaceTabChanged);
    // Targets selected out of the box show their plan right away.
    _replaceRoadmapWithPreview();
    _loadReleaseMetadata();
    _loadDefaultOutputPath();
    _loadFileNameParts();
    _loadConfigPresets();
    if (widget.enableToolchainDiagnostics) {
      _refreshToolchainStatus();
    }
  }

  void _handleWorkspaceTabChanged() {
    final index = _workspaceTabController.index;
    if (index == _workspaceIndex) {
      return;
    }
    setState(() {
      _workspaceIndex = index;
    });
    if (index == 1) {
      _refreshProjectPlatforms();
    }
  }

  Future<void> _loadReleaseMetadata() async {
    final metadata = await _appPreferences.loadReleaseMetadata();
    if (!mounted) {
      return;
    }

    _restoreControllerText(_releaseTagController, metadata.releaseTag);
    _restoreControllerText(_developerEmailController, metadata.developerEmail);
    _restoreControllerText(_publisherNameController, metadata.publisherName);
    _restoreControllerText(_homepageUrlController, metadata.homepageUrl);
    _restoreControllerText(_descriptionController, metadata.description);
    _attachMetadataListeners();
    await _loadDeveloperDefaults(metadata);
  }

  Future<void> _loadDeveloperDefaults(SavedReleaseMetadata metadata) async {
    // The first run with defaults starts from the last typed values.
    final defaults =
        await _appPreferences.loadDeveloperDefaults() ??
        DeveloperDefaults(
          publisherName: metadata.publisherName,
          developerEmail: metadata.developerEmail,
        );
    await _appPreferences.saveDeveloperDefaults(defaults);
    final fields = await _appPreferences.loadDefaultFields();
    if (!mounted) {
      return;
    }

    setState(() {
      _defaultPublisherController.text = defaults.publisherName;
      _defaultEmailController.text = defaults.developerEmail;
      _githubProfileController.text = defaults.githubProfile;
      _defaultLicenseController.text = defaults.license;
      _defaultFields
        ..clear()
        ..addAll(fields);
      _applyDeveloperDefaults();
    });
    if (!_defaultsListenersAttached) {
      for (final controller in _defaultsControllers) {
        controller.addListener(_handleDeveloperDefaultsChanged);
      }
      _defaultsListenersAttached = true;
    }
  }

  List<TextEditingController> get _defaultsControllers => [
    _defaultPublisherController,
    _defaultEmailController,
    _githubProfileController,
    _defaultLicenseController,
  ];

  DeveloperDefaults get _developerDefaults => DeveloperDefaults(
    publisherName: _defaultPublisherController.text,
    developerEmail: _defaultEmailController.text,
    githubProfile: _githubProfileController.text,
    license: _defaultLicenseController.text,
  );

  void _handleDeveloperDefaultsChanged() {
    setState(_applyDeveloperDefaults);
    _defaultsSaveTimer?.cancel();
    _defaultsSaveTimer = Timer(
      const Duration(milliseconds: 400),
      () => _appPreferences.saveDeveloperDefaults(_developerDefaults),
    );
  }

  /// Copies the defaults into the release fields that follow them.
  void _applyDeveloperDefaults() {
    final defaults = _developerDefaults;
    for (final field in _defaultFields) {
      final controller = _controllerFor(field);
      final value = _defaultValueFor(field, defaults);
      if (controller.text != value) {
        controller.text = value;
      }
    }
  }

  TextEditingController _controllerFor(DeveloperField field) {
    return switch (field) {
      DeveloperField.publisher => _publisherNameController,
      DeveloperField.email => _developerEmailController,
      DeveloperField.homepage => _homepageUrlController,
      DeveloperField.license => _licenseController,
    };
  }

  String _defaultValueFor(DeveloperField field, DeveloperDefaults defaults) {
    return switch (field) {
      DeveloperField.publisher => defaults.publisherName.trim(),
      DeveloperField.email => defaults.developerEmail.trim(),
      DeveloperField.homepage =>
        defaults.homepageFor(_projectPath) ?? _projectHomepage ?? '',
      DeveloperField.license => defaults.license.trim(),
    };
  }

  /// Unticking keeps the default text as a starting point for editing.
  void _setUseDefault(DeveloperField field, bool useDefault) {
    setState(() {
      if (useDefault) {
        _defaultFields.add(field);
        _applyDeveloperDefaults();
      } else {
        _defaultFields.remove(field);
      }
    });
    unawaited(_appPreferences.saveDefaultFields(_defaultFields));
  }

  Future<void> _loadFileNameParts() async {
    final parts = await _appPreferences.loadFileNameParts();
    if (!mounted) {
      return;
    }
    setState(() {
      _fileNameParts = parts;
    });
  }

  void _setFileNameParts(Set<FileNamePart> parts) {
    setState(() {
      _fileNameParts = parts;
    });
    unawaited(_appPreferences.saveFileNameParts(parts));
  }

  /// The setup.exe name the chosen parts give for the current project.
  String get _setupFileNamePreview {
    final name = OutputFileName(_fileNameParts).baseName(
      appName: WindowsInstallerMetadata.safeFileName(
        WindowsInstallerMetadata.displayAppName(_appNameController.text),
      ),
      version: WindowsInstallerMetadata.safeFileName(
        WindowsInstallerMetadata.releaseVersion(_releaseTagController.text),
      ),
      kind: 'setup',
    );
    return '$name.exe';
  }

  Future<void> _loadDefaultOutputPath() async {
    final path = await _appPreferences.loadDefaultOutputPath();
    if (!mounted) {
      return;
    }
    setState(() {
      _defaultOutputPath = path;
    });
  }

  void _restoreControllerText(
    TextEditingController controller,
    String savedValue,
  ) {
    if (controller.text.isEmpty && savedValue.isNotEmpty) {
      controller.text = savedValue;
    }
  }

  void _attachMetadataListeners() {
    if (_metadataListenersAttached) {
      return;
    }
    for (final controller in _metadataControllers) {
      controller.addListener(_scheduleReleaseMetadataSave);
    }
    _metadataListenersAttached = true;
  }

  List<TextEditingController> get _metadataControllers => [
    _releaseTagController,
    _developerEmailController,
    _publisherNameController,
    _homepageUrlController,
    _descriptionController,
  ];

  void _scheduleReleaseMetadataSave() {
    _metadataSaveTimer?.cancel();
    _metadataSaveTimer = Timer(
      const Duration(milliseconds: 400),
      _saveReleaseMetadata,
    );
  }

  Future<void> _saveReleaseMetadata() {
    return _appPreferences.saveReleaseMetadata(
      SavedReleaseMetadata(
        releaseTag: _releaseTagController.text,
        developerEmail: _developerEmailController.text,
        publisherName: _publisherNameController.text,
        homepageUrl: _homepageUrlController.text,
        description: _descriptionController.text,
      ),
    );
  }

  Future<void> _refreshToolchainStatus() async {
    final results = await Future.wait([
      _toolchainService.flutterAvailability(),
      _toolchainService.gitAvailability(),
      _toolchainService.visualStudioAvailability(),
      _toolchainService.innoSetupAvailability(),
      _toolchainService.developerModeAvailability(),
      _toolchainService.androidSdkAvailability(),
      _toolchainService.javaAvailability(),
    ]);

    if (!mounted) {
      return;
    }

    setState(() {
      _flutterStatus = results[0];
      _gitStatus = results[1];
      _visualStudioStatus = results[2];
      _innoSetupStatus = results[3];
      _developerModeStatus = results[4];
      _androidSdkStatus = results[5];
      _javaStatus = results[6];
      _toolchainChecked = true;
      _updateTargetStatuses();
    });
  }

  /// Recomputes every target from the toolchain state and the selected
  /// project. A target whose platform the project lacks cannot be built at
  /// all, so it is hidden; its selection comes back with the platform.
  void _updateTargetStatuses() {
    final projectPath = _projectPath;
    for (final target in _targets) {
      final missingPlatform =
          projectPath != null &&
          !ProjectPlatforms.supports(projectPath, target.platform);
      if (missingPlatform) {
        if (target.selected) {
          _selectionsOfHiddenTargets.add(target);
        }
        target
          ..status = TargetStatus.missingPlatform
          ..selected = false;
        continue;
      }
      target.status = _toolchainTargetStatus(target);
      if (_selectionsOfHiddenTargets.remove(target) && target.canSelect) {
        target.selected = true;
      }
      if (!target.canSelect) {
        target.selected = false;
      }
    }
  }

  /// Platforms can be added while PackFoundry is open, e.g. with
  /// `flutter create --platforms=android .`, so they are checked again
  /// whenever the Project workspace is shown.
  void _refreshProjectPlatforms() {
    if (_projectPath == null || _isBuilding) {
      return;
    }
    setState(() {
      _updateTargetStatuses();
      _replaceRoadmapWithPreview();
    });
  }

  TargetStatus _toolchainTargetStatus(BuildTarget target) {
    // The script is only written to disk; the machine that runs it checks
    // its own tools.
    if (target.artifact == BuildTarget.buildScript) {
      return TargetStatus.ready;
    }
    if (!_toolchainChecked) {
      return target.platform == 'Android'
          ? TargetStatus.installable
          : TargetStatus.ready;
    }
    final status = target.platform == 'Android'
        ? _androidBuildStatus
        : _windowsBuildStatus;
    return status == ToolAvailability.installed
        ? TargetStatus.ready
        : TargetStatus.installable;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_buildLog.isEmpty) {
      final l10n = context.l10n;
      _buildLog.add(
        BuildLogEntry(
          title: l10n.readyTitle,
          detail: l10n.readyDetail,
          state: BuildLogState.idle,
        ),
      );
    }
    _scheduleWelcomeDialog();
  }

  @override
  void didUpdateWidget(covariant PackFoundryHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.showWelcome && widget.showWelcome) {
      _welcomeDialogShown = false;
    }
    _scheduleWelcomeDialog();
  }

  void _scheduleWelcomeDialog() {
    if (!widget.showWelcome || _welcomeDialogShown) {
      return;
    }

    _welcomeDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => WelcomeDialog(
          initialThemeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
          onCompleted: widget.onWelcomeCompleted,
        ),
      );
    });
  }

  List<ToolchainGroup> _toolGroups(AppLocalizations l10n) {
    return [
      _commonToolsGroup(l10n),
      _windowsBuildGroup(l10n),
      _androidBuildGroup(l10n),
    ];
  }

  ToolchainGroup _commonToolsGroup(AppLocalizations l10n) {
    return ToolchainGroup(
      title: l10n.commonToolsGroupTitle,
      subtitle: l10n.commonToolsGroupSubtitle,
      status: _commonToolsStatus,
      category: ToolchainCategory.common,
      installTarget: ToolchainInstallTarget.common,
      unlocks: [l10n.allTargets],
      installProgress: _installProgressFor(ToolchainInstallTarget.common),
      tools: [
        ToolStatus(
          name: 'Flutter SDK',
          command: 'flutter.bat',
          status: _flutterStatus,
          note: l10n.flutterSdkNote,
        ),
        ToolStatus(
          name: 'Git',
          command: 'git.exe',
          status: _gitStatus,
          note: l10n.gitNote,
        ),
      ],
    );
  }

  ToolInstallProgress? _installProgressFor(ToolchainInstallTarget target) {
    return _installProgress?.target == target ? _installProgress : null;
  }

  /// Platform groups need the common Flutter SDK as well.
  String? _commonToolsDependencyNote(AppLocalizations l10n) {
    return _commonToolsStatus == ToolAvailability.installed
        ? null
        : l10n.requiresCommonTools;
  }

  ToolchainGroup _windowsBuildGroup(AppLocalizations l10n) {
    return ToolchainGroup(
      title: l10n.windowsBuildGroupTitle,
      subtitle: l10n.windowsBuildGroupSubtitle,
      status: _windowsToolsStatus,
      installTarget: ToolchainInstallTarget.windows,
      unlocks: const ['setup.exe', 'portable'],
      installProgress: _installProgressFor(ToolchainInstallTarget.windows),
      dependencyNote: _commonToolsDependencyNote(l10n),
      installSizeLabel: _visualStudioStatus == ToolAvailability.installed
          ? null
          : '~7 GB',
      tools: [
        ToolStatus(
          name: 'Visual Studio C++',
          command: 'Desktop development with C++',
          status: _visualStudioStatus,
          note: l10n.visualStudioNote,
        ),
        ToolStatus(
          name: 'Inno Setup 6',
          command: 'ISCC.exe',
          status: _innoSetupStatus,
          note: l10n.innoSetupNote,
        ),
        ToolStatus(
          name: l10n.developerModeName,
          command: 'ms-settings:developers',
          status: _developerModeStatus,
          note: l10n.developerModeNote,
        ),
        ToolStatus(
          name: l10n.buildScriptToolName,
          command: WindowsInstallerFiles.scriptFileName,
          status: ToolAvailability.installed,
          note: l10n.buildScriptToolNote,
        ),
      ],
    );
  }

  ToolchainGroup _androidBuildGroup(AppLocalizations l10n) {
    return ToolchainGroup(
      title: l10n.androidBuildGroupTitle,
      subtitle: l10n.androidBuildGroupSubtitle,
      status: _androidToolsStatus,
      installTarget: ToolchainInstallTarget.android,
      unlocks: const ['apk'],
      installProgress: _installProgressFor(ToolchainInstallTarget.android),
      dependencyNote: _commonToolsDependencyNote(l10n),
      tools: [
        ToolStatus(
          name: 'Android SDK',
          command: r'ANDROID_HOME / sdkmanager.bat',
          status: _androidSdkStatus,
          note: l10n.androidSdkNote,
        ),
        ToolStatus(
          name: 'Java',
          command: 'java.exe',
          status: _javaStatus,
          note: l10n.javaNote,
        ),
      ],
    );
  }

  ToolAvailability get _commonToolsStatus {
    if (_flutterStatus == ToolAvailability.installed &&
        _gitStatus == ToolAvailability.installed) {
      return ToolAvailability.installed;
    }
    return ToolAvailability.available;
  }

  ToolAvailability get _windowsToolsStatus {
    if (_visualStudioStatus == ToolAvailability.installed &&
        _innoSetupStatus == ToolAvailability.installed) {
      return ToolAvailability.installed;
    }
    return ToolAvailability.available;
  }

  /// setup.exe is buildable here only with the Flutter SDK, Visual Studio and
  /// Inno Setup together.
  ToolAvailability get _windowsBuildStatus {
    if (_flutterStatus == ToolAvailability.installed &&
        _windowsToolsStatus == ToolAvailability.installed) {
      return ToolAvailability.installed;
    }
    return ToolAvailability.available;
  }

  ToolAvailability get _androidToolsStatus {
    if (_androidSdkStatus == ToolAvailability.installed &&
        _javaStatus == ToolAvailability.installed) {
      return ToolAvailability.installed;
    }
    return ToolAvailability.available;
  }

  /// Android targets are buildable only when the Flutter SDK is there too.
  ToolAvailability get _androidBuildStatus {
    if (_flutterStatus == ToolAvailability.installed &&
        _androidToolsStatus == ToolAvailability.installed) {
      return ToolAvailability.installed;
    }
    return ToolAvailability.available;
  }

  Future<void> _installTools(ToolchainInstallTarget target) async {
    if (_installingToolTarget != null) {
      return;
    }

    final l10n = context.l10n;
    _toolInstallCancelRequested = false;
    _toolchainService.beginInstall();
    setState(() {
      _installingToolTarget = target;
      _installProgress = ToolInstallProgress(
        target: target,
        progress: 0,
        remainingSeconds: null,
        detail: l10n.installPreparing,
      );
    });

    final result = await _runToolInstall(target);

    if (!mounted) {
      return;
    }

    setState(() {
      _installingToolTarget = null;
      _installProgress = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? l10n.toolInstallSuccess(result.message)
              : l10n.toolInstallFailed(result.message),
        ),
      ),
    );

    if (widget.enableToolchainDiagnostics) {
      await _refreshToolchainStatus();
    }
  }

  Future<void> _cancelToolInstall() async {
    _toolInstallCancelRequested = true;
    await _toolchainService.cancelActiveInstall();
  }

  Future<ToolInstallResult> _runToolInstall(
    ToolchainInstallTarget target,
  ) async {
    final l10n = context.l10n;
    final needsCommon = [
      if (_gitStatus != ToolAvailability.installed)
        _wingetStep(l10n.installStepGit, 'Git.Git', weight: 2),
      if (_flutterStatus != ToolAvailability.installed) _flutterStep(l10n),
    ];
    final steps = switch (target) {
      ToolchainInstallTarget.common => needsCommon,
      ToolchainInstallTarget.windows => [
        ...needsCommon,
        if (_visualStudioStatus != ToolAvailability.installed)
          _wingetStep(
            l10n.installStepVisualStudio,
            'Microsoft.VisualStudio.2022.BuildTools',
            weight: 10,
            extraArguments: const [
              '--override',
              '--wait --passive --add Microsoft.VisualStudio.Workload.VCTools '
                  '--includeRecommended',
            ],
          ),
        if (_innoSetupStatus != ToolAvailability.installed)
          _wingetStep(
            l10n.installStepInnoSetup,
            'JRSoftware.InnoSetup',
            weight: 1,
          ),
        if (_developerModeStatus != ToolAvailability.installed)
          _ToolInstallStep(
            title: l10n.installStepDeveloperMode,
            weight: 1,
            run: (report) async {
              await _toolchainService.openDeveloperSettings();
              return ToolInstallResult.success(l10n.developerModeOpened);
            },
          ),
      ],
      ToolchainInstallTarget.android => [
        ...needsCommon,
        if (_javaStatus != ToolAvailability.installed)
          _wingetStep(l10n.installStepJava, 'Microsoft.OpenJDK.17', weight: 2),
        if (_androidSdkStatus != ToolAvailability.installed)
          _ToolInstallStep(
            title: l10n.installStepAndroidSdk,
            weight: 6,
            run: (report) => _toolchainService.installAndroidSdk(
              onProgress: (fraction, detail) => report(fraction, detail),
            ),
          ),
      ],
    };

    if (steps.isEmpty) {
      return const ToolInstallResult.success(
        'Required tools are already installed.',
      );
    }
    return _runInstallSteps(target, steps);
  }

  /// Runs install steps in order and turns their reports into one overall
  /// progress value for the toolchain card.
  Future<ToolInstallResult> _runInstallSteps(
    ToolchainInstallTarget target,
    List<_ToolInstallStep> steps,
  ) async {
    final session = _ToolInstallSession(target, steps);
    final messages = <String>[];
    var lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);

    for (var index = 0; index < steps.length; index++) {
      void report(double? fraction, String detail, {int? remainingSeconds}) {
        final progress = session.report(
          index,
          fraction,
          detail,
          remainingSeconds: remainingSeconds,
        );
        // git and sdkmanager can print hundreds of progress lines a second.
        final now = DateTime.now();
        final stepChanged = _installProgress?.currentStep != index;
        if (!mounted ||
            (!stepChanged &&
                now.difference(lastUpdate) <
                    const Duration(milliseconds: 100))) {
          return;
        }
        lastUpdate = now;
        setState(() => _installProgress = progress);
      }

      report(null, steps[index].title);
      final result = await steps[index].run(report);
      if (_toolInstallCancelRequested) {
        return const ToolInstallResult.failure('Installation was cancelled.');
      }
      if (!result.success) {
        return result;
      }
      messages.add(result.message);
    }
    return ToolInstallResult.success(messages.join('\n'));
  }

  _ToolInstallStep _wingetStep(
    String title,
    String packageId, {
    required int weight,
    List<String> extraArguments = const [],
  }) {
    return _ToolInstallStep(
      title: title,
      weight: weight,
      cancellable: false,
      run: (report) => _toolchainService.installWithWinget(
        packageId,
        extraArguments: extraArguments,
        onProgress: (fraction, detail) => report(fraction, detail),
      ),
    );
  }

  _ToolInstallStep _flutterStep(AppLocalizations l10n) {
    return _ToolInstallStep(
      title: l10n.installStepFlutterSdk,
      weight: 6,
      run: (report) => _toolchainService.installFlutterSdk(
        onProgress: (fraction, detail) => report(fraction, detail),
      ),
    );
  }

  @override
  void dispose() {
    _workspaceTabController.removeListener(_handleWorkspaceTabChanged);
    _workspaceTabController.dispose();
    final runningProject = _runningProjectProcess;
    if (runningProject != null) {
      unawaited(killProcessTree(runningProject));
    }
    final sendProcess = _sendToDeviceProcess;
    if (sendProcess != null) {
      unawaited(killProcessTree(sendProcess));
    }
    if (_metadataListenersAttached) {
      for (final controller in _metadataControllers) {
        controller.removeListener(_scheduleReleaseMetadataSave);
      }
    }
    if (_metadataSaveTimer?.isActive ?? false) {
      unawaited(_saveReleaseMetadata());
    }
    _metadataSaveTimer?.cancel();
    if (_defaultsSaveTimer?.isActive ?? false) {
      unawaited(_appPreferences.saveDeveloperDefaults(_developerDefaults));
    }
    _defaultsSaveTimer?.cancel();
    if (_defaultsListenersAttached) {
      for (final controller in _defaultsControllers) {
        controller.removeListener(_handleDeveloperDefaultsChanged);
      }
    }
    _defaultPublisherController.dispose();
    _defaultEmailController.dispose();
    _githubProfileController.dispose();
    _defaultLicenseController.dispose();
    _appNameController.dispose();
    _projectPathController.dispose();
    _releaseTagController.dispose();
    _developerEmailController.dispose();
    _publisherNameController.dispose();
    _homepageUrlController.dispose();
    _licenseController.dispose();
    _descriptionController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _runBuild() async {
    if (_isBuilding || _isSendingToDevice) {
      return;
    }

    final projectPath = _projectPath;
    if (projectPath == null) {
      _replaceLog(
        BuildLogEntry(
          title: context.l10n.projectNotSelectedTitle,
          detail: context.l10n.projectNotSelectedDetail,
          state: BuildLogState.warning,
        ),
      );
      return;
    }

    setState(() {
      _isBuilding = true;
      _buildProgress = 0;
      _buildLog.clear();
      _replaceRoadmapWithPreview();
    });

    final configuration = BuildConfiguration(
      appName: _appNameController.text,
      releaseTag: _releaseTagController.text,
      developerEmail: _developerEmailController.text,
      publisherName: _publisherNameController.text,
      homepageUrl: _homepageUrlController.text,
      license: _licenseController.text,
      description: _descriptionController.text,
      projectPath: projectPath,
      outputPath: _outputPath ?? _defaultOutputPath,
      iconPath: _iconPath,
      windowWidth: int.tryParse(_widthController.text),
      windowHeight: int.tryParse(_heightController.text),
      targets: _targets,
      fileNameParts: _fileNameParts,
    );

    var hadWarning = false;
    var sawSuccess = false;
    var shouldShowSuccess = false;
    String? firstWarningDetail;
    try {
      await for (final event in _buildService.build(configuration)) {
        if (!mounted) {
          return;
        }

        setState(() {
          final logEntry = event.logEntry;
          final progress = event.progress;
          final roadmapPlan = event.roadmapPlan;
          final roadmapUpdate = event.roadmapUpdate;
          if (logEntry != null) {
            _buildLog.add(logEntry);
            if (logEntry.state == BuildLogState.warning) {
              hadWarning = true;
              firstWarningDetail ??= logEntry.detail.trim().isEmpty
                  ? logEntry.title
                  : logEntry.detail;
            }
            sawSuccess = sawSuccess || logEntry.state == BuildLogState.success;
          }
          if (progress != null) {
            _buildProgress = progress.clamp(0, 100);
          }
          if (roadmapPlan != null) {
            _roadmapSteps
              ..clear()
              ..addAll(roadmapPlan);
          }
          if (roadmapUpdate != null) {
            _applyRoadmapUpdate(roadmapUpdate);
          }
        });
      }
      shouldShowSuccess = sawSuccess && !hadWarning;
    } on Object catch (error) {
      // Without this the stream error stayed invisible: the roadmap was reset
      // and the build simply ended without saying anything.
      hadWarning = true;
      firstWarningDetail ??= error.toString();
      if (mounted) {
        setState(() {
          _buildLog.add(
            BuildLogEntry(
              title: context.l10n.buildWarningsTitle,
              detail: error.toString(),
              state: BuildLogState.warning,
            ),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBuilding = false;
          _buildProgress = 0;
          if (!hadWarning) {
            // On failure the roadmap stays as it is, so the step that broke
            // remains on screen instead of being replaced by a clean preview.
            _replaceRoadmapWithPreview();
          }
        });
        if (shouldShowSuccess) {
          await _showBuildSuccessDialog();
        } else if (hadWarning) {
          await _showBuildWarningsDialog(firstWarningDetail);
        }
      }
    }
  }

  Future<void> _runProjectWithoutBuild() async {
    if (_isBuilding || _isRunningProject || _isSendingToDevice) {
      return;
    }

    final projectPath = _projectPath;
    if (projectPath == null) {
      _replaceLog(
        BuildLogEntry(
          title: context.l10n.projectNotSelectedTitle,
          detail: context.l10n.projectNotSelectedDetail,
          state: BuildLogState.warning,
        ),
      );
      return;
    }

    setState(() {
      _isRunningProject = true;
      _buildLog
        ..clear()
        ..add(
          const BuildLogEntry(
            title: 'Running Flutter app',
            detail: 'flutter run -d windows',
            state: BuildLogState.running,
          ),
        );
    });

    try {
      final process = await _startFlutterRun(projectPath);
      _runningProjectProcess = process;
      _listenToRunOutput(process.stdout, BuildLogState.running);
      _listenToRunOutput(process.stderr, BuildLogState.warning);
      unawaited(_waitForRunProcess(process));
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isRunningProject = false;
        _runningProjectProcess = null;
        _buildLog.add(
          BuildLogEntry(
            title: 'Could not run Flutter app',
            detail: error.toString(),
            state: BuildLogState.warning,
          ),
        );
      });
    }
  }

  Future<Process> _startFlutterRun(String projectPath) {
    return _startFlutter(projectPath, const ['run', '-d', 'windows']);
  }

  /// Starts the resolved `flutter.bat`, so a missing SDK is reported instead
  /// of ending as "flutter is not recognized as a command".
  Future<Process> _startFlutter(String projectPath, List<String> arguments) {
    final locator = FlutterLocator();
    final flutter = locator.find();
    if (flutter == null) {
      throw ProcessException(
        'flutter',
        arguments,
        context.l10n.flutterSdkNotFound,
      );
    }
    return Process.start(
      flutter.path,
      arguments,
      workingDirectory: projectPath,
      environment: {
        ...?BuildService.androidBuildEnvironment(WindowsTools()),
        ...locator.environmentFor(flutter),
      },
      runInShell: true,
    );
  }

  void _listenToRunOutput(Stream<List<int>> stream, BuildLogState state) {
    stream
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) {
          final trimmed = line.trim();
          if (!mounted || trimmed.isEmpty) {
            return;
          }
          setState(() {
            _buildLog.add(
              BuildLogEntry(
                title: state == BuildLogState.warning
                    ? 'Flutter stderr'
                    : 'Flutter output',
                detail: trimmed,
                state: state,
              ),
            );
          });
        });
  }

  Future<void> _waitForRunProcess(Process process) async {
    final exitCode = await process.exitCode;
    if (!mounted || _runningProjectProcess != process) {
      return;
    }
    setState(() {
      _isRunningProject = false;
      _runningProjectProcess = null;
      _buildLog.add(
        BuildLogEntry(
          title: 'Flutter app stopped',
          detail: 'Process exited with code $exitCode.',
          state: exitCode == 0 ? BuildLogState.success : BuildLogState.warning,
        ),
      );
    });
  }

  void _stopRunningProject() {
    final process = _runningProjectProcess;
    if (process == null) {
      return;
    }
    unawaited(killProcessTree(process));
    setState(() {
      _isRunningProject = false;
      _runningProjectProcess = null;
      _buildLog.add(
        const BuildLogEntry(
          title: 'Stopping Flutter app',
          detail: 'Stopped the flutter process and the app it started.',
          state: BuildLogState.running,
        ),
      );
    });
  }

  /// Builds a release APK straight from the project folder and installs it on
  /// an attached device. The packaging pipeline is deliberately not reused: it
  /// copies the project into a throwaway workspace, which would force a cold
  /// Gradle build on every send.
  Future<void> _sendApkToDevice() async {
    if (_isBuilding || _isRunningProject || _isSendingToDevice) {
      return;
    }

    final projectPath = _projectPath;
    if (projectPath == null) {
      _replaceLog(
        BuildLogEntry(
          title: context.l10n.projectNotSelectedTitle,
          detail: context.l10n.projectNotSelectedDetail,
          state: BuildLogState.warning,
        ),
      );
      return;
    }

    if (await _androidDeviceService.resolveExecutable() == null) {
      if (mounted) {
        _showSnackBar(context.l10n.adbMissing);
      }
      return;
    }

    final device = await _resolveTargetDevice();
    if (device == null || !mounted) {
      return;
    }

    setState(() {
      _isSendingToDevice = true;
      _sendToDeviceCancelled = false;
      _sendToDeviceStatus = context.l10n.androidBuildingApk;
      _buildLog
        ..clear()
        ..add(
          BuildLogEntry(
            title: 'Building release APK',
            detail: 'flutter build apk --release (${device.label})',
            state: BuildLogState.running,
          ),
        );
    });

    try {
      final buildExitCode = await _runSendStep(
        await _startFlutterApkBuild(projectPath),
      );
      if (!mounted || _sendToDeviceCancelled) {
        return;
      }
      if (buildExitCode != 0) {
        _finishSendToDevice(context.l10n.androidBuildFailed, failed: true);
        return;
      }

      final apk = BuildService.findReleaseApk(projectPath);
      if (apk == null) {
        _finishSendToDevice(context.l10n.androidApkMissing, failed: true);
        return;
      }

      setState(() {
        _sendToDeviceStatus = context.l10n.androidInstallingApk(device.label);
        _buildLog.add(
          BuildLogEntry(
            title: 'Installing APK',
            detail: 'adb -s ${device.serial} install -r ${apk.path}',
            state: BuildLogState.running,
          ),
        );
      });

      final installed = await _installApkOnDevice(
        device: device,
        apkPath: apk.path,
        projectPath: projectPath,
      );
      if (!mounted || _sendToDeviceCancelled) {
        return;
      }
      if (!installed) {
        _finishSendToDevice(context.l10n.androidInstallFailed, failed: true);
        return;
      }

      await _launchInstalledApp(device: device, projectPath: projectPath);
      if (!mounted || _sendToDeviceCancelled) {
        return;
      }
      _finishSendToDevice(context.l10n.androidInstallSucceeded(device.label));
    } on Object catch (error) {
      if (!mounted || _sendToDeviceCancelled) {
        return;
      }
      setState(() {
        _buildLog.add(
          BuildLogEntry(
            title: 'Could not send the app to the device',
            detail: error.toString(),
            state: BuildLogState.warning,
          ),
        );
      });
      _finishSendToDevice(context.l10n.androidInstallFailed, failed: true);
    }
  }

  /// Picks the device to install on, walking the user through the states adb
  /// reports: nothing attached, attached but waiting for the USB debugging
  /// confirmation, or several devices to choose from.
  Future<AndroidDevice?> _resolveTargetDevice() async {
    while (mounted) {
      final devices = await _androidDeviceService.listDevices();
      if (!mounted) {
        return null;
      }

      final authorized = devices
          .where((device) => device.isAuthorized)
          .toList();
      if (authorized.length == 1) {
        return authorized.first;
      }
      if (authorized.length > 1) {
        return _chooseAndroidDevice(authorized);
      }

      AndroidDevice? unauthorized;
      for (final device in devices) {
        if (device.isUnauthorized) {
          unauthorized = device;
          break;
        }
      }

      final retry = unauthorized == null
          ? await _showDeviceProblemDialog(
              title: context.l10n.androidDeviceSearchTitle,
              message: context.l10n.androidDeviceMissingMessage,
              icon: Icons.usb_outlined,
            )
          : await _showDeviceProblemDialog(
              title: context.l10n.androidDeviceUnauthorizedTitle,
              message: context.l10n.androidDeviceUnauthorizedMessage(
                unauthorized.label,
              ),
              icon: Icons.phonelink_lock_outlined,
            );
      if (!retry) {
        return null;
      }
    }
    return null;
  }

  Future<bool> _showDeviceProblemDialog({
    required String title,
    required String message,
    required IconData icon,
  }) async {
    final l10n = context.l10n;
    final retry = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(icon),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.retryDeviceCheck),
          ),
        ],
      ),
    );
    return retry ?? false;
  }

  Future<AndroidDevice?> _chooseAndroidDevice(
    List<AndroidDevice> devices,
  ) async {
    final l10n = context.l10n;
    return showDialog<AndroidDevice>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.smartphone_outlined),
        title: Text(l10n.chooseAndroidDeviceTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final device in devices)
              ListTile(
                leading: const Icon(Icons.smartphone_outlined),
                title: Text(device.label),
                onTap: () => Navigator.of(context).pop(device),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  /// Installs the APK, recovering from the two failures that a device with an
  /// older build of the same app reliably produces.
  Future<bool> _installApkOnDevice({
    required AndroidDevice device,
    required String apkPath,
    required String projectPath,
  }) async {
    var result = await _runAdbInstall(device.serial, apkPath);
    if (result.isSuccess) {
      return true;
    }

    // A lower versionCode than the installed build: the APK is still the newer
    // source, so retrying with an explicit downgrade is what the user wants.
    if (result.contains('INSTALL_FAILED_VERSION_DOWNGRADE')) {
      _logAdbResult('Retrying install with downgrade allowed', result);
      result = await _runAdbInstall(
        device.serial,
        apkPath,
        allowDowngrade: true,
      );
      if (result.isSuccess) {
        return true;
      }
    }

    // A build signed with another key cannot replace the installed one, and
    // removing it destroys the app data, so this needs an explicit decision.
    final signatureConflict =
        result.contains('INSTALL_FAILED_UPDATE_INCOMPATIBLE') ||
        result.contains('signatures do not match');
    if (signatureConflict) {
      _logAdbResult('Install rejected: signature mismatch', result);
      final applicationId = _readAndroidApplicationId(projectPath);
      if (applicationId != null && await _confirmReinstall()) {
        final uninstall = await _androidDeviceService.run([
          '-s',
          device.serial,
          'uninstall',
          applicationId,
        ]);
        _logAdbResult('Uninstalling the previous build', uninstall);
        result = await _runAdbInstall(device.serial, apkPath);
        if (result.isSuccess) {
          return true;
        }
      }
    }

    _logAdbResult('Install failed', result);
    return false;
  }

  Future<AdbResult> _runAdbInstall(
    String serial,
    String apkPath, {
    bool allowDowngrade = false,
  }) {
    return _androidDeviceService.run([
      '-s',
      serial,
      'install',
      '-r',
      if (allowDowngrade) '-d',
      apkPath,
    ], timeout: const Duration(minutes: 10));
  }

  Future<bool> _confirmReinstall() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_outlined),
        title: Text(l10n.androidSignatureConflictTitle),
        content: Text(l10n.androidSignatureConflictMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.removeAndInstall),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Opens the freshly installed app. A device that refuses to launch it is not
  /// an install failure, so this only ever adds a log entry.
  Future<void> _launchInstalledApp({
    required AndroidDevice device,
    required String projectPath,
  }) async {
    final applicationId = _readAndroidApplicationId(projectPath);
    if (applicationId == null) {
      return;
    }
    final result = await _androidDeviceService.run([
      '-s',
      device.serial,
      'shell',
      'monkey',
      '-p',
      applicationId,
      '-c',
      'android.intent.category.LAUNCHER',
      '1',
    ], timeout: const Duration(seconds: 30));
    _logAdbResult('Launching $applicationId', result);
  }

  /// Reads `applicationId` from the Gradle config of the Android project. Only
  /// a literal value is accepted, so a computed id is skipped instead of being
  /// guessed wrong.
  String? _readAndroidApplicationId(String projectPath) {
    for (final relativePath in const [
      'android/app/build.gradle.kts',
      'android/app/build.gradle',
    ]) {
      final file = File(_joinPath(projectPath, relativePath));
      if (!file.existsSync()) {
        continue;
      }
      final match = RegExp(
        '''applicationId\\s*=?\\s*["']([^"']+)["']''',
      ).firstMatch(file.readAsStringSync());
      final applicationId = match?.group(1);
      if (applicationId != null && applicationId.isNotEmpty) {
        return applicationId;
      }
    }
    return null;
  }

  Future<Process> _startFlutterApkBuild(String projectPath) {
    return _startFlutter(projectPath, const ['build', 'apk', '--release']);
  }

  Future<int> _runSendStep(Process process) async {
    _sendToDeviceProcess = process;
    _listenToRunOutput(process.stdout, BuildLogState.running);
    _listenToRunOutput(process.stderr, BuildLogState.warning);
    return process.exitCode;
  }

  void _logAdbResult(String title, AdbResult result) {
    if (!mounted) {
      return;
    }
    setState(() {
      _buildLog.add(
        BuildLogEntry(
          title: title,
          detail: result.output.isEmpty
              ? 'adb exited with code ${result.exitCode}.'
              : result.output,
          state: result.isSuccess
              ? BuildLogState.success
              : BuildLogState.warning,
        ),
      );
    });
  }

  void _finishSendToDevice(String message, {bool failed = false}) {
    setState(() {
      _isSendingToDevice = false;
      _sendToDeviceProcess = null;
      _sendToDeviceStatus = null;
      _buildLog.add(
        BuildLogEntry(
          title: failed ? 'Send to device failed' : 'Send to device finished',
          detail: message,
          state: failed ? BuildLogState.warning : BuildLogState.success,
        ),
      );
    });
    _showSnackBar(message);
  }

  void _cancelSendToDevice() {
    if (!_isSendingToDevice) {
      return;
    }
    // An adb step cannot be interrupted mid-flight, so the flag is what stops
    // the flow: its result is dropped instead of being reported as a failure.
    _sendToDeviceCancelled = true;
    final sendProcess = _sendToDeviceProcess;
    if (sendProcess != null) {
      unawaited(killProcessTree(sendProcess));
    }
    _sendToDeviceProcess = null;
    setState(() {
      _isSendingToDevice = false;
      _sendToDeviceStatus = null;
      _buildLog.add(
        BuildLogEntry(
          title: 'Send to device cancelled',
          detail: context.l10n.androidSendCancelled,
          state: BuildLogState.warning,
        ),
      );
    });
  }

  void _replaceRoadmapWithPreview() {
    _roadmapSteps
      ..clear()
      ..addAll(_buildService.createRoadmapPlan(_targets));
  }

  void _applyRoadmapUpdate(BuildRoadmapUpdate update) {
    final index = _roadmapSteps.indexWhere((step) => step.id == update.id);
    if (index == -1) {
      return;
    }
    _roadmapSteps[index] = _roadmapSteps[index].copyWith(
      state: update.state,
      progress: update.progress,
      detail: update.detail,
    );
  }

  Future<void> _chooseProjectFolder() async {
    final path = await getDirectoryPath(
      confirmButtonText: context.l10n.chooseProject,
    );
    if (path == null || !mounted) {
      return;
    }

    _setProjectPath(path);
  }

  /// Applies the path typed into the project field. An unknown folder is
  /// reported instead of being applied, so the checks never describe a folder
  /// that is not there.
  void _applyTypedProjectPath() {
    final path = _expandHomeDirectory(_projectPathController.text.trim());
    if (path == _projectPath) {
      if (_projectPathController.text != path) {
        _projectPathController.text = path ?? '';
      }
      return;
    }

    if (path == null) {
      setState(() {
        _projectPath = null;
        _hasDesktopRunner = false;
        _projectChecks.clear();
        _projectPathController.clear();
        _updateTargetStatuses();
        if (!_isBuilding) {
          _replaceRoadmapWithPreview();
        }
      });
      return;
    }

    if (!Directory(path).existsSync()) {
      _showSnackBar(context.l10n.projectFolderNotFound(path));
      return;
    }

    _setProjectPath(path);
  }

  /// Expands `%VARIABLE%` references and a leading `~`, and drops the quotes
  /// Explorer's "Copy as path" adds.
  String? _expandHomeDirectory(String path) {
    var value = path.trim();
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1).trim();
    }
    if (value.isEmpty) {
      return null;
    }
    final tools = WindowsTools();
    value = value.replaceAllMapped(
      RegExp(r'%([^%]+)%'),
      (match) => tools.variable(match.group(1)!) ?? match.group(0)!,
    );
    final home = tools.variable('USERPROFILE');
    if (home == null || home.isEmpty || !value.startsWith('~')) {
      return value;
    }
    if (value == '~') {
      return home;
    }
    return value.startsWith(r'~\') || value.startsWith('~/')
        ? _joinPath(home, value.substring(2))
        : value;
  }

  void _setProjectPath(String path) {
    final windowSize = _readFlutterWindowSize(path);
    final projectMetadata = _readProjectMetadata(path);
    final projectAppName = projectMetadata.name;
    final detectedIcon = const ProjectIconFinder().find(path);
    final previousProject = _projectPath;
    final currentIcon = _iconPath;
    // Never override an icon the user picked from outside the old project.
    final canReplaceIcon =
        currentIcon == null ||
        _iconAutoDetected ||
        (previousProject != null &&
            currentIcon.startsWith(
              '$previousProject${Platform.pathSeparator}',
            ));

    setState(() {
      if (canReplaceIcon) {
        _iconPath = detectedIcon;
        _iconAutoDetected = detectedIcon != null;
      }
      _projectPath = path;
      _projectHomepage = projectMetadata.homepage;
      _updateTargetStatuses();
      if (!_isBuilding) {
        _replaceRoadmapWithPreview();
      }
      _hasDesktopRunner = _hasWindowsRunner(path);
      if (_projectPathController.text != path) {
        _projectPathController.text = path;
      }
      _projectChecks
        ..clear()
        ..addAll(_buildProjectChecks(path, projectMetadata, detectedIcon));
      if (windowSize != null) {
        _widthController.text = windowSize.width.toString();
        _heightController.text = windowSize.height.toString();
      }
      if (projectAppName != null && _shouldAutofillAppName) {
        _appNameController.text = projectAppName;
      }
      if (projectMetadata.version != null &&
          _releaseTagController.text.trim().isEmpty) {
        // The version field edits major.minor.patch; the pubspec build
        // number after `+` has no place in an installer version.
        _releaseTagController.text =
            'v${projectMetadata.version!.split('+').first}';
      }
      if (projectMetadata.description != null &&
          _descriptionController.text.trim().isEmpty) {
        _descriptionController.text = projectMetadata.description!;
      }
      if (projectMetadata.homepage != null &&
          _homepageUrlController.text.trim().isEmpty) {
        _homepageUrlController.text = projectMetadata.homepage!;
      }
      _applyDeveloperDefaults();
    });
  }

  Future<void> _loadConfigPresets() async {
    await _refreshConfigPresets(await _appPreferences.loadConfigPresetPaths());
  }

  /// Rereads every pinned config. Entries whose file no longer exists are
  /// dropped: a preset lives exactly as long as its file on disk.
  Future<void> _refreshConfigPresets(List<String> paths) async {
    final presets = <ConfigPreset>[];
    final keptPaths = <String>[];
    for (final path in paths) {
      if (!await File(path).exists()) {
        continue;
      }
      keptPaths.add(path);
      presets.add(await _readConfigPreset(path));
    }

    if (keptPaths.length != paths.length) {
      await _appPreferences.saveConfigPresetPaths(keptPaths);
    }
    if (!mounted) {
      return;
    }

    setState(() {
      _configPresets
        ..clear()
        ..addAll(presets);
      if (!keptPaths.contains(_activeConfigPath)) {
        _activeConfigPath = null;
      }
    });
  }

  Future<ConfigPreset> _readConfigPreset(String path) async {
    try {
      return ConfigPreset.fromConfig(
        path,
        await _projectConfigService.load(path),
      );
    } on Object {
      return ConfigPreset.broken(path);
    }
  }

  Future<void> _addConfigPreset() async {
    if (_isBuilding) {
      return;
    }

    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(label: context.l10n.configFileType, extensions: ['json']),
      ],
      confirmButtonText: context.l10n.addConfig,
    );
    if (file == null || !mounted) {
      return;
    }

    final alreadyPinned = _configPresets.any(
      (preset) => preset.path == file.path,
    );
    await _pinConfigPath(file.path);
    if (!mounted) {
      return;
    }
    if (alreadyPinned) {
      _showSnackBar(context.l10n.configPresetAlreadyPinned);
    }
    await _applyConfigPreset(file.path);
  }

  Future<void> _pinConfigPath(String path) async {
    final paths = List<String>.from(
      await _appPreferences.loadConfigPresetPaths(),
    );
    if (!paths.contains(path)) {
      paths.add(path);
      await _appPreferences.saveConfigPresetPaths(paths);
    }
    await _refreshConfigPresets(paths);
  }

  Future<void> _applyConfigPreset(String path) async {
    if (_isBuilding) {
      return;
    }

    try {
      final config = await _projectConfigService.load(path);
      if (!mounted) {
        return;
      }
      _applyProjectConfig(config);
      setState(() {
        _activeConfigPath = path;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(context.l10n.configImportFailed(error.toString()));
      await _loadConfigPresets();
    }
  }

  Future<void> _removeConfigPreset(ConfigPreset preset) async {
    final paths = List<String>.from(
      await _appPreferences.loadConfigPresetPaths(),
    )..remove(preset.path);
    await _appPreferences.saveConfigPresetPaths(paths);
    await _refreshConfigPresets(paths);
    if (!mounted) {
      return;
    }
    _showSnackBar(context.l10n.configPresetRemoved);
  }

  Future<void> _exportProjectConfig() async {
    if (_isBuilding) {
      return;
    }

    final location = await getSaveLocation(
      acceptedTypeGroups: [
        XTypeGroup(label: context.l10n.configFileType, extensions: ['json']),
      ],
      initialDirectory: _projectPath,
      suggestedName: 'packfoundry.json',
      confirmButtonText: context.l10n.exportConfig,
      canCreateDirectories: true,
    );
    if (location == null || !mounted) {
      return;
    }

    try {
      await _projectConfigService.save(location.path, _currentProjectConfig());
      await _pinConfigPath(location.path);
      if (!mounted) {
        return;
      }
      setState(() {
        _activeConfigPath = location.path;
      });
      _showSnackBar(context.l10n.configExported);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(context.l10n.configExportFailed(error.toString()));
    }
  }

  ProjectConfig _currentProjectConfig() {
    return ProjectConfig(
      projectPath: _projectPath ?? ProjectConfig.chooseInPackFoundry,
      outputPath: _outputPath ?? ProjectConfig.chooseInPackFoundry,
      iconPath: _iconPath ?? ProjectConfig.chooseInPackFoundry,
      appName: _appNameController.text,
      releaseTag: _releaseTagController.text,
      developerEmail: _developerEmailController.text,
      publisherName: _publisherNameController.text,
      homepageUrl: _homepageUrlController.text,
      license: _licenseController.text,
      description: _descriptionController.text,
      windowWidth: int.tryParse(_widthController.text),
      windowHeight: int.tryParse(_heightController.text),
      packageTypes: [
        for (final target in _targets)
          if (target.selected)
            ProjectConfig.packageTypeForTarget(
              target.platform,
              target.artifact,
            ),
      ],
    );
  }

  void _applyProjectConfig(ProjectConfig config) {
    final projectPath = config.projectPath;
    if (!config.choosesProject && projectPath != null) {
      _setProjectPath(projectPath);
    }

    setState(() {
      _restoreConfigText(_appNameController, config.appName);
      _restoreConfigText(_releaseTagController, config.releaseTag);
      _restoreDefaultableText(DeveloperField.email, config.developerEmail);
      _restoreDefaultableText(DeveloperField.publisher, config.publisherName);
      _restoreDefaultableText(DeveloperField.homepage, config.homepageUrl);
      _restoreDefaultableText(DeveloperField.license, config.license);
      _restoreConfigText(_descriptionController, config.description);
      if (config.windowWidth != null) {
        _widthController.text = config.windowWidth.toString();
      }
      if (config.windowHeight != null) {
        _heightController.text = config.windowHeight.toString();
      }
      if (!config.choosesOutput) {
        _outputPath = config.outputPath;
      }
      if (!config.choosesIcon) {
        _iconPath = config.iconPath;
        _iconAutoDetected = false;
      }
      if (config.packageTypes.isNotEmpty) {
        for (final target in _targets) {
          target.selected =
              target.canSelect &&
              config.packageTypes.any(
                (type) => ProjectConfig.targetMatchesPackageType(
                  type,
                  target.platform,
                  target.artifact,
                ),
              );
        }
      }
      _replaceRoadmapWithPreview();
    });
  }

  void _restoreConfigText(TextEditingController controller, String? value) {
    if (value != null) {
      controller.text = value;
    }
  }

  /// A config value other than the default unticks the field's checkbox so
  /// the value from the config is kept; an empty one leaves the default.
  void _restoreDefaultableText(DeveloperField field, String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return;
    }
    if (_defaultFields.contains(field)) {
      if (text == _defaultValueFor(field, _developerDefaults)) {
        return;
      }
      _defaultFields.remove(field);
      unawaited(_appPreferences.saveDefaultFields(_defaultFields));
    }
    _controllerFor(field).text = text;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showBuildSuccessDialog() async {
    await SystemSound.play(SystemSoundType.alert);
    if (!mounted) {
      return;
    }

    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.task_alt_outlined),
        title: Text(l10n.buildSuccessTitle),
        content: Text(l10n.buildSuccessMessage),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _showBuildWarningsDialog(String? detail) async {
    await SystemSound.play(SystemSoundType.alert);
    if (!mounted) {
      return;
    }

    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error_outline),
        title: Text(l10n.buildWarningsTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.buildWarningsMessage),
              if (detail != null && detail.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                SelectableText(
                  detail.trim(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  bool get _shouldAutofillAppName {
    final currentName = _appNameController.text.trim();
    return currentName.isEmpty || currentName == _defaultAppName;
  }

  _ProjectMetadata _readProjectMetadata(String projectPath) {
    final file = File(_joinPath(projectPath, 'pubspec.yaml'));
    if (!file.existsSync()) {
      return const _ProjectMetadata();
    }

    final content = file.readAsStringSync();
    final rawName = _readPubspecScalar(content, 'name');
    final name = rawName == null || rawName.isEmpty
        ? null
        : rawName
              .split(RegExp(r'[-_\s]+'))
              .where((part) => part.isNotEmpty)
              .map((part) => part[0].toUpperCase() + part.substring(1))
              .join();

    return _ProjectMetadata(
      name: name,
      version: _readPubspecScalar(content, 'version'),
      description: _readPubspecScalar(content, 'description'),
      homepage: _readPubspecScalar(content, 'homepage'),
    );
  }

  String? _readPubspecScalar(String content, String key) {
    final match = RegExp(
      r'^' + key + r':\s*([^#\n]+)',
      multiLine: true,
    ).firstMatch(content);
    final value = match?.group(1)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  /// The run action launches `flutter run -d windows`, so only the Windows
  /// runner makes a project runnable from this host.
  bool _hasWindowsRunner(String projectPath) {
    return File(_joinPath(projectPath, 'windows/runner/main.cpp')).existsSync();
  }

  List<ProjectCheck> _buildProjectChecks(
    String projectPath,
    _ProjectMetadata metadata,
    String? detectedIcon,
  ) {
    final l10n = context.l10n;
    final hasPubspec = File(
      _joinPath(projectPath, 'pubspec.yaml'),
    ).existsSync();
    final hasWindowsRunner = _hasWindowsRunner(projectPath);
    final hasAndroid = ProjectPlatforms.supports(projectPath, 'Android');
    final hasVersion = metadata.version != null && metadata.version!.isNotEmpty;
    final hasDescription =
        metadata.description != null && metadata.description!.isNotEmpty;

    return [
      ProjectCheck(
        label: hasPubspec ? l10n.pubspecFound : l10n.pubspecMissing,
        tone: hasPubspec ? ChipTone.good : ChipTone.warning,
      ),
      if (hasWindowsRunner)
        ProjectCheck(label: l10n.windowsRunnerFound, tone: ChipTone.good),
      if (hasAndroid)
        ProjectCheck(label: l10n.androidManifestFound, tone: ChipTone.good),
      ProjectCheck(
        label: hasVersion
            ? l10n.projectVersionFound
            : l10n.projectVersionMissing,
        tone: hasVersion ? ChipTone.good : ChipTone.neutral,
      ),
      ProjectCheck(
        label: hasDescription
            ? l10n.projectDescriptionFound
            : l10n.projectDescriptionMissing,
        tone: hasDescription ? ChipTone.good : ChipTone.neutral,
      ),
      ProjectCheck(
        label: detectedIcon != null
            ? l10n.projectIconFound(
                detectedIcon.substring(projectPath.length + 1),
              )
            : l10n.projectIconMissing,
        tone: detectedIcon != null ? ChipTone.good : ChipTone.neutral,
      ),
    ];
  }

  _WindowSize? _readFlutterWindowSize(String projectPath) {
    final size = _readWindowsWindowSize(projectPath);
    // `flutter create` always writes 1280x720, so that size says nothing about
    // what the developer wants; offer the PackFoundry default instead.
    if (size != null && size.isFlutterTemplate) {
      return _WindowSize.packFoundryDefault;
    }
    return size;
  }

  _WindowSize? _readWindowsWindowSize(String projectPath) {
    final file = File(_joinPath(projectPath, 'windows/runner/main.cpp'));
    if (!file.existsSync()) {
      return null;
    }

    final match = RegExp(
      r'Win32Window::Size\s+size\s*\(\s*(\d+)\s*,\s*(\d+)\s*\)',
    ).firstMatch(file.readAsStringSync());
    return _windowSizeFromMatch(match);
  }

  _WindowSize? _windowSizeFromMatch(RegExpMatch? match) {
    if (match == null) {
      return null;
    }

    final width = int.tryParse(match.group(1) ?? '');
    final height = int.tryParse(match.group(2) ?? '');
    if (width == null || height == null) {
      return null;
    }
    return _WindowSize(width: width, height: height);
  }

  String _joinPath(String first, String second) {
    final normalizedSecond = second.replaceAll('/', Platform.pathSeparator);
    if (first.endsWith(Platform.pathSeparator)) {
      return '$first$normalizedSecond';
    }
    return '$first${Platform.pathSeparator}$normalizedSecond';
  }

  Future<void> _chooseOutputFolder() async {
    final path = await getDirectoryPath(
      confirmButtonText: context.l10n.chooseOutput,
    );
    if (path == null || !mounted) {
      return;
    }

    setState(() {
      _outputPath = path;
    });
  }

  Future<void> _chooseDefaultOutputFolder() async {
    final path = await getDirectoryPath(
      confirmButtonText: context.l10n.chooseOutput,
    );
    if (path == null || !mounted) {
      return;
    }

    await _setDefaultOutputPath(path);
  }

  Future<void> _setDefaultOutputPath(String? path) async {
    setState(() {
      _defaultOutputPath = path;
    });
    await _appPreferences.saveDefaultOutputPath(path);
  }

  Future<void> _chooseIconFile() async {
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: context.l10n.iconTypeGroup,
          extensions: ['png', 'ico', 'svg'],
        ),
      ],
      confirmButtonText: context.l10n.chooseIcon,
    );
    if (file == null || !mounted) {
      return;
    }

    setState(() {
      _iconPath = file.path;
      _iconAutoDetected = false;
    });
  }

  void _replaceLog(BuildLogEntry entry) {
    setState(() {
      _buildLog
        ..clear()
        ..add(entry);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final toolGroups = _toolGroups(l10n);
    final selectedTargets = _targets.where((target) => target.selected).length;
    final workspaces = [
      _Workspace(
        label: l10n.settings,
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
      ),
      _Workspace(
        label: l10n.project,
        icon: Icons.folder_open_outlined,
        selectedIcon: Icons.folder,
      ),
      _Workspace(
        label: l10n.build,
        icon: Icons.rocket_launch_outlined,
        selectedIcon: Icons.rocket_launch,
      ),
    ];

    final content = _WorkspaceContent(
      index: _workspaceIndex,
      themeMode: widget.themeMode,
      localeMode: widget.localeMode,
      toolGroups: toolGroups,
      installingToolTarget: _installingToolTarget,
      projectPath: _projectPath,
      projectPathController: _projectPathController,
      projectChecks: _projectChecks,
      configPresets: _configPresets,
      activeConfigPath: _activeConfigPath,
      iconPath: _iconPath,
      outputPath: _outputPath,
      defaultOutputPath: _defaultOutputPath,
      appNameController: _appNameController,
      releaseTagController: _releaseTagController,
      developerEmailController: _developerEmailController,
      publisherNameController: _publisherNameController,
      homepageUrlController: _homepageUrlController,
      licenseController: _licenseController,
      descriptionController: _descriptionController,
      defaultPublisherController: _defaultPublisherController,
      defaultEmailController: _defaultEmailController,
      githubProfileController: _githubProfileController,
      defaultLicenseController: _defaultLicenseController,
      defaultFields: _defaultFields,
      developerDefaults: _developerDefaults,
      onUseDefaultChanged: _setUseDefault,
      widthController: _widthController,
      heightController: _heightController,
      targets: _targets,
      selectedTargets: selectedTargets,
      isBuilding: _isBuilding,
      isRunningProject: _isRunningProject,
      canRunProject: _projectPath != null && _hasDesktopRunner,
      canSendToDevice:
          _projectPath != null &&
          _targets.any(
            (target) => target.artifact == BuildTarget.apk && target.selected,
          ),
      isSendingToDevice: _isSendingToDevice,
      sendToDeviceStatus: _sendToDeviceStatus,
      progress: _buildProgress,
      roadmapSteps: _roadmapSteps,
      log: _buildLog,
      onThemeModeChanged: widget.onThemeModeChanged,
      onLocaleModeChanged: widget.onLocaleModeChanged,
      onInstallTools: _installTools,
      onRefreshTools: _refreshToolchainStatus,
      onCancelInstall: _cancelToolInstall,
      onChooseProject: _chooseProjectFolder,
      onProjectPathSubmitted: _applyTypedProjectPath,
      onAddConfigPreset: _addConfigPreset,
      onSaveCurrentConfig: _exportProjectConfig,
      onApplyConfigPreset: (preset) => _applyConfigPreset(preset.path),
      onRemoveConfigPreset: _removeConfigPreset,
      onChooseIcon: _chooseIconFile,
      onChooseOutput: _chooseOutputFolder,
      onChooseDefaultOutput: _chooseDefaultOutputFolder,
      onResetDefaultOutput: () => _setDefaultOutputPath(null),
      fileNameParts: _fileNameParts,
      fileNamePreview: _setupFileNamePreview,
      onFileNamePartsChanged: _setFileNameParts,
      onTargetChanged: _setTargetSelection,
      onBuild: _runBuild,
      onBuildFromProject: _buildFromProject,
      onOpenBuild: _openBuildWorkspace,
      onRunProject: _runProjectWithoutBuild,
      onStopProject: _stopRunningProject,
      onSendToDevice: _sendApkToDevice,
      onCancelSendToDevice: _cancelSendToDevice,
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Image.asset('assets/icon.png', height: 26),
            ),
            Expanded(
              child: TabBar(
                controller: _workspaceTabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  for (var index = 0; index < workspaces.length; index++)
                    Tab(
                      height: 48,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            index == _workspaceIndex
                                ? workspaces[index].selectedIcon
                                : workspaces[index].icon,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(workspaces[index].label),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(child: content),
    );
  }

  void _openBuildWorkspace() {
    _workspaceTabController.animateTo(2);
  }

  /// The build bar of the Project workspace starts the build and shows its
  /// progress on the Build workspace.
  void _buildFromProject() {
    _openBuildWorkspace();
    _runBuild();
  }

  void _setTargetSelection(BuildTarget target, bool selected) {
    if (_isBuilding) {
      return;
    }
    setState(() {
      target.selected = selected;
      _buildProgress = 0;
      _replaceRoadmapWithPreview();
    });
  }
}

class _ProjectMetadata {
  const _ProjectMetadata({
    this.name,
    this.version,
    this.description,
    this.homepage,
  });

  final String? name;
  final String? version;
  final String? description;
  final String? homepage;
}

class _WindowSize {
  const _WindowSize({required this.width, required this.height});

  static const packFoundryDefault = _WindowSize(width: 1920, height: 1080);

  final int width;
  final int height;

  bool get isFlutterTemplate => width == 1280 && height == 720;
}

class _WorkspaceContent extends StatelessWidget {
  const _WorkspaceContent({
    required this.index,
    required this.themeMode,
    required this.localeMode,
    required this.toolGroups,
    required this.installingToolTarget,
    required this.projectPath,
    required this.projectPathController,
    required this.projectChecks,
    required this.configPresets,
    required this.activeConfigPath,
    required this.iconPath,
    required this.outputPath,
    required this.defaultOutputPath,
    required this.appNameController,
    required this.releaseTagController,
    required this.developerEmailController,
    required this.publisherNameController,
    required this.homepageUrlController,
    required this.licenseController,
    required this.descriptionController,
    required this.defaultPublisherController,
    required this.defaultEmailController,
    required this.githubProfileController,
    required this.defaultLicenseController,
    required this.defaultFields,
    required this.developerDefaults,
    required this.onUseDefaultChanged,
    required this.widthController,
    required this.heightController,
    required this.targets,
    required this.selectedTargets,
    required this.isBuilding,
    required this.isRunningProject,
    required this.canRunProject,
    required this.canSendToDevice,
    required this.isSendingToDevice,
    required this.sendToDeviceStatus,
    required this.progress,
    required this.roadmapSteps,
    required this.log,
    required this.onThemeModeChanged,
    required this.onLocaleModeChanged,
    required this.onInstallTools,
    required this.onRefreshTools,
    required this.onCancelInstall,
    required this.onChooseProject,
    required this.onProjectPathSubmitted,
    required this.onAddConfigPreset,
    required this.onSaveCurrentConfig,
    required this.onApplyConfigPreset,
    required this.onRemoveConfigPreset,
    required this.onChooseIcon,
    required this.onChooseOutput,
    required this.onChooseDefaultOutput,
    required this.onResetDefaultOutput,
    required this.fileNameParts,
    required this.fileNamePreview,
    required this.onFileNamePartsChanged,
    required this.onTargetChanged,
    required this.onBuild,
    required this.onBuildFromProject,
    required this.onOpenBuild,
    required this.onRunProject,
    required this.onStopProject,
    required this.onSendToDevice,
    required this.onCancelSendToDevice,
  });

  final int index;
  final ThemeMode themeMode;
  final AppLocaleMode localeMode;
  final List<ToolchainGroup> toolGroups;
  final ToolchainInstallTarget? installingToolTarget;
  final String? projectPath;
  final TextEditingController projectPathController;
  final List<ProjectCheck> projectChecks;
  final List<ConfigPreset> configPresets;
  final String? activeConfigPath;
  final String? iconPath;
  final String? outputPath;
  final String? defaultOutputPath;
  final TextEditingController appNameController;
  final TextEditingController releaseTagController;
  final TextEditingController developerEmailController;
  final TextEditingController publisherNameController;
  final TextEditingController homepageUrlController;
  final TextEditingController licenseController;
  final TextEditingController descriptionController;
  final TextEditingController defaultPublisherController;
  final TextEditingController defaultEmailController;
  final TextEditingController githubProfileController;
  final TextEditingController defaultLicenseController;
  final Set<DeveloperField> defaultFields;
  final DeveloperDefaults developerDefaults;
  final void Function(DeveloperField field, bool useDefault)
  onUseDefaultChanged;
  final TextEditingController widthController;
  final TextEditingController heightController;
  final List<BuildTarget> targets;
  final int selectedTargets;
  final bool isBuilding;
  final bool isRunningProject;
  final bool canRunProject;
  final bool canSendToDevice;
  final bool isSendingToDevice;
  final String? sendToDeviceStatus;
  final int progress;
  final List<BuildRoadmapStep> roadmapSteps;
  final List<BuildLogEntry> log;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<AppLocaleMode> onLocaleModeChanged;
  final ValueChanged<ToolchainInstallTarget> onInstallTools;
  final VoidCallback onRefreshTools;
  final VoidCallback onCancelInstall;
  final VoidCallback onChooseProject;
  final VoidCallback onProjectPathSubmitted;
  final VoidCallback onAddConfigPreset;
  final VoidCallback onSaveCurrentConfig;
  final ValueChanged<ConfigPreset> onApplyConfigPreset;
  final ValueChanged<ConfigPreset> onRemoveConfigPreset;
  final VoidCallback onChooseIcon;
  final VoidCallback onChooseOutput;
  final VoidCallback onChooseDefaultOutput;
  final VoidCallback onResetDefaultOutput;
  final Set<FileNamePart> fileNameParts;
  final String fileNamePreview;
  final ValueChanged<Set<FileNamePart>> onFileNamePartsChanged;
  final void Function(BuildTarget target, bool selected) onTargetChanged;
  final VoidCallback onBuild;
  final VoidCallback onBuildFromProject;
  final VoidCallback onOpenBuild;
  final VoidCallback onRunProject;
  final VoidCallback onStopProject;
  final VoidCallback onSendToDevice;
  final VoidCallback onCancelSendToDevice;

  @override
  Widget build(BuildContext context) {
    final configuration = projectPath == null
        ? null
        : BuildConfiguration(
            appName: appNameController.text,
            releaseTag: releaseTagController.text,
            developerEmail: developerEmailController.text,
            publisherName: publisherNameController.text,
            homepageUrl: homepageUrlController.text,
            license: licenseController.text,
            description: descriptionController.text,
            projectPath: projectPath!,
            outputPath: outputPath ?? defaultOutputPath,
            iconPath: iconPath,
            windowWidth: int.tryParse(widthController.text),
            windowHeight: int.tryParse(heightController.text),
            targets: targets,
            fileNameParts: fileNameParts,
          );
    final children = switch (index) {
      0 => [
        SettingsWorkspace(
          publisherNameController: defaultPublisherController,
          developerEmailController: defaultEmailController,
          githubProfileController: githubProfileController,
          licenseController: defaultLicenseController,
          themeMode: themeMode,
          localeMode: localeMode,
          onThemeModeChanged: onThemeModeChanged,
          onLocaleModeChanged: onLocaleModeChanged,
          defaultOutputPath: defaultOutputPath,
          onChooseDefaultOutput: onChooseDefaultOutput,
          onResetDefaultOutput: onResetDefaultOutput,
          fileNameParts: fileNameParts,
          fileNamePreview: fileNamePreview,
          onFileNamePartsChanged: onFileNamePartsChanged,
          toolGroups: toolGroups,
          installingToolTarget: installingToolTarget,
          onInstallTools: onInstallTools,
          onRefreshTools: onRefreshTools,
          onCancelInstall: onCancelInstall,
        ),
      ],
      1 => [
        ProjectWorkspace(
          projectPath: projectPath,
          pathController: projectPathController,
          checks: projectChecks,
          presets: configPresets,
          activeConfigPath: activeConfigPath,
          iconPath: iconPath,
          outputPath: outputPath,
          defaultOutputPath: defaultOutputPath,
          appNameController: appNameController,
          releaseTagController: releaseTagController,
          descriptionController: descriptionController,
          publisherNameController: publisherNameController,
          developerEmailController: developerEmailController,
          homepageUrlController: homepageUrlController,
          licenseController: licenseController,
          widthController: widthController,
          heightController: heightController,
          defaultFields: defaultFields,
          defaults: developerDefaults,
          targets: targets,
          configuration: configuration,
          isBuilding: isBuilding,
          progress: progress,
          isRunning: isRunningProject,
          canRun: canRunProject,
          canSendToDevice: canSendToDevice,
          isSendingToDevice: isSendingToDevice,
          sendToDeviceStatus: sendToDeviceStatus,
          onChooseProject: onChooseProject,
          onPathSubmitted: onProjectPathSubmitted,
          onAddConfig: onAddConfigPreset,
          onSaveCurrentConfig: onSaveCurrentConfig,
          onApplyPreset: onApplyConfigPreset,
          onRemovePreset: onRemoveConfigPreset,
          onChooseIcon: onChooseIcon,
          onChooseOutput: onChooseOutput,
          onUseDefaultChanged: onUseDefaultChanged,
          onTargetChanged: onTargetChanged,
          onBuild: onBuildFromProject,
          onOpenBuild: onOpenBuild,
          onRun: onRunProject,
          onStop: onStopProject,
          onSendToDevice: onSendToDevice,
          onCancelSendToDevice: onCancelSendToDevice,
        ),
      ],
      _ => [
        BuildPanel(
          selectedTargets: selectedTargets,
          isBuilding: isBuilding,
          isRunning: isRunningProject,
          canRun: canRunProject,
          progress: progress,
          roadmapSteps: roadmapSteps,
          log: log,
          configuration: configuration,
          onBuild: onBuild,
          onRun: onRunProject,
          onStop: onStopProject,
        ),
      ],
    };

    if (index != 2) {
      // Settings and Project lay out and scroll their own pages.
      return children.single;
    }

    // The build workspace fills the window so the plan, commands and log are
    // visible together; it only scrolls when the window is very short.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Low enough for Full HD at 150% scaling (about 600 px of content).
        const minHeight = 480.0;
        final panel = Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: workspaceMaxWidth),
              child: children.single,
            ),
          ),
        );
        if (constraints.maxHeight >= minHeight) {
          return panel;
        }
        return SingleChildScrollView(
          child: SizedBox(height: minHeight, child: panel),
        );
      },
    );
  }
}

class _Workspace {
  const _Workspace({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

typedef _InstallStepReport =
    void Function(double? fraction, String detail, {int? remainingSeconds});

class _ToolInstallStep {
  const _ToolInstallStep({
    required this.title,
    required this.weight,
    required this.run,
    this.cancellable = true,
  });

  final String title;

  /// Relative share of the overall progress bar, roughly the step duration.
  final int weight;
  final bool cancellable;
  final Future<ToolInstallResult> Function(_InstallStepReport report) run;
}

class _ToolInstallSession {
  _ToolInstallSession(this.target, this.steps)
    : _totalWeight = steps.fold(0, (sum, step) => sum + step.weight);

  final ToolchainInstallTarget target;
  final List<_ToolInstallStep> steps;
  final int _totalWeight;
  final _stopwatch = Stopwatch()..start();
  var _stepIndex = -1;
  double? _stepFraction;
  var _overall = 0.0;

  ToolInstallProgress report(
    int stepIndex,
    double? fraction,
    String detail, {
    int? remainingSeconds,
  }) {
    if (stepIndex != _stepIndex) {
      _stepIndex = stepIndex;
      _stepFraction = null;
    }
    // A null fraction means "no new measurement", so the last one is kept and
    // the bar never jumps backwards.
    if (fraction != null) {
      final clamped = fraction.clamp(0.0, 1.0);
      if (_stepFraction == null || clamped > _stepFraction!) {
        _stepFraction = clamped;
      }
    }

    var doneWeight = 0;
    for (var index = 0; index < stepIndex; index++) {
      doneWeight += steps[index].weight;
    }
    final overall =
        (doneWeight + steps[stepIndex].weight * (_stepFraction ?? 0)) /
        _totalWeight;
    if (overall > _overall) {
      _overall = overall;
    }

    return ToolInstallProgress(
      target: target,
      progress: (_overall * 100).floor(),
      remainingSeconds: remainingSeconds ?? _estimateRemainingSeconds(),
      detail: detail,
      steps: [for (final step in steps) step.title],
      currentStep: stepIndex,
      stepProgress: _stepFraction == null
          ? null
          : (_stepFraction! * 100).floor(),
      cancellable: steps[stepIndex].cancellable,
    );
  }

  int? _estimateRemainingSeconds() {
    final elapsed = _stopwatch.elapsed.inSeconds;
    if (_overall < 0.03 || elapsed < 5) {
      return null;
    }
    return (elapsed * (1 - _overall) / _overall).round();
  }
}
