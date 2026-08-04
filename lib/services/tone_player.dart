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
    if (_playingKey != null) await _fadeOutAndStop();
    await _player.setVolume(1.0);
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setSourceBytes(pcmToWavBytes(loopingSinePcm(frequencyHz), 44100));
    await _player.resume();
    _playingKey = key;
    notifyListeners();
  }

  Future<void> stop() async {
    if (_playingKey == null) return;
    await _fadeOutAndStop();
    _playingKey = null;
    notifyListeners();
  }

  /// Cutting the loop off mid-waveform is an abrupt jump to silence that
  /// reliably reads as a click/pop ("creaky") — ramping the volume down
  /// first hides the seam.
  Future<void> _fadeOutAndStop() async {
    const steps = 8;
    for (var i = steps - 1; i >= 0; i--) {
      await _player.setVolume(i / steps);
      await Future.delayed(const Duration(milliseconds: 6));
    }
    await _player.stop();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
