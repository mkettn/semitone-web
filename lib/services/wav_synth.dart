import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// One overtone in [pluckedTonePcm]'s additive synthesis: sounds at
/// [frequency] * [multiple], starting at relative [amplitude] and decaying
/// exponentially at [decayPerSecond].
class _Harmonic {
  const _Harmonic(this.multiple, this.amplitude, this.decayPerSecond);
  final int multiple;
  final double amplitude;
  final double decayPerSecond;
}

/// A handful of harmonics approximating a plucked/struck string: a
/// louder, longer-ringing fundamental plus quieter overtones that decay
/// faster, the way a real piano or guitar note's spectrum thins out over
/// its sustain.
const _harmonics = [
  _Harmonic(1, 1.00, 1.1),
  _Harmonic(2, 0.35, 1.8),
  _Harmonic(3, 0.15, 2.6),
];

/// Synthesizes a single one-shot note at [frequency] that decays to
/// silence on its own, instead of an artificially looped raw tone.
///
/// A looped buffer always has a seam — even a mathematically
/// phase-continuous one still tends to click in practice, since a
/// looping player's restart isn't guaranteed sample-accurate. A one-shot
/// note sidesteps the problem entirely: there's
/// nothing to loop, so nothing to click at. This mirrors how the original
/// Semitone app's own piano avoids the same issue — its `Sound` class
/// plays a real recorded note through once and lets it decay, rather than
/// looping a synthesized wave.
Int16List pluckedTonePcm(
  double frequency, {
  int sampleRate = 44100,
  double durationSeconds = 3.0,
  int amplitude = 22000,
}) {
  final numSamples = math.max(1, (sampleRate * durationSeconds).round());
  final pcm = Int16List(numSamples);

  // A few milliseconds' linear ramp-in avoids a click at the very start
  // (the harmonics don't individually start at a zero crossing the way a
  // lone fundamental would).
  const attackSeconds = 0.004;
  final attackSamples = math.max(1, (sampleRate * attackSeconds).round());

  for (var i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    var sample = 0.0;
    for (final h in _harmonics) {
      sample += h.amplitude *
          math.exp(-h.decayPerSecond * t) *
          math.sin(2 * math.pi * frequency * h.multiple * t);
    }
    if (i < attackSamples) sample *= i / attackSamples;
    pcm[i] = (sample * amplitude).round().clamp(-32768, 32767);
  }
  return pcm;
}

/// Encodes 16-bit mono PCM samples as an in-memory WAV file, for feeding
/// a synthesized sound straight into an [AudioPlayer] via `setSourceBytes`
/// without needing a bundled audio asset.
Uint8List pcmToWavBytes(Int16List pcm, int sampleRate) {
  final dataLength = pcm.lengthInBytes;
  final buffer = BytesBuilder();

  void writeString(String s) => buffer.add(ascii.encode(s));
  void writeUint32(int v) {
    final b = ByteData(4)..setUint32(0, v, Endian.little);
    buffer.add(b.buffer.asUint8List());
  }

  void writeUint16(int v) {
    final b = ByteData(2)..setUint16(0, v, Endian.little);
    buffer.add(b.buffer.asUint8List());
  }

  writeString('RIFF');
  writeUint32(36 + dataLength);
  writeString('WAVE');
  writeString('fmt ');
  writeUint32(16);
  writeUint16(1); // PCM
  writeUint16(1); // mono
  writeUint32(sampleRate);
  writeUint32(sampleRate * 2); // byte rate
  writeUint16(2); // block align
  writeUint16(16); // bits per sample
  writeString('data');
  writeUint32(dataLength);
  buffer.add(pcm.buffer.asUint8List());

  return buffer.toBytes();
}
