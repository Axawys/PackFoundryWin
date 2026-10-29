import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_foundry/l10n/app_localizations.dart';
import 'package:pack_foundry/ui/widgets/version_field.dart';

void main() {
  late TextEditingController tag;

  setUp(() => tag = TextEditingController(text: 'v1.2.3'));
  tearDown(() => tag.dispose());

  Future<void> pumpField(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 360, child: VersionField(controller: tag)),
          ),
        ),
      ),
    );
  }

  Finder part(int index) => find
      .descendant(
        of: find.byType(VersionField),
        matching: find.byType(TextField),
      )
      .at(index);

  List<String?> shown(WidgetTester tester) => [
    for (var index = 0; index < 3; index++)
      tester.widget<TextField>(part(index)).controller?.text,
  ];

  testWidgets('shows the tag as three numbers', (tester) async {
    await pumpField(tester);
    expect(shown(tester), ['1', '2', '3']);
    // Every number has a label of its own, so none covers another.
    for (final label in ['Major', 'Minor', 'Patch']) {
      expect(find.text(label), findsOneWidget);
    }

    tag.text = 'v4.1';
    await tester.pump();
    expect(shown(tester), ['4', '1', '0']);
  });

  testWidgets('arrows step a number and keep the tag in sync', (tester) async {
    await pumpField(tester);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_up).at(1));
    await tester.pump();
    expect(tag.text, 'v1.3.3');

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down).at(0));
    await tester.pump();
    expect(tag.text, 'v0.3.3');

    // Zero is the floor: the down arrow is disabled there.
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down).at(0));
    await tester.pump();
    expect(tag.text, 'v0.3.3');
  });

  testWidgets('accepts typed digits, arrow keys and the mouse wheel', (
    tester,
  ) async {
    await pumpField(tester);

    await tester.enterText(part(2), '12a');
    await tester.pump();
    expect(tag.text, 'v1.2.12');

    await tester.tap(part(0));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(tag.text, 'v2.2.12');

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(tester.getCenter(part(1)));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -20)));
    await tester.pump();
    expect(tag.text, 'v2.3.12');
  });
}
