import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:semitone_web/models/tuning_scale.dart';

import 'support/scale_harness.dart';

/// Settings-screen concerns that aren't a scale feature of their own —
/// page layout, and the two preferences that live here. Creating,
/// editing, duplicating, deleting, importing/exporting scales and
/// resetting settings each have their own fixture.
void main() {
  testWidgets(
    'renders with many scales without overflowing — the whole page just scrolls',
    (WidgetTester tester) async {
      final settings = await seededSettings();
      // Seeded scales plus a large number of user scales, to make sure the
      // embedded scale list doesn't blow past a bounded height.
      for (var i = 0; i < 50; i++) {
        settings.addScale(TuningScale(name: 'Scale $i', degrees: const []));
      }

      await pumpSettings(tester, settings);

      // No RenderFlex/overflow (or any other) exception from laying out 55
      // scale rows plus the rest of the settings content.
      expect(tester.takeException(), isNull);

      // The whole page is one scrollable ListView, not a fixed-height list
      // nested in another scrollable.
      expect(find.byType(ListView), findsOneWidget);
      final scrollableFinder = find.byType(Scrollable);
      expect(scrollableFinder, findsOneWidget);

      // The metronome/about sections and the "New scale" button (replacing
      // the old FAB) live below the (long) scale list — scrolling the one
      // ListView all the way down reaches them without throwing, proving
      // the page scrolls instead of overflowing or clipping content it
      // couldn't fit.
      for (final label in [
        'Scale 49',
        'New scale',
        'Keep tick',
        'Reset settings to defaults',
      ]) {
        await tester.scrollUntilVisible(
          find.text(label),
          300,
          scrollable: scrollableFinder,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(label), findsOneWidget);
      }
    },
  );

  testWidgets('picking a language from the dropdown updates settings.locale', (
    WidgetTester tester,
  ) async {
    final settings = await seededSettings();
    expect(settings.locale, isNull); // starts on "System default".

    await pumpSettings(tester, settings);
    await tester.scrollUntilVisible(
      find.byType(DropdownButton<String?>),
      300,
      scrollable: find.byType(Scrollable),
    );

    // Invoke the dropdown's onChanged directly rather than opening its
    // overlay menu: the same production code either way triggers, and
    // it avoids driving the menu route's overlay animation in a test.
    final dropdown = tester.widget<DropdownButton<String?>>(
      find.byType(DropdownButton<String?>),
    );
    dropdown.onChanged!('de');
    await tester.pump();

    expect(settings.locale, const Locale('de'));
  });

  testWidgets('the keep-tick switch toggles the stored setting', (
    tester,
  ) async {
    final settings = await seededSettings();
    expect(settings.keepTick, isFalse);

    await pumpSettings(tester, settings);
    await tester.scrollUntilVisible(
      find.byType(SwitchListTile),
      300,
      scrollable: find.byType(Scrollable),
    );

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(settings.keepTick, isTrue);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(settings.keepTick, isFalse);
  });
}
