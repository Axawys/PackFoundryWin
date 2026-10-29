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

  /// Android needs the app manifest and its Gradle build file, Windows the
  /// runner's CMake project.
  static bool supports(String projectPath, String platform) {
    bool exists(String relativePath) => File(
      '$projectPath${Platform.pathSeparator}'
      '${relativePath.replaceAll('/', Platform.pathSeparator)}',
    ).existsSync();

    return switch (platform) {
      'Windows' => exists('windows/CMakeLists.txt'),
      'Android' =>
        exists(androidManifest) &&
            (exists('android/app/build.gradle') ||
                exists('android/app/build.gradle.kts')),
      _ => true,
    };
  }

  /// Relative to the project folder.
  static const androidManifest = 'android/app/src/main/AndroidManifest.xml';
}
