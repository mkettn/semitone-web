import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:semitone_web/services/wav_synth.dart';

void main() {
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
