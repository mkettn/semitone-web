import 'package:flutter_test/flutter_test.dart';

import 'package:semitone_web/models/tuning_scale.dart';

void main() {
  test('defaultChromatic has all 12 semitones, named with H instead of B', () {
    final scale = TuningScale.defaultChromatic();
    expect(scale.degrees.map((d) => d.name).toList(), [
      'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'H',
    ]);
    expect(scale.degrees.map((d) => d.cents).toList(),
        [0, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100]);
    expect(scale.degrees[scale.rootIndex].name, 'A');
  });

  test('sliceBoundaries partitions the octave into contiguous wedges', () {
    final scale = TuningScale.defaultChromatic();
    final boundaries = scale.sliceBoundaries;
    expect(boundaries.length, scale.degrees.length);
    // Each boundary should be the midpoint with the previous neighbour.
    expect(boundaries[0], -50); // midpoint of H (1100 - 1200) and C (0)
    expect(boundaries[1], 50); // midpoint of C (0) and C# (100)
    expect(boundaries[2], 150);
  });

  test('match finds the exact degree for its own reference cents', () {
    final scale = TuningScale.defaultChromatic();
    // A is the root at octave 4 by default, so 0 cents from reference -> A4.
    final match = scale.match(0);
    expect(match.degreeName, 'A');
    expect(match.octave, 4);
    expect(match.errorCents, closeTo(0, 1e-9));
  });

  test('duplicating a slice keeps the octave fully covered', () {
    final scale = TuningScale.defaultChromatic();
    final boundaries = scale.sliceBoundaries;
    final total = List.generate(scale.degrees.length, (i) {
      final start = boundaries[i];
      final end = i + 1 < boundaries.length ? boundaries[i + 1] : boundaries[0] + 1200;
      return end - start;
    }).fold<double>(0, (a, b) => a + b);
    expect(total, closeTo(1200, 1e-9));
  });
}
