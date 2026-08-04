import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:semitone_web/l10n/app_localizations.dart';
import 'package:semitone_web/screens/custom_scale_screen.dart';
import 'package:semitone_web/services/settings_service.dart';

void main() {
  // Doesn't tap the play button: CustomScaleScreen owns a TonePlayer
  // (an AudioPlayer under the hood), and there's no real audio plugin
  // registered in the test environment for it to talk to — playback
  // itself hangs rather than throwing (see tone_player_test.dart).
  // Pumping still lets the player's own async plugin registration settle.
  testWidgets('shows a play button for each tone, not yet playing', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.create();
    final scale = settings.scales.first; // seeded Chromatic preset

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CustomScaleScreen(settings: settings, scaleId: scale.id),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    // The degree list is a plain (non-builder) ListView, which still only
    // mounts what's within the viewport — assert on presence, not an
    // exact count, since not every row is necessarily built without
    // scrolling.
    expect(find.byIcon(Icons.play_arrow), findsWidgets);
    expect(find.byIcon(Icons.stop), findsNothing);
  });
}
