import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:semitone_web/models/tuning_scale.dart';
import 'package:semitone_web/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('supports saving, switching between, and deleting multiple scales', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.create();

    expect(settings.customScales, isEmpty);
    expect(settings.activeCustomScale, isNull);

    final scale1 = TuningScale.defaultChromatic().copyWith(name: 'myscale1');
    final scale2 = TuningScale.defaultChromatic().copyWith(name: 'myscale2');
    settings.addScale(scale1);
    settings.addScale(scale2);

    expect(settings.customScales.map((s) => s.name), ['myscale1', 'myscale2']);
    // Adding a scale makes it active.
    expect(settings.activeCustomScale?.name, 'myscale2');

    settings.activeCustomScaleId = scale1.id;
    expect(settings.activeCustomScale?.name, 'myscale1');

    settings.deleteScale(scale1.id);
    expect(settings.customScales.map((s) => s.name), ['myscale2']);
    // Active id pointed at the deleted scale, so it falls back to the
    // remaining one.
    expect(settings.activeCustomScale?.name, 'myscale2');
  });

  test('migrates a legacy single custom_scale entry into the new list', () async {
    final legacy = TuningScale.defaultChromatic().copyWith(name: 'old scale');
    SharedPreferences.setMockInitialValues({
      'custom_scale': legacy.toJsonString(),
    });

    final settings = await SettingsService.create();

    expect(settings.customScales, hasLength(1));
    expect(settings.customScales.single.name, 'old scale');
    expect(settings.activeCustomScale?.name, 'old scale');
  });

  test('activeScale falls back to 12-TET when custom scales are off or empty', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.create();

    expect(settings.activeScale.name, '12-tone equal temperament');

    settings.addScale(TuningScale.defaultChromatic().copyWith(name: 'mine'));
    settings.useCustomScale = true;
    expect(settings.activeScale.name, 'mine');

    settings.useCustomScale = false;
    expect(settings.activeScale.name, '12-tone equal temperament');
  });

  test('activeScale base frequency: global concertA for the default scale, '
      'per-scale for custom scales', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.create();

    settings.concertA = 442;
    expect(settings.activeScale.baseFrequency, 442);

    final custom = TuningScale.defaultChromatic()
        .copyWith(name: 'mine', baseFrequency: 256);
    settings.addScale(custom);
    settings.useCustomScale = true;
    expect(settings.activeScale.baseFrequency, 256);

    // Changing the global concert pitch doesn't affect the custom scale's
    // own base frequency.
    settings.concertA = 445;
    expect(settings.activeScale.baseFrequency, 256);
  });
}
