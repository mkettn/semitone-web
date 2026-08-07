import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// The click-playback surface [MetronomeEngine] needs.
///
/// Exists so the engine's actual behaviour — starting, the beat timer,
/// which beat is the downbeat, restarting on a tempo change — can be
/// tested. `MetronomeEngine.start()` used to `await` a real
/// [AudioPlayer.setSourceBytes], and in `flutter test` (no audio plugin)
/// that never resolves, so every line past the await was unreachable:
/// the timer, the tick, the beat counter, all of it.
abstract class ClickPlayer {
  /// Prepares the two click sounds. Called once, on first start.
  Future<void> load({required Uint8List strong, required Uint8List weak});

  /// Fires one click — the accented downbeat when [strong], else the
  /// quieter off-beat. Deliberately synchronous: a metronome that awaited
  /// its own click would drift with playback latency.
  void play({required bool strong});

  void dispose();
}

/// The real implementation, backed by two `audioplayers` instances — one
/// per click sound, so restarting one never cuts the other off.
class AudioPlayersClickPlayer implements ClickPlayer {
  final AudioPlayer _strongPlayer = AudioPlayer();
  final AudioPlayer _weakPlayer = AudioPlayer();

  @override
  Future<void> load({
    required Uint8List strong,
    required Uint8List weak,
  }) async {
    await _strongPlayer.setSourceBytes(strong);
    await _weakPlayer.setSourceBytes(weak);
    await _strongPlayer.setReleaseMode(ReleaseMode.stop);
    await _weakPlayer.setReleaseMode(ReleaseMode.stop);
  }

  @override
  void play({required bool strong}) {
    final player = strong ? _strongPlayer : _weakPlayer;
    player.seek(Duration.zero);
    player.resume();
  }

  @override
  void dispose() {
    _strongPlayer.dispose();
    _weakPlayer.dispose();
  }
}
