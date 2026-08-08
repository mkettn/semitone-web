import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// The single-player surface [TonePlayer] needs.
///
/// Exists so the parts of [TonePlayer] that are real logic rather than
/// plumbing — the serialized operation queue, the generation counter that
/// lets a later tap abandon an earlier one's audio work, and the
/// click-avoiding volume ramp in `_fadeOutAndStop` — can be tested. Every
/// one of those `await`s a real [AudioPlayer], which under `flutter test`
/// hangs rather than throwing.
abstract class TonePlayback {
  /// Fires when a note reaches the end of its own buffer (as opposed to
  /// being stopped early).
  Stream<void> get onComplete;

  Future<void> setVolume(double volume);

  /// Loads a WAV file from memory, replacing whatever was loaded before.
  Future<void> setSource(Uint8List wavBytes);

  Future<void> resume();

  Future<void> stop();

  void dispose();
}

/// The real implementation, backed by a single `audioplayers` instance —
/// one player, so starting a note inherently replaces the previous one.
class AudioPlayersTonePlayback implements TonePlayback {
  final AudioPlayer _player = AudioPlayer();

  @override
  Stream<void> get onComplete => _player.onPlayerComplete;

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> setSource(Uint8List wavBytes) =>
      _player.setSourceBytes(wavBytes, mimeType: 'audio/wav');

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> stop() => _player.stop();

  @override
  void dispose() => _player.dispose();
}
