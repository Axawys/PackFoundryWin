import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pack_foundry/core/models/build_configuration.dart';
import 'package:pack_foundry/core/models/build_log_entry.dart';
import 'package:pack_foundry/core/models/build_target.dart';
import 'package:pack_foundry/core/services/build_service.dart';
import 'package:pack_foundry/core/services/windows_icon.dart';
import 'package:pack_foundry/core/services/windows_installer_files.dart';

void main() {
  late Directory project;

  setUp(() async {
    project = await Directory.systemTemp.createTemp('pack_foundry_installer_');
    await File('${project.path}\\pubspec.yaml').writeAsString('name: demo\n');
    await File(
      '${project.path}\\windows\\CMakeLists.txt',
    ).create(recursive: true);
    await File(
      '${project.path}\\windows\\CMakeLists.txt',
    ).writeAsString('project(demo)\nset(BINARY_NAME "hash_checker")\n');
  });

  tearDown(() => project.delete(recursive: true));

  BuildConfiguration configuration({
    String appName = 'Hash Checker',
    String? outputPath,
    List<BuildTarget> targets = const [],
  }) {
    return BuildConfiguration(
      appName: appName,
      releaseTag: 'v2.1.1',
      developerEmail: 'dev@example.com',
      publisherName: 'Example Studio',
      homepageUrl: 'https://example.com',
      license: 'GPL-2.0-only',
      description: 'Checks\nfile hashes.',
      projectPath: project.path,
      outputPath: outputPath,
      iconPath: null,
      windowWidth: null,
      windowHeight: null,
      targets: targets,
    );
  }

  test('reads metadata and the runner name from the project', () {
    final metadata = WindowsInstallerMetadata.fromConfiguration(
      configuration(appName: 'Hash: Checker?'),
    );

    expect(metadata.version, '2.1.1');
    expect(metadata.exeName, 'hash_checker.exe');
    expect(metadata.description, 'Checks file hashes.');
    expect(
      metadata.setupFileName,
      'Hash- Checker-_windows_2.1.1_x64_setup.exe',
    );
  });

  test('generates an Inno Setup script from the metadata', () {
    final metadata = WindowsInstallerMetadata.fromConfiguration(
      configuration(appName: 'Hash "Checker" {beta}'),
    );
    final script = const WindowsInstallerFiles().innoSetupScript(
      metadata,
      hasIcon: true,
      hasLicenseFile: false,
    );
    final lines = script.split('\r\n');

    expect(lines, contains('#define MyAppName "Hash \'Checker\' {{beta}"'));
    expect(lines, contains('#define MyAppVersion "2.1.1"'));
    expect(lines, contains('  #define MyAppExeName "hash_checker.exe"'));
    expect(lines, contains('AppId={{hash-checker-beta-packfoundry}'));
    expect(lines, contains('AppPublisherURL=https://example.com'));
    expect(lines, contains('AppContact=dev@example.com'));
    expect(lines, contains('VersionInfoVersion=2.1.1'));
    expect(lines, contains('SetupIconFile=setup.ico'));
    expect(lines.any((line) => line.startsWith('LicenseFile=')), isFalse);
    expect(
      lines,
      contains(
        'Name: "russian"; MessagesFile: "compiler:Languages\\Russian.isl"',
      ),
    );
    expect(
      lines.where((line) => line.startsWith('OutputBaseFilename=')).single,
      startsWith('OutputBaseFilename=Hash -Checker- {beta}_windows_2.1.1'),
    );
  });

  test('generates a double-clickable build script', () {
    final metadata = WindowsInstallerMetadata.fromConfiguration(
      configuration(),
    );
    final script = const WindowsInstallerFiles().buildScript(
      metadata,
      projectPath: r'C:\Work\100% Done',
    );

    expect(script, startsWith('@echo off\r\n'));
    expect(script.replaceAll('\r\n', ''), isNot(contains('\n')));
    expect(script, contains(r'set "PROJECT_DIR=C:\Work\100%% Done"'));
    expect(script, contains('vswhere.exe'));
    expect(
      script,
      contains('Microsoft.VisualStudio.Component.VC.Tools.x86.x64'),
    );
    expect(script, contains('ISCC.exe'));
    expect(script, contains('winget install --id JRSoftware.InnoSetup -e'));
    expect(script, contains('call "%FLUTTER%" pub get'));
    expect(script, contains('call "%FLUTTER%" build windows --release'));
    expect(script, contains('exit /b %EXIT_CODE%'));
    expect(script, contains('pause'));
  });

  test('exports build_setup.cmd with setup.iss to the output folder', () async {
    final output = Directory('${project.path}\\out');
    final events = await BuildService()
        .build(
          configuration(
            outputPath: output.path,
            targets: [
              BuildTarget(
                platform: 'Windows',
                artifact: BuildTarget.buildScript,
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
    expect(logs.last.title, 'Build completed');
    expect(logs.any((log) => log.state == BuildLogState.warning), isFalse);
    expect(File('${output.path}\\build_setup.cmd').existsSync(), isTrue);
    final iss = await File('${output.path}\\setup.iss').readAsBytes();
    expect(iss.take(3), [0xEF, 0xBB, 0xBF]);
  });

  test('packs PNG images into an ICO container', () {
    Uint8List fakePng(int size) {
      final bytes = Uint8List(24);
      ByteData.sublistView(bytes)
        ..setUint32(16, size)
        ..setUint32(20, size);
      return bytes;
    }

    final ico = WindowsIcon.encode([fakePng(16), fakePng(256)]);
    final view = ByteData.sublistView(ico);

    expect(view.getUint16(2, Endian.little), 1);
    expect(view.getUint16(4, Endian.little), 2);
    expect(ico[6], 16);
    // 256 px is stored as 0 in the directory entry.
    expect(ico[6 + 16], 0);
    expect(view.getUint32(6 + 12, Endian.little), 6 + 16 * 2);
    expect(ico.length, 6 + 16 * 2 + 24 * 2);
  });
}
