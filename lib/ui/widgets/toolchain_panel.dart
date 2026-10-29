import 'package:flutter/material.dart';

import '../../core/models/tool_status.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'section.dart';

class ToolchainPanel extends StatelessWidget {
  const ToolchainPanel({
    required this.groups,
    required this.installingTarget,
    required this.onInstallTools,
    required this.onRemoveTools,
    required this.onCancelInstall,
    this.initiallyExpanded = false,
    super.key,
  });

  final List<ToolchainGroup> groups;
  final ToolchainInstallTarget? installingTarget;
  final ValueChanged<ToolchainInstallTarget> onInstallTools;
  final ValueChanged<ToolchainInstallTarget> onRemoveTools;
  final VoidCallback onCancelInstall;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final missing = [
      for (final group in groups)
        for (final tool in group.tools)
          if (tool.status != ToolAvailability.installed) tool,
    ].length;
    final summaryColor = missing == 0
        ? context.status.success
        : context.status.problem;
    final commonGroups = [
      for (final group in groups)
        if (group.category == ToolchainCategory.common) group,
    ];
    final platformGroups = [
      for (final group in groups)
        if (group.category == ToolchainCategory.platform) group,
    ];

    return CollapsibleSection(
      title: l10n.toolchain,
      icon: Icons.construction_outlined,
      storageKey: 'toolchain',
      initiallyExpanded: initiallyExpanded || installingTarget != null,
      summary: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            missing == 0 ? Icons.check_circle_outline : Icons.error_outline,
            size: 18,
            color: summaryColor,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              missing == 0
                  ? l10n.toolchainAllSet
                  : l10n.toolchainMissing(missing),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: summaryColor),
            ),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = switch (constraints.maxWidth) {
            >= 1180 => 3,
            >= 720 => 2,
            _ => 1,
          };

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (commonGroups.isNotEmpty) ...[
                _CategoryHeader(
                  title: l10n.toolchainCommonSection,
                  hint: l10n.toolchainCommonSectionHint,
                ),
                const SizedBox(height: 10),
                for (final group in commonGroups) ...[
                  _buildCard(group, toolColumns: columns),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
              ],
              if (platformGroups.isNotEmpty) ...[
                _CategoryHeader(
                  title: l10n.toolchainPlatformsSection,
                  hint: l10n.toolchainPlatformsSectionHint,
                ),
                const SizedBox(height: 10),
                _buildGrid(platformGroups, columns),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildCard(ToolchainGroup group, {int toolColumns = 1}) {
    return _ToolchainGroupCard(
      group: group,
      installing: installingTarget == group.installTarget,
      busy: installingTarget != null,
      toolColumns: toolColumns,
      onInstallTools: onInstallTools,
      onRemoveTools: onRemoveTools,
      onCancelInstall: onCancelInstall,
    );
  }

  Widget _buildGrid(List<ToolchainGroup> groups, int columns) {
    const spacing = 12.0;
    final columnGroups = [
      for (var column = 0; column < columns; column++)
        [
          for (var index = column; index < groups.length; index += columns)
            groups[index],
        ],
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var column = 0; column < columnGroups.length; column++) ...[
          Expanded(
            child: Column(
              children: [
                for (final group in columnGroups[column]) ...[
                  _buildCard(group),
                  if (group != columnGroups[column].last)
                    const SizedBox(height: spacing),
                ],
              ],
            ),
          ),
          if (column != columnGroups.length - 1) const SizedBox(width: spacing),
        ],
      ],
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 10,
      runSpacing: 2,
      children: [
        Text(
          title.toUpperCase(),
          style: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        Text(
          hint,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ToolchainGroupCard extends StatelessWidget {
  const _ToolchainGroupCard({
    required this.group,
    required this.installing,
    required this.busy,
    required this.toolColumns,
    required this.onInstallTools,
    required this.onRemoveTools,
    required this.onCancelInstall,
  });

  final ToolchainGroup group;
  final bool installing;

  /// True while any group is installing; only one installation runs at once.
  final bool busy;
  final int toolColumns;
  final ValueChanged<ToolchainInstallTarget> onInstallTools;
  final ValueChanged<ToolchainInstallTarget> onRemoveTools;
  final VoidCallback onCancelInstall;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: _statusColor(context, group.status),
                child: const SizedBox(width: 5),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _groupIcon(group.status),
                            color: _statusColor(context, group.status),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.title,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(group.subtitle),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (group.dependencyNote != null) ...[
                        const SizedBox(height: 10),
                        _DependencyNote(text: group.dependencyNote!),
                      ],
                      if (group.installProgress != null) ...[
                        const SizedBox(height: 12),
                        _InstallProgress(
                          progress: group.installProgress!,
                          onCancel: onCancelInstall,
                        ),
                      ],
                      if (group.status != ToolAvailability.installed ||
                          group.canRemove) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            if (group.status != ToolAvailability.installed) ...[
                              OutlinedButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => onInstallTools(group.installTarget),
                                icon: Icon(
                                  installing
                                      ? Icons.hourglass_top_outlined
                                      : Icons.download_outlined,
                                ),
                                label: Text(
                                  installing
                                      ? l10n.installingTools
                                      : l10n.installMissingTools,
                                ),
                              ),
                              if (group.installSizeLabel != null)
                                _InstallSizeBadge(
                                  label: l10n.builderInstallSize(
                                    group.installSizeLabel!,
                                  ),
                                ),
                            ],
                            if (group.canRemove)
                              OutlinedButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => onRemoveTools(group.installTarget),
                                icon: const Icon(Icons.delete_outline),
                                label: Text(l10n.removeBuilder),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Divider(height: 1, color: colorScheme.outlineVariant),
                      const SizedBox(height: 12),
                      if (toolColumns > 1)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final tool in group.tools) ...[
                              Expanded(child: _ToolRow(tool: tool)),
                              if (tool != group.tools.last)
                                const SizedBox(width: 16),
                            ],
                          ],
                        )
                      else
                        for (final tool in group.tools) ...[
                          _ToolRow(tool: tool),
                          if (tool != group.tools.last)
                            const Divider(height: 20),
                        ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _groupIcon(ToolAvailability status) {
    return switch (status) {
      ToolAvailability.installed => Icons.task_alt_outlined,
      ToolAvailability.available => Icons.build_circle_outlined,
      ToolAvailability.missing => Icons.report_problem_outlined,
    };
  }
}

class _InstallSizeBadge extends StatelessWidget {
  const _InstallSizeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sd_storage_outlined,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
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
        padding: const EdgeInsets.all(12),
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
                minHeight: 10,
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

class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.tool});

  final ToolStatus tool;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(_toolIcon(tool.status), color: _statusColor(context, tool.status)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tool.name, style: Theme.of(context).textTheme.titleSmall),
              if (tool.showCommand)
                Text(
                  tool.command,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 4),
              Text(tool.note),
            ],
          ),
        ),
      ],
    );
  }

  IconData _toolIcon(ToolAvailability status) {
    return switch (status) {
      ToolAvailability.installed => Icons.check_circle_outline,
      ToolAvailability.available => Icons.add_circle_outline,
      ToolAvailability.missing => Icons.error_outline,
    };
  }
}

Color _statusColor(BuildContext context, ToolAvailability status) {
  return switch (status) {
    ToolAvailability.installed => context.status.success,
    ToolAvailability.available => Theme.of(
      context,
    ).colorScheme.onSurfaceVariant,
    ToolAvailability.missing => context.status.problem,
  };
}
