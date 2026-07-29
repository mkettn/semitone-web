import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tuning_scale.dart';

/// Central app settings, mirroring the preferences exposed by the
/// original Semitone Android app (concert pitch, metronome "keep tick"),
/// plus the custom scale boundaries feature (multiple named scales, one
/// of them active).
class SettingsService extends ChangeNotifier {
  SettingsService(this._prefs) {
    _migrateLegacySingleScale();
  }

  static const _keyConcertA = 'concert_a';
  static const _keyKeepTick = 'keeptick';
  static const _keyUseCustomScale = 'use_custom_scale';
  static const _keyCustomScales = 'custom_scales';
  static const _keyActiveCustomScaleId = 'active_custom_scale_id';
  static const _keyLegacyCustomScale = 'custom_scale';

  final SharedPreferences _prefs;

  static Future<SettingsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService(prefs);
  }

  /// One-time migration from the earlier single-scale storage format.
  void _migrateLegacySingleScale() {
    final legacyRaw = _prefs.getString(_keyLegacyCustomScale);
    if (legacyRaw == null || _prefs.containsKey(_keyCustomScales)) return;
    try {
      final legacy = TuningScale.fromJsonString(legacyRaw);
      _writeScales([legacy]);
      _prefs.setString(_keyActiveCustomScaleId, legacy.id);
    } catch (_) {
      // Corrupt legacy data: fall through to the normal empty-list default.
    } finally {
      _prefs.remove(_keyLegacyCustomScale);
    }
  }

  int get concertA => _prefs.getInt(_keyConcertA) ?? 440;

  set concertA(int value) {
    _prefs.setInt(_keyConcertA, value);
    notifyListeners();
  }

  bool get keepTick => _prefs.getBool(_keyKeepTick) ?? false;

  set keepTick(bool value) {
    _prefs.setBool(_keyKeepTick, value);
    notifyListeners();
  }

  bool get useCustomScale => _prefs.getBool(_keyUseCustomScale) ?? false;

  set useCustomScale(bool value) {
    _prefs.setBool(_keyUseCustomScale, value);
    notifyListeners();
  }

  /// All scales the user has saved, in creation order.
  List<TuningScale> get customScales {
    final raw = _prefs.getStringList(_keyCustomScales);
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
      _keyCustomScales,
      scales.map((s) => s.toJsonString()).toList(),
    );
  }

  String? get activeCustomScaleId =>
      _prefs.getString(_keyActiveCustomScaleId);

  set activeCustomScaleId(String? id) {
    if (id == null) {
      _prefs.remove(_keyActiveCustomScaleId);
    } else {
      _prefs.setString(_keyActiveCustomScaleId, id);
    }
    notifyListeners();
  }

  /// The currently selected custom scale, or the first saved scale if none
  /// (or a stale one) is selected, or null if none exist yet.
  TuningScale? get activeCustomScale {
    final scales = customScales;
    if (scales.isEmpty) return null;
    final id = activeCustomScaleId;
    return scales.firstWhere(
      (s) => s.id == id,
      orElse: () => scales.first,
    );
  }

  /// Adds a new scale and makes it the active one.
  void addScale(TuningScale scale) {
    _writeScales([...customScales, scale]);
    _prefs.setString(_keyActiveCustomScaleId, scale.id);
    notifyListeners();
  }

  /// Replaces the scale with the same id (used for in-place edits).
  void updateScale(TuningScale scale) {
    final scales = customScales;
    final index = scales.indexWhere((s) => s.id == scale.id);
    if (index == -1) return;
    scales[index] = scale;
    _writeScales(scales);
    notifyListeners();
  }

  /// Duplicates a saved scale under a new id and makes the copy active.
  TuningScale duplicateScale(String id) {
    final source = customScales.firstWhere((s) => s.id == id);
    final copy = source.duplicate();
    addScale(copy);
    return copy;
  }

  void deleteScale(String id) {
    final scales = customScales..removeWhere((s) => s.id == id);
    _writeScales(scales);
    if (activeCustomScaleId == id) {
      _prefs.remove(_keyActiveCustomScaleId);
    }
    notifyListeners();
  }

  /// The scale actually used by the tuner: the active custom scale when
  /// enabled and non-empty, otherwise standard 12-tone equal temperament.
  TuningScale get activeScale {
    final active = activeCustomScale;
    if (useCustomScale && active != null && active.degrees.isNotEmpty) {
      return active;
    }
    return TuningScale.defaultTwelveTet();
  }
}
