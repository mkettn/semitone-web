import 'package:flutter_test/flutter_test.dart';

import 'package:semitone_web/dsp/pitch_pipeline.dart';

import 'support/pcm.dart';

void main() {
  group('buffering', () {
    test('returns null until a full frame has accumulated', () {
      final pipeline = PitchPipeline();
      // Half a frame: 2048 samples of the 4096 needed.
      expect(pipeline.feed(sinePcm(440, samples: 2048)), isNull);
      // The other half completes the frame, so this one produces a reading.
      // Continues the sine where the first chunk left off — a real capture
      // never restarts phase mid-stream, and splicing two copies of the
      // same 2048 samples makes the frame periodic at the splice rather
      // than at the tone's own period, which the detector reads as no
      // clear pitch.
      expect(
        pipeline.feed(sinePcm(440, samples: 2048, phaseOffsetSamples: 2048)),
        isNotNull,
      );
    });

    test('counts samples across chunks regardless of frame boundaries', () {
      final pipeline = PitchPipeline();
      pipeline.feed(sinePcm(440, samples: 1000));
      pipeline.feed(sinePcm(440, samples: 500));
      expect(pipeline.samplesCounted, 1500);
    });

    test('a chunk larger than one frame still yields a reading', () {
      final pipeline = PitchPipeline();
      expect(pipeline.feed(sinePcm(440, samples: 8192)), isNotNull);
    });
  });

  group('pitch detection', () {
    // Drives the full path: PCM bytes -> Float64 samples -> PitchDetector's
    // FFT/autocorrelation/peak-picking -> median smoothing -> Hz. A
    // separate PitchDetector unit test would cover the same code with less
    // of it connected.
    test('detects the fundamental of a synthesized sine', () {
      for (final frequency in [110.0, 220.0, 330.0, 660.0, 880.0]) {
        final pipeline = PitchPipeline();
        final reading = feedFrames(pipeline, frequency);
        expect(reading, isNotNull, reason: '$frequency Hz produced no reading');
        // Autocorrelation with quadratic interpolation lands within a
        // couple percent; below ~150 Hz a period is a large fraction of
        // the 4096-sample window, so the low end is the loosest.
        expect(
          reading!.frequency,
          closeTo(frequency, frequency * 0.02),
          reason: 'detected ${reading.frequency} for $frequency Hz',
        );
      }
    });

    test('reports silence as no pitch rather than a bogus frequency', () {
      final pipeline = PitchPipeline();
      expect(pipeline.feed(silencePcm()), isNull);
    });

    test('smoothing rejects a single outlier frame', () {
      final pipeline = PitchPipeline();
      // Fill the history with a steady tone...
      feedFrames(pipeline, 220, count: 20);
      // ...then one bad frame an octave up. The median of 16 should ignore
      // it entirely.
      final reading = pipeline.feed(sinePcm(440));
      expect(reading!.frequency, closeTo(220, 220 * 0.02));
    });

    test('sustained change eventually moves the smoothed value', () {
      final pipeline = PitchPipeline();
      feedFrames(pipeline, 220, count: 20);
      final reading = feedFrames(pipeline, 440, count: 20);
      expect(reading!.frequency, closeTo(440, 440 * 0.02));
    });
  });

  group('calibration offset', () {
    test('is subtracted from the raw reading', () {
      final baseline = PitchPipeline();
      final uncorrected = feedFrames(baseline, 440)!.frequency;

      final corrected = PitchPipeline()..calibrationOffsetHz = 10;
      final result = feedFrames(corrected, 440)!;

      expect(result.frequency, lessThan(uncorrected));
      expect(result.frequency, closeTo(uncorrected - 10, 1.0));
    });

    test('defaults to zero, leaving readings untouched', () {
      expect(PitchPipeline().calibrationOffsetHz, 0.0);
    });

    test(
      'an offset that would drive the reading to zero yields no reading',
      () {
        // Nonsensical calibration, but it must not emit a negative or zero
        // frequency downstream — matchFrequency would produce a NaN cent
        // error from log(0).
        final pipeline = PitchPipeline()..calibrationOffsetHz = 5000;
        expect(pipeline.feed(sinePcm(440)), isNull);
      },
    );
  });

  group('effective sample rate', () {
    test('stays at the nominal rate before the calibration window', () {
      final pipeline = PitchPipeline(nominalSampleRate: 44100);
      pipeline.feed(
        sinePcm(440),
        elapsed: const Duration(
          milliseconds: PitchPipeline.calibrationMinMs - 1,
        ),
      );
      expect(pipeline.effectiveSampleRate, 44100.0);
    });

    test('is measured from elapsed time once past the window', () {
      // The platform says 44100 but is really delivering 48000: 48000
      // samples (96000 bytes) arrived in one second.
      final pipeline = PitchPipeline(nominalSampleRate: 44100);
      pipeline.feed(
        sinePcm(440, samples: 48000),
        elapsed: const Duration(seconds: 1),
      );
      expect(pipeline.effectiveSampleRate, closeTo(48000, 1));
    });

    test('a wrong nominal rate is corrected, fixing the detected pitch', () {
      // Audio really sampled at 48 kHz, but the pipeline was told 44100 —
      // the web case this measurement exists for. Without the correction
      // every reading is off by the 48000/44100 ratio (~9%).
      const realRate = 48000.0;
      final pipeline = PitchPipeline(nominalSampleRate: 44100);

      // One second of audio first, so the measurement kicks in.
      pipeline.feed(
        sinePcm(440, samples: 48000, sampleRate: realRate),
        elapsed: const Duration(seconds: 1),
      );
      expect(pipeline.effectiveSampleRate, closeTo(realRate, 1));

      PitchReading? reading;
      for (var i = 0; i < 12; i++) {
        // Elapsed time has to stay consistent with how many samples have
        // been handed over, or the measurement drifts to whatever rate the
        // test itself implies rather than the one being simulated.
        final totalSamples = 48000 + (i + 1) * 4096;
        reading = pipeline.feed(
          sinePcm(
            440,
            sampleRate: realRate,
            phaseOffsetSamples: 48000 + i * 4096,
          ),
          elapsed: Duration(
            microseconds: (totalSamples / realRate * 1e6).round(),
          ),
        );
      }
      expect(pipeline.effectiveSampleRate, closeTo(realRate, 1));
      expect(reading!.frequency, closeTo(440, 440 * 0.02));
    });
  });

  group('reset', () {
    test('clears buffered audio, history and the rate measurement', () {
      final pipeline = PitchPipeline(nominalSampleRate: 44100);
      pipeline.feed(
        sinePcm(440, samples: 48000),
        elapsed: const Duration(seconds: 1),
      );
      expect(pipeline.samplesCounted, 48000);
      expect(pipeline.effectiveSampleRate, isNot(44100.0));

      pipeline.reset();

      expect(pipeline.samplesCounted, 0);
      expect(pipeline.effectiveSampleRate, 44100.0);
      // A half frame left over from before the reset must not combine with
      // a new half frame to produce a reading out of two unrelated halves.
      expect(pipeline.feed(sinePcm(440, samples: 2048)), isNull);
    });

    test('keeps the calibration offset, which is a user setting', () {
      final pipeline = PitchPipeline()..calibrationOffsetHz = 3.5;
      pipeline.reset();
      expect(pipeline.calibrationOffsetHz, 3.5);
    });
  });
}
