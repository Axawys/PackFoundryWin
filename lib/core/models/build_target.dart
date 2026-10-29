class BuildTarget {
  BuildTarget({
    required this.platform,
    required this.artifact,
    required this.status,
    this.selected = false,
  });

  /// Artifact names of the targets PackFoundry builds.
  static const setupExe = 'Inno Setup exe';
  static const buildScript = 'Build script';
  static const apk = 'APK';

  final String platform;
  final String artifact;
  TargetStatus status;
  bool selected;

  bool get canSelect {
    return status == TargetStatus.ready || status == TargetStatus.installable;
  }

  /// Short, language-agnostic label shown in the target picker. Falls back to
  /// [artifact] for formats without a dedicated short name.
  String get displayLabel {
    return switch (artifact) {
      setupExe => 'setup.exe',
      buildScript => 'build_setup.cmd',
      apk => 'apk',
      _ => artifact,
    };
  }

  String get statusLabel {
    return switch (status) {
      TargetStatus.ready => 'Ready to build on this machine',
      TargetStatus.installable => 'Install extra tools to enable',
      TargetStatus.blocked => 'Blocked until SDK/toolchain is installed',
      TargetStatus.missingPlatform => 'Platform is not added to the project',
    };
  }
}

enum TargetStatus { ready, installable, blocked, missingPlatform }
