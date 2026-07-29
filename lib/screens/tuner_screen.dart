import 'package:flutter/material.dart';

import '../models/tuning_scale.dart';
import '../services/scale_io.dart';
import '../services/settings_service.dart';
import '../services/tuner_engine.dart';
import '../theme/semitone_theme.dart';
import '../widgets/cent_error_bar.dart';
import 'custom_scale_screen.dart';

class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key, required this.settings});

  final SettingsService settings;

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> {
  final _engine = TunerEngine();
  ScaleMatch? _match;
  bool _hasPermission = true;
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onSettingsChanged);
    _init();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _init() async {
    _hasPermission = await _engine.hasPermission();
    if (_hasPermission) {
      _engine.readings.listen(_onReading);
      await _engine.start();
    }
    if (mounted) setState(() {});
  }

  void _onReading(PitchReading reading) {
    final scale = widget.settings.activeScale ?? TuningScale.defaultChromatic();
    final match = scale.matchFrequency(reading.frequency);
    if (mounted) setState(() => _match = match);
  }

  Future<void> _requestPermission() async {
    setState(() => _requested = true);
    await _engine.start();
    _hasPermission = await _engine.hasPermission();
    if (_hasPermission) {
      _engine.readings.listen(_onReading);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettingsChanged);
    _engine.dispose();
    super.dispose();
  }

  Future<void> _openEditor(String scaleId) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomScaleScreen(settings: widget.settings, scaleId: scaleId),
      ),
    );
  }

  Future<void> _createScale() async {
    final scale = TuningScale.defaultChromatic()
        .copyWith(name: 'New scale ${widget.settings.scales.length + 1}');
    widget.settings.addScale(scale);
    await _openEditor(scale.id);
  }

  Future<void> _copyScale(TuningScale current) async {
    final copy = widget.settings.duplicateScale(current.id);
    await _openEditor(copy.id);
  }

  void _deleteScale(TuningScale current) {
    if (widget.settings.scales.length <= 1) {
      _showMessage("Can't delete the last scale.");
      return;
    }
    widget.settings.deleteScale(current.id);
    _showMessage('Deleted "${current.name}".');
  }

  Future<void> _exportScale(TuningScale current) async {
    try {
      await exportScale(current);
    } catch (e) {
      _showMessage('Could not export: $e');
    }
  }

  Future<void> _importScale() async {
    try {
      final imported = await importScale();
      if (imported == null) return; // user cancelled the picker
      widget.settings.addScale(imported);
      _showMessage('Imported "${imported.name}".');
    } on ScaleIoException catch (e) {
      _showMessage(e.message);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission) {
      return Center(
        child: TextButton(
          onPressed: _requested ? null : _requestPermission,
          child: const Text(
            'Tap to grant microphone permission',
            style: TextStyle(color: SemitoneColors.grey4, fontSize: 14),
          ),
        ),
      );
    }

    if (_engine.captureFailed) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No audio input device is available on this system.',
            textAlign: TextAlign.center,
            style: TextStyle(color: SemitoneColors.grey4, fontSize: 14),
          ),
        ),
      );
    }

    final scales = widget.settings.scales;
    final activeScale = widget.settings.activeScale ?? TuningScale.defaultChromatic();
    final match = _match;

    return Column(
      children: [
        _ScaleSwitcherBar(
          scales: scales,
          activeScale: activeScale,
          onSelect: (id) => widget.settings.activeScaleId = id,
          onEdit: () => _openEditor(activeScale.id),
          onNew: _createScale,
          onCopy: () => _copyScale(activeScale),
          onDelete: () => _deleteScale(activeScale),
          onExport: () => _exportScale(activeScale),
          onImport: _importScale,
        ),
        CentErrorBar(errorCents: match?.errorCents ?? 0),
        Expanded(
          child: Center(
            child: Text(
              match == null ? '--' : '${match.degreeName}${match.octave}',
              style: const TextStyle(
                color: SemitoneColors.white,
                fontSize: 96,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Scale switcher for the tuner: a dropdown to pick which saved scale is
/// active, plus buttons to edit it, create a new one, copy it, delete it,
/// or export/import a scale file — all directly on-screen, no extra
/// screens or popups.
class _ScaleSwitcherBar extends StatelessWidget {
  const _ScaleSwitcherBar({
    required this.scales,
    required this.activeScale,
    required this.onSelect,
    required this.onEdit,
    required this.onNew,
    required this.onCopy,
    required this.onDelete,
    required this.onExport,
    required this.onImport,
  });

  final List<TuningScale> scales;
  final TuningScale activeScale;
  final ValueChanged<String> onSelect;
  final VoidCallback onEdit;
  final VoidCallback onNew;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final VoidCallback onExport;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    // activeScale might not (yet) be in `scales` right after a settings
    // change is still propagating; fall back to just showing its name.
    final dropdownValue =
        scales.any((s) => s.id == activeScale.id) ? activeScale.id : null;

    return Container(
      color: SemitoneColors.grey1,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: dropdownValue,
                    isExpanded: true,
                    dropdownColor: SemitoneColors.grey2,
                    hint: Text(activeScale.name),
                    style: const TextStyle(color: SemitoneColors.white),
                    items: [
                      for (final scale in scales)
                        DropdownMenuItem(value: scale.id, child: Text(scale.name)),
                    ],
                    onChanged: (id) {
                      if (id != null) onSelect(id);
                    },
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                color: SemitoneColors.grey4,
                tooltip: 'Edit "${activeScale.name}"',
                onPressed: onEdit,
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            children: [
              _ActionButton(icon: Icons.add, label: 'New', onPressed: onNew),
              _ActionButton(icon: Icons.content_copy, label: 'Copy', onPressed: onCopy),
              _ActionButton(icon: Icons.delete_outline, label: 'Delete', onPressed: onDelete),
              _ActionButton(icon: Icons.file_download_outlined, label: 'Export', onPressed: onExport),
              _ActionButton(icon: Icons.file_upload_outlined, label: 'Import', onPressed: onImport),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: SemitoneColors.grey4),
      label: Text(label, style: const TextStyle(color: SemitoneColors.grey4, fontSize: 12)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
