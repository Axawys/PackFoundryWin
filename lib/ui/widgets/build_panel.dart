import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/build_configuration.dart';
import '../../core/models/build_log_entry.dart';
import '../../core/models/build_target.dart';
import '../../core/services/package_file_names.dart';
import '../../core/services/windows_installer_files.dart';
import '../../core/services/windows_tools.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'workspace_card.dart';

/// Build workspace: the step plan on one side and, on the other, the cmd.exe
/// commands of the selected step together with the live process log.
class BuildPanel extends StatefulWidget {
  const BuildPanel({
    required this.selectedTargets,
    required this.isBuilding,
    required this.progress,
    required this.roadmapSteps,
    required this.log,
    required this.onBuild,
    required this.isRunning,
    required this.canRun,
    required this.onRun,
    required this.onStop,
    this.configuration,
    super.key,
  });

  final int selectedTargets;
  final bool isBuilding;
  final int progress;
  final List<BuildRoadmapStep> roadmapSteps;
  final List<BuildLogEntry> log;
  final VoidCallback onBuild;
  final bool isRunning;
  final bool canRun;
  final VoidCallback onRun;
  final VoidCallback onStop;
  final BuildConfiguration? configuration;

  @override
  State<BuildPanel> createState() => _BuildPanelState();
}

class _BuildPanelState extends State<BuildPanel> {
  /// Height of the split view when the panel is placed in a scrollable parent
  /// and cannot simply fill the viewport.
  static const _fallbackBodyHeight = 640.0;
  static const _sideBySideMinWidth = 860.0;

  String? _selectedStepId;
  String? _lastRunningStepId;

  @override
  void initState() {
    super.initState();
    _syncSelection();
  }

  @override
  void didUpdateWidget(BuildPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSelection();
  }

  /// Follows the running step, but keeps a step the user picked until the
  /// build moves on to the next one.
  void _syncSelection() {
    final steps = widget.roadmapSteps;
    String? runningStepId;
    for (final step in steps) {
      if (step.state == BuildRoadmapStepState.running) {
        runningStepId = step.id;
        break;
      }
    }
    if (runningStepId != null && runningStepId != _lastRunningStepId) {
      _selectedStepId = runningStepId;
    }
    _lastRunningStepId = runningStepId;

    final selectionExists = steps.any((step) => step.id == _selectedStepId);
    if (!selectionExists) {
      _selectedStepId = steps.isEmpty ? null : steps.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.hasBoundedHeight;
        final body = _buildBody(constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummaryCard(context),
            const SizedBox(height: 12),
            if (bounded)
              Expanded(child: body)
            else
              SizedBox(height: _fallbackBodyHeight, child: body),
          ],
        );
      },
    );
  }

  /// What is being built: the app, its targets and their files, the overall
  /// progress, and the build and run actions.
  Widget _buildSummaryCard(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final remainingSeconds = _estimatedRemainingSeconds(widget.roadmapSteps);
    final configuration = widget.configuration;
    final selected = configuration == null
        ? const <BuildTarget>[]
        : [
            for (final target in configuration.targets)
              if (target.selected) target,
          ];
    final appName = configuration == null
        ? l10n.noProjectSelected
        : WindowsInstallerMetadata.displayAppName(configuration.appName);
    final tag = configuration?.releaseTag.trim() ?? '';

    final actions = Wrap(
      spacing: 10,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        if (widget.canRun)
          OutlinedButton.icon(
            onPressed: widget.isBuilding
                ? null
                : widget.isRunning
                ? widget.onStop
                : widget.onRun,
            icon: Icon(
              widget.isRunning
                  ? Icons.stop_circle_outlined
                  : Icons.play_arrow_outlined,
            ),
            label: Text(
              widget.isRunning ? l10n.stopRunningApp : l10n.runWithoutBuild,
            ),
          ),
        FilledButton.icon(
          onPressed:
              widget.isBuilding ||
                  widget.isRunning ||
                  widget.selectedTargets == 0
              ? null
              : widget.onBuild,
          icon: Icon(
            widget.isBuilding
                ? Icons.hourglass_top_outlined
                : Icons.rocket_launch_outlined,
          ),
          label: Text(widget.isBuilding ? l10n.building : l10n.buildInstallers),
        ),
      ],
    );

    return WorkspaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIconPreview(
                path: configuration?.iconPath,
                size: 56,
                fallbackIcon: Icons.rocket_launch_outlined,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            appName,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: configuration == null
                                  ? colors.onSurfaceVariant
                                  : null,
                            ),
                          ),
                        ),
                        if (tag.isNotEmpty) SummaryChip(label: tag),
                        if (widget.isRunning)
                          _BuildStatusChip(
                            icon: Icons.play_circle_outline,
                            label: l10n.runningApp,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        l10n.selectedTargets(widget.selectedTargets),
                        if (configuration != null && selected.isNotEmpty)
                          packageFileNames(configuration, selected).join(', '),
                      ].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: muted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              actions,
            ],
          ),
          if (widget.isBuilding || widget.progress > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: widget.progress / 100,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),
                _BuildStatusChip(
                  icon: Icons.percent,
                  label: l10n.overallProgressLabel(widget.progress),
                ),
                if (widget.isBuilding && remainingSeconds != null) ...[
                  const SizedBox(width: 8),
                  _BuildStatusChip(
                    icon: Icons.schedule_outlined,
                    label: l10n.buildRemainingTime(remainingSeconds),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(double width) {
    final steps = widget.roadmapSteps;
    BuildRoadmapStep? selectedStep;
    for (final step in steps) {
      if (step.id == _selectedStepId) {
        selectedStep = step;
      }
    }
    final configuration = widget.configuration;
    final commandPlan =
        configuration == null || configuration.projectPath.trim().isEmpty
        ? null
        : _BuildCommandPlan(configuration, steps);

    final plan = _BuildPlanPane(
      steps: steps,
      selectedStepId: _selectedStepId,
      onSelect: (stepId) => setState(() => _selectedStepId = stepId),
    );
    final console = _BuildConsole(
      steps: steps,
      selectedStep: selectedStep,
      commandPlan: commandPlan,
      log: widget.log,
    );

    if (width >= _sideBySideMinWidth) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 2, child: plan),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: console),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 2, child: plan),
        const SizedBox(height: 12),
        Expanded(flex: 3, child: console),
      ],
    );
  }

  int? _estimatedRemainingSeconds(List<BuildRoadmapStep> steps) {
    if (steps.isEmpty) {
      return null;
    }

    var total = 0.0;
    for (final step in steps) {
      final estimate = step.estimatedSeconds;
      if (estimate == null || estimate <= 0) {
        continue;
      }

      switch (step.state) {
        case BuildRoadmapStepState.pending:
          total += estimate;
        case BuildRoadmapStepState.running:
          final progressRatio = step.progress.clamp(0, 100) / 100;
          total += estimate * (1 - progressRatio);
        case BuildRoadmapStepState.success:
        case BuildRoadmapStepState.warning:
        case BuildRoadmapStepState.skipped:
          break;
      }
    }

    return total.round();
  }
}

/// Shared frame of the two halves: a titled, bordered pane.
class _Pane extends StatelessWidget {
  const _Pane({required this.header, required this.child});

  final Widget header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Divider(height: 1, color: colorScheme.outlineVariant),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _PaneHeader extends StatelessWidget {
  const _PaneHeader({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
        child: Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

class _PaneMessage extends StatelessWidget {
  const _PaneMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _BuildPlanPane extends StatefulWidget {
  const _BuildPlanPane({
    required this.steps,
    required this.selectedStepId,
    required this.onSelect,
  });

  final List<BuildRoadmapStep> steps;
  final String? selectedStepId;
  final ValueChanged<String> onSelect;

  @override
  State<_BuildPlanPane> createState() => _BuildPlanPaneState();
}

class _BuildPlanPaneState extends State<_BuildPlanPane> {
  static const _minimumStepDisplayDuration = Duration(seconds: 1);
  static const _nextStepDelay = Duration(milliseconds: 180);

  late List<BuildRoadmapStep> _displayedSteps;
  late List<BuildRoadmapStep> _targetSteps;
  final _stepKeys = <String, GlobalKey>{};
  Timer? _transitionTimer;

  @override
  void initState() {
    super.initState();
    _displayedSteps = List.of(widget.steps);
    _targetSteps = List.of(widget.steps);
  }

  @override
  void didUpdateWidget(_BuildPlanPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedStepId != widget.selectedStepId) {
      _revealSelectedStep();
    }
    if (!_sameStepIds(_targetSteps, widget.steps)) {
      _transitionTimer?.cancel();
      _transitionTimer = null;
      _targetSteps = List.of(widget.steps);
      _displayedSteps = List.of(widget.steps);
      return;
    }

    _targetSteps = List.of(widget.steps);
    _advanceDisplayedSteps();
  }

  @override
  void dispose() {
    _transitionTimer?.cancel();
    super.dispose();
  }

  void _revealSelectedStep() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stepContext = _stepKeys[widget.selectedStepId]?.currentContext;
      if (stepContext == null || !stepContext.mounted) {
        return;
      }
      Scrollable.ensureVisible(
        stepContext,
        alignment: 0.3,
        duration: const Duration(milliseconds: 200),
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  /// Fast steps would flash by unnoticed, so each finished step is held in
  /// its running state for a moment before it switches to the final state.
  void _advanceDisplayedSteps() {
    if (_transitionTimer?.isActive ?? false) {
      return;
    }
    if (_stepsMatch(_displayedSteps, _targetSteps)) {
      return;
    }

    for (var index = 0; index < _displayedSteps.length; index++) {
      final displayed = _displayedSteps[index];
      final target = _targetSteps[index];
      if (_stepMatches(displayed, target)) {
        continue;
      }

      if (_shouldHoldBeforeFinalState(displayed, target)) {
        setState(() {
          _displayedSteps[index] = displayed.copyWith(
            state: BuildRoadmapStepState.running,
            progress: 100,
            detail: target.detail,
          );
        });
        _transitionTimer = Timer(_minimumStepDisplayDuration, () {
          if (!mounted) {
            return;
          }
          setState(() {
            _displayedSteps[index] = _targetSteps[index];
          });
          _transitionTimer = Timer(_nextStepDelay, () {
            _transitionTimer = null;
            if (mounted) {
              _advanceDisplayedSteps();
            }
          });
        });
        return;
      }

      setState(() {
        _displayedSteps[index] = target;
      });
      _advanceDisplayedSteps();
      return;
    }
  }

  bool _shouldHoldBeforeFinalState(
    BuildRoadmapStep displayed,
    BuildRoadmapStep target,
  ) {
    final targetIsFinal = switch (target.state) {
      BuildRoadmapStepState.success ||
      BuildRoadmapStepState.warning ||
      BuildRoadmapStepState.skipped => true,
      BuildRoadmapStepState.pending || BuildRoadmapStepState.running => false,
    };
    return targetIsFinal &&
        displayed.state != target.state &&
        displayed.state != BuildRoadmapStepState.skipped;
  }

  bool _sameStepIds(
    List<BuildRoadmapStep> first,
    List<BuildRoadmapStep> second,
  ) {
    if (first.length != second.length) {
      return false;
    }
    for (var index = 0; index < first.length; index++) {
      if (first[index].id != second[index].id) {
        return false;
      }
    }
    return true;
  }

  bool _stepsMatch(
    List<BuildRoadmapStep> first,
    List<BuildRoadmapStep> second,
  ) {
    if (first.length != second.length) {
      return false;
    }
    for (var index = 0; index < first.length; index++) {
      if (!_stepMatches(first[index], second[index])) {
        return false;
      }
    }
    return true;
  }

  bool _stepMatches(BuildRoadmapStep first, BuildRoadmapStep second) {
    return first.id == second.id &&
        first.state == second.state &&
        first.progress == second.progress &&
        first.detail == second.detail;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final finished = _displayedSteps
        .where(
          (step) =>
              step.state == BuildRoadmapStepState.success ||
              step.state == BuildRoadmapStepState.skipped,
        )
        .length;

    return _Pane(
      header: _PaneHeader(
        icon: Icons.account_tree_outlined,
        title: l10n.buildPlanTitle,
        actions: [
          if (_displayedSteps.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '$finished / ${_displayedSteps.length}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      ),
      child: _displayedSteps.isEmpty
          ? _PaneMessage(l10n.noBuildPlan)
          : ListView(
              padding: const EdgeInsets.all(6),
              children: [
                for (final step in _displayedSteps)
                  _PlanStepTile(
                    key: _stepKeys.putIfAbsent(step.id, GlobalKey.new),
                    step: step,
                    selected: step.id == widget.selectedStepId,
                    onTap: () => widget.onSelect(step.id),
                  ),
              ],
            ),
    );
  }
}

class _PlanStepTile extends StatelessWidget {
  const _PlanStepTile({
    required this.step,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final BuildRoadmapStep step;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final running = step.state == BuildRoadmapStepState.running;
    final failed = step.state == BuildRoadmapStepState.warning;
    final detail = step.detail;
    final showDetail =
        (running || failed || selected) && detail != null && detail.isNotEmpty;

    return Semantics(
      selected: selected,
      label: l10n.roadmapStatusLabel(step.state.name),
      child: Material(
        color: selected
            ? colorScheme.surfaceContainerHighest
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StepIndicator(step: step),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.roadmapStepTitle(step.id, step.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: running || selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: step.state == BuildRoadmapStepState.pending
                              ? colorScheme.onSurfaceVariant
                              : null,
                        ),
                      ),
                    ),
                    if (running)
                      Text(
                        '${step.progress}%',
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
                if (running) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: LinearProgressIndicator(
                      value: step.progress.clamp(0, 100) / 100,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
                if (showDetail) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: Text(
                      l10n.roadmapDetail(detail),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: failed
                            ? context.status.problem
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final BuildRoadmapStep step;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final indicator = switch (step.state) {
      BuildRoadmapStepState.pending => DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colorScheme.outline, width: 1.5),
        ),
        child: Center(
          child: Text(
            step.number.toString(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
      BuildRoadmapStepState.running => Padding(
        padding: const EdgeInsets.all(2),
        child: CircularProgressIndicator(
          value: step.progress.clamp(0, 100) / 100,
          strokeWidth: 2.5,
          backgroundColor: colorScheme.outlineVariant,
        ),
      ),
      BuildRoadmapStepState.success => Icon(
        Icons.check_circle,
        size: 22,
        color: context.status.success,
      ),
      BuildRoadmapStepState.warning => Icon(
        Icons.error,
        size: 22,
        color: context.status.problem,
      ),
      BuildRoadmapStepState.skipped => Icon(
        Icons.remove_circle_outline,
        size: 22,
        color: colorScheme.outline,
      ),
    };
    return SizedBox.square(dimension: 22, child: indicator);
  }
}

class _BuildConsole extends StatefulWidget {
  const _BuildConsole({
    required this.steps,
    required this.selectedStep,
    required this.commandPlan,
    required this.log,
  });

  final List<BuildRoadmapStep> steps;
  final BuildRoadmapStep? selectedStep;

  /// Null until a project is selected, because commands need real paths.
  final _BuildCommandPlan? commandPlan;
  final List<BuildLogEntry> log;

  @override
  State<_BuildConsole> createState() => _BuildConsoleState();
}

class _BuildConsoleState extends State<_BuildConsole> {
  final _logController = ScrollController();

  @override
  void didUpdateWidget(_BuildConsole oldWidget) {
    super.didUpdateWidget(oldWidget);
    final logChanged =
        oldWidget.log.length != widget.log.length ||
        (widget.log.isNotEmpty &&
            !identical(oldWidget.log.last, widget.log.last));
    if (!logChanged) {
      return;
    }
    // Stick to the newest entry unless the user scrolled up to read history.
    final followTail =
        !_logController.hasClients ||
        _logController.position.pixels >=
            _logController.position.maxScrollExtent - 48;
    if (followTail) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_logController.hasClients) {
          _logController.jumpTo(_logController.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _logController.dispose();
    super.dispose();
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.copiedToClipboard)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final step = widget.selectedStep;
    final plan = widget.commandPlan;
    final commands = step == null || plan == null
        ? const <String>[]
        : plan.commandsFor(step.id);

    return _Pane(
      header: _PaneHeader(
        icon: Icons.terminal_outlined,
        title: step == null
            ? l10n.buildCommandsTitle
            : '${l10n.buildCommandsTitle} · ${l10n.roadmapStepTitle(step.id, step.title)}',
        subtitle: step == null
            ? null
            : _withUsualDuration(
                l10n,
                l10n.roadmapStepDescription(step.id, step.description),
                step.estimatedSeconds,
              ),
        actions: [
          if (step != null)
            Tooltip(
              message: l10n.roadmapStepExpandedDetail(step.id),
              constraints: const BoxConstraints(maxWidth: 420),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.info_outline, size: 18),
              ),
            ),
          IconButton(
            tooltip: l10n.copyStepCommands,
            onPressed: commands.isEmpty
                ? null
                : () => _copy(commands.join('\n')),
            icon: const Icon(Icons.copy_outlined, size: 18),
          ),
          TextButton.icon(
            onPressed: plan == null || widget.steps.isEmpty
                ? null
                : () => _copy(plan.script(widget.steps, l10n)),
            icon: const Icon(Icons.description_outlined, size: 18),
            label: Text(l10n.copyFullScript),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: _buildCommands(context, step, plan)),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          _PaneHeader(
            icon: Icons.receipt_long_outlined,
            title: l10n.processLogTitle,
            actions: [
              IconButton(
                tooltip: l10n.copyLog,
                onPressed: widget.log.isEmpty
                    ? null
                    : () => _copy(
                        widget.log
                            .map((entry) => '${entry.title}\n${entry.detail}')
                            .join('\n\n'),
                      ),
                icon: const Icon(Icons.copy_outlined, size: 18),
              ),
            ],
          ),
          Expanded(
            flex: 2,
            // One selection area lets a whole error be selected and copied.
            child: SelectionArea(
              child: ListView.builder(
                controller: _logController,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                itemCount: widget.log.length,
                itemBuilder: (context, index) =>
                    _LogEntryTile(entry: widget.log[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommands(
    BuildContext context,
    BuildRoadmapStep? step,
    _BuildCommandPlan? plan,
  ) {
    final l10n = context.l10n;
    if (step == null) {
      return _PaneMessage(l10n.noBuildCommands);
    }
    if (plan == null) {
      return _PaneMessage(l10n.selectProjectForCommands);
    }
    final commands = plan.commandsFor(step.id);
    if (commands.isEmpty) {
      return _PaneMessage(l10n.noStepCommands);
    }

    final colorScheme = Theme.of(context).colorScheme;
    final firstNumber = plan.firstNumberFor(step.id);
    return ListView.separated(
      // A new step starts at its first command instead of the old offset.
      key: PageStorageKey('commands:${step.id}'),
      padding: const EdgeInsets.fromLTRB(8, 12, 14, 12),
      itemCount: commands.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '${firstNumber + index}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                color: colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              commands[index],
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                height: 1.35,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _withUsualDuration(
    AppLocalizations l10n,
    String description,
    int? seconds,
  ) {
    if (seconds == null || seconds <= 0) {
      return description;
    }
    final usual = seconds < 60
        ? l10n.roadmapUsuallySeconds(seconds)
        : l10n.roadmapUsuallyMinutes((seconds / 60).round());
    return '$description · $usual';
  }
}

class _BuildStatusChip extends StatelessWidget {
  const _BuildStatusChip({required this.icon, required this.label});

  final IconData icon;
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
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  const _LogEntryTile({required this.entry});

  final BuildLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final warning = entry.state == BuildLogState.warning;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              _entryIcon(entry.state),
              color: _entryColor(context),
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: warning ? context.status.problem : null,
                  ),
                ),
                if (entry.detail.isNotEmpty)
                  Text(
                    entry.detail,
                    // Errors stay readable in full; routine entries are kept
                    // short so the log does not crowd the commands.
                    maxLines: warning ? null : 3,
                    overflow: warning ? null : TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.35,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _entryIcon(BuildLogState state) {
    return switch (state) {
      BuildLogState.idle => Icons.radio_button_unchecked,
      BuildLogState.running => Icons.sync,
      BuildLogState.success => Icons.check_circle_outline,
      BuildLogState.warning => Icons.warning_amber_outlined,
    };
  }

  Color _entryColor(BuildContext context) {
    return switch (entry.state) {
      BuildLogState.idle => Theme.of(context).colorScheme.onSurfaceVariant,
      BuildLogState.running => Theme.of(context).colorScheme.onSurfaceVariant,
      BuildLogState.success => context.status.success,
      BuildLogState.warning => context.status.problem,
    };
  }
}

/// cmd.exe commands equivalent to the build plan, with real project values,
/// so the build can be understood, reproduced or debugged by hand.
class _BuildCommandPlan {
  _BuildCommandPlan(this.configuration, List<BuildRoadmapStep> steps) {
    var nextNumber = 1;
    final metadata = WindowsInstallerMetadata.fromConfiguration(configuration);
    for (final step in steps) {
      final commands = _commandsForStep(step.id, metadata);
      _commands[step.id] = commands;
      _firstNumbers[step.id] = nextNumber;
      nextNumber += commands.length;
    }
  }

  final BuildConfiguration configuration;
  final _commands = <String, List<String>>{};
  final _firstNumbers = <String, int>{};

  List<String> commandsFor(String stepId) => _commands[stepId] ?? const [];

  int firstNumberFor(String stepId) => _firstNumbers[stepId] ?? 1;

  /// The whole plan as a `.cmd` script, with CRLF line endings.
  String script(List<BuildRoadmapStep> steps, AppLocalizations l10n) {
    final lines = <String>['@echo off', 'setlocal EnableExtensions'];
    for (final step in steps) {
      final commands = commandsFor(step.id);
      if (commands.isEmpty) {
        continue;
      }
      lines
        ..add('')
        ..add(
          'rem ${step.number}. ${l10n.roadmapStepTitle(step.id, step.title)}',
        )
        ..addAll(commands);
    }
    return '${lines.join('\r\n')}\r\n';
  }

  List<String> _commandsForStep(
    String stepId,
    WindowsInstallerMetadata metadata,
  ) {
    final project = configuration.projectPath;
    final output = configuration.outputPath?.trim().isNotEmpty == true
        ? configuration.outputPath!.trim()
        : '$project\\build\\pack_foundry';
    final iscc = WindowsTools().findInnoCompiler()?.path ?? 'ISCC.exe';
    final apkName = apkFileName(metadata);

    return switch (stepId) {
      'project' => [
        'set "PROJECT=${_cmdValue(project)}"',
        'set "EXPORT=${_cmdValue(output)}"',
        r'if not exist "%PROJECT%\pubspec.yaml" exit /b 1',
        r'if not exist "%EXPORT%" mkdir "%EXPORT%"',
      ],
      'build-script' => const [
        r'rem PackFoundry writes build_setup.cmd, setup.iss and setup.ico to %EXPORT%',
        r'call "%EXPORT%\build_setup.cmd" "%PROJECT%"',
      ],
      'workspace' => const [
        r'set "WORK_ROOT=%TEMP%\packfoundry-manual"',
        r'set "WORKSPACE=%WORK_ROOT%\project"',
        r'robocopy "%PROJECT%" "%WORKSPACE%" /E /NFL /NDL /NJH /XD build .dart_tool .git .idea',
      ],
      'windows-build' => const [
        r'cd /d "%WORKSPACE%"',
        'call flutter build windows --release',
      ],
      'installer' => [
        'set "ISCC=${_cmdValue(iscc)}"',
        r'rem PackFoundry writes setup.iss to %WORK_ROOT%\inno',
        '"%ISCC%" /Qp "/DSourceDir=%WORKSPACE%\\${WindowsInstallerFiles.releaseFolder}" '
            '"/DMyAppExeName=${_cmdValue(metadata.exeName)}" "/O%EXPORT%" '
            r'"%WORK_ROOT%\inno\setup.iss"',
        'dir "%EXPORT%\\${_cmdValue(metadata.setupFileName)}"',
      ],
      'portable' => [
        'set "ISCC=${_cmdValue(iscc)}"',
        r'rem PackFoundry writes portable.iss to %WORK_ROOT%\inno',
        '"%ISCC%" /Qp "/DSourceDir=%WORKSPACE%\\${WindowsInstallerFiles.releaseFolder}" '
            '"/DMyAppExeName=${_cmdValue(metadata.exeName)}" "/O%EXPORT%" '
            r'"%WORK_ROOT%\inno\portable.iss"',
        'dir "%EXPORT%\\${_cmdValue(metadata.portableFileName)}"',
      ],
      'android-build' => const [
        r'cd /d "%WORKSPACE%"',
        'call flutter build apk --release',
      ],
      'apk-export' => [
        r'copy /y "%WORKSPACE%\build\app\outputs\flutter-apk\app-release.apk" '
            '"%EXPORT%\\${_cmdValue(apkName)}"',
      ],
      'summary' => const [r'dir /b "%EXPORT%"'],
      'cleanup' => const [r'rmdir /s /q "%WORK_ROOT%"'],
      _ => const [],
    };
  }

  /// A value inside `set "NAME=value"`, where percent signs must be doubled.
  String _cmdValue(String value) => value.replaceAll('%', '%%');
}
