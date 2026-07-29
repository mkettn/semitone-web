import 'package:flutter_test/flutter_test.dart';

import 'package:semitone_web/models/scale_degree.dart';
import 'package:semitone_web/models/tuning_scale.dart';

/// A 12-tone chromatic fixture for exercising generic TuningScale
/// behaviour in isolation from the app's actual assets/scales/*.json
/// presets (see scale_presets_test.dart for those).
TuningScale _chromaticFixture({double baseFrequency = 440}) {
  const names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'H'];
  return TuningScale(
    name: 'Chromatic fixture',
    degrees: [for (var i = 0; i < names.length; i++) ScaleDegree(name: names[i], cents: i * 100.0)],
    rootIndex: names.indexOf('A'),
    rootOctave: 4,
    baseFrequency: baseFrequency,
  );
}

void main() {
  test('sliceBoundaries partitions the octave into contiguous wedges', () {
    final scale = _chromaticFixture();
    final boundaries = scale.sliceBoundaries;
    expect(boundaries.length, scale.degrees.length);
    // Each boundary should be the midpoint with the previous neighbour.
    expect(boundaries[0], -50); // midpoint of H (1100 - 1200) and C (0)
    expect(boundaries[1], 50); // midpoint of C (0) and C# (100)
    expect(boundaries[2], 150);
  });

  test('match finds the exact degree for its own reference cents', () {
    final scale = _chromaticFixture();
    // A is the root at octave 4 by default, so 0 cents from reference -> A4.
    final match = scale.match(0);
    expect(match.degreeName, 'A');
    expect(match.octave, 4);
    expect(match.errorCents, closeTo(0, 1e-9));
  });

  test('duplicating a slice keeps the octave fully covered', () {
    final scale = _chromaticFixture();
    final boundaries = scale.sliceBoundaries;
    final total = List.generate(scale.degrees.length, (i) {
      final start = boundaries[i];
      final end = i + 1 < boundaries.length ? boundaries[i + 1] : boundaries[0] + 1200;
      return end - start;
    }).fold<double>(0, (a, b) => a + b);
    expect(total, closeTo(1200, 1e-9));
  });

  test('each scale carries its own base frequency, defaulting to 440', () {
    expect(TuningScale.empty().baseFrequency, 440);

    final custom = _chromaticFixture(baseFrequency: 256);
    expect(custom.baseFrequency, 256);
    // copyWith without touching baseFrequency preserves it.
    expect(custom.copyWith(name: 'renamed').baseFrequency, 256);
    // duplicate() carries the base frequency over too.
    expect(custom.duplicate().baseFrequency, 256);
  });

  test('matchFrequency interprets a frequency relative to the scale\'s own base', () {
    final scaleAt440 = _chromaticFixture(baseFrequency: 440);
    final scaleAt256 = _chromaticFixture(baseFrequency: 256);

    // Same absolute frequency, different scales -> different results, because
    // each scale's root sits at its own base frequency.
    final matchVs440 = scaleAt440.matchFrequency(440);
    expect(matchVs440.degreeName, 'A');
    expect(matchVs440.errorCents, closeTo(0, 1e-6));

    final matchVs256 = scaleAt256.matchFrequency(256);
    expect(matchVs256.degreeName, 'A');
    expect(matchVs256.errorCents, closeTo(0, 1e-6));

    // 440 Hz against the scale rooted at 256 Hz is nowhere near its root.
    final mismatched = scaleAt256.matchFrequency(440);
    expect(mismatched.errorCents.abs() < 1e-6, isFalse);
  });

  test('round-trips baseFrequency through JSON', () {
    final scale = _chromaticFixture(baseFrequency: 261.63);
    final restored = TuningScale.fromJsonString(scale.toJsonString());
    expect(restored.baseFrequency, 261.63);
  });

  test('empty() has no degrees and matches as "?"', () {
    final scale = TuningScale.empty();
    expect(scale.degrees, isEmpty);
    final match = scale.matchFrequency(440);
    expect(match.degreeName, '?');
  });
}
