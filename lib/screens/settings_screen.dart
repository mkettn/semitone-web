import 'package:flutter/material.dart';

import '../models/scale_presets.dart';
import '../models/tuning_scale.dart';
import '../services/scale_io.dart';
import '../services/settings_service.dart';
import '../theme/semitone_theme.dart';
import 'custom_scale_screen.dart';

/// Settings, including scale management (create/edit/copy/delete/
/// export/import) embedded directly here rather than on a separate
/// screen. Picking which scale is *active* still happens from the main
/// screen's title dropdown, not here. The whole page is one ListView, so
/// however many scales are saved, it just scrolls — it never overflows.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});

  final SettingsService settings;

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
    final scale = template.copyWith(name: 'New scale ${settings.scales.length + 1}');
    settings.addScale(scale);
    if (context.mounted) await _openEditor(context, scale.id);
  }

  Future<void> _copyScale(BuildContext context, TuningScale scale) async {
    final copy = settings.duplicateScale(scale.id);
    if (context.mounted) await _openEditor(context, copy.id);
  }

  void _deleteScale(BuildContext context, TuningScale scale) {
    if (settings.scales.length <= 1) {
      _showMessage(context, "Can't delete the last scale.");
      return;
    }
    settings.deleteScale(scale.id);
    _showMessage(context, 'Deleted "${scale.name}".');
  }

  Future<void> _exportScale(BuildContext context, TuningScale scale) async {
    try {
      await exportScale(scale);
    } catch (e) {
      if (context.mounted) _showMessage(context, 'Could not export: $e');
    }
  }

  Future<void> _importScale(BuildContext context) async {
    try {
      final imported = await importScale();
      if (imported == null) return; // user cancelled the picker
      settings.addScale(imported);
      if (context.mounted) _showMessage(context, 'Imported "${imported.name}".');
    } on ScaleIoException catch (e) {
      if (context.mounted) _showMessage(context, e.message);
    }
  }

  void _showMessage(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _resetToDefaults(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset settings?'),
        content: const Text(
          'This replaces every saved scale — including your own — with '
          'the bundled presets. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await settings.resetToDefaults();
    if (context.mounted) _showMessage(context, 'Settings reset to defaults.');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final scales = settings.scales;
        final activeId = settings.activeScaleId ?? (scales.isNotEmpty ? scales.first.id : null);

        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            children: [
              _SectionHeader(
                'Scales',
                trailing: IconButton(
                  icon: const Icon(Icons.file_upload_outlined),
                  color: SemitoneColors.grey4,
                  tooltip: 'Import a scale from file',
                  onPressed: () => _importScale(context),
                ),
              ),
              if (scales.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'No scales yet.',
                    style: TextStyle(color: SemitoneColors.grey4),
                  ),
                )
              else
                for (final scale in scales)
                  ListTile(
                    title: Text(scale.name),
                    subtitle: Text(
                      '${scale.degrees.length} tone heights'
                      '${scale.id == activeId ? ' • active' : ''}',
                    ),
                    onTap: () => _openEditor(context, scale.id),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          color: SemitoneColors.grey4,
                          tooltip: 'Edit scale',
                          onPressed: () => _openEditor(context, scale.id),
                        ),
                        IconButton(
                          icon: const Icon(Icons.file_download_outlined),
                          color: SemitoneColors.grey4,
                          tooltip: 'Export scale',
                          onPressed: () => _exportScale(context, scale),
                        ),
                        IconButton(
                          icon: const Icon(Icons.content_copy),
                          color: SemitoneColors.grey4,
                          tooltip: 'Copy scale',
                          onPressed: () => _copyScale(context, scale),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: SemitoneColors.grey4,
                          tooltip: 'Delete scale',
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
                  label: const Text('New scale'),
                ),
              ),
              const _SectionHeader('Metronome'),
              SwitchListTile(
                title: const Text('Keep tick'),
                subtitle: const Text('Keep the metronome running between tabs'),
                value: settings.keepTick,
                onChanged: (v) => settings.keepTick = v,
              ),
              const _SectionHeader('About'),
              const ListTile(
                title: Text('Semitone Web'),
                subtitle: Text(
                  'A Flutter tuner & metronome, in the spirit of the '
                  'original Semitone app.',
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: OutlinedButton.icon(
                  onPressed: () => _resetToDefaults(context),
                  icon: const Icon(Icons.restore),
                  label: const Text('Reset settings to defaults'),
                ),
              ),
            ],
          ),
        );
      },
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
