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
  int _generation = 0;

  // Every operation that touches `_player` (fade/stop/load/resume) runs
  // through this queue, one at a time. toggle()/stop() can be called
  // faster than those async AudioPlayer calls resolve — letting two
  // overlap means they race on the same player, and whichever happens to
  // finish last wins regardless of which tap was actually the user's
  // latest. `_playingKey` itself updates synchronously in the public
  // methods below, before anything is queued, so isPlaying()/playingKey
  // reflect the user's intent immediately even while the audio operation
  // for an earlier tap is still in flight.
  Future<void> _queue = Future.value();

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _queue.then((_) => operation());
    // Keep the queue alive even if this operation throws, so one failed
    // operation doesn't wedge every later toggle()/stop() behind a
    // permanently-rejected future. Callers still see `result` reject.
    _queue = result.catchError((_) {});
    return result;
  }

  Object? get playingKey => _playingKey;
  bool isPlaying(Object key) => _playingKey == key;

  /// Starts [frequencyHz] under [key], or stops if [key] is already
  /// playing.
  Future<void> toggle(Object key, double frequencyHz) {
    if (_playingKey == key) return stop();

    final wasPlaying = _playingKey != null;
    _playingKey = key;
    final generation = ++_generation;
    notifyListeners();

    return _enqueue(() async {
      if (wasPlaying) await _fadeOutAndStop();
      // A later toggle()/stop() already moved past this one — e.g. three
      // rapid taps on different rows only need the last one to actually
      // sound, not each key blipping through in turn. Bail before doing
      // any more (increasingly pointless) audio work.
      if (generation != _generation) return;

      await _player.setVolume(1.0);
      await _player.setSourceBytes(
        pcmToWavBytes(pluckedTonePcm(frequencyHz), 44100),
        mimeType: 'audio/wav',
      );
      if (generation != _generation) return;

      await _player.resume();
    });
  }

  Future<void> stop() {
    if (_playingKey == null) return Future.value();
    _playingKey = null;
    ++_generation;
    notifyListeners();
    return _enqueue(_fadeOutAndStop);
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
