import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}
