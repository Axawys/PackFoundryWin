import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_foundry/ui/widgets/license_field.dart';

void main() {
  testWidgets('picks a license from the list and cannot be typed into', (
    tester,
  ) async {
    final license = TextEditingController(text: 'GPL-3.0-only');
    addTearDown(license.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LicenseField(
              controller: license,
              label: 'License',
              width: 300,
            ),
          ),
        ),
      ),
    );

    final field = find.descendant(
      of: find.byType(LicenseField),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(field).readOnly, isTrue);

    await tester.tap(field);
    await tester.pumpAndSettle();
    final mit = find.textContaining('MIT License', findRichText: true).last;
    await tester.ensureVisible(mit);
    await tester.tap(mit);
    await tester.pumpAndSettle();

    expect(license.text, 'MIT');
  });
}
