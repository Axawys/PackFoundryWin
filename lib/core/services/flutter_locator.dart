import 'dart:io';

/// Finds the Flutter SDK executable.
///
/// Apps started from the Start menu or Explorer do not always see the PATH a
/// terminal has, so `flutter` resolved by name fails even when the SDK is
/// installed. Resolving `flutter.bat` up front and running it directly avoids
/// that.
class FlutterLocator {
  FlutterLocator({Map<String, String>? environment})
    : _environment = environment ?? Platform.environment;

  final Map<String, String> _environment;

  /// The SDK PackFoundry installs from the toolchain tab.
  File get managedExecutable => File(
    [
      packFoundryDataDirectory(_environment),
      'flutter',
      'bin',
      'flutter.bat',
    ].join(r'\'),
  );

  /// Looks in PATH, then FLUTTER_ROOT, then the usual install folders and
  /// finally the SDK managed by PackFoundry.
  File? find() {
    for (final candidate in _candidates()) {
      if (candidate.existsSync()) {
        return candidate;
      }
    }
    return null;
  }

  /// Environment overrides for a child process run with [flutter]: its `bin`
  /// folder goes first on PATH, because tools started by the flutter tool call
  /// `flutter` and `dart` by name.
  Map<String, String> environmentFor(File flutter) {
    final path = _readVariable('PATH');
    return {
      'PATH': path == null || path.isEmpty
          ? flutter.parent.path
          : '${flutter.parent.path};$path',
    };
  }

  Iterable<File> _candidates() sync* {
    final path = _readVariable('PATH');
    if (path != null) {
      for (final directory in path.split(';')) {
        final trimmed = directory.trim().replaceAll('"', '');
        if (trimmed.isNotEmpty) {
          yield File(_join(trimmed, 'flutter.bat'));
        }
      }
    }

    final flutterRoot = _readVariable('FLUTTER_ROOT');
    if (flutterRoot != null && flutterRoot.isNotEmpty) {
      yield File(_join(flutterRoot, r'bin\flutter.bat'));
    }

    final profile = _readVariable('USERPROFILE');
    if (profile != null && profile.isNotEmpty) {
      for (final folder in const [
        'flutter',
        r'dev\flutter',
        r'development\flutter',
        r'sdk\flutter',
        r'sdks\flutter',
        r'fvm\default',
      ]) {
        yield File(_join(profile, '$folder\\bin\\flutter.bat'));
      }
    }
    for (final folder in const [r'C:\src\flutter', r'C:\flutter']) {
      yield File('$folder\\bin\\flutter.bat');
    }
    final localAppData = _readVariable('LOCALAPPDATA');
    if (localAppData != null && localAppData.isNotEmpty) {
      yield File(_join(localAppData, r'flutter\bin\flutter.bat'));
    }

    yield managedExecutable;
  }

  /// Windows environment variable names are case-insensitive, but a map
  /// passed in by tests or callers is not.
  String? _readVariable(String name) {
    final direct = _environment[name];
    if (direct != null) {
      return direct;
    }
    final upper = name.toUpperCase();
    for (final entry in _environment.entries) {
      if (entry.key.toUpperCase() == upper) {
        return entry.value;
      }
    }
    return null;
  }

  static String _join(String first, String second) {
    return first.endsWith(r'\') ? '$first$second' : '$first\\$second';
  }
}

/// `%LOCALAPPDATA%\PackFoundry`, the folder for tools PackFoundry installs.
String packFoundryDataDirectory([Map<String, String>? environment]) {
  final values = environment ?? Platform.environment;
  String? read(String name) {
    for (final entry in values.entries) {
      if (entry.key.toUpperCase() == name) {
        return entry.value;
      }
    }
    return null;
  }

  final localAppData = read('LOCALAPPDATA');
  if (localAppData != null && localAppData.isNotEmpty) {
    return '$localAppData\\PackFoundry';
  }
  final profile = read('USERPROFILE');
  if (profile != null && profile.isNotEmpty) {
    return '$profile\\AppData\\Local\\PackFoundry';
  }
  return '${Directory.systemTemp.path}\\PackFoundry';
}
