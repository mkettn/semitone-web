import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Drives a simple metronome, synthesizing its own click sounds (short sine
/// bursts) so the app doesn't depend on bundled audio assets.
class MetronomeEngine extends ChangeNotifier {
  MetronomeEngine();

  static const minBpm = 20;
  static const maxBpm = 300;

  final AudioPlayer _strongPlayer = AudioPlayer();
  final AudioPlayer _weakPlayer = AudioPlayer();
  Timer? _timer;

  int _bpm = 120;
  int _beatsPerBar = 4;
  int _beat = 0;
  bool _running = false;

  int get bpm => _bpm;
  int get beatsPerBar => _beatsPerBar;
  int get currentBeat => _beat;
  bool get running => _running;

  set bpm(int value) {
    _bpm = value.clamp(minBpm, maxBpm);
    notifyListeners();
    if (_running) _restartTimer();
  }

  set beatsPerBar(int value) {
    _beatsPerBar = value.clamp(1, 12);
    notifyListeners();
  }

  Future<void> _init() async {
    await _strongPlayer.setSourceBytes(_click(frequency: 1600, ms: 60));
    await _weakPlayer.setSourceBytes(_click(frequency: 1000, ms: 45));
    await _strongPlayer.setReleaseMode(ReleaseMode.stop);
    await _weakPlayer.setReleaseMode(ReleaseMode.stop);
  }

  bool _initialized = false;

  Future<void> start() async {
    if (_running) return;
    if (!_initialized) {
      await _init();
      _initialized = true;
    }
    _running = true;
    _beat = 0;
    _tick();
    _restartTimer();
    notifyListeners();
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  void _restartTimer() {
    _timer?.cancel();
    final interval = Duration(milliseconds: (60000 / _bpm).round());
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  void _tick() {
    final isDownbeat = _beat == 0;
    final player = isDownbeat ? _strongPlayer : _weakPlayer;
    player.seek(Duration.zero);
    player.resume();
    _beat = (_beat + 1) % _beatsPerBar;
    notifyListeners();
  }

  /// Synthesize a short sine-wave click as an in-memory WAV file.
  Uint8List _click({required double frequency, required int ms}) {
    const sampleRate = 44100;
    final numSamples = (sampleRate * ms / 1000).round();
    final pcm = Int16List(numSamples);
    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final envelope = math.exp(-t * 30);
      final sample = math.sin(2 * math.pi * frequency * t) * envelope;
      pcm[i] = (sample * 32000).round().clamp(-32768, 32767);
    }
    return _wavBytes(pcm, sampleRate);
  }

  Uint8List _wavBytes(Int16List pcm, int sampleRate) {
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

  @override
  void dispose() {
    _timer?.cancel();
    _strongPlayer.dispose();
    _weakPlayer.dispose();
    super.dispose();
  }
}
