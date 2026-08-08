import 'dart:typed_data';

import 'package:record/record.dart';

/// The slice of microphone capture [TunerEngine] actually needs, narrow
/// enough that a test can implement it in a few lines.
///
/// Exists so the engine's wiring — permission handling, the
/// capture-failure path, chunk forwarding, teardown — can be exercised
/// without a real recorder. `flutter test` registers no `record` plugin,
/// and awaiting a real [AudioRecorder] hangs rather than throwing, so
/// there is otherwise no way in.
///
/// This is not a simulated microphone: a fake supplies whatever bytes the
/// test wants to assert on, the same way any other stubbed dependency
/// would. Recording real audio remains the platform's job.
abstract class AudioCapture {
  Future<bool> hasPermission();

  /// Starts capture, yielding little-endian 16-bit mono PCM chunks.
  Future<Stream<Uint8List>> startStream({required int sampleRate});

  Future<void> stop();

  Future<void> dispose();
}

/// The real implementation, backed by the `record` plugin.
class RecordAudioCapture implements AudioCapture {
  final AudioRecorder _recorder = AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<Stream<Uint8List>> startStream({required int sampleRate}) {
    return _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
      ),
    );
  }

  @override
  Future<void> stop() => _recorder.stop();

  @override
  Future<void> dispose() => _recorder.dispose();
}
