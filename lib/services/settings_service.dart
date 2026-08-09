// Every _prefs.set*/.remove call below is deliberately unawaited: the
// shared_preferences plugin keeps a read-your-own-writes in-memory cache,
// so a getter called right after a setter (as every one of them is, via
// notifyListeners()) already sees the new value — the actual disk flush
// happens in the background and nothing here needs to wait on it.
// ignore_for_file: discarded_futures, unawaited_futures

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
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
  static const _keyMicOffsetHz = 'mic_offset_hz';
  static const _keyLanguageCode = 'language_code';

  final SharedPreferences _prefs;

  static Future<SettingsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsService._(prefs);
    await settings._seedDefaultScalesIfEmpty();
    return settings;
  }

  /// First run: seed the scale list with every bundled preset, active on
  /// the first one (Chromatic, by filename order — see
  /// [loadPresetScales]).
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

  /// Fixed correction, in Hz, subtracted from every raw pitch reading
  /// before it's matched against a scale — compensates for a microphone's
  /// ADC reporting a consistently sharp or flat frequency. Set via the
  /// calibration screen; zero (no correction) until then.
  double get micOffsetHz => _prefs.getDouble(_keyMicOffsetHz) ?? 0.0;

  set micOffsetHz(double value) {
    _prefs.setDouble(_keyMicOffsetHz, value);
    notifyListeners();
  }

  /// The UI language the user picked, as a [Locale] built from a saved
  /// language code — or null to follow the system's language (the
  /// default), letting Flutter's own locale resolution pick the best
  /// supported match.
  Locale? get locale {
    final code = _prefs.getString(_keyLanguageCode);
    if (code == null) return null;
    return Locale(code);
  }

  set locale(Locale? value) {
    if (value == null) {
      _prefs.remove(_keyLanguageCode);
    } else {
      _prefs.setString(_keyLanguageCode, value.languageCode);
    }
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
  /// to an empty placeholder scale (see [TuningScale.match] for how an
  /// empty scale is handled).
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

  /// Discards every saved scale — including the user's own — and reloads
  /// the bundled presets from scratch, active on the first one.
  Future<void> resetToDefaults() async {
    final defaults = await loadPresetScales();
    _writeScales(defaults);
    if (defaults.isNotEmpty) {
      _prefs.setString(_keyActiveScaleId, defaults.first.id);
    } else {
      _prefs.remove(_keyActiveScaleId);
    }
    notifyListeners();
  }
}
