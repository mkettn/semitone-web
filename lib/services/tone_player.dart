import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'wav_synth.dart';

/// Plays a single sustained sine-wave tone at a time — for previewing a
/// scale degree's pitch while editing it, not for actual tuning reference.
/// Starting a new tone stops whatever was already playing; toggling the
/// same key off just stops it.
class TonePlayer extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  Object? _playingKey;

  Object? get playingKey => _playingKey;
  bool isPlaying(Object key) => _playingKey == key;

  /// Starts [frequencyHz] under [key], or stops if [key] is already
  /// playing.
  Future<void> toggle(Object key, double frequencyHz) async {
    if (_playingKey == key) {
      await stop();
      return;
    }
    await _player.stop();
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setSourceBytes(_toneWav(frequencyHz));
    await _player.resume();
    _playingKey = key;
    notifyListeners();
  }

  Future<void> stop() async {
    if (_playingKey == null) return;
    await _player.stop();
    _playingKey = null;
    notifyListeners();
  }

  /// Synthesizes a whole number of cycles of a sine wave at [frequency],
  /// so the buffer starts and ends at a zero crossing with matching slope
  /// — [ReleaseMode.loop] repeats it seamlessly, with no click at the seam.
  Uint8List _toneWav(double frequency) {
    const sampleRate = 44100;
    const targetSeconds = 0.5;
    final cycles = math.max(1, (frequency * targetSeconds).round());
    final numSamples = (sampleRate * cycles / frequency).round();
    final pcm = Int16List(numSamples);
    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final sample = math.sin(2 * math.pi * frequency * t);
      pcm[i] = (sample * 26000).round().clamp(-32768, 32767);
    }
    return pcmToWavBytes(pcm, sampleRate);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
