import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:semitone_web/l10n/app_localizations.dart';
import 'package:semitone_web/models/tuning_scale.dart';
import 'package:semitone_web/screens/settings_screen.dart';
import 'package:semitone_web/services/settings_service.dart';

void main() {
  testWidgets(
    'renders with many scales without overflowing — the whole page just scrolls',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.create();
      // Seeded scales plus a large number of user scales, to make sure the
      // embedded scale list doesn't blow past a bounded height.
      for (var i = 0; i < 50; i++) {
        settings.addScale(TuningScale(name: 'Scale $i', degrees: const []));
      }

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(settings: settings),
        ),
      );
      await tester.pump();

      // No RenderFlex/overflow (or any other) exception from laying out 55
      // scale rows plus the rest of the settings content.
      expect(tester.takeException(), isNull);

      // The whole page is one scrollable ListView, not a fixed-height list
      // nested in another scrollable.
      final listFinder = find.byType(ListView);
      expect(listFinder, findsOneWidget);
      final scrollableFinder = find.byType(Scrollable);
      expect(scrollableFinder, findsOneWidget);

      // The metronome/about sections and the "New scale" button (replacing
      // the old FAB) live below the (long) scale list — scrolling the one
      // ListView all the way down reaches them without throwing, proving
      // the page scrolls instead of overflowing or clipping content it
      // couldn't fit.
      await tester.scrollUntilVisible(find.text('Scale 49'), 300, scrollable: scrollableFinder);
      expect(tester.takeException(), isNull);
      expect(find.text('Scale 49'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('New scale'), 300, scrollable: scrollableFinder);
      expect(tester.takeException(), isNull);
      expect(find.text('New scale'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Keep tick'), 300, scrollable: scrollableFinder);
      expect(tester.takeException(), isNull);
      expect(find.text('Keep tick'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Reset settings to defaults'),
        300,
        scrollable: scrollableFinder,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Reset settings to defaults'), findsOneWidget);
    },
  );

  testWidgets(
    'picking a language from the dropdown updates settings.locale',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.create();
      expect(settings.locale, isNull); // starts on "System default".

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(settings: settings),
        ),
      );
      await tester.pump();

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
    },
  );
}
