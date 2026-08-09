import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'click_player.dart';
import 'wav_synth.dart';

/// Drives a simple metronome, synthesizing its own click sounds (short sine
/// bursts) so the app doesn't depend on bundled audio assets.
class MetronomeEngine extends ChangeNotifier {
  MetronomeEngine({ClickPlayer? player})
    : _player = player ?? AudioPlayersClickPlayer();

  static const minBpm = 20;
  static const maxBpm = 300;

  final ClickPlayer _player;
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
    await _player.load(
      strong: _click(frequency: 1600, ms: 60),
      weak: _click(frequency: 1000, ms: 45),
    );
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
    _player.play(strong: _beat == 0);
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
    return pcmToWavBytes(pcm, sampleRate);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
    super.dispose();
  }
}
