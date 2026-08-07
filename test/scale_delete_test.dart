import 'package:flutter_test/flutter_test.dart';

import 'package:semitone_web/models/scale_degree.dart';
import 'package:semitone_web/models/tuning_scale.dart';

import 'support/scale_harness.dart';

/// Deleting a scale: the bin button on each row of the Settings screen's
/// scales list.
void main() {
  testWidgets('removes the scale and says which one went', (tester) async {
    final settings = await seededSettings();
    final doomed = settings.scales.first;
    final before = settings.scales.length;

    await pumpSettings(tester, settings);
    await tester.tap(find.byTooltip('Delete scale').first);
    await tester.pump();

    expect(settings.scales, hasLength(before - 1));
    expect(settings.scales.any((s) => s.id == doomed.id), isFalse);
    expect(find.text('Deleted "${doomed.name}".'), findsOneWidget);
  });

  testWidgets('refuses to delete the last remaining scale', (tester) async {
    final settings = await settingsWithScales([
      TuningScale(
        name: 'Only one',
        degrees: const [ScaleDegree(name: 'C', cents: 0)],
      ),
    ]);
    expect(settings.scales, hasLength(1));

    await pumpSettings(tester, settings);
    await tester.tap(find.byTooltip('Delete scale').first);
    await tester.pump();

    // The tuner always needs something to match against.
    expect(settings.scales, hasLength(1));
    expect(find.text("Can't delete the last scale."), findsOneWidget);
  });

  testWidgets('deleting the active scale hands over to another one', (
    tester,
  ) async {
    final settings = await seededSettings();
    final active = settings.activeScale!;
    expect(active.id, settings.scales.first.id);

    await pumpSettings(tester, settings);
    await tester.tap(find.byTooltip('Delete scale').first);
    await tester.pump();

    // Never left pointing at a scale that no longer exists.
    expect(settings.activeScaleId, isNot(active.id));
    expect(settings.activeScale, isNotNull);
    expect(settings.scales.any((s) => s.id == settings.activeScaleId), isTrue);
  });

  testWidgets('deleting an inactive scale leaves the active one alone', (
    tester,
  ) async {
    final settings = await seededSettings();
    final activeId = settings.activeScaleId;

    await pumpSettings(tester, settings);
    // The second row is not the active scale.
    await tester.tap(find.byTooltip('Delete scale').at(1));
    await tester.pump();

    expect(settings.activeScaleId, activeId);
  });

  testWidgets('the deleted scale disappears from the list', (tester) async {
    final settings = await settingsWithScales([
      TuningScale(name: 'Keep me', degrees: const []),
      TuningScale(name: 'Bin me', degrees: const []),
    ]);

    await pumpSettings(tester, settings);
    expect(find.text('Bin me'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete scale').at(1));
    await tester.pump();

    expect(find.text('Bin me'), findsNothing);
    expect(find.text('Keep me'), findsOneWidget);
  });
}
