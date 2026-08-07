import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:semitone_web/main.dart';
import 'package:semitone_web/services/settings_service.dart';

/// Drives the real app shell — [SemitoneWebApp] with its tabs, app-bar
/// scale switcher and settings gear — rather than mounting one screen at a
/// time, so the routing between screens is what's under test.
void main() {
  Future<SettingsService> seeded() async {
    SharedPreferences.setMockInitialValues({});
    return SettingsService.create();
  }

  testWidgets('walks Home -> Settings -> Calibration and back out again', (
    tester,
  ) async {
    final settings = await seeded();
    await tester.pumpWidget(SemitoneWebApp(settings: settings));
    await tester.pump();

    // Home: two tabs and the scale switcher in the title.
    expect(find.text('TUNER'), findsOneWidget);
    expect(find.text('METRONOME'), findsOneWidget);

    // -> Settings, via the app-bar gear.
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    // The app-bar title, which stays put however far the page is scrolled
    // — unlike the sections further down, which the five seeded scales
    // push below the fold.
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    expect(find.text('SCALES'), findsOneWidget);
    // The tabs are gone: Settings is a full route, not a panel.
    expect(find.text('TUNER'), findsNothing);

    // -> Calibration, from the Advanced section.
    final settingsList = find.byType(Scrollable);
    await tester.scrollUntilVisible(
      find.text('Microphone calibration'),
      300,
      scrollable: settingsList,
    );
    await tester.tap(find.text('Microphone calibration').first);
    await tester.pumpAndSettle();
    expect(find.text('Reference tone (Hz)'), findsOneWidget);
    expect(find.text('Current offset: 0.00 Hz'), findsOneWidget);

    // <- back to Settings.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Reference tone (Hz)'), findsNothing);
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);

    // <- back to Home.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('TUNER'), findsOneWidget);
    expect(find.text('METRONOME'), findsOneWidget);
  });

  testWidgets('switches the active scale from the app-bar dropdown', (
    tester,
  ) async {
    final settings = await seeded();
    // Seeded active on the first preset (Chromatic, by filename order).
    expect(settings.activeScale!.name, 'Chromatic');

    await tester.pumpWidget(SemitoneWebApp(settings: settings));
    await tester.pump();
    expect(find.text('Chromatic'), findsOneWidget);

    // Open the switcher and pick a different scale.
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Byzantine — Diatonic').last);
    await tester.pumpAndSettle();

    expect(settings.activeScale!.name, 'Byzantine — Diatonic');
    // The title follows the selection.
    expect(find.text('Byzantine — Diatonic'), findsOneWidget);
    expect(find.text('Chromatic'), findsNothing);
  });

  testWidgets('renaming a scale in the editor reaches the Home dropdown', (
    tester,
  ) async {
    final settings = await seeded();
    await tester.pumpWidget(SemitoneWebApp(settings: settings));
    await tester.pump();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    // Edit the active scale (Chromatic is the first row).
    await tester.tap(find.byTooltip('Edit scale').first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Chromatic'),
      'Renamed scale',
    );
    await tester.pump();

    await tester.pageBack(); // out of the editor
    await tester.pumpAndSettle();
    await tester.pageBack(); // out of settings
    await tester.pumpAndSettle();

    // The rename made it all the way through SettingsService to the
    // switcher in the app bar.
    expect(find.text('Renamed scale'), findsOneWidget);
  });
}
