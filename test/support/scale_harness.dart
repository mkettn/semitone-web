import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:semitone_web/l10n/app_localizations.dart';
import 'package:semitone_web/models/scale_degree.dart';
import 'package:semitone_web/models/tuning_scale.dart';
import 'package:semitone_web/screens/custom_scale_screen.dart';
import 'package:semitone_web/screens/settings_screen.dart';
import 'package:semitone_web/services/scale_io.dart';
import 'package:semitone_web/services/settings_service.dart';

/// Shared setup for the per-feature scale fixtures (`scale_new_test.dart`,
/// `scale_edit_test.dart`, `scale_duplicate_test.dart`,
/// `scale_delete_test.dart`, `scale_import_export_test.dart`).
///
/// Not named `*_test.dart`, so `flutter test` treats it as a library
/// rather than a suite with no tests in it.

/// Storage seeded with the bundled presets, as a first run would be.
Future<SettingsService> seededSettings() async {
  SharedPreferences.setMockInitialValues({});
  return SettingsService.create();
}

/// Storage seeded with exactly [scales]. `SettingsService` only installs
/// the presets when nothing is stored, so a non-empty list suppresses
/// them — the way to get a known, short scale list.
Future<SettingsService> settingsWithScales(List<TuningScale> scales) async {
  SharedPreferences.setMockInitialValues({
    'custom_scales': [for (final scale in scales) scale.toJsonString()],
  });
  return SettingsService.create();
}

/// Mounts [SettingsScreen] on its own rather than through the app shell,
/// whose tuner tab wants a microphone.
Future<void> pumpSettings(
  WidgetTester tester,
  SettingsService settings, {
  ScaleFileIo? fileIo,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SettingsScreen(
        settings: settings,
        fileIo: fileIo ?? defaultScaleFileIo,
      ),
    ),
  );
  await tester.pump();
}

/// Seeds storage with [scale] as the only saved scale and mounts its
/// editor.
///
/// Uses a taller-than-default surface: the editor's page is one lazily
/// built [ListView], and at the standard 800px test height the cake chart
/// and the scale-level fields push all but the first degree row out of the
/// viewport — where it isn't merely invisible but never mounted, so
/// finders don't see it and taps land on nothing.
Future<SettingsService> pumpEditor(
  WidgetTester tester,
  TuningScale scale,
) async {
  final settings = await settingsWithScales([scale]);
  await pumpEditorFor(tester, settings, scale.id);
  return settings;
}

/// Mounts the editor against existing [settings], rather than seeding
/// fresh storage the way [pumpEditor] does — for reopening a scale after
/// it's been edited.
Future<void> pumpEditorFor(
  WidgetTester tester,
  SettingsService settings,
  String scaleId,
) async {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CustomScaleScreen(settings: settings, scaleId: scaleId),
    ),
  );
  await tester.pump();
}

/// A deliberately small scale, so every degree row fits on screen and row
/// indices stay predictable — unlike the 12-degree Chromatic preset.
TuningScale threeToneScale() => TuningScale(
  name: 'Triad',
  degrees: const [
    ScaleDegree(name: 'C', cents: 0),
    ScaleDegree(name: 'E', cents: 400),
    ScaleDegree(name: 'G', cents: 700),
  ],
);

/// The scale as it now stands in storage — the editor persists every edit
/// immediately, so this is what assertions look at.
TuningScale saved(SettingsService settings, String id) =>
    settings.scales.firstWhere((s) => s.id == id);

/// The cents of the degree named [name], for asserting on a scale whose
/// degrees may have re-sorted since the edit.
double centsOf(SettingsService settings, String id, String name) =>
    saved(settings, id).degrees.firstWhere((d) => d.name == name).cents;

/// A degree list flattened to `name@cents`, for comparing two scales'
/// contents without depending on `ScaleDegree` equality.
Iterable<String> degreeSignature(TuningScale scale) =>
    scale.degrees.map((d) => '${d.name}@${d.cents}');

// The editor's text fields in tree order: scale name, base frequency,
// root octave, then two per degree row (name, then cents). Indices rather
// than keys, since nothing in the widget tree distinguishes them; adding
// keys would make this sturdier and is worth doing next time the screen
// is open anyway.
Finder degreeNameField(int row) => find.byType(TextField).at(3 + row * 2);
Finder degreeCentsField(int row) => find.byType(TextField).at(4 + row * 2);

/// Stands in for the file picker and file saver, so import and export can
/// be driven without a real dialog. Records the last save, and hands out
/// whatever [pickResult] is set to.
class FakeScaleFileIo implements ScaleFileIo {
  /// What the picker returns. Null means the user cancelled.
  PickedScaleFile? pickResult;

  /// Makes [save] fail, standing in for a write the platform rejects.
  bool throwOnSave = false;

  String? savedName;
  Uint8List? savedBytes;
  int saveCount = 0;
  int pickCount = 0;

  /// Arms the picker with a file containing [text].
  void willPickText(String text) =>
      pickResult = PickedScaleFile(Uint8List.fromList(utf8.encode(text)));

  /// Arms the picker with whatever [save] last wrote.
  void willPickLastSaved() => pickResult = PickedScaleFile(savedBytes);

  @override
  Future<void> save({required String name, required Uint8List bytes}) async {
    saveCount++;
    if (throwOnSave) throw StateError('destination not writable');
    savedName = name;
    savedBytes = bytes;
  }

  @override
  Future<PickedScaleFile?> pickJson() async {
    pickCount++;
    return pickResult;
  }
}
