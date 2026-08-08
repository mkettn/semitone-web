import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:semitone_web/models/tuning_scale.dart';

import 'support/scale_harness.dart';

/// Resetting settings: the "Reset settings to defaults" button at the foot
/// of the Settings screen, and its confirmation dialog. It throws away
/// every saved scale — including the user's own — so the dialog is the
/// only thing standing between a stray tap and losing all of them.
void main() {
  Future<void> openResetDialog(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Reset settings to defaults'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('Reset settings to defaults'));
    await tester.pumpAndSettle();
    // Asserted here rather than per-test: without it, a test that checks
    // the dialog is *gone* afterwards would pass just as happily if it had
    // never opened.
    expect(find.text('Reset settings?'), findsOneWidget);
  }

  testWidgets('asks before doing anything', (tester) async {
    final settings = await seededSettings();
    settings.addScale(TuningScale(name: 'Mine', degrees: const []));

    await pumpSettings(tester, settings);
    await openResetDialog(tester);

    expect(find.text('Reset settings?'), findsOneWidget);
    expect(find.textContaining('This cannot be undone.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Reset'), findsOneWidget);
    // Nothing has happened yet.
    expect(settings.scales.any((s) => s.name == 'Mine'), isTrue);
  });

  testWidgets('cancelling keeps the user\'s scales', (tester) async {
    final settings = await seededSettings();
    settings.addScale(TuningScale(name: 'Mine', degrees: const []));
    final before = settings.scales.length;

    await pumpSettings(tester, settings);
    await openResetDialog(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(settings.scales, hasLength(before));
    expect(settings.scales.any((s) => s.name == 'Mine'), isTrue);
    expect(find.text('Reset settings?'), findsNothing);
    expect(find.text('Settings reset to defaults.'), findsNothing);
  });

  testWidgets('dismissing the dialog is the same as cancelling', (
    tester,
  ) async {
    final settings = await seededSettings();
    settings.addScale(TuningScale(name: 'Mine', degrees: const []));

    await pumpSettings(tester, settings);
    await openResetDialog(tester);
    // Tap the barrier rather than either button.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Reset settings?'), findsNothing);
    expect(settings.scales.any((s) => s.name == 'Mine'), isTrue);
  });

  testWidgets('confirming discards them and reloads the presets', (
    tester,
  ) async {
    final settings = await seededSettings();
    final presetCount = settings.scales.length;
    settings.addScale(TuningScale(name: 'Mine', degrees: const []));

    await pumpSettings(tester, settings);
    await openResetDialog(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Reset'));
    await tester.pumpAndSettle();

    expect(settings.scales.any((s) => s.name == 'Mine'), isFalse);
    expect(settings.scales, hasLength(presetCount));
    expect(find.text('Settings reset to defaults.'), findsOneWidget);
  });

  testWidgets('confirming makes the first preset active again', (tester) async {
    final settings = await seededSettings();
    final mine = TuningScale(name: 'Mine', degrees: const []);
    settings.addScale(mine);
    expect(settings.activeScaleId, mine.id);

    await pumpSettings(tester, settings);
    await openResetDialog(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Reset'));
    await tester.pumpAndSettle();

    // Would otherwise point at a scale that no longer exists.
    expect(settings.activeScale!.name, 'Chromatic');
    expect(settings.scales.any((s) => s.id == settings.activeScaleId), isTrue);
  });

  testWidgets('the reloaded presets are the bundled ones', (tester) async {
    // Start from a single unrelated scale, so nothing survives from before.
    final settings = await settingsWithScales([threeToneScale()]);

    await pumpSettings(tester, settings);
    await openResetDialog(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Reset'));
    await tester.pumpAndSettle();

    expect(settings.scales.any((s) => s.name == 'Triad'), isFalse);
    expect(settings.scales.first.name, 'Chromatic');
    expect(settings.scales.first.degrees, hasLength(12));
    expect(
      settings.scales.map((s) => s.name),
      contains('Byzantine — Diatonic'),
    );
  });
}
