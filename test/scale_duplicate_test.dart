import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:semitone_web/models/scale_degree.dart';
import 'package:semitone_web/models/tuning_scale.dart';
import 'package:semitone_web/screens/custom_scale_screen.dart';

import 'support/scale_harness.dart';

/// Duplicating a scale: the copy button on each row of the Settings
/// screen's scales list.
void main() {
  testWidgets('copies every part of the scale, not just its name', (
    tester,
  ) async {
    final original = TuningScale(
      name: 'Byzantine test',
      degrees: const [
        ScaleDegree(name: 'Νη', cents: 0),
        ScaleDegree(name: 'Πα', cents: 200),
        ScaleDegree(name: 'Βου', cents: 366.6666666666667),
      ],
      rootIndex: 1,
      rootOctave: 3,
      baseFrequency: 432,
    );
    final settings = await settingsWithScales([original]);

    await pumpSettings(tester, settings);
    await tester.tap(find.byTooltip('Copy scale').first);
    await tester.pumpAndSettle();

    final copy = settings.scales.last;
    expect(copy.name, 'Byzantine test (copy)');
    expect(degreeSignature(copy), degreeSignature(original));
    expect(copy.rootIndex, 1);
    expect(copy.rootOctave, 3);
    expect(copy.baseFrequency, 432);
  });

  testWidgets('the copy is a separate scale, and the original survives', (
    tester,
  ) async {
    final settings = await seededSettings();
    final original = settings.scales.first;
    final before = settings.scales.length;

    await pumpSettings(tester, settings);
    await tester.tap(find.byTooltip('Copy scale').first);
    await tester.pumpAndSettle();

    expect(settings.scales, hasLength(before + 1));
    final copy = settings.scales.last;
    expect(copy.id, isNot(original.id));

    final keptOriginal = settings.scales.firstWhere((s) => s.id == original.id);
    expect(keptOriginal.name, original.name);
    expect(degreeSignature(keptOriginal), degreeSignature(original));
  });

  testWidgets('the copy becomes active', (tester) async {
    final settings = await seededSettings();

    await pumpSettings(tester, settings);
    await tester.tap(find.byTooltip('Copy scale').first);
    await tester.pumpAndSettle();

    expect(settings.activeScaleId, settings.scales.last.id);
  });

  testWidgets('the editor opens on the copy, not the original', (tester) async {
    final settings = await seededSettings();
    final original = settings.scales.first;

    await pumpSettings(tester, settings);
    await tester.tap(find.byTooltip('Copy scale').first);
    await tester.pumpAndSettle();

    // The whole point of duplicating is to change the copy — landing on
    // the original would edit the scale the user meant to preserve.
    final editor = tester.widget<CustomScaleScreen>(
      find.byType(CustomScaleScreen),
    );
    expect(editor.scaleId, settings.scales.last.id);
    expect(editor.scaleId, isNot(original.id));
  });

  testWidgets('editing the copy leaves the original alone', (tester) async {
    final settings = await settingsWithScales([threeToneScale()]);
    final original = settings.scales.single;

    await pumpSettings(tester, settings);
    await tester.tap(find.byTooltip('Copy scale').first);
    await tester.pumpAndSettle();

    // Rename in the editor that just opened on the copy.
    await tester.enterText(find.byType(TextField).first, 'Changed');
    await tester.pump();

    final copy = settings.scales.last;
    expect(copy.name, 'Changed');
    expect(saved(settings, original.id).name, 'Triad');
  });

  testWidgets('duplicating twice gives two distinct copies', (tester) async {
    final settings = await settingsWithScales([threeToneScale()]);

    await pumpSettings(tester, settings);
    await tester.tap(find.byTooltip('Copy scale').first);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Copy scale').first);
    await tester.pumpAndSettle();

    expect(settings.scales, hasLength(3));
    final ids = settings.scales.map((s) => s.id).toSet();
    expect(ids, hasLength(3), reason: 'no id collisions between copies');
  });
}
