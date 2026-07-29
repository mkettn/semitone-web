import 'package:flutter/material.dart';

import '../models/scale_degree.dart';
import '../models/tuning_scale.dart';
import '../services/settings_service.dart';
import '../theme/semitone_theme.dart';

/// New feature: lets the user define their own tone-height boundaries
/// (name + position in cents within an octave) instead of relying on
/// standard 12-tone equal temperament. The tuner matches detected pitches
/// against these boundaries when "Use custom scale boundaries" is enabled.
class CustomScaleScreen extends StatefulWidget {
  const CustomScaleScreen({super.key, required this.settings});

  final SettingsService settings;

  @override
  State<CustomScaleScreen> createState() => _CustomScaleScreenState();
}

class _CustomScaleScreenState extends State<CustomScaleScreen> {
  late TuningScale _scale;
  late TextEditingController _nameController;
  late TextEditingController _rootOctaveController;

  @override
  void initState() {
    super.initState();
    _scale = widget.settings.customScale;
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
    widget.settings.customScale = _scale;
  }

  void _addDegree() {
    final degrees = [
      ..._scale.degrees,
      ScaleDegree(name: 'New', cents: 0),
    ];
    setState(() {
      _scale = _scale.copyWith(degrees: degrees);
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
    final def = TuningScale.defaultTwelveTet();
    setState(() {
      _scale = _scale.copyWith(
        degrees: def.degrees,
        rootIndex: def.rootIndex,
        rootOctave: def.rootOctave,
      );
      _rootOctaveController.text = _scale.rootOctave.toString();
    });
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    // Sort degrees by cents for display, but keep track of the original
    // (sorted-by-cents) indices, since TuningScale itself sorts on
    // construction — the incoming `_scale.degrees` list is already sorted.
    final degrees = _scale.degrees;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Scale Boundaries'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset to 12-tone equal temperament',
            onPressed: _resetToDefault,
          ),
        ],
      ),
      body: Column(
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
                      _scale = _scale.copyWith(name: v);
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
                  child: Text('Cents', style: TextStyle(color: SemitoneColors.grey4)),
                ),
                SizedBox(width: 96, child: Text('Root', style: TextStyle(color: SemitoneColors.grey4))),
              ],
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: degrees.isEmpty
                ? const Center(
                    child: Text(
                      'No tone heights defined yet.\nTap + to add one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: SemitoneColors.grey4),
                    ),
                  )
                : ListView.builder(
                    itemCount: degrees.length,
                    itemBuilder: (context, index) {
                      final degree = degrees[index];
                      return _DegreeRow(
                        key: ValueKey('$index-${degree.name}'),
                        degree: degree,
                        isRoot: _scale.rootIndex == index,
                        onChanged: (d) => _updateDegree(index, d),
                        onSetRoot: () => _setRoot(index),
                        onDelete: () => _removeDegree(index),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDegree,
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
    required this.onChanged,
    required this.onSetRoot,
    required this.onDelete,
  });

  final ScaleDegree degree;
  final bool isRoot;
  final ValueChanged<ScaleDegree> onChanged;
  final VoidCallback onSetRoot;
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
  void dispose() {
    _nameController.dispose();
    _centsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            width: 96,
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
                  icon: const Icon(Icons.delete_outline),
                  color: SemitoneColors.grey4,
                  onPressed: widget.onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
