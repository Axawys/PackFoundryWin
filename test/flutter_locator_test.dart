import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pack_foundry/core/services/flutter_locator.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('pack_foundry_flutter_');
  });

  tearDown(() => root.delete(recursive: true));

  Future<File> fakeFlutter(String sdkFolder) async {
    final file = File('${root.path}\\$sdkFolder\\bin\\flutter.bat');
    await file.create(recursive: true);
    return file;
  }

  Map<String, String> environment({String path = r'C:\Windows\System32'}) {
    return {
      'PATH': path,
      'USERPROFILE': '${root.path}\\profile',
      'LOCALAPPDATA': '${root.path}\\local',
    };
  }

  test('falls back to the managed SDK when flutter is not on PATH', () async {
    final managed = await fakeFlutter(r'local\PackFoundry\flutter');
    final locator = FlutterLocator(environment: environment());

    expect(locator.find()?.path, managed.path);
    expect(locator.managedExecutable.path, managed.path);
  });

  test('prefers flutter from PATH over other installs', () async {
    final onPath = await fakeFlutter('custom');
    await fakeFlutter(r'profile\flutter');
    await fakeFlutter(r'local\PackFoundry\flutter');
    final locator = FlutterLocator(
      environment: environment(
        path: '${root.path}\\empty;"${onPath.parent.path}"',
      ),
    );

    expect(locator.find()?.path, onPath.path);
  });

  test('finds FLUTTER_ROOT and usual profile folders', () async {
    final inProfile = await fakeFlutter(r'profile\dev\flutter');
    expect(
      FlutterLocator(environment: environment()).find()?.path,
      inProfile.path,
    );

    final fromRoot = await fakeFlutter('sdk-root');
    expect(
      FlutterLocator(
        environment: {
          ...environment(),
          'FLUTTER_ROOT': fromRoot.parent.parent.path,
        },
      ).find()?.path,
      fromRoot.path,
    );
  });

  test('reads environment variables case-insensitively', () async {
    final onPath = await fakeFlutter('custom');
    final locator = FlutterLocator(
      environment: {'Path': onPath.parent.path, 'LocalAppData': root.path},
    );

    expect(locator.find()?.path, onPath.path);
  });

  test('puts the SDK bin folder first on PATH for child processes', () {
    final locator = FlutterLocator(
      environment: {'PATH': r'C:\Windows;C:\Tools'},
    );

    expect(
      locator.environmentFor(File(r'C:\flutter\bin\flutter.bat'))['PATH'],
      r'C:\flutter\bin;C:\Windows;C:\Tools',
    );
  });
}
