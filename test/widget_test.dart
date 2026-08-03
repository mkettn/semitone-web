import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:semitone_web/l10n/app_localizations.dart';
import 'package:semitone_web/main.dart';
import 'package:semitone_web/services/settings_service.dart';

void main() {
  testWidgets('renders tuner and metronome tabs', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.create();

    await tester.pumpWidget(SemitoneWebApp(settings: settings));
    await tester.pump();

    expect(find.text('TUNER'), findsOneWidget);
    expect(find.text('METRONOME'), findsOneWidget);
    // The app bar title is a scale-switcher dropdown, seeded active on the
    // bundled "Chromatic" preset, rather than static "Semitone Web" text.
    expect(find.byType(DropdownButton<String>), findsOneWidget);
    expect(find.text('Chromatic'), findsOneWidget);
  });

  // Exercises AppLocalizations resolution directly against a bare
  // MaterialApp, rather than through SemitoneWebApp/HomeScreen: those pull
  // in TunerScreen's microphone capture, which never settles in the test
  // environment (no real audio plugin) and can hang pumpWidget.
  testWidgets('AppLocalizations resolves German and English translations', (
    WidgetTester tester,
  ) async {
    Widget appWithLocale(Locale locale) {
      return MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Text(AppLocalizations.of(context)!.tabTuner),
        ),
      );
    }

    await tester.pumpWidget(appWithLocale(const Locale('en')));
    await tester.pump();
    expect(find.text('TUNER'), findsOneWidget);

    await tester.pumpWidget(appWithLocale(const Locale('de')));
    await tester.pump();
    expect(find.text('STIMMGERÄT'), findsOneWidget);
  });
}
