import 'dart:io';

/// Picks the most likely application icon of a Flutter project, so selecting
/// a project does not require choosing the icon by hand.
class ProjectIconFinder {
  const ProjectIconFinder();

  static const _preferredNames = {
    'icon',
    'app_icon',
    'appicon',
    'launcher_icon',
    'ic_launcher',
    'logo',
    'app_logo',
  };

  /// Returns the icon configured for flutter_launcher_icons when it is a PNG,
  /// otherwise the best PNG directly inside `assets/`, or null.
  String? find(String projectPath) {
    return _launcherIconsImage(projectPath) ?? _bestAssetsPng(projectPath);
  }

  String? _launcherIconsImage(String projectPath) {
    final pubspec = File('$projectPath${Platform.pathSeparator}pubspec.yaml');
    if (!pubspec.existsSync()) {
      return null;
    }
    final match = RegExp(
      r'''^\s*image_path:\s*["']?([^"'\s#]+)''',
      multiLine: true,
    ).firstMatch(pubspec.readAsStringSync());
    final relativePath = match?.group(1);
    if (relativePath == null || !_isPng(relativePath)) {
      return null;
    }
    final icon = File(
      '$projectPath${Platform.pathSeparator}'
      '${relativePath.replaceAll('/', Platform.pathSeparator)}',
    );
    return icon.existsSync() ? icon.path : null;
  }

  String? _bestAssetsPng(String projectPath) {
    final assets = Directory('$projectPath${Platform.pathSeparator}assets');
    if (!assets.existsSync()) {
      return null;
    }
    final candidates = [
      for (final entity in assets.listSync(followLinks: false))
        if (entity is File && _isPng(entity.path)) entity,
    ];
    if (candidates.isEmpty) {
      return null;
    }

    // Icon-like names win; among equals the biggest file is usually the
    // highest-resolution source image.
    candidates.sort((first, second) {
      final byName = _nameRank(first).compareTo(_nameRank(second));
      if (byName != 0) {
        return byName;
      }
      return second.lengthSync().compareTo(first.lengthSync());
    });
    return candidates.first.path;
  }

  int _nameRank(File file) {
    final fileName = file.uri.pathSegments.last.toLowerCase();
    final stem = fileName.substring(0, fileName.length - '.png'.length);
    if (_preferredNames.contains(stem)) {
      return 0;
    }
    if (stem.contains('icon')) {
      return 1;
    }
    if (stem.contains('logo')) {
      return 2;
    }
    return 3;
  }

  bool _isPng(String path) => path.toLowerCase().endsWith('.png');
}
