import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'wav_synth.dart';

/// Plays a single one-shot preview note at a time — for previewing a scale
/// degree's pitch while editing it, not for actual tuning reference. The
/// note decays to silence on its own after a few seconds; starting a new
/// one stops whatever was already playing, and toggling the same key off
/// just stops it early.
class TonePlayer extends ChangeNotifier {
  TonePlayer() {
    _player.onPlayerComplete.listen((_) {
      if (_playingKey == null) return;
      _playingKey = null;
      notifyListeners();
    });
  }

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
    await _player.setSourceBytes(
      pcmToWavBytes(pluckedTonePcm(frequencyHz), 44100),
      mimeType: 'audio/wav',
    );
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

  /// Cutting playback off mid-waveform is an abrupt jump to silence that
  /// reliably reads as a click/pop — ramping the volume down first hides
  /// it. Only matters for an early interruption now (switching notes or
  /// explicit stop); letting a note decay to the end of its own buffer
  /// never needs this, since it's already faded to ~silence by then.
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
