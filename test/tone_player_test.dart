import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:semitone_web/services/tone_playback.dart';
import 'package:semitone_web/services/tone_player.dart';

/// Records what [TonePlayer] asks of its player, without making sound.
///
/// The real [AudioPlayersTonePlayback] can't be driven under
/// `flutter test` — every call awaits a plugin that never answers, so the
/// fade ramp and the queue's ordering could not be observed at all.
class FakeTonePlayback implements TonePlayback {
  final _complete = StreamController<void>.broadcast();

  /// Every call in order, e.g. `['volume', 'source', 'resume']`.
  final List<String> calls = [];
  final List<double> volumes = [];
  final List<Uint8List> sources = [];
  int disposeCount = 0;

  /// Makes the next [setSource] throw, standing in for a decode failure.
  bool failNextSetSource = false;

  /// Simulates a note reaching the end of its own buffer.
  void finishNote() => _complete.add(null);

  @override
  Stream<void> get onComplete => _complete.stream;

  @override
  Future<void> setVolume(double volume) async {
    calls.add('volume');
    volumes.add(volume);
  }

  @override
  Future<void> setSource(Uint8List wavBytes) async {
    calls.add('source');
    if (failNextSetSource) {
      failNextSetSource = false;
      throw StateError('could not decode');
    }
    sources.add(wavBytes);
  }

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  void dispose() {
    disposeCount++;
    _complete.close();
  }
}

void main() {
  // These assert that playingKey/isPlaying() update *synchronously*,
  // before any of the async audio work resolves — the property that keeps
  // rapid taps from racing each other. They deliberately don't await.
  group('synchronous state', () {
    test('starts with nothing playing', () {
      final player = TonePlayer(playback: FakeTonePlayback());

      expect(player.playingKey, isNull);
      expect(player.isPlaying(0), isFalse);
      expect(player.isPlaying('anything'), isFalse);
    });

    test('toggle updates playingKey synchronously', () {
      final player = TonePlayer(playback: FakeTonePlayback());

      unawaited(player.toggle('C', 440.0));

      expect(player.isPlaying('C'), isTrue);
    });

    test("toggling a different key switches playingKey synchronously, without "
        "waiting for the previous key's audio to finish loading", () {
      final player = TonePlayer(playback: FakeTonePlayback());

      unawaited(player.toggle('C', 440.0));
      unawaited(player.toggle('D', 293.66));

      expect(player.isPlaying('D'), isTrue);
      expect(player.isPlaying('C'), isFalse);
    });

    test('toggling the same key again stops it synchronously', () {
      final player = TonePlayer(playback: FakeTonePlayback());

      unawaited(player.toggle('C', 440.0));
      expect(player.isPlaying('C'), isTrue);

      unawaited(player.toggle('C', 440.0));
      expect(player.playingKey, isNull);
    });

    test('rapid taps leave playingKey on the last one tapped', () {
      final player = TonePlayer(playback: FakeTonePlayback());

      unawaited(player.toggle('C', 261.63));
      unawaited(player.toggle('D', 293.66));
      unawaited(player.toggle('E', 329.63));

      expect(player.playingKey, 'E');
    });

    test('stop() clears playingKey synchronously', () {
      final player = TonePlayer(playback: FakeTonePlayback());

      unawaited(player.toggle('C', 440.0));
      unawaited(player.stop());

      expect(player.playingKey, isNull);
    });
  });

  // Plain `test`, not `testWidgets`: the fade awaits real
  // `Future.delayed`s, which under FakeAsync would need pumping and
  // deadlock on a bare await.
  group('playback', () {
    test('starting a note loads it at full volume and plays it', () async {
      final playback = FakeTonePlayback();
      final player = TonePlayer(playback: playback);

      await player.toggle('C', 440.0);

      expect(playback.calls, ['volume', 'source', 'resume']);
      expect(playback.volumes, [1.0]);
      expect(playback.sources.single, isNotEmpty);
    });

    test('different keys load different audio', () async {
      final playback = FakeTonePlayback();
      final player = TonePlayer(playback: playback);

      await player.toggle('C', 261.63);
      await player.toggle('E', 329.63);

      expect(playback.sources, hasLength(2));
      expect(playback.sources[0], isNot(equals(playback.sources[1])));
    });

    test('stopping ramps the volume down before stopping', () async {
      final playback = FakeTonePlayback();
      final player = TonePlayer(playback: playback);
      await player.toggle('C', 440.0);
      playback.calls.clear();
      playback.volumes.clear();

      await player.stop();

      // Cutting playback off mid-waveform reads as an audible click, so
      // the volume ramps to silence first and only then stops.
      expect(playback.volumes, [
        7 / 8,
        6 / 8,
        5 / 8,
        4 / 8,
        3 / 8,
        2 / 8,
        1 / 8,
        0 / 8,
      ]);
      expect(playback.calls.last, 'stop');
    });

    test('stop() with nothing playing does no audio work at all', () async {
      final playback = FakeTonePlayback();
      final player = TonePlayer(playback: playback);

      await player.stop();

      expect(playback.calls, isEmpty);
    });

    test(
      'switching notes fades the old one out before loading the new',
      () async {
        final playback = FakeTonePlayback();
        final player = TonePlayer(playback: playback);
        await player.toggle('C', 261.63);
        playback.calls.clear();

        await player.toggle('E', 329.63);

        // The ramp and stop for 'C' must all precede 'E' being loaded.
        final sourceIndex = playback.calls.indexOf('source');
        expect(playback.calls.indexOf('stop'), lessThan(sourceIndex));
        expect(playback.calls.last, 'resume');
      },
    );

    test('rapid taps only ever load the last key tapped', () async {
      final playback = FakeTonePlayback();
      final player = TonePlayer(playback: playback);

      // Three taps in a row — the first two are superseded before their
      // audio work runs, and blipping through each in turn would be both
      // pointless and audible.
      unawaited(player.toggle('C', 261.63));
      unawaited(player.toggle('D', 293.66));
      await player.toggle('E', 329.63);

      expect(playback.sources, hasLength(1));
      expect(player.playingKey, 'E');
    });

    test(
      'a note finishing on its own clears playingKey and notifies',
      () async {
        final playback = FakeTonePlayback();
        final player = TonePlayer(playback: playback);
        var notifications = 0;
        player.addListener(() => notifications++);

        await player.toggle('C', 440.0);
        expect(player.isPlaying('C'), isTrue);

        playback.finishNote();
        await Future<void>.delayed(Duration.zero);

        expect(player.playingKey, isNull);
        // One for the toggle, one for the note ending.
        expect(notifications, 2);
      },
    );

    test('a note finishing when nothing is playing notifies no one', () async {
      final playback = FakeTonePlayback();
      final player = TonePlayer(playback: playback);
      var notifications = 0;
      player.addListener(() => notifications++);

      playback.finishNote();
      await Future<void>.delayed(Duration.zero);

      expect(notifications, 0);
    });

    test('a failed operation surfaces but does not wedge the queue', () async {
      final playback = FakeTonePlayback();
      final player = TonePlayer(playback: playback);

      playback.failNextSetSource = true;
      await expectLater(player.toggle('C', 440.0), throwsStateError);

      // The queue chains every operation onto the previous one, so a
      // rejected future left unhandled would block every later tap behind
      // it forever.
      await player.toggle('E', 329.63);
      expect(playback.sources, hasLength(1));
      expect(player.playingKey, 'E');
    });

    test('dispose() releases the player', () {
      final playback = FakeTonePlayback();
      TonePlayer(playback: playback).dispose();

      expect(playback.disposeCount, 1);
    });
  });
}
