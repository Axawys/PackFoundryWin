import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_foundry/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory root;

  setUp(() {
    SharedPreferences.setMockInitialValues({'hideWelcome': true});
    root = Directory.systemTemp.createTempSync('pack_foundry_targets_');
  });

  tearDown(() => root.deleteSync(recursive: true));

  /// A Flutter project folder with the files of the given platforms.
  String project(String name, {bool windows = false, bool android = false}) {
    final path = '${root.path}${Platform.pathSeparator}$name';
    void touch(String relative) => File(
      '$path${Platform.pathSeparator}'
      '${relative.replaceAll('/', Platform.pathSeparator)}',
    ).createSync(recursive: true);

    touch('pubspec.yaml');
    if (windows) {
      touch('windows/CMakeLists.txt');
      touch('windows/runner/main.cpp');
    }
    if (android) {
      touch('android/app/build.gradle.kts');
      touch('android/app/src/main/AndroidManifest.xml');
    }
    return path;
  }

  Future<void> openProject(WidgetTester tester, String path) async {
    final field = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Project path',
    );
    await tester.enterText(field, path);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
  }

  Finder tile(String label) => find.text(label);

  Future<void> reopenProjectTab(WidgetTester tester) async {
    Finder tab(String label) =>
        find.descendant(of: find.byType(TabBar), matching: find.text(label));
    await tester.tap(tab('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(tab('Project'));
    await tester.pumpAndSettle();
  }

  testWidgets('offers only the targets of platforms the project has', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final windowsOnly = project('windows_only', windows: true);
    final androidOnly = project('android_only', android: true);
    final both = project('both', windows: true, android: true);

    await tester.pumpWidget(
      const PackFoundryApp(enableToolchainDiagnostics: false),
    );
    await tester.pumpAndSettle();

    await openProject(tester, windowsOnly);
    expect(tile('setup.exe'), findsOneWidget);
    expect(tile('apk'), findsNothing);

    await openProject(tester, androidOnly);
    expect(tile('apk'), findsOneWidget);
    for (final windowsTarget in ['setup.exe', 'portable', 'build_setup.cmd']) {
      expect(tile(windowsTarget), findsNothing);
    }

    // A selection survives a project without the platform.
    await openProject(tester, both);
    await tester.tap(tile('apk'));
    await tester.pump();
    expect(find.textContaining('setup.exe + apk'), findsOneWidget);

    await openProject(tester, windowsOnly);
    expect(tile('apk'), findsNothing);

    await openProject(tester, both);
    expect(find.textContaining('setup.exe + apk'), findsOneWidget);
  });

  testWidgets('shows a platform added while the app is open', (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final path = project('grows', windows: true);

    await tester.pumpWidget(
      const PackFoundryApp(enableToolchainDiagnostics: false),
    );
    await tester.pumpAndSettle();
    await openProject(tester, path);
    expect(tile('apk'), findsNothing);

    // What `flutter create --platforms=android .` adds.
    for (final relative in [
      'android/app/build.gradle.kts',
      'android/app/src/main/AndroidManifest.xml',
    ]) {
      File(
        '$path${Platform.pathSeparator}'
        '${relative.replaceAll('/', Platform.pathSeparator)}',
      ).createSync(recursive: true);
    }
    await reopenProjectTab(tester);

    expect(tile('apk'), findsOneWidget);
  });
}
