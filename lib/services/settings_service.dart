import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/scale_presets.dart';
import '../models/tuning_scale.dart';

/// Central app settings: metronome "keep tick", and the tuner's scales.
///
/// There's no "standard" scale separate from user-defined ones — the
/// tuner always matches against whichever scale is active, out of a list
/// that starts out seeded with every bundled preset (see
/// [loadPresetScales]) and that the user can add to, edit, duplicate, or
/// remove from freely.
class SettingsService extends ChangeNotifier {
  SettingsService._(this._prefs);

  static const _keyKeepTick = 'keeptick';
  static const _keyScales = 'custom_scales';
  static const _keyActiveScaleId = 'active_custom_scale_id';
  static const _keyLegacyCustomScale = 'custom_scale';

  final SharedPreferences _prefs;

  static Future<SettingsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsService._(prefs);
    settings._migrateLegacySingleScale();
    await settings._seedDefaultScalesIfEmpty();
    return settings;
  }

  /// One-time migration from the single-scale storage format that
  /// predates saving multiple scales.
  void _migrateLegacySingleScale() {
    final legacyRaw = _prefs.getString(_keyLegacyCustomScale);
    if (legacyRaw == null || _prefs.containsKey(_keyScales)) return;
    try {
      final legacy = TuningScale.fromJsonString(legacyRaw);
      _writeScales([legacy]);
      _prefs.setString(_keyActiveScaleId, legacy.id);
    } catch (_) {
      // Corrupt legacy data: fall through to the normal seeding below.
    } finally {
      _prefs.remove(_keyLegacyCustomScale);
    }
  }

  /// First run (or the legacy migration above found nothing usable):
  /// seed the scale list with every bundled preset, active on the first
  /// one (Chromatic, by filename order — see [loadPresetScales]).
  Future<void> _seedDefaultScalesIfEmpty() async {
    if (_prefs.getStringList(_keyScales)?.isNotEmpty ?? false) return;
    final seeded = await loadPresetScales();
    if (seeded.isEmpty) return;
    _writeScales(seeded);
    _prefs.setString(_keyActiveScaleId, seeded.first.id);
  }

  bool get keepTick => _prefs.getBool(_keyKeepTick) ?? false;

  set keepTick(bool value) {
    _prefs.setBool(_keyKeepTick, value);
    notifyListeners();
  }

  /// All scales the user has saved (built-in presets and their own),
  /// in creation order.
  List<TuningScale> get scales {
    final raw = _prefs.getStringList(_keyScales);
    if (raw == null) return const [];
    return raw
        .map((s) {
          try {
            return TuningScale.fromJsonString(s);
          } catch (_) {
            return null;
          }
        })
        .whereType<TuningScale>()
        .toList();
  }

  void _writeScales(List<TuningScale> scales) {
    _prefs.setStringList(
      _keyScales,
      scales.map((s) => s.toJsonString()).toList(),
    );
  }

  String? get activeScaleId => _prefs.getString(_keyActiveScaleId);

  set activeScaleId(String? id) {
    if (id == null) {
      _prefs.remove(_keyActiveScaleId);
    } else {
      _prefs.setString(_keyActiveScaleId, id);
    }
    notifyListeners();
  }

  /// The scale the tuner matches detected pitches against: the selected
  /// scale, or the first saved one if none (or a stale one) is selected.
  /// Only null if [scales] is somehow empty — shouldn't happen once
  /// seeded, but callers that need a guaranteed instance should fall back
  /// to `TuningScale.defaultChromatic()`.
  TuningScale? get activeScale {
    final all = scales;
    if (all.isEmpty) return null;
    final id = activeScaleId;
    return all.firstWhere((s) => s.id == id, orElse: () => all.first);
  }

  /// Adds a new scale and makes it the active one.
  void addScale(TuningScale scale) {
    _writeScales([...scales, scale]);
    _prefs.setString(_keyActiveScaleId, scale.id);
    notifyListeners();
  }

  /// Replaces the scale with the same id (used for in-place edits).
  void updateScale(TuningScale scale) {
    final all = scales;
    final index = all.indexWhere((s) => s.id == scale.id);
    if (index == -1) return;
    all[index] = scale;
    _writeScales(all);
    notifyListeners();
  }

  /// Duplicates a saved scale under a new id and makes the copy active.
  TuningScale duplicateScale(String id) {
    final source = scales.firstWhere((s) => s.id == id);
    final copy = source.duplicate();
    addScale(copy);
    return copy;
  }

  /// Deletes a scale, unless it's the only one left — the tuner always
  /// needs at least one scale to match against.
  void deleteScale(String id) {
    final all = scales;
    if (all.length <= 1) return;
    all.removeWhere((s) => s.id == id);
    _writeScales(all);
    if (activeScaleId == id) {
      _prefs.setString(_keyActiveScaleId, all.first.id);
    }
    notifyListeners();
  }
}
