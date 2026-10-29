import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pack_foundry/core/models/tool_status.dart';
import 'package:pack_foundry/l10n/app_localizations.dart';
import 'package:pack_foundry/ui/theme/app_theme.dart';
import 'package:pack_foundry/ui/widgets/toolchain_panel.dart';

void main() {
  Widget buildPanel(List<ToolchainGroup> groups, {VoidCallback? onCancel}) {
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
            onInstallTools: (_) {},
            onRemoveTools: (_) {},
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

  testWidgets('shows common tools in their own section', (tester) async {
    await tester.pumpWidget(
      buildPanel(const [
        ToolchainGroup(
          title: 'FLUTTER',
          subtitle: 'Common',
          status: ToolAvailability.available,
          category: ToolchainCategory.common,
          installTarget: ToolchainInstallTarget.common,
          tools: [flutterTool],
        ),
        ToolchainGroup(
          title: 'APK',
          subtitle: 'Android',
          status: ToolAvailability.installed,
          installTarget: ToolchainInstallTarget.android,
          dependencyNote: 'Needs common tools',
          tools: [],
        ),
      ]),
    );

    final common = tester.getTopLeft(find.text('COMMON'));
    final platforms = tester.getTopLeft(find.text('PLATFORMS'));
    expect(common.dy, lessThan(tester.getTopLeft(find.text('FLUTTER')).dy));
    expect(
      platforms.dy,
      greaterThan(tester.getTopLeft(find.text('FLUTTER')).dy),
    );
    expect(platforms.dy, lessThan(tester.getTopLeft(find.text('APK')).dy));
    expect(find.text('Needs common tools'), findsOneWidget);
  });

  testWidgets('shows overall progress and install steps', (tester) async {
    var cancelled = false;
    await tester.pumpWidget(
      buildPanel(const [
        ToolchainGroup(
          title: 'FLUTTER',
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
