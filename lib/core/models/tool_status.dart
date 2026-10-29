import 'chip_tone.dart';

class ToolchainGroup {
  const ToolchainGroup({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.tools,
    required this.installTarget,
    this.category = ToolchainCategory.platform,
    this.canRemove = false,
    this.installProgress,
    this.installSizeLabel,
    this.dependencyNote,
  });

  final String title;
  final String subtitle;
  final ToolAvailability status;
  final List<ToolStatus> tools;
  final ToolchainInstallTarget installTarget;
  final ToolchainCategory category;
  final bool canRemove;
  final ToolInstallProgress? installProgress;
  final String? installSizeLabel;

  /// Shown when the group relies on tools from another group that are not
  /// ready yet, e.g. platform targets waiting for the common Flutter SDK.
  final String? dependencyNote;

  ChipTone get chipTone {
    return switch (status) {
      ToolAvailability.installed => ChipTone.good,
      ToolAvailability.available => ChipTone.neutral,
      ToolAvailability.missing => ChipTone.warning,
    };
  }
}

class ToolStatus {
  const ToolStatus({
    required this.name,
    required this.command,
    required this.status,
    required this.note,
    this.showCommand = true,
  });

  final String name;
  final String command;
  final ToolAvailability status;
  final String note;
  final bool showCommand;

  String get statusLabel {
    return switch (status) {
      ToolAvailability.installed => 'Installed',
      ToolAvailability.available => 'Installable',
      ToolAvailability.missing => 'Missing',
    };
  }

  ChipTone get chipTone {
    return switch (status) {
      ToolAvailability.installed => ChipTone.good,
      ToolAvailability.available => ChipTone.neutral,
      ToolAvailability.missing => ChipTone.warning,
    };
  }
}

class ToolInstallProgress {
  const ToolInstallProgress({
    required this.target,
    required this.progress,
    required this.remainingSeconds,
    required this.detail,
    this.steps = const [],
    this.currentStep = 0,
    this.stepProgress,
    this.cancellable = true,
  });

  final ToolchainInstallTarget target;

  /// Overall progress of the whole installation, 0-100.
  final int progress;

  /// Estimated time left, or null while there is not enough data to guess.
  final int? remainingSeconds;
  final String detail;
  final List<String> steps;
  final int currentStep;

  /// Progress of the current step, 0-100, or null when the step cannot report
  /// it (for example a package manager running behind pkexec).
  final int? stepProgress;

  /// False while a step runs that cannot be interrupted safely, such as a
  /// privileged package manager transaction.
  final bool cancellable;
}

enum ToolAvailability { installed, available, missing }

enum ToolchainInstallTarget { common, windows, android }

enum ToolchainCategory { common, platform }
