import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:semitone_web/services/audio_capture.dart';
import 'package:semitone_web/services/tuner_engine.dart';

import 'pitch_pipeline_test.dart' show sinePcm;

/// Stand-in for the `record` plugin: hands the engine whatever bytes the
/// test pushes, and records how it was driven.
///
/// Not a simulated microphone — it captures nothing. It exists so the
/// engine's own wiring (permissions, the failure path, forwarding chunks,
/// teardown) can be exercised at all; under `flutter test` there is no
/// audio plugin, and awaiting a real recorder hangs rather than throwing.
class FakeAudioCapture implements AudioCapture {
  FakeAudioCapture({this.permitted = true, this.failOnStart = false});

  bool permitted;
  bool failOnStart;

  final _chunks = StreamController<Uint8List>.broadcast();
  int startCount = 0;
  int stopCount = 0;
  int disposeCount = 0;
  int? requestedSampleRate;

  /// Pushes one chunk to whoever is listening, then lets microtasks run
  /// so the engine's `listen` callback has actually processed it.
  Future<void> emit(Uint8List chunk) async {
    _chunks.add(chunk);
    await Future<void>.delayed(Duration.zero);
  }

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<Stream<Uint8List>> startStream({required int sampleRate}) async {
    startCount++;
    requestedSampleRate = sampleRate;
    if (failOnStart) throw StateError('no audio backend');
    return _chunks.stream;
  }

  @override
  Future<void> stop() async => stopCount++;

  @override
  Future<void> dispose() async {
    disposeCount++;
    await _chunks.close();
  }
}

void main() {
  group('calibration offset', () {
    test('defaults to 0', () {
      expect(TunerEngine(capture: FakeAudioCapture()).calibrationOffsetHz, 0.0);
    });

    test('is settable, read back as set, and reaches the pipeline', () {
      final engine = TunerEngine(capture: FakeAudioCapture());
      engine.calibrationOffsetHz = 2.0;

      expect(engine.calibrationOffsetHz, 2.0);
      // The screens set it on the engine but the pipeline is what applies
      // it, so the delegation is the part worth pinning down.
      expect(engine.pipeline.calibrationOffsetHz, 2.0);
    });
  });

  group('start', () {
    test('does nothing without microphone permission', () async {
      final capture = FakeAudioCapture(permitted: false);
      final engine = TunerEngine(capture: capture);

      await engine.start();

      expect(engine.isRunning, isFalse);
      expect(capture.startCount, 0);
      expect(engine.captureFailed, isFalse);
    });

    test('sets captureFailed when the audio backend is unavailable', () async {
      final capture = FakeAudioCapture(failOnStart: true);
      final engine = TunerEngine(capture: capture);

      await engine.start();

      // Distinct from "permission not granted" — the screens show a
      // different message for each.
      expect(engine.captureFailed, isTrue);
      expect(engine.isRunning, isFalse);
    });

    test('requests the configured sample rate', () async {
      final capture = FakeAudioCapture();
      await TunerEngine(sampleRate: 48000, capture: capture).start();

      expect(capture.requestedSampleRate, 48000);
    });

    test('is idempotent while already running', () async {
      final capture = FakeAudioCapture();
      final engine = TunerEngine(capture: capture);

      await engine.start();
      await engine.start();

      expect(capture.startCount, 1);
      expect(engine.isRunning, isTrue);
    });
  });

  group('readings', () {
    test('emits a detected pitch for captured audio', () async {
      final capture = FakeAudioCapture();
      final engine = TunerEngine(capture: capture);
      final readings = <PitchReading>[];
      engine.readings.listen(readings.add);

      await engine.start();
      for (var i = 0; i < 12; i++) {
        await capture.emit(sinePcm(220, phaseOffsetSamples: i * 4096));
      }

      expect(readings, isNotEmpty);
      expect(readings.last.frequency, closeTo(220, 220 * 0.02));
    });

    test('stays silent while the first frame is still buffering', () async {
      final capture = FakeAudioCapture();
      final engine = TunerEngine(capture: capture);
      final readings = <PitchReading>[];
      engine.readings.listen(readings.add);

      await engine.start();
      await capture.emit(sinePcm(220, samples: 1024));

      expect(readings, isEmpty);
    });

    test('restarting clears state left over from the last capture', () async {
      final capture = FakeAudioCapture();
      final engine = TunerEngine(capture: capture);

      await engine.start();
      await capture.emit(sinePcm(220, samples: 2048));
      expect(engine.pipeline.samplesCounted, 2048);

      await engine.stop();
      await engine.start();

      expect(engine.pipeline.samplesCounted, 0);
    });
  });

  group('teardown', () {
    test('stop() halts capture and leaves the engine restartable', () async {
      final capture = FakeAudioCapture();
      final engine = TunerEngine(capture: capture);

      await engine.start();
      await engine.stop();

      expect(engine.isRunning, isFalse);
      expect(capture.stopCount, 1);

      await engine.start();
      expect(engine.isRunning, isTrue);
      expect(capture.startCount, 2);
    });

    test('dispose() stops capture and releases the recorder', () async {
      final capture = FakeAudioCapture();
      final engine = TunerEngine(capture: capture);

      await engine.start();
      await engine.dispose();

      expect(engine.isRunning, isFalse);
      expect(capture.stopCount, 1);
      expect(capture.disposeCount, 1);
    });

    test('dispose() without ever starting is harmless', () async {
      final capture = FakeAudioCapture();
      await TunerEngine(capture: capture).dispose();

      expect(capture.disposeCount, 1);
    });
  });
}
