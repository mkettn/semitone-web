import 'dart:convert';

import 'package:flutter/services.dart';

import 'tuning_scale.dart';

/// Directory of pre-configured scales, one `.json` file per scale (see
/// [TuningScale.toJson] for the shape). Declared as a whole-directory
/// asset in pubspec.yaml, so adding another preset is just dropping in
/// another file here — no code changes needed.
const _presetAssetDir = 'assets/scales/';

/// Loads every scale bundled under [_presetAssetDir], in filename order
/// (hence the `NN_` prefixes — that's what keeps Chromatic first). Each
/// call returns fresh [TuningScale] instances with newly generated ids.
Future<List<TuningScale>> loadPresetScales() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final paths = manifest
      .listAssets()
      .where((path) => path.startsWith(_presetAssetDir) && path.endsWith('.json'))
      .toList()
    ..sort();

  final scales = <TuningScale>[];
  for (final path in paths) {
    final raw = await rootBundle.loadString(path);
    scales.add(TuningScale.fromJson(jsonDecode(raw) as Map<String, dynamic>));
  }
  return scales;
}
