import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tuning_scale.dart';

/// Central app settings, mirroring the preferences exposed by the
/// original Semitone Android app (concert pitch, metronome "keep tick"),
/// plus the new custom scale boundaries feature.
class SettingsService extends ChangeNotifier {
  SettingsService(this._prefs);

  static const _keyConcertA = 'concert_a';
  static const _keyKeepTick = 'keeptick';
  static const _keyUseCustomScale = 'use_custom_scale';
  static const _keyCustomScale = 'custom_scale';

  final SharedPreferences _prefs;

  static Future<SettingsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService(prefs);
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

  /// The user-defined tuning scale (may be empty/default until edited).
  TuningScale get customScale {
    final raw = _prefs.getString(_keyCustomScale);
    if (raw == null) return _defaultCustomScale();
    try {
      return TuningScale.fromJsonString(raw);
    } catch (_) {
      return _defaultCustomScale();
    }
  }

  set customScale(TuningScale value) {
    _prefs.setString(_keyCustomScale, value.toJsonString());
    notifyListeners();
  }

  /// The scale actually used by the tuner: the custom scale when enabled
  /// and non-empty, otherwise standard 12-tone equal temperament.
  TuningScale get activeScale {
    if (useCustomScale && customScale.degrees.isNotEmpty) {
      return customScale;
    }
    return TuningScale.defaultTwelveTet();
  }

  TuningScale _defaultCustomScale() => TuningScale.defaultDiatonic();
}
