import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pack_foundry/core/models/tool_status.dart';
import 'package:pack_foundry/l10n/app_localizations.dart';
import 'package:pack_foundry/ui/theme/app_theme.dart';
import 'package:pack_foundry/ui/widgets/toolchain_panel.dart';

void main() {
  Widget buildPanel(
    List<ToolchainGroup> groups, {
    VoidCallback? onCancel,
    ValueChanged<ToolchainInstallTarget>? onInstall,
  }) {
    return MaterialApp(
      theme: buildAppTheme(Brightness.light),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ToolchainPanel(
            groups: groups,
            installingTarget: groups
                .where((group) => group.installProgress != null)
                .map((group) => group.installTarget)
                .firstOrNull,
            onInstallTools: onInstall ?? (_) {},
            onCancelInstall: onCancel ?? () {},
            initiallyExpanded: true,
          ),
        ),
      ),
    );
  }

  const flutterTool = ToolStatus(
    name: 'Flutter SDK',
    command: 'flutter',
    status: ToolAvailability.missing,
    note: '',
  );

  testWidgets('shows a card per platform with its state and targets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ToolchainInstallTarget? installed;
    await tester.pumpWidget(
      buildPanel(const [
        ToolchainGroup(
          title: 'Android',
          subtitle: 'APK',
          status: ToolAvailability.available,
          installTarget: ToolchainInstallTarget.android,
          dependencyNote: 'Needs common tools',
          installSizeLabel: '3 GB',
          unlocks: ['apk'],
          tools: [
            ToolStatus(
              name: 'Android SDK',
              command: 'adb',
              status: ToolAvailability.missing,
              note: 'Builds APK',
            ),
            ToolStatus(
              name: 'Java',
              command: 'java',
              status: ToolAvailability.missing,
              note: 'Runs Gradle',
            ),
          ],
        ),
        ToolchainGroup(
          title: 'Flutter',
          subtitle: 'Common',
          status: ToolAvailability.installed,
          category: ToolchainCategory.common,
          installTarget: ToolchainInstallTarget.common,
          unlocks: ['every target'],
          tools: [
            ToolStatus(
              name: 'Flutter SDK',
              command: 'flutter',
              status: ToolAvailability.installed,
              note: 'Required for every build target',
            ),
          ],
        ),
      ], onInstall: (target) => installed = target),
    );

    // The common card comes first even when listed later.
    expect(
      tester.getTopLeft(find.text('Flutter')).dx,
      lessThan(tester.getTopLeft(find.text('Android')).dx),
    );
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('2 missing'), findsOneWidget);
    expect(find.text('every target'), findsOneWidget);
    expect(find.text('apk'), findsOneWidget);
    expect(find.text('Needs common tools'), findsOneWidget);
    // Only the card with missing tools offers an install.
    final install = find.widgetWithText(
      FilledButton,
      'Install missing tools · 3 GB',
    );
    expect(install, findsOneWidget);
    await tester.tap(install);
    expect(installed, ToolchainInstallTarget.android);
  });

  testWidgets('warns in the header only about missing common tools', (
    tester,
  ) async {
    ToolchainGroup android(ToolAvailability status) => ToolchainGroup(
      title: 'APK',
      subtitle: 'Android',
      status: status,
      installTarget: ToolchainInstallTarget.android,
      tools: [
        ToolStatus(
          name: 'Android SDK',
          command: 'adb',
          status: status,
          note: '',
        ),
      ],
    );
    ToolchainGroup common(ToolAvailability status) => ToolchainGroup(
      title: 'FLUTTER',
      subtitle: 'Common',
      status: status,
      category: ToolchainCategory.common,
      installTarget: ToolchainInstallTarget.common,
      tools: [
        ToolStatus(
          name: 'Flutter SDK',
          command: 'flutter',
          status: status,
          note: '',
        ),
      ],
    );

    await tester.pumpWidget(
      buildPanel([
        common(ToolAvailability.installed),
        android(ToolAvailability.missing),
      ]),
    );
    expect(find.textContaining('Not installed'), findsNothing);

    await tester.pumpWidget(
      buildPanel([
        common(ToolAvailability.missing),
        android(ToolAvailability.missing),
      ]),
    );
    expect(find.text('Not installed: Flutter SDK'), findsOneWidget);
  });

  testWidgets('shows overall progress and install steps', (tester) async {
    var cancelled = false;
    await tester.pumpWidget(
      buildPanel(const [
        ToolchainGroup(
          title: 'Flutter',
          subtitle: 'Common',
          status: ToolAvailability.available,
          category: ToolchainCategory.common,
          installTarget: ToolchainInstallTarget.common,
          tools: [flutterTool],
          installProgress: ToolInstallProgress(
            target: ToolchainInstallTarget.common,
            progress: 42,
            remainingSeconds: null,
            detail: 'Receiving objects:  45%',
            steps: ['System packages', 'Flutter SDK'],
            currentStep: 1,
            stepProgress: 45,
          ),
        ),
      ], onCancel: () => cancelled = true),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Installing: 42%'), findsOneWidget);
    expect(find.text('Step 2 of 2'), findsOneWidget);
    expect(find.text('45%'), findsOneWidget);
    expect(find.text('Estimating time…'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.42, 0.001));

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    expect(cancelled, isTrue);
  });
}
