import 'scale_degree.dart';
import 'tuning_scale.dart';

/// A named starting point offered when creating a new scale.
class ScalePreset {
  const ScalePreset({
    required this.name,
    required this.description,
    required this.build,
  });

  final String name;
  final String description;
  final TuningScale Function() build;
}

const _byzantineDegreeNames = ['Νη', 'Πα', 'Βου', 'Γα', 'Δι', 'Κε', 'Ζω'];

/// Builds one genus of Byzantine chant theory (Modern Patriarchal
/// Committee 72-moria system): [cumulativeMoria] is, for each of the 7
/// degrees starting at Νη (the *vasi* / base note, 0 moria), how many of
/// the octave's 72 moria have accumulated by that degree. One morion is
/// 1200/72 cents.
TuningScale _byzantineGenus(String name, List<int> cumulativeMoria) {
  final degrees = [
    for (var i = 0; i < _byzantineDegreeNames.length; i++)
      ScaleDegree(
        name: _byzantineDegreeNames[i],
        cents: cumulativeMoria[i] * 1200 / 72,
      ),
  ];
  return TuningScale(
    name: name,
    degrees: degrees,
    rootIndex: 0, // Νη, the vasi (base note)
    rootOctave: 4,
  );
}

/// Starting points offered when creating a new scale: the default
/// chromatic scale, and the four genera of Byzantine chant theory, rooted
/// on Νη (Ni), the *vasi* (base note). Byzantine chant has no fixed
/// concert pitch — set the tuner's concert pitch (Settings) to whatever
/// frequency you want Νη to be, and every other degree is expressed
/// relative to it, same as this app already does for every scale.
List<ScalePreset> get scalePresets => [
      ScalePreset(
        name: 'Chromatic',
        description: 'All 12 semitones (C, C#, D, ... A, A#, H)',
        build: TuningScale.defaultChromatic,
      ),
      ScalePreset(
        name: 'Byzantine — Diatonic',
        description: 'Νη-Πα-Βου-Γα-Δι-Κε-Ζω, 12-10-8-12-12-10-8 moria',
        build: () =>
            _byzantineGenus('Byzantine Diatonic', [0, 12, 22, 30, 42, 54, 64]),
      ),
      ScalePreset(
        name: 'Byzantine — Soft chromatic',
        description: 'Νη-Πα-Βου-Γα-Δι-Κε-Ζω, 8-14-8-12-8-14-8 moria',
        build: () => _byzantineGenus(
            'Byzantine Soft Chromatic', [0, 8, 22, 30, 42, 50, 64]),
      ),
      ScalePreset(
        name: 'Byzantine — Hard chromatic',
        description: 'Νη-Πα-Βου-Γα-Δι-Κε-Ζω, 6-20-4-12-6-20-4 moria',
        build: () => _byzantineGenus(
            'Byzantine Hard Chromatic', [0, 6, 26, 30, 42, 48, 68]),
      ),
      ScalePreset(
        name: 'Byzantine — Enharmonic',
        description: 'Νη-Πα-Βου-Γα-Δι-Κε-Ζω, 12-12-6-12-12-12-6 moria',
        build: () => _byzantineGenus(
            'Byzantine Enharmonic', [0, 12, 24, 30, 42, 54, 66]),
      ),
    ];
