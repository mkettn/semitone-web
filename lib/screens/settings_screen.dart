import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/scale_presets.dart';
import '../models/tuning_scale.dart';
import '../services/scale_io.dart';
import '../services/settings_service.dart';
import '../theme/semitone_theme.dart';
import 'calibration_screen.dart';
import 'custom_scale_screen.dart';

/// Settings, including scale management (create/edit/copy/delete/
/// export/import) embedded directly here rather than on a separate
/// screen. Picking which scale is *active* still happens from the main
/// screen's title dropdown, not here. The whole page is one ListView, so
/// however many scales are saved, it just scrolls — it never overflows.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    this.fileIo = defaultScaleFileIo,
  });

  final SettingsService settings;

  /// How importing and exporting reach the filesystem. Injectable so the
  /// import/export flows can be tested without a real file picker (see
  /// [ScaleFileIo]); the default talks to the actual platform plugins.
  final ScaleFileIo fileIo;

  Future<void> _openEditor(BuildContext context, String scaleId) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomScaleScreen(settings: settings, scaleId: scaleId),
      ),
    );
  }

  Future<void> _createScale(BuildContext context) async {
    final presets = await loadPresetScales();
    final template = presets.firstWhere(
      (s) => s.name == 'Chromatic',
      orElse: TuningScale.empty,
    );
    final scale = template.copyWith(
      name: 'New scale ${settings.scales.length + 1}',
    );
    settings.addScale(scale);
    if (context.mounted) await _openEditor(context, scale.id);
  }

  Future<void> _copyScale(BuildContext context, TuningScale scale) async {
    final copy = settings.duplicateScale(scale.id);
    if (context.mounted) await _openEditor(context, copy.id);
  }

  void _deleteScale(BuildContext context, TuningScale scale) {
    final l10n = AppLocalizations.of(context)!;
    if (settings.scales.length <= 1) {
      _showMessage(context, l10n.cantDeleteLastScale);
      return;
    }
    settings.deleteScale(scale.id);
    _showMessage(context, l10n.deletedScaleMessage(scale.name));
  }

  Future<void> _exportScale(BuildContext context, TuningScale scale) async {
    try {
      await exportScale(scale, io: fileIo);
    } catch (e) {
      if (context.mounted) {
        _showMessage(
          context,
          AppLocalizations.of(context)!.exportFailedMessage('$e'),
        );
      }
    }
  }

  Future<void> _importScale(BuildContext context) async {
    try {
      final imported = await importScale(io: fileIo);
      if (imported == null) return; // user cancelled the picker

      // Importing adds a copy rather than replacing anything, so a file
      // whose name is already in the list would otherwise produce two
      // identically labelled rows.
      final named = imported.copyWith(
        name: uniqueScaleName(
          imported.name,
          settings.scales.map((s) => s.name),
        ),
      );
      settings.addScale(named);
      if (context.mounted) {
        // Reports the name it was actually saved under, so a rename is
        // visible rather than silent.
        _showMessage(
          context,
          AppLocalizations.of(context)!.importedScaleMessage(named.name),
        );
      }
    } on ScaleIoException catch (e) {
      if (context.mounted) _showMessage(context, e.message);
    }
  }

  void _showMessage(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _resetToDefaults(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.resetDialogTitle),
        content: Text(l10n.resetDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.resetButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await settings.resetToDefaults();
    if (context.mounted) _showMessage(context, l10n.settingsResetMessage);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        final scales = settings.scales;
        final activeId =
            settings.activeScaleId ??
            (scales.isNotEmpty ? scales.first.id : null);

        return Scaffold(
          appBar: AppBar(title: Text(l10n.settingsTitle)),
          body: ListView(
            children: [
              _SectionHeader(
                l10n.scalesSectionHeader,
                trailing: IconButton(
                  icon: const Icon(Icons.file_upload_outlined),
                  color: SemitoneColors.grey4,
                  tooltip: l10n.importScaleTooltip,
                  onPressed: () => _importScale(context),
                ),
              ),
              if (scales.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    l10n.noScalesYet,
                    style: const TextStyle(color: SemitoneColors.grey4),
                  ),
                )
              else
                for (final scale in scales)
                  ListTile(
                    title: Text(scale.name),
                    subtitle: Text(
                      l10n.toneHeightsCount(scale.degrees.length) +
                          (scale.id == activeId ? l10n.activeScaleSuffix : ''),
                    ),
                    onTap: () => _openEditor(context, scale.id),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          color: SemitoneColors.grey4,
                          tooltip: l10n.editScaleTooltip,
                          onPressed: () => _openEditor(context, scale.id),
                        ),
                        IconButton(
                          icon: const Icon(Icons.file_download_outlined),
                          color: SemitoneColors.grey4,
                          tooltip: l10n.exportScaleTooltip,
                          onPressed: () => _exportScale(context, scale),
                        ),
                        IconButton(
                          icon: const Icon(Icons.content_copy),
                          color: SemitoneColors.grey4,
                          tooltip: l10n.copyScaleTooltip,
                          onPressed: () => _copyScale(context, scale),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: SemitoneColors.grey4,
                          tooltip: l10n.deleteScaleTooltip,
                          onPressed: () => _deleteScale(context, scale),
                        ),
                      ],
                    ),
                  ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: OutlinedButton.icon(
                  onPressed: () => _createScale(context),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.newScaleButton),
                ),
              ),
              _SectionHeader(l10n.metronomeSectionHeader),
              SwitchListTile(
                title: Text(l10n.keepTickTitle),
                subtitle: Text(l10n.keepTickSubtitle),
                value: settings.keepTick,
                onChanged: (v) => settings.keepTick = v,
              ),
              _SectionHeader(l10n.languageSectionHeader),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: _LanguageDropdown(settings: settings),
              ),
              _SectionHeader(l10n.advancedSectionHeader),
              ListTile(
                title: Text(l10n.micCalibrationTitle),
                subtitle: Text(l10n.micCalibrationSubtitle),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CalibrationScreen(settings: settings),
                  ),
                ),
              ),
              _SectionHeader(l10n.aboutSectionHeader),
              ListTile(
                title: Text(l10n.appTitle),
                subtitle: Text(l10n.appDescription),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: OutlinedButton.icon(
                  onPressed: () => _resetToDefaults(context),
                  icon: const Icon(Icons.restore),
                  label: Text(l10n.resetSettingsButton),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Each supported locale's own name for itself (e.g. "Deutsch" for German),
/// read from that locale's own ARB file (`languageName` key) rather than
/// hardcoded here — so a new language is just another ARB file away, with
/// nothing in Dart code to update. Computed once, synchronously: the
/// generated delegate's `load()` resolves via a [SynchronousFuture] (there's
/// no real I/O — the translations are compiled in), whose `then()` callback
/// runs immediately rather than being deferred to a microtask, and the set
/// of supported locales is fixed at build time.
final Map<String, String> _languageNamesByCode = {
  for (final locale in AppLocalizations.supportedLocales)
    locale.languageCode: _loadLanguageNameSync(locale),
};

String _loadLanguageNameSync(Locale locale) {
  String? name;
  AppLocalizations.delegate
      .load(locale)
      .then((l10n) => name = l10n.languageName);
  return name!;
}

/// Picks the UI language: "System default" (null, the default — Flutter
/// resolves the best supported match from the device's own locale) or one
/// of the languages the app ships translations for.
class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown({required this.settings});

  final SettingsService settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final current = settings.locale?.languageCode;

    return DropdownButtonHideUnderline(
      child: DropdownButton<String?>(
        value: current,
        isExpanded: true,
        dropdownColor: SemitoneColors.grey2,
        iconEnabledColor: SemitoneColors.white,
        style: const TextStyle(color: SemitoneColors.white, fontSize: 16),
        items: [
          DropdownMenuItem(
            value: null,
            child: Text(l10n.languageSystemDefault),
          ),
          for (final entry in _languageNamesByCode.entries)
            DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        ],
        onChanged: (code) =>
            settings.locale = code == null ? null : Locale(code),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: SemitoneColors.blue,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
