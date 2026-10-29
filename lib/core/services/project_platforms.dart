import 'dart:io';

/// Tells which Flutter platforms a project has been created for.
///
/// Building a platform the project lacks fails deep inside the flutter tool,
/// e.g. `flutter build apk` without `android/` reports that it cannot read
/// `android/app/build.gradle`, so targets are checked up front instead.
class ProjectPlatforms {
  const ProjectPlatforms._();

  /// The project folder a platform lives in, or null when PackFoundry does
  /// not need one for that platform.
  static String? folderFor(String platform) {
    return switch (platform) {
      'Windows' => 'windows',
      'Android' => 'android',
      _ => null,
    };
  }

  static bool supports(String projectPath, String platform) {
    final separator = Platform.pathSeparator;
    return switch (platform) {
      'Windows' => File(
        '$projectPath${separator}windows${separator}CMakeLists.txt',
      ).existsSync(),
      'Android' =>
        File('$projectPath${separator}android${separator}app${separator}build.gradle')
                .existsSync() ||
            File(
              '$projectPath${separator}android${separator}app${separator}build.gradle.kts',
            ).existsSync(),
      _ => true,
    };
  }
}
