import 'package:flutter/material.dart';

import '../../core/models/tool_status.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'section.dart';

/// The toolchain as one card per platform: whether its targets can be built,
/// which tools it needs, and one button that installs what is missing.
class ToolchainPanel extends StatelessWidget {
  const ToolchainPanel({
    required this.groups,
    required this.installingTarget,
    required this.onInstallTools,
    required this.onCancelInstall,
    this.onRefresh,
    this.initiallyExpanded = false,
    super.key,
  });

  final List<ToolchainGroup> groups;
  final ToolchainInstallTarget? installingTarget;
  final ValueChanged<ToolchainInstallTarget> onInstallTools;
  final VoidCallback onCancelInstall;

  /// Checks the tools again, e.g. after installing one by hand.
  final VoidCallback? onRefresh;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Common tools first: every other card depends on them.
    final ordered = [
      for (final group in groups)
        if (group.category == ToolchainCategory.common) group,
      for (final group in groups)
        if (group.category != ToolchainCategory.common) group,
    ];
    // Only the common tools are needed for every build, so only they warn
    // while the section is closed; platform tools show inside it.
    final missingCommon = [
      for (final group in ordered)
        if (group.category == ToolchainCategory.common)
          for (final tool in group.tools)
            if (tool.status != ToolAvailability.installed) tool.name,
    ];

    return CollapsibleSection(
      title: l10n.toolchain,
      icon: Icons.construction_outlined,
      storageKey: 'toolchain',
      initiallyExpanded: initiallyExpanded || installingTarget != null,
      summary: missingCommon.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 18,
                  color: context.status.problem,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    l10n.toolsNotInstalled(missingCommon.join(', ')),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.status.problem),
                  ),
                ),
              ],
            ),
      action: onRefresh == null
          ? null
          : OutlinedButton.icon(
              onPressed: installingTarget == null ? onRefresh : null,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.checkToolsAgain),
            ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cards = [
            for (final group in ordered)
              _PlatformCard(
                group: group,
                installing: installingTarget == group.installTarget,
                busy: installingTarget != null,
                onInstallTools: onInstallTools,
                onCancelInstall: onCancelInstall,
                fillHeight: constraints.maxWidth >= 900,
              ),
          ];
          if (constraints.maxWidth < 900) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < cards.length; index++) ...[
                  if (index > 0) const SizedBox(height: 12),
                  cards[index],
                ],
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < cards.length; index++) ...[
                  if (index > 0) const SizedBox(width: 12),
                  Expanded(child: cards[index]),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlatformCard extends StatelessWidget {
  const _PlatformCard({
    required this.group,
    required this.installing,
    required this.busy,
    required this.onInstallTools,
    required this.onCancelInstall,
    required this.fillHeight,
  });

  final ToolchainGroup group;
  final bool installing;

  /// True while any group is installing; only one installation runs at once.
  final bool busy;
  final ValueChanged<ToolchainInstallTarget> onInstallTools;
  final VoidCallback onCancelInstall;

  /// Cards side by side share one height and keep their actions at the
  /// bottom; stacked cards take only the height they need.
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final missing = group.missingCount;
    final ready = missing == 0;
    final progress = group.installProgress;
    final statusColor = ready ? context.status.success : context.status.problem;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(
          color: ready || progress != null
              ? colors.outlineVariant
              : context.status.problem.withValues(alpha: 0.6),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Tooltip(
            message: group.subtitle,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 6),
                  Text(l10n.installingTools, style: theme.textTheme.labelLarge),
                ] else ...[
                  Icon(
                    ready ? Icons.check_circle : Icons.cancel_outlined,
                    size: 20,
                    color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    ready ? l10n.toolsReady : l10n.toolsMissingCount(missing),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: statusColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (group.unlocks.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final target in group.unlocks)
                  _TargetLabel(label: target, ready: ready),
              ],
            ),
          ],
          const SizedBox(height: 12),
          for (final tool in group.tools) ...[
            _ToolLine(tool: tool),
            const SizedBox(height: 8),
          ],
          if (group.dependencyNote != null) ...[
            _DependencyNote(text: group.dependencyNote!),
            const SizedBox(height: 8),
          ],
          if (fillHeight) const Spacer(),
          if (progress != null)
            _InstallProgress(progress: progress, onCancel: onCancelInstall)
          else if (!ready)
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => onInstallTools(group.installTarget),
              icon: const Icon(Icons.download_outlined, size: 18),
              label: Text(
                group.installSizeLabel == null
                    ? l10n.installMissingTools
                    : '${l10n.installMissingTools} · ${group.installSizeLabel}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

/// A build target the card's tools make possible.
class _TargetLabel extends StatelessWidget {
  const _TargetLabel({required this.label, required this.ready});

  final String label;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ready ? Icons.check_circle : Icons.cancel_outlined,
            size: 14,
            color: ready ? context.status.success : context.status.problem,
          ),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _ToolLine extends StatelessWidget {
  const _ToolLine({required this.tool});

  final ToolStatus tool;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final installed = tool.status == ToolAvailability.installed;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            installed ? Icons.check_circle : Icons.cancel_outlined,
            size: 16,
            color: installed ? context.status.success : context.status.problem,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tool.name, style: theme.textTheme.bodyMedium),
              Text(
                tool.note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DependencyNote extends StatelessWidget {
  const _DependencyNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = context.status.problem;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _InstallProgress extends StatelessWidget {
  const _InstallProgress({required this.progress, required this.onCancel});

  final ToolInstallProgress progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final remainingSeconds = progress.remainingSeconds;
    final steps = progress.steps;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.installOverallProgress(progress.progress),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Tooltip(
                  message: progress.cancellable ? '' : l10n.installCannotCancel,
                  child: TextButton.icon(
                    onPressed: progress.cancellable ? onCancel : null,
                    icon: const Icon(Icons.close, size: 16),
                    label: Text(l10n.cancel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TweenAnimationBuilder<double>(
              tween: Tween(end: progress.progress.clamp(0, 100) / 100),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (steps.isNotEmpty)
                  Expanded(
                    child: Text(
                      l10n.installStepCounter(
                        progress.currentStep + 1,
                        steps.length,
                      ),
                      style: textTheme.bodySmall,
                    ),
                  )
                else
                  const Spacer(),
                Text(
                  remainingSeconds == null
                      ? l10n.installEstimatingTime
                      : l10n.buildRemainingTime(remainingSeconds),
                  style: textTheme.bodySmall,
                ),
              ],
            ),
            if (steps.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (var index = 0; index < steps.length; index++)
                _InstallStepRow(
                  title: steps[index],
                  state: index < progress.currentStep
                      ? _StepState.done
                      : index == progress.currentStep
                      ? _StepState.running
                      : _StepState.pending,
                  stepProgress: index == progress.currentStep
                      ? progress.stepProgress
                      : null,
                ),
            ],
            if (progress.detail.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                progress.detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _StepState { done, running, pending }

class _InstallStepRow extends StatelessWidget {
  const _InstallStepRow({
    required this.title,
    required this.state,
    required this.stepProgress,
  });

  final String title;
  final _StepState state;

  /// Percent of the running step, or null when it cannot be measured.
  final int? stepProgress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final percent = stepProgress;

    final leading = switch (state) {
      _StepState.done => Icon(
        Icons.check_circle,
        size: 18,
        color: context.status.success,
      ),
      _StepState.running => SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator(
          value: percent == null ? null : percent / 100,
          strokeWidth: 2.5,
          backgroundColor: colorScheme.outlineVariant,
        ),
      ),
      _StepState.pending => Icon(
        Icons.radio_button_unchecked,
        size: 18,
        color: colorScheme.outline,
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox.square(dimension: 18, child: Center(child: leading)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: state == _StepState.running
                    ? FontWeight.w700
                    : FontWeight.w400,
                color: state == _StepState.pending
                    ? colorScheme.onSurfaceVariant
                    : null,
              ),
            ),
          ),
          if (state == _StepState.running && percent != null)
            Text(
              '$percent%',
              style: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }
}
