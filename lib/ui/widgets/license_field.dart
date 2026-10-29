import 'package:flutter/material.dart';

import '../../core/models/licenses.dart';

/// Picks one of the popular licenses; any other SPDX id can be typed in.
class LicenseField extends StatelessWidget {
  const LicenseField({
    required this.controller,
    required this.label,
    required this.width,
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final double width;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final mutedStyle = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return DropdownMenu<String>(
      controller: controller,
      width: width,
      enabled: enabled,
      requestFocusOnTap: true,
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
