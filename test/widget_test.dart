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

  // Regression test for the metronome getting torn down on every tab
  // switch (issue #10): TabBarView's PageView disposes off-screen tab
  // content, and MetronomeScreen used to own (and dispose) its own
  // MetronomeEngine, so leaving the Metronome tab silently destroyed it
  // and switching back created a fresh one at default settings —
  // regardless of the "keep tick" setting, since nothing read it. Can't
  // assert on the running/ticking state directly: MetronomeEngine.start()
  // awaits AudioPlayer.setSourceBytes, which never resolves without a
  // real audio plugin in this test environment (same limitation as
  // TonePlayer's playback tests). BPM is a synchronous property, so it's
  // used here as a proxy for "is this still the same engine instance" —
  // the old, buggy structure would reset it to the default 120 on every
  // switch back to the tab.
  testWidgets(
    'metronome BPM survives switching away from and back to its tab',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.create();

      await tester.pumpWidget(SemitoneWebApp(settings: settings));
      await tester.pump();

      await tester.tap(find.text('METRONOME'));
      await tester.pumpAndSettle();

      // Bump BPM up from the default 120.
      await tester.tap(find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(find.text('123'), findsOneWidget);

      await tester.tap(find.text('TUNER'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('METRONOME'));
      await tester.pumpAndSettle();

      expect(find.text('123'), findsOneWidget);
    },
  );

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
