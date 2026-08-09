import 'dart:math' as math;
import 'dart:typed_data';

import 'package:semitone_web/dsp/pitch_pipeline.dart';

/// Synthesized audio input for the tuner's DSP.
///
/// This is not a simulated microphone — it's the byte layout the pipeline
/// parses, built by arithmetic. Nothing here captures, records or plays
/// audio; the tests that use it never touch an audio device.

/// Little-endian 16-bit mono PCM of a [frequency] Hz sine, as the platform
/// recorder would deliver it.
///
/// [phaseOffsetSamples] continues the wave from where a previous chunk
/// left off. Restarting every chunk at phase zero puts a discontinuity at
/// each boundary, which the detector reads as no clear pitch.
Uint8List sinePcm(
  double frequency, {
  int samples = 4096,
  double sampleRate = 44100,
  double amplitude = 8000,
  int phaseOffsetSamples = 0,
}) {
  final bytes = ByteData(samples * 2);
  for (var i = 0; i < samples; i++) {
    final t = (i + phaseOffsetSamples) / sampleRate;
    final value = (math.sin(2 * math.pi * frequency * t) * amplitude).round();
    bytes.setInt16(i * 2, value, Endian.little);
  }
  return bytes.buffer.asUint8List();
}

/// Silence — a valid PCM chunk with no pitch in it.
Uint8List silencePcm({int samples = 4096}) => Uint8List(samples * 2);

/// Feeds [count] phase-continuous frames of [frequency] and returns the
/// last reading.
///
/// The smoother starts with a history of 16 zeros (the 440 Hz anchor in
/// semitone space), so the median only reaches the true value once at
/// least 9 real readings have pushed the old zeros past the midpoint —
/// see [PitchPipeline.historySize]. Tests that care about the converged
/// value feed comfortably more than that.
PitchReading? feedFrames(
  PitchPipeline pipeline,
  double frequency, {
  int count = 12,
  double sampleRate = 44100,
}) {
  PitchReading? last;
  for (var i = 0; i < count; i++) {
    last = pipeline.feed(
      sinePcm(frequency, sampleRate: sampleRate, phaseOffsetSamples: i * 4096),
    );
  }
  return last;
}
