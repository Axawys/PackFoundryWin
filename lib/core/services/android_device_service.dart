import 'dart:io';

import 'windows_tools.dart';

/// One entry of `adb devices -l`.
class AndroidDevice {
  const AndroidDevice({
    required this.serial,
    required this.state,
    required this.model,
  });

  final String serial;

  /// Raw adb connection state: `device`, `unauthorized`, `offline`, ...
  final String state;

  /// Marketing model reported by adb, when the device is far enough in the
  /// handshake to report one.
  final String? model;

  /// Only authorized devices accept an install.
  bool get isAuthorized => state == 'device';

  /// The USB debugging prompt was not confirmed on the phone yet.
  bool get isUnauthorized => state == 'unauthorized';

  String get label {
    final model = this.model;
    if (model == null || model.isEmpty) {
      return serial;
    }
    return '${model.replaceAll('_', ' ')} ($serial)';
  }
}

/// Result of an adb invocation, with both streams merged so callers can match
/// on the install failure codes adb prints to either of them.
class AdbResult {
  const AdbResult({required this.exitCode, required this.output});

  final int exitCode;
  final String output;

  bool get isSuccess => exitCode == 0;

  bool contains(String needle) {
    return output.toLowerCase().contains(needle.toLowerCase());
  }
}

/// Parses the table `adb devices -l` prints. Header, blank and daemon-status
/// lines are skipped; everything else is one attached device.
List<AndroidDevice> parseAdbDevices(String output) {
  final devices = <AndroidDevice>[];
  for (final line in output.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('List of devices') ||
        trimmed.startsWith('*')) {
      continue;
    }

    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length < 2) {
      continue;
    }
    devices.add(
      AndroidDevice(
        serial: parts.first,
        state: parts[1],
        model: _readProperty(parts, 'model'),
      ),
    );
  }
  return devices;
}

String? _readProperty(List<String> parts, String key) {
  for (final part in parts) {
    if (part.startsWith('$key:')) {
      final value = part.substring(key.length + 1).trim();
      return value.isEmpty ? null : value;
    }
  }
  return null;
}

/// Talks to Android devices over adb. The executable is resolved from PATH, the
/// SDK the user configured, or the SDK PackFoundry manages itself, so a device
/// works without any manual setup once the Android toolchain is installed.
class AndroidDeviceService {
  String? _cachedExecutable;

  Future<String?> resolveExecutable() async {
    final cached = _cachedExecutable;
    if (cached != null) {
      return cached;
    }

    for (final candidate in _executableCandidates()) {
      try {
        final result = await Process.run(candidate, const [
          'version',
        ], runInShell: true).timeout(const Duration(seconds: 6));
        if (result.exitCode == 0) {
          _cachedExecutable = candidate;
          return candidate;
        }
      } on Object {
        continue;
      }
    }
    return null;
  }

  /// Every attached device, including unauthorized and offline ones: the caller
  /// explains how to fix those instead of pretending nothing is connected.
  Future<List<AndroidDevice>> listDevices() async {
    final executable = await resolveExecutable();
    if (executable == null) {
      return const [];
    }

    try {
      final result = await Process.run(executable, const [
        'devices',
        '-l',
      ], runInShell: true).timeout(const Duration(seconds: 15));
      if (result.exitCode != 0) {
        return const [];
      }
      return parseAdbDevices('${result.stdout}');
    } on Object {
      return const [];
    }
  }

  Future<AdbResult> run(
    List<String> arguments, {
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final executable = await resolveExecutable();
    if (executable == null) {
      return const AdbResult(exitCode: -1, output: 'adb was not found.');
    }

    final result = await Process.run(
      executable,
      arguments,
      runInShell: true,
    ).timeout(timeout);
    return AdbResult(
      exitCode: result.exitCode,
      output: '${result.stdout}${result.stderr}'.trim(),
    );
  }

  Future<Process> start(List<String> arguments) async {
    final executable = await resolveExecutable();
    if (executable == null) {
      throw const ProcessException('adb', [], 'adb was not found.');
    }
    return Process.start(executable, arguments, runInShell: true);
  }

  List<String> _executableCandidates() {
    final found = WindowsTools().findAdb();
    return [if (found != null) found.path, 'adb'];
  }
}
