import 'dart:async';
import 'dart:typed_data';

import '../dsp/pitch_pipeline.dart';
import 'audio_capture.dart';

export '../dsp/pitch_pipeline.dart' show PitchReading;

/// Captures microphone audio and streams pitch estimates, replicating the
/// original app's RecordEngine + DSP + moving-median smoothing pipeline.
///
/// Only the capture plumbing lives here; everything that turns bytes into
/// a frequency is [PitchPipeline]'s, which is testable on its own. Both
/// halves of the platform-facing surface — the recorder and the pipeline —
/// are injectable so the wiring itself can be tested too.
class TunerEngine {
  TunerEngine({
    this.sampleRate = 44100,
    this.bufferSize = 4096,
    AudioCapture? capture,
  }) : _capture = capture ?? RecordAudioCapture();

  final int sampleRate;
  final int bufferSize;

  final AudioCapture _capture;
  StreamSubscription<Uint8List>? _sub;
  final _controller = StreamController<PitchReading>.broadcast();

  /// The signal processing this engine feeds. Exposed so the calibration
  /// screen (and tests) can reach [PitchPipeline.effectiveSampleRate] and
  /// friends without going through the recorder.
  late final PitchPipeline pipeline = PitchPipeline(
    bufferSize: bufferSize,
    nominalSampleRate: sampleRate,
  );

  // Measures how long capture has been running, so the pipeline can work
  // out the sample rate the platform is really delivering. Owned here
  // rather than in the pipeline to keep the latter free of wall-clock
  // time, and so deterministic under test.
  final Stopwatch _captureClock = Stopwatch();

  /// Fixed correction, in Hz, subtracted from every raw reading before
  /// smoothing — compensates for a microphone whose ADC consistently
  /// reports a sharp or flat frequency. See the calibration screen.
  double get calibrationOffsetHz => pipeline.calibrationOffsetHz;

  set calibrationOffsetHz(double value) => pipeline.calibrationOffsetHz = value;

  Stream<PitchReading> get readings => _controller.stream;

  Future<bool> hasPermission() => _capture.hasPermission();

  bool get isRunning => _sub != null;

  /// Set when the platform's audio backend is unavailable (e.g. no
  /// microphone / recording binary present), as opposed to the user simply
  /// not having granted permission yet.
  bool captureFailed = false;

  Future<void> start() async {
    if (isRunning) return;
    if (!await _capture.hasPermission()) return;

    Stream<Uint8List> stream;
    try {
      stream = await _capture.startStream(sampleRate: sampleRate);
    } catch (_) {
      captureFailed = true;
      return;
    }

    pipeline.reset();
    _captureClock
      ..reset()
      ..stop();

    _sub = stream.listen((chunk) {
      if (!_captureClock.isRunning) _captureClock.start();
      final reading = pipeline.feed(chunk, elapsed: _captureClock.elapsed);
      if (reading != null) _controller.add(reading);
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _captureClock.stop();
    await _capture.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
    await _capture.dispose();
  }
}
