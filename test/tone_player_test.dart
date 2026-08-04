import 'package:flutter_test/flutter_test.dart';

import 'package:semitone_web/services/tone_player.dart';

void main() {
  // TonePlayer's AudioPlayer registers itself with the platform plugin
  // channel asynchronously on construction; pumping lets that settle
  // before the test completes (see tuner_engine_test.dart for the same
  // pattern). Actual playback (toggle/stop) isn't exercised here — there's
  // no real audio plugin registered in the test environment, and it hangs
  // rather than throwing.
  testWidgets('starts with nothing playing', (tester) async {
    final player = TonePlayer();
    await tester.pump();

    expect(player.playingKey, isNull);
    expect(player.isPlaying(0), isFalse);
    expect(player.isPlaying('anything'), isFalse);
  });
}
