import 'package:flutter/material.dart';

import 'workspace_card.dart';

/// A titled [WorkspaceCard].
class Section extends StatelessWidget {
  const Section({
    required this.title,
    required this.icon,
    required this.child,
    this.expand = false,
    super.key,
  });

  final String title;
  final IconData icon;
  final Widget child;

  /// Stretches [child] over the remaining height when the section is placed in
  /// a bounded parent instead of a scroll view.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return WorkspaceCard(
      title: title,
      icon: icon,
      expand: expand,
      child: child,
    );
  }
}

/// A [Section] whose body opens and closes from its header. The state is
/// kept in [PageStorage] under [storageKey], so it survives tab switches.
class CollapsibleSection extends StatefulWidget {
  const CollapsibleSection({
    required this.title,
    required this.icon,
    required this.child,
    required this.storageKey,
    this.summary,
    this.initiallyExpanded = false,
    super.key,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final String storageKey;

  /// Shown next to the title, e.g. a status that stays visible when closed.
  final Widget? summary;
  final bool initiallyExpanded;

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  late bool _expanded;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _expanded =
        PageStorage.maybeOf(
              context,
            )?.readState(context, identifier: widget.storageKey)
            as bool? ??
        widget.initiallyExpanded;
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    PageStorage.maybeOf(
      context,
    )?.writeState(context, _expanded, identifier: widget.storageKey);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(widget.icon, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    widget.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: widget.summary,
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}
