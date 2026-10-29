import '../models/build_configuration.dart';
import '../models/build_target.dart';
import 'windows_installer_files.dart';

/// `AppName_android_1.3.0_universal.apk`.
String apkFileName(WindowsInstallerMetadata metadata) {
  final name = [
    WindowsInstallerMetadata.safeFileName(metadata.appName),
    'android',
    WindowsInstallerMetadata.safeFileName(metadata.version),
    'universal',
  ].join('_');
  return '$name.apk';
}

/// File names the selected [targets] of [configuration] are exported as.
List<String> packageFileNames(
  BuildConfiguration configuration,
  Iterable<BuildTarget> targets,
) {
  final metadata = WindowsInstallerMetadata.fromConfiguration(configuration);
  return [
    for (final target in targets)
      switch (target.artifact) {
        BuildTarget.setupExe => metadata.setupFileName,
        BuildTarget.portable => metadata.portableFileName,
        BuildTarget.buildScript => WindowsInstallerFiles.scriptFileName,
        BuildTarget.apk => apkFileName(metadata),
        _ => target.displayLabel,
      },
  ];
}
