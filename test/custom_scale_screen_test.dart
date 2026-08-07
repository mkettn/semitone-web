import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:semitone_web/l10n/app_localizations.dart';
import 'package:semitone_web/models/scale_degree.dart';
import 'package:semitone_web/models/tuning_scale.dart';
import 'package:semitone_web/screens/custom_scale_screen.dart';
import 'package:semitone_web/services/settings_service.dart';
import 'package:semitone_web/widgets/scale_cake_chart.dart';

/// A deliberately small scale, so every degree row fits on screen without
/// scrolling and row indices stay predictable — unlike the 12-degree
/// bundled Chromatic preset.
TuningScale threeToneScale() => TuningScale(
  name: 'Triad',
  degrees: const [
    ScaleDegree(name: 'C', cents: 0),
    ScaleDegree(name: 'E', cents: 400),
    ScaleDegree(name: 'G', cents: 700),
  ],
);

/// Seeds storage with [scale] as the only saved scale and mounts its
/// editor.
///
/// Uses a taller-than-default surface: the editor's page is one lazily
/// built [ListView], and at the standard 800px test height the chart and
/// the scale-level fields push all but the first degree row out of the
/// viewport — where it isn't merely invisible but never mounted, so
/// finders don't see it and taps land on nothing.
Future<SettingsService> pumpEditor(
  WidgetTester tester,
  TuningScale scale,
) async {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    'custom_scales': [scale.toJsonString()],
  });
  final settings = await SettingsService.create();

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CustomScaleScreen(settings: settings, scaleId: scale.id),
    ),
  );
  await tester.pump();
  return settings;
}

/// The scale as it now stands in storage — every edit persists
/// immediately, so this is what the assertions look at.
TuningScale saved(SettingsService settings, String id) =>
    settings.scales.firstWhere((s) => s.id == id);

// The editor's text fields in tree order: scale name, base frequency,
// root octave, then two per degree row (name, then cents). Indices rather
// than keys, since nothing in the widget tree distinguishes them and
// adding keys would be a production change this round doesn't need.
Finder degreeNameField(int row) => find.byType(TextField).at(3 + row * 2);
Finder degreeCentsField(int row) => find.byType(TextField).at(4 + row * 2);

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

  group('scale-level fields', () {
    testWidgets('renaming the scale persists it', (tester) async {
      final scale = threeToneScale();
      final settings = await pumpEditor(tester, scale);

      await tester.enterText(find.byType(TextField).first, 'Major triad');
      await tester.pump();

      expect(saved(settings, scale.id).name, 'Major triad');
      // The app bar tracks the name as it's typed.
      expect(find.widgetWithText(AppBar, 'Major triad'), findsOneWidget);
    });

    testWidgets('changing the base frequency retunes the whole scale', (
      tester,
    ) async {
      final scale = threeToneScale();
      final settings = await pumpEditor(tester, scale);
      expect(saved(settings, scale.id).frequencyForDegree(0), 440);

      await tester.enterText(find.byType(TextField).at(1), '432');
      await tester.pump();

      final updated = saved(settings, scale.id);
      expect(updated.baseFrequency, 432);
      // The root sits at the base frequency; the others keep their cent
      // distances from it.
      expect(updated.frequencyForDegree(0), 432);
      expect(updated.frequencyForDegree(1), closeTo(432 * 1.2599, 0.5));
    });

    testWidgets('a nonsensical base frequency is ignored, not stored', (
      tester,
    ) async {
      final scale = threeToneScale();
      final settings = await pumpEditor(tester, scale);

      await tester.enterText(find.byType(TextField).at(1), 'not a number');
      await tester.pump();
      expect(saved(settings, scale.id).baseFrequency, 440);

      await tester.enterText(find.byType(TextField).at(1), '-100');
      await tester.pump();
      expect(saved(settings, scale.id).baseFrequency, 440);
    });

    testWidgets('changing the root octave persists it', (tester) async {
      final scale = threeToneScale();
      final settings = await pumpEditor(tester, scale);

      await tester.enterText(find.byType(TextField).at(2), '3');
      await tester.pump();

      expect(saved(settings, scale.id).rootOctave, 3);
    });
  });

  group('degrees', () {
    testWidgets('the + button adds a tone', (tester) async {
      final scale = threeToneScale();
      final settings = await pumpEditor(tester, scale);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      final updated = saved(settings, scale.id);
      expect(updated.degrees, hasLength(4));
      expect(updated.degrees.any((d) => d.name == 'New'), isTrue);
    });

    testWidgets('duplicating a tone splits its wedge at the midpoint', (
      tester,
    ) async {
      final scale = threeToneScale();
      final settings = await pumpEditor(tester, scale);

      // Row 0 is C at 0 cents; its neighbour is E at 400.
      await tester.tap(find.byTooltip('Duplicate (splits this wedge)').first);
      await tester.pump();

      final updated = saved(settings, scale.id);
      expect(updated.degrees, hasLength(4));
      final copy = updated.degrees.firstWhere((d) => d.name == 'C copy');
      expect(copy.cents, 200);
    });

    testWidgets('duplicating the last tone wraps around the octave', (
      tester,
    ) async {
      final scale = threeToneScale();
      final settings = await pumpEditor(tester, scale);

      // Row 2 is G at 700; the "next" tone is C at 0 in the *next*
      // octave, i.e. 1200 — so the midpoint is 950, not 350.
      await tester.tap(find.byTooltip('Duplicate (splits this wedge)').at(2));
      await tester.pump();

      final copy = saved(
        settings,
        scale.id,
      ).degrees.firstWhere((d) => d.name == 'G copy');
      expect(copy.cents, 950);
    });

    testWidgets('deleting a tone removes it', (tester) async {
      final scale = threeToneScale();
      final settings = await pumpEditor(tester, scale);

      await tester.tap(find.byTooltip('Delete').first);
      await tester.pump();

      final updated = saved(settings, scale.id);
      expect(updated.degrees, hasLength(2));
      expect(updated.degrees.any((d) => d.name == 'C'), isFalse);
    });

    testWidgets('renaming a tone persists it', (tester) async {
      final scale = threeToneScale();
      final settings = await pumpEditor(tester, scale);

      await tester.enterText(degreeNameField(0), 'Do');
      await tester.pump();

      expect(saved(settings, scale.id).degrees.first.name, 'Do');
    });

    testWidgets('the star sets the root, and only one tone is the root', (
      tester,
    ) async {
      final scale = threeToneScale();
      final settings = await pumpEditor(tester, scale);
      expect(saved(settings, scale.id).rootIndex, 0);
      // One filled star (row 0), two outlines.
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.star_border), findsNWidgets(2));

      // The first outlined star is row 1.
      await tester.tap(find.byIcon(Icons.star_border).first);
      await tester.pump();

      expect(saved(settings, scale.id).rootIndex, 1);
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.star_border), findsNWidgets(2));
    });

    testWidgets('deleting the root tone keeps rootIndex in range', (
      tester,
    ) async {
      final scale = TuningScale(
        name: 'Triad',
        degrees: const [
          ScaleDegree(name: 'C', cents: 0),
          ScaleDegree(name: 'E', cents: 400),
          ScaleDegree(name: 'G', cents: 700),
        ],
        rootIndex: 2,
      );
      final settings = await pumpEditor(tester, scale);

      await tester.tap(find.byTooltip('Delete').at(2));
      await tester.pump();

      final updated = saved(settings, scale.id);
      expect(updated.degrees, hasLength(2));
      // Would otherwise dangle past the end of the shortened list.
      expect(updated.rootIndex, lessThan(updated.degrees.length));
    });
  });

  group('cents entry', () {
    testWidgets('a plain value is stored as typed', (tester) async {
      final scale = threeToneScale();
      final settings = await pumpEditor(tester, scale);

      await tester.enterText(degreeCentsField(0), '150');
      await tester.pump();

      final c = saved(settings, scale.id);
      expect(c.degrees.firstWhere((d) => d.name == 'C').cents, 150);
    });

    testWidgets('a value past the octave wraps into it', (tester) async {
      final scale = threeToneScale();
      final settings = await pumpEditor(tester, scale);

      // 1300 cents is an octave plus 100 — the same pitch class as 100.
      await tester.enterText(degreeCentsField(0), '1300');
      await tester.pump();

      expect(
        saved(
          settings,
          scale.id,
        ).degrees.firstWhere((d) => d.name == 'C').cents,
        100,
      );
    });

    testWidgets('a negative value wraps to the top of the octave', (
      tester,
    ) async {
      final scale = threeToneScale();
      final settings = await pumpEditor(tester, scale);

      await tester.enterText(degreeCentsField(0), '-50');
      await tester.pump();

      expect(
        saved(
          settings,
          scale.id,
        ).degrees.firstWhere((d) => d.name == 'C').cents,
        1150,
      );
    });

    testWidgets('unparseable text leaves the stored value alone', (
      tester,
    ) async {
      final scale = threeToneScale();
      final settings = await pumpEditor(tester, scale);

      await tester.enterText(degreeCentsField(0), 'abc');
      await tester.pump();

      expect(
        saved(
          settings,
          scale.id,
        ).degrees.firstWhere((d) => d.name == 'C').cents,
        0,
      );
    });
  });

  group('cake chart', () {
    ScaleCakeChart chart(WidgetTester tester) =>
        tester.widget<ScaleCakeChart>(find.byType(ScaleCakeChart));

    /// Taps [offset] away from the chart's centre. The wedge under a point
    /// is worked out from its angle: 12 o'clock is 0 cents, running
    /// clockwise through the octave.
    Future<void> tapChart(WidgetTester tester, Offset offset) async {
      await tester.tapAt(
        tester.getCenter(find.byType(ScaleCakeChart)) + offset,
      );
      await tester.pump();
    }

    testWidgets('nothing is selected to begin with', (tester) async {
      await pumpEditor(tester, threeToneScale());
      expect(chart(tester).selectedIndex, isNull);
    });

    testWidgets('tapping a wedge selects the tone it belongs to', (
      tester,
    ) async {
      await pumpEditor(tester, threeToneScale());

      // Straight up = 0 cents, inside C's wedge (which runs -250..200).
      await tapChart(tester, const Offset(0, -60));
      expect(chart(tester).selectedIndex, 0);

      // Right = 300 cents, inside E's wedge (200..550).
      await tapChart(tester, const Offset(60, 0));
      expect(chart(tester).selectedIndex, 1);

      // Down = 600 cents, inside G's wedge (550..950).
      await tapChart(tester, const Offset(0, 60));
      expect(chart(tester).selectedIndex, 2);
    });

    testWidgets('a tap outside the circle selects nothing', (tester) async {
      await pumpEditor(tester, threeToneScale());

      await tapChart(tester, const Offset(0, -60));
      expect(chart(tester).selectedIndex, 0);

      // Inside the chart's square, but beyond the circle it draws in.
      await tapChart(tester, const Offset(110, -110));
      expect(chart(tester).selectedIndex, 0, reason: 'selection unchanged');
    });

    testWidgets('a scale with no tones renders a placeholder instead', (
      tester,
    ) async {
      await pumpEditor(tester, TuningScale(name: 'Empty', degrees: const []));

      expect(find.text('No tone heights defined'), findsOneWidget);
      expect(
        find.textContaining('No tone heights defined yet'),
        findsOneWidget,
      );
    });
  });

  testWidgets('the app-bar reset restores the chromatic default', (
    tester,
  ) async {
    final scale = threeToneScale();
    final settings = await pumpEditor(tester, scale);

    await tester.tap(find.byTooltip('Reset to default chromatic scale'));
    await tester.pumpAndSettle();

    final updated = saved(settings, scale.id);
    expect(updated.degrees, hasLength(12));
    expect(updated.degrees.first.name, 'C');
    // The name is the user's own and isn't part of what "reset" means.
    expect(updated.name, 'Triad');
  });
}
