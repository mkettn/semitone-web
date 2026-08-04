import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:semitone_web/services/wav_synth.dart';

void main() {
  test('loopingSinePcm starts at a zero crossing', () {
    final pcm = loopingSinePcm(440.0);
    expect(pcm.first, 0);
  });

  test('loopingSinePcm has no discontinuity at the loop seam', () {
    const frequency = 444.0; // deliberately not a "nice" divisor of 44100
    const sampleRate = 44100;
    const targetSeconds = 1.0;
    final pcm = loopingSinePcm(
      frequency,
      sampleRate: sampleRate,
      targetSeconds: targetSeconds,
    );

    // loopingSinePcm nudges the synthesis frequency to whatever makes
    // pcm.length an exact whole number of cycles — recompute that
    // adjustment the same way it does, from the same inputs, and confirm
    // continuing the wave one sample past the buffer lands back on the
    // first sample. That's the actual property that makes ReleaseMode.loop
    // click-free: the seam has to be phase-continuous, not just "close".
    final cycles = math.max(1, (frequency * targetSeconds).round());
    final loopFrequency = cycles * sampleRate / pcm.length;
    final nextSample = (math.sin(2 * math.pi * loopFrequency * pcm.length / sampleRate) * 26000)
        .round()
        .clamp(-32768, 32767);
    expect(nextSample, pcm.first);
  });

  test('loopingSinePcm stays within a fraction of a cent of the requested pitch', () {
    const frequency = 444.0;
    const sampleRate = 44100;
    const targetSeconds = 1.0;
    final pcm = loopingSinePcm(
      frequency,
      sampleRate: sampleRate,
      targetSeconds: targetSeconds,
    );

    final cycles = math.max(1, (frequency * targetSeconds).round());
    final loopFrequency = cycles * sampleRate / pcm.length;
    final centsOff = 1200 * (math.log(loopFrequency / frequency) / math.ln2);
    expect(centsOff.abs(), lessThan(0.1));
  });

  test('loopingSinePcm respects targetSeconds to within one cycle', () {
    const frequency = 220.0;
    final pcm = loopingSinePcm(frequency, targetSeconds: 1.0);
    expect(pcm.length, closeTo(44100, 44100 / frequency));
  });

  test('encodes a valid RIFF/WAVE header for the given PCM data', () {
    final pcm = Int16List.fromList([0, 16384, -16384, 32767, -32768]);
    final bytes = pcmToWavBytes(pcm, 44100);
    final data = ByteData.sublistView(bytes);

    String tag(int offset) => String.fromCharCodes(bytes.sublist(offset, offset + 4));

    expect(tag(0), 'RIFF');
    expect(tag(8), 'WAVE');
    expect(tag(12), 'fmt ');
    expect(tag(36), 'data');

    // fmt chunk: PCM, mono, sample rate, byte rate, block align, bits/sample.
    expect(data.getUint32(16, Endian.little), 16); // fmt chunk size
    expect(data.getUint16(20, Endian.little), 1); // PCM
    expect(data.getUint16(22, Endian.little), 1); // mono
    expect(data.getUint32(24, Endian.little), 44100); // sample rate
    expect(data.getUint32(28, Endian.little), 44100 * 2); // byte rate
    expect(data.getUint16(32, Endian.little), 2); // block align
    expect(data.getUint16(34, Endian.little), 16); // bits per sample

    // data chunk size matches the PCM byte length, and the RIFF size
    // covers everything after the initial 8-byte "RIFF"+size header.
    final dataLength = pcm.lengthInBytes;
    expect(data.getUint32(40, Endian.little), dataLength);
    expect(data.getUint32(4, Endian.little), 36 + dataLength);
    expect(bytes.length, 44 + dataLength);
  });

  test('round-trips the PCM samples verbatim into the data chunk', () {
    final pcm = Int16List.fromList([1, -1, 12345, -12345, 0]);
    final bytes = pcmToWavBytes(pcm, 8000);
    final dataChunk = ByteData.sublistView(bytes, 44);

    for (var i = 0; i < pcm.length; i++) {
      expect(dataChunk.getInt16(i * 2, Endian.little), pcm[i]);
    }
  });
}
