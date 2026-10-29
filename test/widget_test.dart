import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_foundry/core/models/build_log_entry.dart';
import 'package:pack_foundry/core/models/build_target.dart';
import 'package:pack_foundry/core/models/build_configuration.dart';
import 'package:pack_foundry/core/models/project_config.dart';
import 'package:pack_foundry/core/services/build_service.dart';
import 'package:pack_foundry/core/services/project_config_service.dart';
import 'package:pack_foundry/l10n/app_localizations.dart';
import 'package:pack_foundry/main.dart';
import 'package:pack_foundry/ui/widgets/build_panel.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'hideWelcome': true});
  });

  testWidgets('shows PackFoundry workspaces', (tester) async {
    await tester.pumpWidget(
      const PackFoundryApp(enableToolchainDiagnostics: false),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Project'), findsWidgets);
    expect(find.text('Build'), findsOneWidget);
    expect(find.text('Application settings'), findsOneWidget);
    expect(find.text('Installers'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pump();
    expect(find.text('Toolchain'), findsOneWidget);
    await tester.ensureVisible(find.text('Preferences'));
    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Interface theme'), findsOneWidget);

    await tester.tap(find.text('Build'));
    await tester.pump();
    // setup.exe is selected out of the box.
    expect(find.text('1 selected target'), findsOneWidget);
    expect(find.bySubtype<FilledButton>(), findsOneWidget);
  });

  test('creates a pending roadmap preview from selected targets', () {
    final targets = [
      BuildTarget(
        platform: 'Windows',
        artifact: BuildTarget.setupExe,
        status: TargetStatus.ready,
        selected: true,
      ),
      BuildTarget(
        platform: 'Windows',
        artifact: BuildTarget.buildScript,
        status: TargetStatus.ready,
        selected: true,
      ),
      BuildTarget(
        platform: 'Android',
        artifact: BuildTarget.apk,
        status: TargetStatus.ready,
      ),
    ];

    final steps = BuildService().createRoadmapPlan(targets);

    expect(
      steps.map((step) => step.id),
      containsAllInOrder(<String>[
        'project',
        'build-script',
        'workspace',
        'windows-build',
        'installer',
        'summary',
        'cleanup',
      ]),
    );
    expect(steps.map((step) => step.id), isNot(contains('android-build')));
    expect(
      steps.every((step) => step.state == BuildRoadmapStepState.pending),
      isTrue,
    );
  });

  test('exports only the script without a temporary workspace', () {
    final steps = BuildService().createRoadmapPlan([
      BuildTarget(
        platform: 'Windows',
        artifact: BuildTarget.buildScript,
        status: TargetStatus.ready,
        selected: true,
      ),
    ]);

    expect(steps.map((step) => step.id), [
      'project',
      'build-script',
      'summary',
    ]);
  });

  test('creates an APK roadmap preview from Android target', () {
    final targets = [
      BuildTarget(
        platform: 'Android',
        artifact: BuildTarget.apk,
        status: TargetStatus.ready,
        selected: true,
      ),
    ];

    final steps = BuildService().createRoadmapPlan(targets);

    expect(
      steps.map((step) => step.id),
      containsAll(<String>[
        'project',
        'workspace',
        'android-build',
        'apk-export',
        'summary',
        'cleanup',
      ]),
    );
    expect(steps.map((step) => step.id), isNot(contains('windows-build')));
  });

  test('maps targets to config package types and labels', () {
    expect(
      ProjectConfig.packageTypeForTarget('Windows', BuildTarget.setupExe),
      'exe',
    );
    expect(
      ProjectConfig.packageTypeForTarget('Windows', BuildTarget.buildScript),
      'cmd',
    );
    expect(
      ProjectConfig.packageTypeForTarget('Android', BuildTarget.apk),
      'apk',
    );
    expect(
      BuildTarget(
        platform: 'Windows',
        artifact: BuildTarget.buildScript,
        status: TargetStatus.ready,
      ).displayLabel,
      'build_setup.cmd',
    );
  });

  testWidgets('shows ISCC commands for the installer step', (tester) async {
    // Tall enough for the lazily built command list to show every command.
    tester.view.physicalSize = const Size(1280, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final target = BuildTarget(
      platform: 'Windows',
      artifact: BuildTarget.setupExe,
      status: TargetStatus.ready,
      selected: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BuildPanel(
            selectedTargets: 1,
            isBuilding: false,
            progress: 0,
            roadmapSteps: BuildService().createRoadmapPlan([target]),
            log: const [],
            configuration: BuildConfiguration(
              appName: 'Hash Checker',
              releaseTag: 'v2.1.1',
              developerEmail: 'dev@example.com',
              publisherName: 'Example Studio',
              homepageUrl: 'https://example.com',
              license: 'GPL-2.0-only',
              description: 'Checks file hashes.',
              projectPath: r'C:\Users\user\Hash Checker',
              outputPath: r'C:\Users\user\Packages',
              iconPath: null,
              windowWidth: null,
              windowHeight: null,
              targets: [target],
            ),
            onBuild: () {},
            isRunning: false,
            canRun: true,
            onRun: () {},
            onStop: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('SETUP.EXE'));
    await tester.pump();

    expect(find.text('Commands · SETUP.EXE'), findsOneWidget);
    expect(find.textContaining('"/O%EXPORT%"'), findsOneWidget);
    expect(
      find.text(r'dir "%EXPORT%\Hash Checker_windows_2.1.1_x64_setup.exe"'),
      findsOneWidget,
    );
  });

  test('saves and loads PackFoundry project config', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'pack_foundry_config_test_',
    );
    addTearDown(() => tempDir.delete(recursive: true));

    final service = ProjectConfigService();
    final separator = Platform.pathSeparator;
    final configPath = '${tempDir.path}${separator}packfoundry.json';
    final config = ProjectConfig(
      projectPath: '.',
      outputPath: ProjectConfig.chooseInPackFoundry,
      iconPath: 'assets/icon.png',
      appName: 'HashChecker',
      releaseTag: 'v2.1.1',
      developerEmail: 'dev@example.com',
      publisherName: 'Example Studio',
      homepageUrl: 'https://example.com',
      license: 'GPL-2.0-only',
      description: 'Checks file hashes.',
      windowWidth: 1280,
      windowHeight: 800,
      packageTypes: const ['exe', 'cmd', 'apk'],
    );

    await service.save(configPath, config);
    final loaded = await service.load(configPath);

    expect(loaded.projectPath, '${tempDir.path}$separator.');
    expect(loaded.choosesOutput, isTrue);
    expect(
      loaded.iconPath,
      '${tempDir.path}${separator}assets${separator}icon.png',
    );
    expect(loaded.releaseTag, 'v2.1.1');
    expect(loaded.packageTypes, ['exe', 'cmd', 'apk']);
  });

  testWidgets('shows roadmap before starting the selected build', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const PackFoundryApp(enableToolchainDiagnostics: false),
    );
    await tester.pump();
    await tester.pump();


    await tester.tap(find.text('Build'));
    await tester.pump();

    expect(find.text('Build plan'), findsOneWidget);
    expect(find.text('Process log'), findsOneWidget);
    expect(find.text('SETUP.EXE'), findsOneWidget);
    expect(find.text('Flutter build'), findsOneWidget);
    expect(find.text('Full'), findsNothing);
    expect(find.text('Simplified'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      find.text(
        'Select a Flutter project so PackFoundry can resolve real paths and names.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows executable commands with resolved build values', (
    tester,
  ) async {
    final target = BuildTarget(
      platform: 'Windows',
      artifact: BuildTarget.setupExe,
      status: TargetStatus.ready,
      selected: true,
    );
    final steps = BuildService().createRoadmapPlan([target]);
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BuildPanel(
              selectedTargets: 1,
              isBuilding: false,
              progress: 0,
              roadmapSteps: steps,
              log: const [],
              configuration: BuildConfiguration(
                appName: 'Hash Checker',
                releaseTag: 'v2.1.1',
                developerEmail: 'dev@example.com',
                publisherName: 'Example Studio',
                homepageUrl: 'https://example.com',
                license: 'GPL-2.0-only',
                description: 'Checks file hashes.',
                projectPath: r'C:\Users\user\Hash Checker',
                outputPath: r'C:\Users\user\100% Packages',
                iconPath: r'C:\Users\user\hashchecker.png',
                windowWidth: 1280,
                windowHeight: 800,
                targets: [target],
              ),
              onBuild: () {},
              isRunning: false,
              canRun: true,
              onRun: () {},
              onStop: () {},
            ),
          ),
        ),
      ),
    );

    // The first step is selected before the build starts.
    expect(find.text('Commands · Project'), findsOneWidget);
    expect(
      find.text(r'set "PROJECT=C:\Users\user\Hash Checker"'),
      findsOneWidget,
    );
    // Percent signs are doubled inside a .cmd script.
    expect(
      find.text(r'set "EXPORT=C:\Users\user\100%% Packages"'),
      findsOneWidget,
    );
    expect(find.text('call flutter build windows --release'), findsNothing);

    await tester.tap(find.text('Flutter build'));
    await tester.pump();

    expect(find.text('Commands · Flutter build'), findsOneWidget);
    expect(find.text('call flutter build windows --release'), findsOneWidget);
    expect(
      find.text(r'set "PROJECT=C:\Users\user\Hash Checker"'),
      findsNothing,
    );

    await tester.tap(find.text('Full script'));
    await tester.pump();

    expect(clipboardText, startsWith('@echo off\r\n'));
    expect(
      clipboardText,
      contains(r'set "PROJECT=C:\Users\user\Hash Checker"'),
    );
    expect(clipboardText, contains('call flutter build windows --release'));
    expect(clipboardText, isNot(contains('#!/usr/bin/env bash')));
  });

  testWidgets('remembers release metadata fields', (tester) async {
    Finder field(String label) {
      return find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
    }

    await tester.pumpWidget(
      const PackFoundryApp(enableToolchainDiagnostics: false),
    );
    await tester.pump();
    await tester.pump();

    // Developer fields follow the settings until their checkbox is cleared.
    for (final label in ['Developer email', 'Developer / publisher']) {
      expect(tester.widget<TextField>(field(label)).readOnly, isTrue);
    }
    final defaultBoxes = find.text('Default');
    expect(defaultBoxes, findsNWidgets(4));
    for (var index = 0; index < 4; index++) {
      await tester.ensureVisible(defaultBoxes.at(index));
      await tester.tap(defaultBoxes.at(index));
      await tester.pump();
    }

    await tester.enterText(field('Release tag'), 'v2.3.0');
    await tester.enterText(field('Developer email'), 'dev@example.com');
    await tester.enterText(field('Developer / publisher'), 'Example Studio');
    await tester.enterText(field('Project homepage'), 'https://example.com');
    await tester.enterText(field('Package description'), 'Saved description');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('releaseTag'), 'v2.3.0');
    expect(preferences.getString('developerEmail'), 'dev@example.com');
    expect(preferences.getString('publisherName'), 'Example Studio');
    expect(preferences.getString('homepageUrl'), 'https://example.com');
    expect(preferences.getString('projectDescription'), 'Saved description');

    await tester.pumpWidget(
      PackFoundryApp(key: UniqueKey(), enableToolchainDiagnostics: false),
    );
    await tester.pump();
    await tester.pump();

    expect(
      tester.widget<TextField>(field('Release tag')).controller?.text,
      'v2.3.0',
    );
    expect(
      tester.widget<TextField>(field('Developer email')).controller?.text,
      'dev@example.com',
    );
    expect(
      tester.widget<TextField>(field('Developer / publisher')).controller?.text,
      'Example Studio',
    );
    expect(
      tester.widget<TextField>(field('Project homepage')).controller?.text,
      'https://example.com',
    );
    expect(
      tester.widget<TextField>(field('Package description')).controller?.text,
      'Saved description',
    );
  });

  testWidgets('fills developer fields from the settings defaults', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'hideWelcome': true,
      'defaultPublisherName': 'Axawys',
      'defaultDeveloperEmail': 'axawys@example.com',
      'githubProfile': 'Axawys',
    });
    Finder field(String label) {
      return find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
    }

    await tester.pumpWidget(
      const PackFoundryApp(enableToolchainDiagnostics: false),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(field('Developer / publisher')).controller?.text,
      'Axawys',
    );
    expect(
      tester.widget<TextField>(field('Developer email')).controller?.text,
      'axawys@example.com',
    );

    final emailDefault = find.text('Default').at(1);
    await tester.ensureVisible(emailDefault);
    await tester.tap(emailDefault);
    await tester.pump();
    expect(
      tester.widget<TextField>(field('Developer email')).readOnly,
      isFalse,
    );
    await tester.enterText(field('Developer email'), 'other@example.com');
    await tester.pump(const Duration(milliseconds: 450));

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('manualFields'), ['email']);
    expect(
      preferences.getString('defaultDeveloperEmail'),
      'axawys@example.com',
    );
  });

  testWidgets('shows welcome dialog by default', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const PackFoundryApp(enableToolchainDiagnostics: false),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Welcome to PackFoundry'), findsOneWidget);
    expect(find.text('Interface theme'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Do not show again'), findsOneWidget);
  });

  testWidgets('applies welcome theme selection immediately', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const PackFoundryApp(enableToolchainDiagnostics: false),
    );
    await tester.pump();
    await tester.pump();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );

    await tester.tap(find.text('Dark'));
    await tester.pump();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
  });

  testWidgets('applies language selection immediately', (tester) async {
    await tester.pumpWidget(
      const PackFoundryApp(enableToolchainDiagnostics: false),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.ensureVisible(find.text('Interface language'));
    expect(find.text('Interface language'), findsOneWidget);

    await tester.ensureVisible(find.text('Russian'));
    await tester.tap(find.text('Russian'));
    await tester.pump();

    expect(find.text('Язык интерфейса'), findsOneWidget);
    expect(find.text('Настройки'), findsOneWidget);
  });

  testWidgets('localizes build roadmap in Russian', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            child: BuildPanel(
              selectedTargets: 1,
              isBuilding: true,
              progress: 25,
              roadmapSteps: const [
                BuildRoadmapStep(
                  id: 'cleanup',
                  number: 1,
                  title: 'Cleanup',
                  description: 'Remove the temporary workspace.',
                  state: BuildRoadmapStepState.running,
                  progress: 40,
                  estimatedSeconds: 180,
                  detail: 'Temporary files were removed.',
                ),
              ],
              log: const [],
              onBuild: () {},
              isRunning: false,
              canRun: true,
              onRun: () {},
              onStop: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('План сборки'), findsOneWidget);
    expect(find.text('Журнал процессов'), findsOneWidget);
    expect(find.text('Очистка'), findsOneWidget);
    expect(find.text('Команды · Очистка'), findsOneWidget);
    expect(find.text('Временные файлы удалены.'), findsOneWidget);
    expect(find.textContaining('Обычно: ~3 мин'), findsOneWidget);
  });

  testWidgets('shows estimated remaining build time', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BuildPanel(
              selectedTargets: 1,
              isBuilding: true,
              progress: 25,
              roadmapSteps: const [
                BuildRoadmapStep(
                  id: 'project',
                  number: 1,
                  title: 'Project',
                  description:
                      'Check pubspec.yaml, app metadata and export folder.',
                  state: BuildRoadmapStepState.success,
                  progress: 100,
                  estimatedSeconds: 10,
                ),
                BuildRoadmapStep(
                  id: 'windows-build',
                  number: 2,
                  title: 'Flutter build',
                  description: 'Compile the Windows release runner.',
                  state: BuildRoadmapStepState.running,
                  progress: 50,
                  estimatedSeconds: 120,
                ),
                BuildRoadmapStep(
                  id: 'cleanup',
                  number: 3,
                  title: 'Cleanup',
                  description: 'Remove the temporary workspace.',
                  state: BuildRoadmapStepState.pending,
                  progress: 0,
                  estimatedSeconds: 180,
                ),
              ],
              log: const [],
              onBuild: () {},
              isRunning: false,
              canRun: true,
              onRun: () {},
              onStop: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Overall progress: 25%'), findsOneWidget);
    expect(find.text('Remaining: ~4 min'), findsOneWidget);
  });

  testWidgets('selects the running step and follows the build', (tester) async {
    Widget buildPanel(List<BuildRoadmapStep> steps) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BuildPanel(
              selectedTargets: 1,
              isBuilding: true,
              progress: 25,
              roadmapSteps: steps,
              log: const [],
              onBuild: () {},
              isRunning: false,
              canRun: true,
              onRun: () {},
              onStop: () {},
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(
      buildPanel(const [
        BuildRoadmapStep(
          id: 'windows-build',
          number: 1,
          title: 'Flutter build',
          description: 'Compile the Windows release runner.',
          state: BuildRoadmapStepState.running,
          progress: 20,
          estimatedSeconds: 120,
        ),
        BuildRoadmapStep(
          id: 'cleanup',
          number: 2,
          title: 'Cleanup',
          description: 'Remove the temporary workspace.',
          state: BuildRoadmapStepState.pending,
          progress: 0,
          estimatedSeconds: 180,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Commands · Flutter build'), findsOneWidget);

    await tester.pumpWidget(
      buildPanel(const [
        BuildRoadmapStep(
          id: 'windows-build',
          number: 1,
          title: 'Flutter build',
          description: 'Compile the Windows release runner.',
          state: BuildRoadmapStepState.success,
          progress: 100,
          estimatedSeconds: 120,
        ),
        BuildRoadmapStep(
          id: 'cleanup',
          number: 2,
          title: 'Cleanup',
          description: 'Remove the temporary workspace.',
          state: BuildRoadmapStepState.running,
          progress: 30,
          estimatedSeconds: 180,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Commands · Cleanup'), findsOneWidget);
  });

  testWidgets('holds fast roadmap completion briefly before final state', (
    tester,
  ) async {
    Widget buildPanel(BuildRoadmapStep step) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BuildPanel(
              selectedTargets: 1,
              isBuilding: false,
              isRunning: false,
              canRun: true,
              progress: 0,
              roadmapSteps: [step],
              log: const [],
              onBuild: () {},
              onRun: () {},
              onStop: () {},
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(
      buildPanel(
        const BuildRoadmapStep(
          id: 'summary',
          number: 1,
          title: 'Export',
          description: 'Verify and report generated artifacts.',
          state: BuildRoadmapStepState.pending,
        ),
      ),
    );

    await tester.pumpWidget(
      buildPanel(
        const BuildRoadmapStep(
          id: 'summary',
          number: 1,
          title: 'Export',
          description: 'Verify and report generated artifacts.',
          state: BuildRoadmapStepState.success,
          progress: 100,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('keeps a step picked by the user while it is running', (
    tester,
  ) async {
    Widget buildPanel(int cleanupProgress) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BuildPanel(
              selectedTargets: 1,
              isBuilding: true,
              progress: 25,
              roadmapSteps: [
                BuildRoadmapStep(
                  id: 'cleanup',
                  number: 1,
                  title: 'Cleanup',
                  description: 'Remove the temporary workspace.',
                  state: BuildRoadmapStepState.running,
                  progress: cleanupProgress,
                  estimatedSeconds: 180,
                ),
                const BuildRoadmapStep(
                  id: 'installer',
                  number: 2,
                  title: 'SETUP.EXE',
                  description:
                      'Generate setup.iss and compile it with Inno Setup.',
                  state: BuildRoadmapStepState.pending,
                  progress: 0,
                  estimatedSeconds: 25,
                ),
              ],
              log: const [],
              onBuild: () {},
              isRunning: false,
              canRun: true,
              onRun: () {},
              onStop: () {},
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildPanel(40));
    expect(find.text('Commands · Cleanup'), findsOneWidget);

    await tester.tap(find.text('SETUP.EXE'));
    await tester.pump();
    expect(find.text('Commands · SETUP.EXE'), findsOneWidget);

    await tester.pumpWidget(buildPanel(60));
    await tester.pump();
    expect(find.text('Commands · SETUP.EXE'), findsOneWidget);
  });

  testWidgets('fits the build workspace into the window', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const PackFoundryApp(enableToolchainDiagnostics: false),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Build'));
    await tester.pump();

    final screen = Offset.zero & const Size(1280, 800);
    final plan = tester.getRect(find.text('Build plan'));
    final log = tester.getRect(find.text('Process log'));
    expect(screen.contains(plan.center), isTrue);
    expect(screen.contains(log.center), isTrue);
    // Plan and console sit side by side rather than one under the other.
    expect(log.left, greaterThan(plan.right));
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses Russian system locale when available', (tester) async {
    tester.binding.platformDispatcher.localesTestValue = const [Locale('ru')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(
      const PackFoundryApp(enableToolchainDiagnostics: false),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Настройки'), findsOneWidget);
    expect(find.text('Проект'), findsWidgets);
    expect(find.text('Сборка'), findsOneWidget);
    expect(find.text('Настройки приложения'), findsOneWidget);
    expect(find.text('Установщики'), findsOneWidget);

    await tester.tap(find.text('Сборка'));
    await tester.pump();
    expect(
      find.ancestor(
        of: find.text('Собрать'),
        matching: find.bySubtype<FilledButton>(),
      ),
      findsOneWidget,
    );
  });
}
