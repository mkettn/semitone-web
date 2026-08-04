import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/scale_degree.dart';
import '../models/scale_presets.dart';
import '../models/tuning_scale.dart';
import '../services/settings_service.dart';
import '../services/tone_player.dart';
import '../theme/semitone_theme.dart';
import '../widgets/scale_cake_chart.dart';

/// Editor for one saved scale's tone-height boundaries (name + position
/// in cents within an octave). Reached from the tuner tab's scale
/// switcher, either to edit the active scale or right after creating or
/// duplicating one.
///
/// The octave is visualized as a "cake": each tone owns a wedge running
/// from the midpoint with its previous neighbour to the midpoint with its
/// next one. Starting from the default chromatic scale (C, C#, D, ... A,
/// A#, H — German naming, H = B), a tone can be duplicated ("copy") to
/// split its wedge in two, and then repositioned to redraw where the
/// octave gets split.
///
/// Each scale has its own base frequency (the pitch of its root tone,
/// marked with a ★) rather than sharing one global concert pitch — useful
/// both for having several scales tuned to different references, and for
/// scales with no fixed concert pitch at all (e.g. Byzantine chant, whose
/// base note can be set to whatever the *vasi* happens to be).
class CustomScaleScreen extends StatefulWidget {
  const CustomScaleScreen({
    super.key,
    required this.settings,
    required this.scaleId,
  });

  final SettingsService settings;

  /// Id of the saved scale (from [SettingsService.scales]) being
  /// edited.
  final String scaleId;

  @override
  State<CustomScaleScreen> createState() => _CustomScaleScreenState();
}

class _CustomScaleScreenState extends State<CustomScaleScreen> {
  late TuningScale _scale;
  late TextEditingController _nameController;
  late TextEditingController _rootOctaveController;
  late TextEditingController _baseFrequencyController;
  final _tonePlayer = TonePlayer();
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _scale = widget.settings.scales.firstWhere(
      (s) => s.id == widget.scaleId,
      orElse: TuningScale.empty,
    );
    _nameController = TextEditingController(text: _scale.name);
    _rootOctaveController =
        TextEditingController(text: _scale.rootOctave.toString());
    _baseFrequencyController =
        TextEditingController(text: _formatHz(_scale.baseFrequency));
    _tonePlayer.addListener(_onTonePlayerChanged);
  }

  void _onTonePlayerChanged() => setState(() {});

  String _formatHz(double hz) =>
      hz == hz.roundToDouble() ? hz.toStringAsFixed(0) : hz.toStringAsFixed(2);

  @override
  void dispose() {
    _nameController.dispose();
    _rootOctaveController.dispose();
    _baseFrequencyController.dispose();
    _tonePlayer.removeListener(_onTonePlayerChanged);
    _tonePlayer.dispose();
    super.dispose();
  }

  void _persist() {
    widget.settings.updateScale(_scale);
  }

  void _addDegree() {
    _tonePlayer.stop();
    final degrees = [
      ..._scale.degrees,
      const ScaleDegree(name: 'New', cents: 0),
    ];
    setState(() {
      _scale = _scale.copyWith(degrees: degrees);
    });
    _persist();
  }

  /// Duplicates a tone and places the copy at the midpoint of its current
  /// wedge and the next tone's, splitting that slice of the cake in two.
  /// The user can then drag either copy's boundary to redraw the split.
  void _duplicateDegree(int index) {
    _tonePlayer.stop();
    final degrees = _scale.degrees;
    final n = degrees.length;
    final current = degrees[index];
    final next = degrees[(index + 1) % n];
    final nextCents = next.cents <= current.cents ? next.cents + 1200 : next.cents;
    final midpoint = (current.cents + nextCents) / 2 % 1200;

    final updated = [...degrees, ScaleDegree(name: '${current.name} copy', cents: midpoint)];
    setState(() {
      _scale = _scale.copyWith(degrees: updated);
      _selectedIndex = null;
    });
    _persist();
  }

  void _removeDegree(int index) {
    _tonePlayer.stop();
    final degrees = [..._scale.degrees]..removeAt(index);
    final newRoot = _scale.rootIndex >= degrees.length
        ? (degrees.isEmpty ? 0 : degrees.length - 1)
        : _scale.rootIndex;
    setState(() {
      _scale = _scale.copyWith(degrees: degrees, rootIndex: newRoot);
      _selectedIndex = null;
    });
    _persist();
  }

  void _updateDegree(int index, ScaleDegree updated) {
    // The row's pitch may have just changed — stop rather than keep
    // playing a now-stale frequency.
    if (_tonePlayer.isPlaying(index)) _tonePlayer.stop();
    final degrees = [..._scale.degrees];
    degrees[index] = updated;
    setState(() {
      _scale = _scale.copyWith(degrees: degrees);
    });
    _persist();
  }

  void _setRoot(int index) {
    _tonePlayer.stop();
    setState(() {
      _scale = _scale.copyWith(rootIndex: index);
    });
    _persist();
  }

  Future<void> _resetToDefault() async {
    _tonePlayer.stop();
    final presets = await loadPresetScales();
    final def = presets.firstWhere(
      (s) => s.name == 'Chromatic',
      orElse: TuningScale.empty,
    );
    if (!mounted || def.degrees.isEmpty) return;
    setState(() {
      _scale = _scale.copyWith(
        degrees: def.degrees,
        rootIndex: def.rootIndex,
        rootOctave: def.rootOctave,
      );
      _rootOctaveController.text = _scale.rootOctave.toString();
      _selectedIndex = null;
    });
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final degrees = _scale.degrees;

    return Scaffold(
      appBar: AppBar(
        title: Text(_scale.name.isEmpty ? l10n.editScaleFallbackTitle : _scale.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: l10n.resetToDefaultChromaticTooltip,
            onPressed: _resetToDefault,
          ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.scaleNameLabel,
                isDense: true,
              ),
              onChanged: (v) {
                setState(() => _scale = _scale.copyWith(name: v));
                _persist();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _baseFrequencyController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n.baseFrequencyLabel,
                      helperText: l10n.baseFrequencyHelper,
                      suffixText: 'Hz',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      final parsed = double.tryParse(v);
                      if (parsed != null && parsed > 0) {
                        _tonePlayer.stop();
                        _scale = _scale.copyWith(baseFrequency: parsed);
                        _persist();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _rootOctaveController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.rootOctaveLabel,
                      isDense: true,
                    ),
                    onChanged: (v) {
                      final parsed = int.tryParse(v);
                      if (parsed != null) {
                        _tonePlayer.stop();
                        _scale = _scale.copyWith(rootOctave: parsed);
                        _persist();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: ScaleCakeChart(
              scale: _scale,
              selectedIndex: _selectedIndex,
              onSelect: (i) => setState(() => _selectedIndex = i),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text(
              l10n.cakeInstructions,
              style: const TextStyle(color: SemitoneColors.grey4, fontSize: 12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(l10n.nameColumnHeader, style: const TextStyle(color: SemitoneColors.grey4)),
                ),
                Expanded(
                  flex: 2,
                  child: Text(l10n.positionColumnHeader, style: const TextStyle(color: SemitoneColors.grey4)),
                ),
                const SizedBox(width: 192),
              ],
            ),
          ),
          const Divider(height: 16),
          if (degrees.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  l10n.noDegreesYet,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: SemitoneColors.grey4),
                ),
              ),
            )
          else
            ...List.generate(degrees.length, (index) {
              final degree = degrees[index];
              final frequency = _scale.frequencyForDegree(index);
              return _DegreeRow(
                key: ValueKey('$index-${degree.name}'),
                degree: degree,
                isRoot: _scale.rootIndex == index,
                isSelected: _selectedIndex == index,
                isPlaying: _tonePlayer.isPlaying(index),
                onTap: () => setState(() => _selectedIndex = index),
                onChanged: (d) => _updateDegree(index, d),
                onSetRoot: () => _setRoot(index),
                onDuplicate: () => _duplicateDegree(index),
                onDelete: () => _removeDegree(index),
                onTogglePlay: () => _tonePlayer.toggle(index, frequency),
              );
            }),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDegree,
        tooltip: l10n.addToneTooltip,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _DegreeRow extends StatefulWidget {
  const _DegreeRow({
    super.key,
    required this.degree,
    required this.isRoot,
    required this.isSelected,
    required this.isPlaying,
    required this.onTap,
    required this.onChanged,
    required this.onSetRoot,
    required this.onDuplicate,
    required this.onDelete,
    required this.onTogglePlay,
  });

  final ScaleDegree degree;
  final bool isRoot;
  final bool isSelected;
  final bool isPlaying;
  final VoidCallback onTap;
  final ValueChanged<ScaleDegree> onChanged;
  final VoidCallback onSetRoot;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onTogglePlay;

  @override
  State<_DegreeRow> createState() => _DegreeRowState();
}

class _DegreeRowState extends State<_DegreeRow> {
  late TextEditingController _nameController;
  late TextEditingController _centsController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.degree.name);
    _centsController =
        TextEditingController(text: widget.degree.cents.toStringAsFixed(1));
  }

  @override
  void didUpdateWidget(covariant _DegreeRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.degree.cents != widget.degree.cents &&
        double.tryParse(_centsController.text) != widget.degree.cents) {
      _centsController.text = widget.degree.cents.toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _centsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: widget.onTap,
      child: Container(
        color: widget.isSelected
            ? SemitoneColors.grey2.withValues(alpha: 0.6)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(isDense: true),
                onChanged: (v) =>
                    widget.onChanged(widget.degree.copyWith(name: v)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _centsController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(isDense: true),
                onChanged: (v) {
                  final parsed = double.tryParse(v);
                  if (parsed != null) {
                    final clamped = parsed % 1200;
                    widget.onChanged(
                      widget.degree.copyWith(cents: clamped < 0 ? clamped + 1200 : clamped),
                    );
                  }
                },
              ),
            ),
            SizedBox(
              width: 192,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      widget.isPlaying ? Icons.stop : Icons.play_arrow,
                    ),
                    color: widget.isPlaying
                        ? SemitoneColors.blue
                        : SemitoneColors.grey4,
                    tooltip: widget.isPlaying
                        ? l10n.stopToneTooltip
                        : l10n.playToneTooltip,
                    onPressed: widget.onTogglePlay,
                  ),
                  IconButton(
                    icon: Icon(
                      widget.isRoot ? Icons.star : Icons.star_border,
                    ),
                    color: widget.isRoot
                        ? SemitoneColors.blue
                        : SemitoneColors.grey4,
                    tooltip: l10n.setAsRootTooltip,
                    onPressed: widget.onSetRoot,
                  ),
                  IconButton(
                    icon: const Icon(Icons.content_copy),
                    color: SemitoneColors.grey4,
                    tooltip: l10n.duplicateToneTooltip,
                    onPressed: widget.onDuplicate,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: SemitoneColors.grey4,
                    tooltip: l10n.deleteTooltip,
                    onPressed: widget.onDelete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
