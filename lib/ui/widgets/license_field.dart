import 'package:flutter/material.dart';

import '../../core/models/licenses.dart';

/// Picks one of the popular licenses. The field cannot be typed into, so the
/// installer always gets a known SPDX id.
class LicenseField extends StatelessWidget {
  const LicenseField({
    required this.controller,
    required this.label,
    this.width,
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final String label;

  /// Null makes the field as wide as its parent.
  final double? width;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final mutedStyle = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return DropdownMenu<String>(
      controller: controller,
      width: width,
      expandedInsets: width == null ? EdgeInsets.zero : null,
      // The arrow button would make the field taller than the text fields
      // around it.
      inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
        suffixIconConstraints: const BoxConstraints(
          minWidth: 40,
          maxHeight: 40,
        ),
      ),
      enabled: enabled,
      // A tap opens the list instead of focusing a text field to type in.
      requestFocusOnTap: false,
      enableFilter: false,
      enableSearch: false,
      menuHeight: 360,
      label: Text(label),
      dropdownMenuEntries: [
        for (final option in LicenseOption.popular)
          DropdownMenuEntry(
            value: option.id,
            label: option.id,
            labelWidget: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: option.id),
                  TextSpan(text: '  ${option.name}', style: mutedStyle),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
