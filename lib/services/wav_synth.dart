import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// Synthesizes a sine wave that loops with zero discontinuity at the seam.
///
/// Picking a whole number of cycles isn't enough on its own: the resulting
/// sample count still has to be rounded to an integer, and synthesizing at
/// the original [frequency] over that rounded count leaves a small
/// leftover phase at the last sample — an audible click every time a
/// looping player repeats the buffer, worse the shorter the loop.
/// Instead, once the sample count is fixed, the wave is generated at the
/// frequency that count implies exactly — a fraction of a cent away from
/// [frequency] at most, inaudible, but the phase at sample `numSamples` is
/// now mathematically an exact multiple of a full turn.
Int16List loopingSinePcm(
  double frequency, {
  int sampleRate = 44100,
  double targetSeconds = 1.0,
  int amplitude = 26000,
}) {
  final cycles = math.max(1, (frequency * targetSeconds).round());
  final numSamples = (sampleRate * cycles / frequency).round();
  final loopFrequency = cycles * sampleRate / numSamples;
  final pcm = Int16List(numSamples);
  for (var i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    final sample = math.sin(2 * math.pi * loopFrequency * t);
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
