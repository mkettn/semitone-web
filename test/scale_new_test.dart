import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:semitone_web/screens/custom_scale_screen.dart';

import 'support/scale_harness.dart';

/// Creating a scale: the "New scale" button at the foot of the Settings
/// screen's scales section.
void main() {
  Future<void> tapNewScale(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('New scale'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('New scale'));
    await tester.pumpAndSettle();
  }

  testWidgets('adds a scale and makes it the active one', (tester) async {
    final settings = await seededSettings();
    final before = settings.scales.length;

    await pumpSettings(tester, settings);
    await tapNewScale(tester);

    expect(settings.scales, hasLength(before + 1));
    final created = settings.scales.last;
    // Named for its position in the list.
    expect(created.name, 'New scale ${before + 1}');
    expect(settings.activeScaleId, created.id);
  });

  testWidgets('starts from the chromatic preset rather than empty', (
    tester,
  ) async {
    final settings = await seededSettings();

    await pumpSettings(tester, settings);
    await tapNewScale(tester);

    final created = settings.scales.last;
    final chromatic = settings.scales.firstWhere((s) => s.name == 'Chromatic');
    // There's something on the cake to edit straight away.
    expect(degreeSignature(created), degreeSignature(chromatic));
    expect(created.rootIndex, chromatic.rootIndex);
    // ...but it's a separate scale, not a second reference to the preset.
    expect(created.id, isNot(chromatic.id));
  });

  testWidgets('opens the editor on the scale it just created', (tester) async {
    final settings = await seededSettings();

    await pumpSettings(tester, settings);
    await tapNewScale(tester);

    final editor = tester.widget<CustomScaleScreen>(
      find.byType(CustomScaleScreen),
    );
    expect(editor.scaleId, settings.scales.last.id);
  });

  testWidgets('creating twice gives two independent scales', (tester) async {
    final settings = await seededSettings();
    final before = settings.scales.length;

    await pumpSettings(tester, settings);
    await tapNewScale(tester);
    // Back to Settings, then create another.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapNewScale(tester);

    expect(settings.scales, hasLength(before + 2));
    final first = settings.scales[before];
    final second = settings.scales[before + 1];
    expect(first.id, isNot(second.id));
    // The counter keeps them apart rather than reusing one name.
    expect(first.name, 'New scale ${before + 1}');
    expect(second.name, 'New scale ${before + 2}');
  });

  testWidgets('the new scale shows up in the settings list', (tester) async {
    final settings = await seededSettings();

    await pumpSettings(tester, settings);
    await tapNewScale(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text(settings.scales.last.name),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text(settings.scales.last.name), findsOneWidget);
  });
}
