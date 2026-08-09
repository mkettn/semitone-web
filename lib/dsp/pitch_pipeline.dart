import 'dart:math' as math;
import 'dart:typed_data';

import 'pitch_detector.dart';

/// Result of one pitch-detection cycle.
class PitchReading {
  const PitchReading({required this.frequency});

  /// Smoothed estimate of the fundamental frequency, in Hz. Interpreting
  /// this against any particular scale (which note it is, how many cents
  /// off) is the caller's job, via that scale's own base frequency.
  final double frequency;
}

/// The signal-processing half of the tuner: raw PCM bytes in, smoothed
/// pitch readings out.
///
/// Deliberately knows nothing about microphones, plugins or streams —
/// [TunerEngine] owns the `record` plugin and the capture clock, and does
/// nothing with the bytes but hand them here. That split is what makes
/// this testable: `flutter test` has no audio backend, and awaiting a
/// real recorder hangs rather than fails, so as long as the buffering,
/// sample-rate correction, calibration and smoothing lived inside the
/// recorder's stream callback they could never run under test. Feeding
/// [feed] a [Uint8List] needs no microphone, real or simulated.
class PitchPipeline {
  PitchPipeline({this.bufferSize = 4096, this.nominalSampleRate = 44100});

  /// Samples per analysis frame. Must be a power of two ([PitchDetector]
  /// rounds down to one otherwise).
  final int bufferSize;

  /// The sample rate that was *requested* from the platform, used until
  /// enough audio has arrived to measure the real one. See
  /// [effectiveSampleRate].
  final int nominalSampleRate;

  /// How many past frames the median smoother considers.
  static const historySize = 16;

  /// How much audio must have been captured before the measured sample
  /// rate is trusted over [nominalSampleRate]. Below this, the elapsed-time
  /// measurement is too short to divide by accurately.
  static const calibrationMinMs = 500;

  // Purely an internal anchor for smoothing in log-frequency (semitone)
  // space, which behaves consistently across registers unlike smoothing
  // raw Hz values directly. Not user-facing and unrelated to any scale's
  // own base frequency - converted back to Hz before reaching listeners.
  static const _smoothingAnchor = 440.0;

  /// Fixed correction, in Hz, subtracted from every raw reading before
  /// smoothing — compensates for a microphone whose ADC consistently
  /// reports a sharp or flat frequency. See the calibration screen.
  double calibrationOffsetHz = 0.0;

  late final PitchDetector _detector = PitchDetector(bufferSize);
  final BytesBuilder _byteBuffer = BytesBuilder();
  final List<double> _history = List.filled(historySize, 0, growable: true);

  int _samplesCounted = 0;
  late double _effectiveSampleRate = nominalSampleRate.toDouble();

  /// The sample rate actually being delivered, measured from elapsed time
  /// vs. samples received.
  ///
  /// The platform can deliver a different rate than the one requested —
  /// notably on web, where the browser's AudioContext silently overrides it
  /// to match the device's native rate (see record_web's `adjustConfig`).
  /// Trusting the requested constant there produces a fixed,
  /// device-dependent pitch offset. Stays at [nominalSampleRate] until
  /// [calibrationMinMs] of audio has arrived.
  double get effectiveSampleRate => _effectiveSampleRate;

  /// Total 16-bit samples seen since construction or the last [reset].
  int get samplesCounted => _samplesCounted;

  /// Drops all buffered audio, smoothing history and rate measurement,
  /// as if capture were starting fresh. [calibrationOffsetHz] is a user
  /// setting rather than capture state, so it survives.
  void reset() {
    _byteBuffer.clear();
    _samplesCounted = 0;
    _effectiveSampleRate = nominalSampleRate.toDouble();
    _history.fillRange(0, _history.length, 0);
  }

  /// Accumulates one chunk of little-endian 16-bit mono PCM, returning a
  /// smoothed reading once a full frame's worth has arrived — or null
  /// while still buffering, or when the chunk held no discernible pitch.
  ///
  /// [elapsed] is the capture time so far, used to measure
  /// [effectiveSampleRate]; the caller owns that clock.
  PitchReading? feed(Uint8List chunk, {Duration elapsed = Duration.zero}) {
    _samplesCounted += chunk.length ~/ 2;
    final elapsedMs = elapsed.inMilliseconds;
    if (elapsedMs >= calibrationMinMs) {
      _effectiveSampleRate = _samplesCounted / (elapsedMs / 1000.0);
    }

    _byteBuffer.add(chunk);
    final bytes = _byteBuffer.toBytes();
    final neededBytes = bufferSize * 2; // 16-bit samples
    if (bytes.length < neededBytes) return null;

    // Use the most recent `neededBytes` and drop the rest.
    final frame = bytes.sublist(bytes.length - neededBytes);
    _byteBuffer.clear();

    final pcm = ByteData.sublistView(frame);
    final samples = Float64List(bufferSize);
    for (var i = 0; i < bufferSize; i++) {
      samples[i] = pcm.getInt16(i * 2, Endian.little) / 1024.0;
    }

    final rawFreq = _detector.frequency(samples, _effectiveSampleRate);
    if (rawFreq == null || rawFreq.isNaN || rawFreq <= 0) return null;
    final freq = rawFreq - calibrationOffsetHz;
    if (freq <= 0) return null;

    return PitchReading(frequency: _smooth(freq));
  }

  /// Moving median over the last [historySize] readings, taken in
  /// log-frequency space so the smoothing behaves the same in every
  /// register. Rejects the occasional octave-jump or noise spike that
  /// autocorrelation peak-picking throws off, at the cost of a short lag
  /// while the history fills.
  double _smooth(double freq) {
    final semitone = 12 * (math.log(freq / _smoothingAnchor) / math.ln2);
    _history.removeAt(0);
    _history.add(semitone);
    final sorted = [..._history]..sort();
    final median =
        (sorted[historySize ~/ 2 - 1] + sorted[historySize ~/ 2]) / 2;
    return (_smoothingAnchor * math.pow(2, median / 12)).toDouble();
  }
}
