import 'package:flutter/material.dart';

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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            if (expand) Expanded(child: child) else child,
          ],
        ),
      ),
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
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(widget.icon),
                  const SizedBox(width: 10),
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (widget.summary != null) ...[
                    const SizedBox(width: 12),
                    Flexible(child: widget.summary!),
                  ],
                  const Spacer(),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}
