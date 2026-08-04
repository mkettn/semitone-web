import 'dart:convert';
import 'dart:typed_data';

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
