import 'package:flutter_test/flutter_test.dart';

import 'package:semitone_web/models/scale_presets.dart';
import 'package:semitone_web/models/tuning_scale.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Map<String, TuningScale>> loadByName() async {
    final scales = await loadPresetScales();
    return {for (final s in scales) s.name: s};
  }

  test('Chromatic loads first, with all 12 semitones named with H instead of B', () async {
    final scales = await loadPresetScales();
    expect(scales.first.name, 'Chromatic');
    expect(scales.first.degrees.map((d) => d.name).toList(), [
      'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'H',
    ]);
  });

  test('Byzantine genera match the published 72-moria degree centers', () async {
    final byName = await loadByName();

    void expectCents(String presetName, List<double> expectedCents) {
      final scale = byName[presetName]!;
      final actual = scale.degrees.map((d) => d.cents).toList();
      expect(actual.length, expectedCents.length);
      for (var i = 0; i < actual.length; i++) {
        expect(actual[i], closeTo(expectedCents[i], 0.05));
      }
    }

    expectCents('Byzantine — Diatonic', [0, 200, 366.7, 500, 700, 900, 1066.7]);
    expectCents('Byzantine — Soft chromatic', [0, 133.3, 366.7, 500, 700, 833.3, 1066.7]);
    expectCents('Byzantine — Hard chromatic', [0, 100, 433.3, 500, 700, 800, 1133.3]);
    expectCents('Byzantine — Enharmonic', [0, 200, 400, 500, 700, 900, 1100]);
  });

  test('every Byzantine genus is rooted on Νη, the base note, at 0 cents', () async {
    final scales = await loadPresetScales();
    for (final scale in scales.where((s) => s.name.startsWith('Byzantine'))) {
      expect(scale.degrees[scale.rootIndex].name, 'Νη');
      expect(scale.degrees[scale.rootIndex].cents, 0);
    }
  });

  test('every preset\'s wedges cover the full octave with no gaps', () async {
    final scales = await loadPresetScales();
    for (final scale in scales) {
      final boundaries = scale.sliceBoundaries;
      final total = List.generate(boundaries.length, (i) {
        final start = boundaries[i];
        final end = i + 1 < boundaries.length ? boundaries[i + 1] : boundaries[0] + 1200;
        return end - start;
      }).fold<double>(0, (a, b) => a + b);
      expect(total, closeTo(1200, 1e-6), reason: scale.name);
    }
  });

  test('each call to loadPresetScales returns fresh ids', () async {
    final first = await loadPresetScales();
    final second = await loadPresetScales();
    expect(first.first.id, isNot(second.first.id));
  });
}
