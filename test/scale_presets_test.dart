import 'package:flutter_test/flutter_test.dart';

import 'package:semitone_web/models/scale_presets.dart';

void main() {
  test('Byzantine genera match the published 72-moria degree centers', () {
    final byName = {for (final p in scalePresets) p.name: p.build()};

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

  test('every Byzantine genus is rooted on Νη, the base note, at 0 cents', () {
    for (final preset in scalePresets.where((p) => p.name.startsWith('Byzantine'))) {
      final scale = preset.build();
      expect(scale.degrees[scale.rootIndex].name, 'Νη');
      expect(scale.degrees[scale.rootIndex].cents, 0);
    }
  });

  test('each genus wedges cover the full octave with no gaps', () {
    for (final preset in scalePresets) {
      final scale = preset.build();
      final boundaries = scale.sliceBoundaries;
      final total = List.generate(boundaries.length, (i) {
        final start = boundaries[i];
        final end = i + 1 < boundaries.length ? boundaries[i + 1] : boundaries[0] + 1200;
        return end - start;
      }).fold<double>(0, (a, b) => a + b);
      expect(total, closeTo(1200, 1e-6), reason: preset.name);
    }
  });
}
