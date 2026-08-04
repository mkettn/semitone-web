import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:semitone_web/services/tone_player.dart';

void main() {
  // TonePlayer's AudioPlayer registers itself with the platform plugin
  // channel asynchronously on construction; pumping lets that settle
  // before the test completes (see tuner_engine_test.dart for the same
  // pattern). None of these tests await toggle()/stop() themselves —
  // there's no real audio plugin registered in the test environment, and
  // doing so hangs rather than throwing. What's exercised here is that
  // playingKey/isPlaying() update synchronously, before any of that
  // unmockable async work has had a chance to resolve — that's precisely
  // the property that keeps rapid taps from racing each other.
  testWidgets('starts with nothing playing', (tester) async {
    final player = TonePlayer();
    await tester.pump();

    expect(player.playingKey, isNull);
    expect(player.isPlaying(0), isFalse);
    expect(player.isPlaying('anything'), isFalse);
  });

  testWidgets('toggle updates playingKey synchronously', (tester) async {
    final player = TonePlayer();
    await tester.pump();

    unawaited(player.toggle('C', 440.0));
    expect(player.isPlaying('C'), isTrue);
  });

  testWidgets(
    'toggling a different key switches playingKey synchronously, without waiting for the previous key\'s audio to finish loading',
    (tester) async {
      final player = TonePlayer();
      await tester.pump();

      unawaited(player.toggle('C', 440.0));
      unawaited(player.toggle('D', 293.66));

      expect(player.isPlaying('D'), isTrue);
      expect(player.isPlaying('C'), isFalse);
    },
  );

  testWidgets('toggling the same key again stops it synchronously (start then stop)', (
    tester,
  ) async {
    final player = TonePlayer();
    await tester.pump();

    unawaited(player.toggle('C', 440.0));
    expect(player.isPlaying('C'), isTrue);

    unawaited(player.toggle('C', 440.0));
    expect(player.playingKey, isNull);
  });

  testWidgets('rapid taps across several keys leave playingKey on the last one tapped', (
    tester,
  ) async {
    final player = TonePlayer();
    await tester.pump();

    unawaited(player.toggle('C', 261.63));
    unawaited(player.toggle('D', 293.66));
    unawaited(player.toggle('E', 329.63));

    expect(player.playingKey, 'E');
  });

  testWidgets('stop() clears playingKey synchronously', (tester) async {
    final player = TonePlayer();
    await tester.pump();

    unawaited(player.toggle('C', 440.0));
    unawaited(player.stop());

    expect(player.playingKey, isNull);
  });
}
