import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pack_foundry/core/models/build_configuration.dart';
import 'package:pack_foundry/core/models/build_log_entry.dart';
import 'package:pack_foundry/core/models/build_target.dart';
import 'package:pack_foundry/core/services/build_service.dart';
import 'package:pack_foundry/core/services/project_platforms.dart';

void main() {
  late Directory project;

  setUp(() async {
    project = await Directory.systemTemp.createTemp('pack_foundry_platforms_');
    await File('${project.path}/pubspec.yaml').writeAsString('name: demo\n');
  });

  tearDown(() => project.delete(recursive: true));

  Future<void> touch(String relativePath) async {
    await File('${project.path}/$relativePath').create(recursive: true);
  }

  test('detects platforms by their project files', () async {
    expect(ProjectPlatforms.supports(project.path, 'Android'), isFalse);
    expect(ProjectPlatforms.supports(project.path, 'Windows'), isFalse);

    await touch('android/app/build.gradle.kts');

    expect(ProjectPlatforms.supports(project.path, 'Android'), isTrue);
    expect(ProjectPlatforms.supports(project.path, 'Windows'), isFalse);

    await touch('windows/CMakeLists.txt');

    expect(ProjectPlatforms.supports(project.path, 'Windows'), isTrue);
  });

  test(
    'skips APK with a hint when the project has no android folder',
    () async {
      final events = await BuildService()
          .build(
            BuildConfiguration(
              appName: 'Demo',
              releaseTag: '',
              developerEmail: '',
              publisherName: '',
              homepageUrl: '',
              license: '',
              description: '',
              projectPath: project.path,
              outputPath: '${project.path}/out',
              iconPath: null,
              windowWidth: null,
              windowHeight: null,
              targets: [
                BuildTarget(
                  platform: 'Android',
                  artifact: BuildTarget.apk,
                  status: TargetStatus.ready,
                  selected: true,
                ),
              ],
            ),
          )
          .toList();

      final logs = [
        for (final event in events)
          if (event.logEntry != null) event.logEntry!,
      ];
      expect(
        logs.any(
          (log) =>
              log.state == BuildLogState.warning &&
              log.detail.contains('flutter create --platforms=android .'),
        ),
        isTrue,
      );
      expect(logs.last.title, 'No supported targets selected');
      expect(
        events.first.roadmapPlan?.map((step) => step.id),
        isNot(contains('android-build')),
      );
    },
  );
}
