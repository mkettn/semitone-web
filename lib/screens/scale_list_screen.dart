import 'package:flutter/material.dart';

import '../models/scale_presets.dart';
import '../models/tuning_scale.dart';
import '../services/scale_io.dart';
import '../services/settings_service.dart';
import '../theme/semitone_theme.dart';
import 'custom_scale_screen.dart';

/// Lists every saved scale (built-in presets and the user's own), with
/// buttons to create, edit, copy, delete, export, or import scales — no
/// popups. Picking which scale is *active* happens from the main
/// screen's dropdown, not here.
class ScaleListScreen extends StatelessWidget {
  const ScaleListScreen({super.key, required this.settings});

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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final scales = settings.scales;
        final activeId = settings.activeScaleId ?? (scales.isNotEmpty ? scales.first.id : null);

        return Scaffold(
          appBar: AppBar(
            title: const Text('My Scales'),
            actions: [
              IconButton(
                icon: const Icon(Icons.file_upload_outlined),
                tooltip: 'Import a scale from file',
                onPressed: () => _importScale(context),
              ),
            ],
          ),
          body: scales.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No scales yet.\nTap + to create one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: SemitoneColors.grey4),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: scales.length,
                  itemBuilder: (context, index) {
                    final scale = scales[index];
                    final isActive = scale.id == activeId;
                    return ListTile(
                      title: Text(scale.name),
                      subtitle: Text(
                        '${scale.degrees.length} tone heights'
                        '${isActive ? ' • active' : ''}',
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
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _createScale(context),
            tooltip: 'Create a new scale',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
