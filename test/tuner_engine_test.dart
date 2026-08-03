import 'package:flutter_test/flutter_test.dart';

import 'package:semitone_web/services/tuner_engine.dart';

void main() {
  // TunerEngine's AudioRecorder registers itself with the platform plugin
  // channel asynchronously on construction; pumping lets that settle before
  // the test completes, instead of it throwing a MissingPluginException
  // after the fact (there's no real recording plugin registered in tests).
  testWidgets('calibrationOffsetHz defaults to 0', (tester) async {
    final engine = TunerEngine();
    await tester.pump();
    expect(engine.calibrationOffsetHz, 0.0);
  });

  testWidgets('calibrationOffsetHz is settable and read back as set', (
    tester,
  ) async {
    final engine = TunerEngine();
    await tester.pump();
    engine.calibrationOffsetHz = 2.0;
    expect(engine.calibrationOffsetHz, 2.0);
  });
}
