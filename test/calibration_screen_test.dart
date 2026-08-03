import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:semitone_web/screens/calibration_screen.dart';
import 'package:semitone_web/services/settings_service.dart';

void main() {
  testWidgets('renders the reference field and reflects the stored offset', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.create();

    await tester.pumpWidget(
      MaterialApp(home: CalibrationScreen(settings: settings)),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Reference tone (Hz)'), findsOneWidget);
    expect(find.text('Current offset: 0.00 Hz'), findsOneWidget);

    // No reading yet (no mic in the test environment), so there's nothing
    // to set an offset from.
    final setButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Set offset from current reading'),
    );
    expect(setButton.onPressed, isNull);

    // Nothing to reset yet either, since the offset is still 0.
    final resetButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Reset to 0 Hz'),
    );
    expect(resetButton.onPressed, isNull);

    settings.micOffsetHz = 2.5;
    await tester.pump();
    expect(find.text('Current offset: 2.50 Hz'), findsOneWidget);
  });
}
