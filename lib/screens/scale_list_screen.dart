import 'package:flutter/material.dart';

import '../models/scale_presets.dart';
import '../models/tuning_scale.dart';
import '../services/settings_service.dart';
import '../theme/semitone_theme.dart';
import 'custom_scale_screen.dart';

/// Lists all of the user's saved custom scales (e.g. "myscale1",
/// "myscale2") and lets them switch which one the tuner uses, create new
/// ones, duplicate, rename (via the editor), or delete them.
class ScaleListScreen extends StatefulWidget {
  const ScaleListScreen({super.key, required this.settings});

  final SettingsService settings;

  @override
  State<ScaleListScreen> createState() => _ScaleListScreenState();
}

class _ScaleListScreenState extends State<ScaleListScreen> {
  Future<void> _createScale() async {
    final preset = await _promptForPreset(context);
    if (preset == null) return;
    if (!mounted) return;

    final name = await _promptForName(
      context,
      title: 'New scale',
      initial: preset.name == 'Chromatic'
          ? 'My scale ${widget.settings.customScales.length + 1}'
          : preset.name,
    );
    if (name == null || name.trim().isEmpty) return;

    final scale = preset.build().copyWith(name: name.trim());
    widget.settings.addScale(scale);
    setState(() {});
    if (!mounted) return;
    await _openEditor(scale.id);
  }

  Future<ScalePreset?> _promptForPreset(BuildContext context) {
    return showDialog<ScalePreset>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Start from'),
        children: [
          for (final preset in scalePresets)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(preset),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(preset.name),
                    Text(
                      preset.description,
                      style: const TextStyle(
                        color: SemitoneColors.grey4,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _duplicateScale(String id) async {
    widget.settings.duplicateScale(id);
    setState(() {});
  }

  Future<void> _deleteScale(TuningScale scale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete scale?'),
        content: Text('This will permanently delete "${scale.name}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.settings.deleteScale(scale.id);
      setState(() {});
    }
  }

  Future<void> _openEditor(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomScaleScreen(settings: widget.settings, scaleId: id),
      ),
    );
    setState(() {});
  }

  Future<String?> _promptForName(
    BuildContext context, {
    required String title,
    String initial = '',
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Scale name'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scales = widget.settings.customScales;
    final activeId = widget.settings.activeCustomScaleId ??
        (scales.isNotEmpty ? scales.first.id : null);

    return Scaffold(
      appBar: AppBar(title: const Text('My Scales')),
      body: scales.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No custom scales yet.\nTap + to create one, starting from the default chromatic scale.',
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
                  leading: IconButton(
                    icon: Icon(
                      isActive ? Icons.radio_button_checked : Icons.radio_button_off,
                    ),
                    color: isActive ? SemitoneColors.blue : SemitoneColors.grey4,
                    tooltip: 'Use this scale',
                    onPressed: () {
                      widget.settings.activeCustomScaleId = scale.id;
                      setState(() {});
                    },
                  ),
                  title: Text(scale.name),
                  subtitle: Text(
                    '${scale.degrees.length} tone heights'
                    '${isActive ? ' • active' : ''}',
                  ),
                  onTap: () => _openEditor(scale.id),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.content_copy),
                        color: SemitoneColors.grey4,
                        tooltip: 'Duplicate scale',
                        onPressed: () => _duplicateScale(scale.id),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: SemitoneColors.grey4,
                        tooltip: 'Delete scale',
                        onPressed: () => _deleteScale(scale),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createScale,
        tooltip: 'Create a new scale',
        child: const Icon(Icons.add),
      ),
    );
  }
}
