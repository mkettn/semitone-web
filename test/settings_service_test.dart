import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:semitone_web/models/scale_degree.dart';
import 'package:semitone_web/models/scale_presets.dart';
import 'package:semitone_web/models/tuning_scale.dart';
import 'package:semitone_web/services/settings_service.dart';

/// A minimal scale fixture for tests that don't care about actual note
/// content, just that a distinct TuningScale instance with a given name
/// exists.
TuningScale _fixture(String name) {
  return TuningScale(
    name: name,
    degrees: const [ScaleDegree(name: 'X', cents: 0)],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('seeds every bundled preset on first run, active on the chromatic one', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.create();
    final presets = await loadPresetScales();

    expect(settings.scales.map((s) => s.name), presets.map((p) => p.name));
    expect(settings.activeScale?.name, 'Chromatic');
  });

  test('supports adding, switching between, and deleting scales', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.create();
    final seededCount = settings.scales.length;

    final scale1 = _fixture('myscale1');
    final scale2 = _fixture('myscale2');
    settings.addScale(scale1);
    settings.addScale(scale2);

    expect(settings.scales.length, seededCount + 2);
    // Adding a scale makes it active.
    expect(settings.activeScale?.name, 'myscale2');

    settings.activeScaleId = scale1.id;
    expect(settings.activeScale?.name, 'myscale1');

    settings.deleteScale(scale1.id);
    expect(settings.scales.any((s) => s.id == scale1.id), isFalse);
    // Active id pointed at the deleted scale, so it falls back to the
    // first remaining one.
    expect(settings.activeScale, isNotNull);
    expect(settings.activeScale!.id, isNot(scale1.id));
  });

  test('deleteScale refuses to remove the last remaining scale', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.create();

    // Whittle down to a single scale.
    final scales = settings.scales;
    for (final scale in scales.skip(1)) {
      settings.deleteScale(scale.id);
    }
    expect(settings.scales, hasLength(1));

    final last = settings.scales.single;
    settings.deleteScale(last.id);
    expect(settings.scales, hasLength(1));
    expect(settings.scales.single.id, last.id);
  });

  test('activeScale falls back to the first saved scale if the active id is stale', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.create();

    settings.activeScaleId = 'not-a-real-id';
    expect(settings.activeScale, isNotNull);
    expect(settings.activeScale!.id, settings.scales.first.id);
  });

  test('resetToDefaults discards user scales and reloads the bundled presets', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.create();
    final presets = await loadPresetScales();

    settings.addScale(_fixture('my custom scale'));
    settings.deleteScale(settings.scales.first.id);
    expect(settings.scales.map((s) => s.name), isNot(presets.map((p) => p.name)));

    await settings.resetToDefaults();

    expect(settings.scales.map((s) => s.name), presets.map((p) => p.name));
    expect(settings.scales.any((s) => s.name == 'my custom scale'), isFalse);
    expect(settings.activeScale?.name, 'Chromatic');
  });

  test('micOffsetHz defaults to 0 and persists a set value', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.create();

    expect(settings.micOffsetHz, 0.0);

    settings.micOffsetHz = 2.0;
    expect(settings.micOffsetHz, 2.0);
  });
}
