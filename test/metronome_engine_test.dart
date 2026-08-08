import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:semitone_web/services/click_player.dart';
import 'package:semitone_web/services/metronome_engine.dart';

/// Records clicks instead of making sound, so the beat timer can be
/// asserted on. The real [AudioPlayersClickPlayer] can't be used under
/// `flutter test`: `load()` would await a plugin that never answers, and
/// every line of `start()` past that await would be unreachable.
class FakeClickPlayer implements ClickPlayer {
  /// One entry per click: true for the accented downbeat.
  final List<bool> clicks = [];
  int loadCount = 0;
  int disposeCount = 0;
  Uint8List? strongBytes;
  Uint8List? weakBytes;

  @override
  Future<void> load({
    required Uint8List strong,
    required Uint8List weak,
  }) async {
    loadCount++;
    strongBytes = strong;
    weakBytes = weak;
  }

  @override
  void play({required bool strong}) => clicks.add(strong);

  @override
  void dispose() => disposeCount++;
}

void main() {
  // testWidgets rather than test: it runs the body inside FakeAsync, so
  // `tester.pump(duration)` advances Timer.periodic without real waiting.
  testWidgets('starts stopped at 120 bpm', (tester) async {
    final engine = MetronomeEngine(player: FakeClickPlayer());

    expect(engine.running, isFalse);
    expect(engine.bpm, 120);
    expect(engine.beatsPerBar, 4);
    expect(engine.currentBeat, 0);
  });

  testWidgets('start() clicks the downbeat immediately', (tester) async {
    final player = FakeClickPlayer();
    final engine = MetronomeEngine(player: player);

    await engine.start();

    expect(engine.running, isTrue);
    expect(player.loadCount, 1);
    // The first beat sounds right away rather than one interval later.
    expect(player.clicks, [true]);
    expect(engine.currentBeat, 1);

    engine.dispose();
  });

  testWidgets('accents the downbeat and cycles through the bar', (
    tester,
  ) async {
    final player = FakeClickPlayer();
    final engine = MetronomeEngine(player: player);
    engine.bpm = 120; // 500 ms per beat

    await engine.start();
    // Seven more beats: two full 4/4 bars including the opening downbeat.
    await tester.pump(const Duration(milliseconds: 3500));

    expect(player.clicks, [
      true,
      false,
      false,
      false,
      true,
      false,
      false,
      false,
    ]);
    expect(engine.currentBeat, 0);

    engine.dispose();
  });

  testWidgets('beat interval follows the tempo', (tester) async {
    final player = FakeClickPlayer();
    final engine = MetronomeEngine(player: player);
    engine.bpm = 60; // one beat per second

    await engine.start();
    expect(player.clicks.length, 1);

    await tester.pump(const Duration(milliseconds: 999));
    expect(player.clicks.length, 1, reason: 'no beat before the interval');

    await tester.pump(const Duration(milliseconds: 2));
    expect(player.clicks.length, 2, reason: 'beat lands at 1000 ms');

    engine.dispose();
  });

  testWidgets('changing tempo while running restarts the timer', (
    tester,
  ) async {
    final player = FakeClickPlayer();
    final engine = MetronomeEngine(player: player);
    engine.bpm = 60;

    await engine.start();
    await tester.pump(const Duration(milliseconds: 1000));
    expect(player.clicks.length, 2);

    // Doubling the tempo has to take effect now, not at the end of the
    // current (one-second) interval.
    engine.bpm = 240; // 250 ms per beat
    await tester.pump(const Duration(milliseconds: 1000));
    expect(player.clicks.length, 6);

    engine.dispose();
  });

  testWidgets('stop() halts the clicks and start() resumes from the top', (
    tester,
  ) async {
    final player = FakeClickPlayer();
    final engine = MetronomeEngine(player: player);
    engine.bpm = 120;

    await engine.start();
    await tester.pump(const Duration(milliseconds: 1000));
    final beforeStop = player.clicks.length;

    engine.stop();
    expect(engine.running, isFalse);
    await tester.pump(const Duration(seconds: 3));
    expect(player.clicks.length, beforeStop, reason: 'no clicks while stopped');

    await engine.start();
    expect(engine.running, isTrue);
    // Restarting begins a fresh bar on the accented beat.
    expect(player.clicks.last, isTrue);
    // The click sounds were prepared once, on first start.
    expect(player.loadCount, 1);

    engine.dispose();
  });

  testWidgets('start() while already running is a no-op', (tester) async {
    final player = FakeClickPlayer();
    final engine = MetronomeEngine(player: player);

    await engine.start();
    await engine.start();

    expect(player.clicks.length, 1);
    engine.dispose();
  });

  testWidgets('respects a shorter bar', (tester) async {
    final player = FakeClickPlayer();
    final engine = MetronomeEngine(player: player);
    engine.bpm = 120;
    engine.beatsPerBar = 3;

    await engine.start();
    await tester.pump(const Duration(milliseconds: 2500));

    expect(player.clicks, [true, false, false, true, false, false]);

    engine.dispose();
  });

  group('clamping', () {
    test('bpm clamps to the supported range', () {
      final engine = MetronomeEngine(player: FakeClickPlayer());

      engine.bpm = 5;
      expect(engine.bpm, MetronomeEngine.minBpm);

      engine.bpm = 5000;
      expect(engine.bpm, MetronomeEngine.maxBpm);

      engine.bpm = 90;
      expect(engine.bpm, 90);
    });

    test('beatsPerBar clamps to 1..12', () {
      final engine = MetronomeEngine(player: FakeClickPlayer());

      engine.beatsPerBar = 0;
      expect(engine.beatsPerBar, 1);

      engine.beatsPerBar = 99;
      expect(engine.beatsPerBar, 12);
    });

    test('setting bpm notifies listeners', () {
      final engine = MetronomeEngine(player: FakeClickPlayer());
      var notifications = 0;
      engine.addListener(() => notifications++);

      engine.bpm = 130;
      engine.beatsPerBar = 3;

      expect(notifications, 2);
    });
  });

  testWidgets('synthesizes two distinct clicks', (tester) async {
    final player = FakeClickPlayer();
    final engine = MetronomeEngine(player: player);

    await engine.start();

    // Both are WAV files, and the accented one is the longer/higher of the
    // two (60 ms at 1600 Hz vs 45 ms at 1000 Hz).
    expect(String.fromCharCodes(player.strongBytes!.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(player.weakBytes!.sublist(0, 4)), 'RIFF');
    expect(player.strongBytes!.length, greaterThan(player.weakBytes!.length));

    engine.dispose();
  });

  testWidgets('dispose() releases the player and cancels the timer', (
    tester,
  ) async {
    final player = FakeClickPlayer();
    final engine = MetronomeEngine(player: player);

    await engine.start();
    final beforeDispose = player.clicks.length;
    engine.dispose();

    expect(player.disposeCount, 1);
    await tester.pump(const Duration(seconds: 3));
    expect(player.clicks.length, beforeDispose);
  });
}
