import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:semitone_web/dsp/pitch_pipeline.dart';
import 'package:semitone_web/models/scale_degree.dart';
import 'package:semitone_web/models/tuning_scale.dart';

import 'support/pcm.dart';

/// Joins the tuner's two halves: synthesized PCM through [PitchPipeline],
/// then the resulting frequency through [TuningScale.matchFrequency] — the
/// same path `TunerScreen` runs, minus the microphone.
///
/// This deliberately does *not* try to verify the app against a real
/// singer or instrument; how well the detector copes with a human voice,
/// room noise and a phone microphone is a question for the web deploy, not
/// for `flutter test`. What's checked here is the arithmetic between the
/// two: a known input frequency lands on the right note, with the right
/// sign and rough size of cent error, and the calibration offset shifts it
/// the way the calibration screen promises.
///
/// Tolerances are in cents rather than Hz because that's what the readout
/// shows. The detector itself is good to a couple of cents at these
/// frequencies (see `pitch_pipeline_test.dart`), so ±12 cents leaves room
/// for it without letting a semitone (100 cents) of error pass.
const _toleranceCents = 12.0;

/// 12-tone equal temperament, A4 = 440 Hz — the bundled Chromatic preset's
/// shape, built here so the test doesn't depend on asset loading.
TuningScale chromatic({double baseFrequency = 440}) => TuningScale(
  name: 'Chromatic',
  degrees: const [
    ScaleDegree(name: 'C', cents: 0),
    ScaleDegree(name: 'C#', cents: 100),
    ScaleDegree(name: 'D', cents: 200),
    ScaleDegree(name: 'D#', cents: 300),
    ScaleDegree(name: 'E', cents: 400),
    ScaleDegree(name: 'F', cents: 500),
    ScaleDegree(name: 'F#', cents: 600),
    ScaleDegree(name: 'G', cents: 700),
    ScaleDegree(name: 'G#', cents: 800),
    ScaleDegree(name: 'A', cents: 900),
    ScaleDegree(name: 'A#', cents: 1000),
    ScaleDegree(name: 'H', cents: 1100),
  ],
  rootIndex: 9, // A
  rootOctave: 4,
  baseFrequency: baseFrequency,
);

/// [cents] above (or below) [hz].
double detune(double hz, double cents) => hz * math.pow(2, cents / 1200);

/// Runs a steady [frequency] through the pipeline and matches the result
/// against [scale] — pipeline in, readout out.
ScaleMatch readout(
  double frequency, {
  required TuningScale scale,
  double calibrationOffsetHz = 0,
}) {
  final pipeline = PitchPipeline()..calibrationOffsetHz = calibrationOffsetHz;
  final reading = feedFrames(pipeline, frequency, count: 20);
  expect(reading, isNotNull, reason: 'no pitch detected for $frequency Hz');
  return scale.matchFrequency(reading!.frequency);
}

void main() {
  group('a tone in tune reads as its note', () {
    // A4 is the scale's own root, so it exercises the zero case; the
    // others make sure the octave arithmetic isn't accidentally anchored
    // to the root.
    const cases = {
      'A': 440.0, // root, octave 4
      'C': 261.63, // octave 4, below the root
      'E': 329.63, // octave 4
      'G': 392.00, // octave 4
    };

    for (final entry in cases.entries) {
      test('${entry.value} Hz reads as ${entry.key}4', () {
        final match = readout(entry.value, scale: chromatic());

        expect(match.degreeName, entry.key);
        expect(match.octave, 4);
        expect(match.errorCents, closeTo(0, _toleranceCents));
      });
    }

    test('the same pitch class an octave up keeps its name', () {
      final match = readout(880, scale: chromatic());

      expect(match.degreeName, 'A');
      expect(match.octave, 5);
      expect(match.errorCents, closeTo(0, _toleranceCents));
    });
  });

  group('a tone out of tune reads as the nearest note, with the error', () {
    test('sharp of A reads as A with a positive error', () {
      final match = readout(detune(440, 30), scale: chromatic());

      expect(match.degreeName, 'A');
      expect(match.errorCents, closeTo(30, _toleranceCents));
      expect(match.errorCents, greaterThan(0), reason: 'sharp is positive');
    });

    test('flat of A reads as A with a negative error', () {
      final match = readout(detune(440, -30), scale: chromatic());

      expect(match.degreeName, 'A');
      expect(match.errorCents, closeTo(-30, _toleranceCents));
      expect(match.errorCents, lessThan(0), reason: 'flat is negative');
    });

    test('past the halfway point it snaps to the neighbouring note', () {
      // 70 cents above A is nearer A# (100) than A (0), so the readout
      // should flip note and change sign rather than showing "A +70".
      final match = readout(detune(440, 70), scale: chromatic());

      expect(match.degreeName, 'A#');
      expect(match.errorCents, closeTo(-30, _toleranceCents));
    });
  });

  group('the calibration offset shifts the readout', () {
    // The calibration screen's promise: play a known reference tone, save
    // the difference between what the mic reports and what you played, and
    // every later reading has that difference removed.
    test('a mic reading 5 Hz sharp is corrected back to in tune', () {
      final scale = chromatic();

      // Uncorrected, a mic that reports 445 for a 440 Hz tone reads sharp.
      final uncorrected = readout(445, scale: scale);
      expect(uncorrected.degreeName, 'A');
      expect(uncorrected.errorCents, greaterThan(10));

      // With the offset the calibration screen would have saved
      // (measured 445 - reference 440), the same input reads in tune.
      final corrected = readout(445, scale: scale, calibrationOffsetHz: 5);
      expect(corrected.degreeName, 'A');
      expect(corrected.errorCents, closeTo(0, _toleranceCents));
    });

    test('a negative offset corrects a mic that reads flat', () {
      final corrected = readout(
        435,
        scale: chromatic(),
        calibrationOffsetHz: -5,
      );

      expect(corrected.degreeName, 'A');
      expect(corrected.errorCents, closeTo(0, _toleranceCents));
    });

    test('an offset large enough to cross a semitone changes the note', () {
      // Not a sane calibration, but it pins down that the offset is applied
      // before matching rather than after — otherwise the note would stay
      // put and only the cent error would move.
      final match = readout(440, scale: chromatic(), calibrationOffsetHz: 25);

      expect(match.degreeName, 'G#');
    });
  });

  group('against a scale with its own base frequency', () {
    test('a scale tuned to 432 Hz matches its own root', () {
      // Byzantine presets use 432 rather than 440; the root has to land on
      // the scale's base frequency, not on concert A.
      final match = readout(432, scale: chromatic(baseFrequency: 432));

      expect(match.degreeName, 'A');
      expect(match.octave, 4);
      expect(match.errorCents, closeTo(0, _toleranceCents));
    });

    test('440 Hz against a 432 Hz scale reads sharp, not in tune', () {
      // 440 is ~32 cents above 432.
      final match = readout(440, scale: chromatic(baseFrequency: 432));

      expect(match.degreeName, 'A');
      expect(match.errorCents, closeTo(32, _toleranceCents));
    });
  });

  test('an unequal scale matches its own uneven boundaries', () {
    // A Byzantine-style genus: the second degree sits at 200 cents but the
    // third at 366.67, so a tone at 350 cents belongs to the third — a
    // 12-TET scale would have called it 300 (D#).
    final scale = TuningScale(
      name: 'Diatonic genus',
      degrees: const [
        ScaleDegree(name: 'Νη', cents: 0),
        ScaleDegree(name: 'Πα', cents: 200),
        ScaleDegree(name: 'Βου', cents: 366.6666666666667),
        ScaleDegree(name: 'Γα', cents: 500),
      ],
      rootIndex: 0,
      baseFrequency: 440,
    );

    final match = readout(detune(440, 350), scale: scale);

    expect(match.degreeName, 'Βου');
    expect(match.errorCents, closeTo(350 - 366.67, _toleranceCents));
  });
}
