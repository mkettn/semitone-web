import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:record/record.dart';

import '../dsp/pitch_detector.dart';

/// Result of one pitch-detection cycle.
class PitchReading {
  const PitchReading({required this.frequency});

  /// Smoothed estimate of the fundamental frequency, in Hz. Interpreting
  /// this against any particular scale (which note it is, how many cents
  /// off) is the caller's job, via that scale's own base frequency.
  final double frequency;
}

/// Captures microphone audio and streams pitch estimates, replicating the
/// original app's RecordEngine + DSP + moving-median smoothing pipeline.
class TunerEngine {
  TunerEngine({this.sampleRate = 44100, this.bufferSize = 4096});

  final int sampleRate;
  final int bufferSize;
  static const _histSize = 16;

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  final _controller = StreamController<PitchReading>.broadcast();
  late final PitchDetector _detector = PitchDetector(bufferSize);

  final List<double> _history = List.filled(_histSize, 0, growable: true);

  /// Fixed correction, in Hz, subtracted from every raw reading before
  /// smoothing — compensates for a microphone whose ADC consistently
  /// reports a sharp or flat frequency. See the calibration screen.
  double calibrationOffsetHz = 0.0;

  // Purely an internal anchor for smoothing in log-frequency (semitone)
  // space, which behaves consistently across registers unlike smoothing
  // raw Hz values directly. Not user-facing and unrelated to any scale's
  // own base frequency - converted back to Hz before reaching listeners.
  static const _smoothingAnchor = 440.0;

  // The sample rate actually delivered by the platform can differ from the
  // one requested in RecordConfig — notably on web, where the browser's
  // AudioContext silently overrides it to match the device's native rate
  // (see record_web's `adjustConfig`). Trusting the requested constant there
  // produces a fixed, device-dependent pitch offset, so we measure the
  // effective rate at runtime from elapsed time vs. samples received.
  final Stopwatch _captureClock = Stopwatch();
  int _samplesCounted = 0;
  double _effectiveSampleRate = 0;

  static const _calibrationMinMs = 500;

  Stream<PitchReading> get readings => _controller.stream;

  Future<bool> hasPermission() => _recorder.hasPermission();

  bool get isRunning => _sub != null;

  /// Set when the platform's audio backend is unavailable (e.g. no
  /// microphone / recording binary present), as opposed to the user simply
  /// not having granted permission yet.
  bool captureFailed = false;

  Future<void> start() async {
    if (isRunning) return;
    if (!await _recorder.hasPermission()) return;

    Stream<Uint8List> stream;
    try {
      stream = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
        ),
      );
    } catch (_) {
      captureFailed = true;
      return;
    }

    final byteBuffer = BytesBuilder();
    final neededBytes = bufferSize * 2; // 16-bit samples

    _captureClock
      ..reset()
      ..stop();
    _samplesCounted = 0;
    _effectiveSampleRate = sampleRate.toDouble();

    _sub = stream.listen((chunk) {
      if (!_captureClock.isRunning) _captureClock.start();
      _samplesCounted += chunk.length ~/ 2;
      if (_captureClock.elapsedMilliseconds >= _calibrationMinMs) {
        _effectiveSampleRate =
            _samplesCounted / (_captureClock.elapsedMilliseconds / 1000.0);
      }

      byteBuffer.add(chunk);
      final bytes = byteBuffer.toBytes();
      if (bytes.length < neededBytes) return;

      // Use the most recent `neededBytes` and drop the rest.
      final start = bytes.length - neededBytes;
      final frame = bytes.sublist(start);
      byteBuffer.clear();

      final pcm = ByteData.sublistView(frame);
      final samples = Float64List(bufferSize);
      for (var i = 0; i < bufferSize; i++) {
        final s = pcm.getInt16(i * 2, Endian.little);
        samples[i] = s / 1024.0;
      }

      final rawFreq = _detector.frequency(samples, _effectiveSampleRate);
      if (rawFreq == null || rawFreq.isNaN || rawFreq <= 0) return;
      final freq = rawFreq - calibrationOffsetHz;
      if (freq <= 0) return;

      final semitone = 12 * (math.log(freq / _smoothingAnchor) / math.ln2);
      _history.removeAt(0);
      _history.add(semitone);
      final sorted = [..._history]..sort();
      final median =
          (sorted[_histSize ~/ 2 - 1] + sorted[_histSize ~/ 2]) / 2;
      final smoothedFreq =
          (_smoothingAnchor * math.pow(2, median / 12)).toDouble();

      _controller.add(PitchReading(frequency: smoothedFreq));
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _captureClock.stop();
    await _recorder.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
    await _recorder.dispose();
  }
}
