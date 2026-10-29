import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';

/// Edits a release tag such as `v1.2.3` as three fields: major, minor and
/// patch. Each number can be typed, clicked up and down, changed with the
/// arrow keys or the mouse wheel. [controller] always holds the whole tag.
class VersionField extends StatefulWidget {
  const VersionField({required this.controller, super.key});

  final TextEditingController controller;

  @override
  State<VersionField> createState() => _VersionFieldState();
}

class _VersionFieldState extends State<VersionField> {
  static final _versionPattern = RegExp(r'(\d+)(?:\.(\d+))?(?:\.(\d+))?');

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTagChanged);
  }

  @override
  void didUpdateWidget(VersionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleTagChanged);
      widget.controller.addListener(_handleTagChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTagChanged);
    super.dispose();
  }

  void _handleTagChanged() => setState(() {});

  /// Major, minor and patch of the current tag; missing parts are 0.
  List<int> get _parts {
    final match = _versionPattern.firstMatch(widget.controller.text);
    return [
      for (var group = 1; group <= 3; group++)
        int.tryParse(match?.group(group) ?? '') ?? 0,
    ];
  }

  void _setPart(int index, int value) {
    final parts = _parts..[index] = value.clamp(0, 9999);
    final tag = 'v${parts.join('.')}';
    if (widget.controller.text != tag) {
      widget.controller.text = tag;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final parts = _parts;
    final labels = [l10n.versionMajor, l10n.versionMinor, l10n.versionPatch];

    return Row(
      children: [
        for (var index = 0; index < 3; index++) ...[
          if (index > 0) const SizedBox(width: 10),
          Expanded(
            child: _NumberSpinner(
              key: ValueKey(index),
              label: labels[index],
              value: parts[index],
              onChanged: (value) => _setPart(index, value),
            ),
          ),
        ],
      ],
    );
  }
}

/// One number of the version: an outlined field with its own label and up
/// and down arrows inside on the right.
class _NumberSpinner extends StatefulWidget {
  const _NumberSpinner({
    required this.value,
    required this.onChanged,
    required this.label,
    super.key,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final String label;

  @override
  State<_NumberSpinner> createState() => _NumberSpinnerState();
}

class _NumberSpinnerState extends State<_NumberSpinner> {
  late final _text = TextEditingController(text: '${widget.value}');
  late final _focus = FocusNode(onKeyEvent: _handleKey);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      // An emptied number becomes 0 once the field is left.
      if (!_focus.hasFocus && _text.text.isEmpty) {
        _text.text = '${widget.value}';
      }
    });
  }

  @override
  void didUpdateWidget(_NumberSpinner oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shown = int.tryParse(_text.text);
    if (shown != widget.value && !(_text.text.isEmpty && _focus.hasFocus)) {
      _text.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _step(int delta) {
    final next = (widget.value + delta).clamp(0, 9999);
    if (next != widget.value) {
      widget.onChanged(next);
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _step(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _step(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (signal) {
        if (signal is PointerScrollEvent) {
          _step(signal.scrollDelta.dy < 0 ? 1 : -1);
        }
      },
      child: TextField(
        controller: _text,
        focusNode: _focus,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],
        decoration: InputDecoration(
          labelText: widget.label,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 30,
            minHeight: 32,
          ),
          // The arrows repeat the arrow keys, so screen readers skip them.
          suffixIcon: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ArrowButton(
                    icon: Icons.keyboard_arrow_up,
                    tooltip: '+1',
                    onPressed: () => _step(1),
                  ),
                  _ArrowButton(
                    icon: Icons.keyboard_arrow_down,
                    tooltip: '−1',
                    onPressed: widget.value > 0 ? () => _step(-1) : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        onChanged: (text) {
          final value = int.tryParse(text);
          if (value != null) {
            widget.onChanged(value);
          }
        },
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 22,
          height: 14,
          child: Icon(
            icon,
            size: 18,
            color: onPressed == null
                ? colors.onSurface.withValues(alpha: 0.3)
                : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
