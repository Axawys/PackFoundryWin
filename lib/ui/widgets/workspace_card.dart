import 'dart:io';

import 'package:flutter/material.dart';

/// Content width of every workspace; wider windows center it.
const workspaceMaxWidth = 1400.0;

/// The card every workspace is built from: a bordered panel with an optional
/// title, led by an icon or a step number.
class WorkspaceCard extends StatelessWidget {
  const WorkspaceCard({
    required this.child,
    this.title,
    this.icon,
    this.step,
    this.trailing,
    this.expand = false,
    super.key,
  });

  final String? title;
  final IconData? icon;
  final int? step;

  /// Shown at the end of the title row.
  final Widget? trailing;
  final Widget child;

  /// Stretches [child] over the remaining height when the card is placed in a
  /// bounded parent instead of a scroll view.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (title != null) ...[
              WorkspaceCardTitle(
                title: title!,
                icon: icon,
                step: step,
                trailing: trailing,
              ),
              const SizedBox(height: 16),
            ],
            if (expand) Expanded(child: child) else child,
          ],
        ),
      ),
    );
  }
}

class WorkspaceCardTitle extends StatelessWidget {
  const WorkspaceCardTitle({
    required this.title,
    this.icon,
    this.step,
    this.trailing,
    super.key,
  });

  final String title;
  final IconData? icon;
  final int? step;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      children: [
        if (step != null) ...[
          CircleAvatar(
            radius: 13,
            backgroundColor: colors.surfaceContainerHighest,
            child: Text(
              '$step',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ] else if (icon != null) ...[
          Icon(icon, size: 22),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// A scrolling workspace with its content centered at [workspaceMaxWidth]
/// and an optional bar pinned below it.
class WorkspacePage extends StatelessWidget {
  const WorkspacePage({required this.children, this.bottomBar, super.key});

  final List<Widget> children;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final page = SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: workspaceMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
    if (bottomBar == null) {
      return page;
    }
    return Column(
      children: [
        Expanded(child: page),
        bottomBar!,
      ],
    );
  }
}

/// Lays [cards] out side by side with equal heights, or stacks them when the
/// row would be narrower than [minRowWidth].
class WorkspaceCardRow extends StatelessWidget {
  const WorkspaceCardRow({
    required this.cards,
    this.minRowWidth = 1000,
    super.key,
  });

  final List<Widget> cards;
  final double minRowWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < minRowWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                if (index > 0) const SizedBox(height: 16),
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
                if (index > 0) const SizedBox(width: 16),
                Expanded(child: cards[index]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class SummaryChip extends StatelessWidget {
  const SummaryChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(label, style: Theme.of(context).textTheme.labelLarge),
      ),
    );
  }
}

/// A rounded tile with the app icon at [path], or a placeholder.
class AppIconPreview extends StatelessWidget {
  const AppIconPreview({
    required this.path,
    required this.size,
    this.fallbackIcon = Icons.image_outlined,
    super.key,
  });

  final String? path;
  final double size;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final iconPath = path;
    final fallback = Icon(
      fallbackIcon,
      size: size * 0.4,
      color: colors.onSurfaceVariant,
    );

    Widget content;
    if (iconPath == null || !File(iconPath).existsSync()) {
      content = fallback;
    } else if (iconPath.toLowerCase().endsWith('.svg')) {
      content = Text(
        'SVG',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      );
    } else {
      content = Image.file(
        File(iconPath),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      alignment: Alignment.center,
      child: content,
    );
  }
}
