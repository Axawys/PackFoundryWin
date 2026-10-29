import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pack_foundry/core/services/project_icon_finder.dart';

void main() {
  late Directory project;

  setUp(() async {
    project = await Directory.systemTemp.createTemp('pack_foundry_icon_');
    await File('${project.path}/pubspec.yaml').writeAsString('name: demo\n');
  });

  tearDown(() => project.delete(recursive: true));

  Future<String> addAsset(String name, {int bytes = 10}) async {
    final separator = Platform.pathSeparator;
    final file = File(
      '${project.path}${separator}assets$separator'
      '${name.replaceAll('/', separator)}',
    );
    await file.create(recursive: true);
    await file.writeAsBytes(List.filled(bytes, 0));
    return file.path;
  }

  test('returns null without PNG files in assets', () async {
    await addAsset('readme.txt');
    await addAsset('nested/icon.png');

    expect(const ProjectIconFinder().find(project.path), isNull);
  });

  test('prefers icon-like names over bigger images', () async {
    await addAsset('background.png', bytes: 5000);
    await addAsset('company_logo.png', bytes: 3000);
    final icon = await addAsset('app_icon.png', bytes: 100);

    expect(const ProjectIconFinder().find(project.path), icon);
  });

  test('picks the biggest PNG when names do not hint', () async {
    await addAsset('a.png', bytes: 100);
    final big = await addAsset('b.PNG', bytes: 900);

    expect(const ProjectIconFinder().find(project.path), big);
  });

  test('uses the flutter_launcher_icons image first', () async {
    await addAsset('icon.png');
    final launcher = await addAsset('branding/launcher.png');
    await File('${project.path}/pubspec.yaml').writeAsString('''
name: demo
flutter_launcher_icons:
  android: true
  image_path: "assets/branding/launcher.png"
''');

    expect(const ProjectIconFinder().find(project.path), launcher);
  });
}
