import 'package:flutter/material.dart';

import '../models/scale_degree.dart';
import '../models/tuning_scale.dart';
import '../services/settings_service.dart';
import '../theme/semitone_theme.dart';
import '../widgets/scale_cake_chart.dart';

/// New feature: lets the user define their own tone-height boundaries
/// (name + position in cents within an octave) instead of relying on
/// standard 12-tone equal temperament. The tuner matches detected pitches
/// against these boundaries when "Use custom scale boundaries" is enabled.
///
/// The octave is visualized as a "cake": each tone owns a wedge running
/// from the midpoint with its previous neighbour to the midpoint with its
/// next one. Starting from the default C-D-E-F-G-A-H (German naming, H =
/// B) diatonic scale, a tone can be duplicated ("copy") to split its wedge
/// in two, and then repositioned to redraw where the octave gets split.
class CustomScaleScreen extends StatefulWidget {
  const CustomScaleScreen({
    super.key,
    required this.settings,
    required this.scaleId,
  });

  final SettingsService settings;

  /// Id of the saved scale (from [SettingsService.customScales]) being
  /// edited.
  final String scaleId;

  @override
  State<CustomScaleScreen> createState() => _CustomScaleScreenState();
}

class _CustomScaleScreenState extends State<CustomScaleScreen> {
  late TuningScale _scale;
  late TextEditingController _nameController;
  late TextEditingController _rootOctaveController;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _scale = widget.settings.customScales.firstWhere(
      (s) => s.id == widget.scaleId,
      orElse: TuningScale.defaultDiatonic,
    );
    _nameController = TextEditingController(text: _scale.name);
    _rootOctaveController =
        TextEditingController(text: _scale.rootOctave.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rootOctaveController.dispose();
    super.dispose();
  }

  void _persist() {
    widget.settings.updateScale(_scale);
  }

  void _addDegree() {
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
    final degrees = [..._scale.degrees];
    degrees[index] = updated;
    setState(() {
      _scale = _scale.copyWith(degrees: degrees);
    });
    _persist();
  }

  void _setRoot(int index) {
    setState(() {
      _scale = _scale.copyWith(rootIndex: index);
    });
    _persist();
  }

  void _resetToDefault() {
    final def = TuningScale.defaultDiatonic();
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
    final degrees = _scale.degrees;

    return Scaffold(
      appBar: AppBar(
        title: Text(_scale.name.isEmpty ? 'Edit scale' : _scale.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset to C-D-E-F-G-A-H',
            onPressed: _resetToDefault,
          ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Scale name',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      setState(() => _scale = _scale.copyWith(name: v));
                      _persist();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _rootOctaveController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Root octave',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      final parsed = int.tryParse(v);
                      if (parsed != null) {
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text(
              'Tap a slice to select it below. Each tone\'s wedge runs from '
              'the midpoint with its previous neighbour to the midpoint with '
              'its next one — duplicate a tone to split its wedge, then move '
              'the copy to redraw the split.',
              style: TextStyle(color: SemitoneColors.grey4, fontSize: 12),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('Name', style: TextStyle(color: SemitoneColors.grey4)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Position (cents)', style: TextStyle(color: SemitoneColors.grey4)),
                ),
                SizedBox(width: 136, child: Text('', style: TextStyle(color: SemitoneColors.grey4))),
              ],
            ),
          ),
          const Divider(height: 16),
          if (degrees.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No tone heights defined yet.\nTap + to add one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SemitoneColors.grey4),
                ),
              ),
            )
          else
            ...List.generate(degrees.length, (index) {
              final degree = degrees[index];
              return _DegreeRow(
                key: ValueKey('$index-${degree.name}'),
                degree: degree,
                isRoot: _scale.rootIndex == index,
                isSelected: _selectedIndex == index,
                onTap: () => setState(() => _selectedIndex = index),
                onChanged: (d) => _updateDegree(index, d),
                onSetRoot: () => _setRoot(index),
                onDuplicate: () => _duplicateDegree(index),
                onDelete: () => _removeDegree(index),
              );
            }),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDegree,
        tooltip: 'Add a new tone',
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
    required this.onTap,
    required this.onChanged,
    required this.onSetRoot,
    required this.onDuplicate,
    required this.onDelete,
  });

  final ScaleDegree degree;
  final bool isRoot;
  final bool isSelected;
  final VoidCallback onTap;
  final ValueChanged<ScaleDegree> onChanged;
  final VoidCallback onSetRoot;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

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
              width: 136,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      widget.isRoot ? Icons.star : Icons.star_border,
                    ),
                    color: widget.isRoot
                        ? SemitoneColors.blue
                        : SemitoneColors.grey4,
                    tooltip: 'Set as root',
                    onPressed: widget.onSetRoot,
                  ),
                  IconButton(
                    icon: const Icon(Icons.content_copy),
                    color: SemitoneColors.grey4,
                    tooltip: 'Duplicate (splits this wedge)',
                    onPressed: widget.onDuplicate,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: SemitoneColors.grey4,
                    tooltip: 'Delete',
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
