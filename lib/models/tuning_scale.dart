import 'dart:convert';
import 'dart:math' as math;

import 'scale_degree.dart';

/// The result of matching a detected pitch against a [TuningScale].
class ScaleMatch {
  const ScaleMatch({
    required this.degreeName,
    required this.octave,
    required this.errorCents,
  });

  final String degreeName;
  final int octave;

  /// Signed deviation in cents from the matched degree (-600..600).
  final double errorCents;

  String get label => '$degreeName${octave >= 0 ? octave : octave}';
}

/// A set of named tone-height boundaries within an octave, used to
/// interpret a detected pitch. Defaults to standard 12-tone equal
/// temperament, but can be replaced by user-defined boundaries to
/// support custom / microtonal scales.
class TuningScale {
  TuningScale({
    required this.name,
    required List<ScaleDegree> degrees,
    this.rootIndex = 0,
    this.rootOctave = 4,
  }) : degrees = List.unmodifiable(
          [...degrees]..sort((a, b) => a.cents.compareTo(b.cents)),
        );

  final String name;

  /// Degrees sorted ascending by cents, each in [0, 1200).
  final List<ScaleDegree> degrees;

  /// Index (into the *sorted* [degrees]) of the degree that lines up with
  /// the reference pitch (concert A) at [rootOctave].
  final int rootIndex;

  /// Octave number assigned to [rootIndex] when the detected pitch exactly
  /// matches the reference frequency.
  final int rootOctave;

  static const List<String> _chromaticNames = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
  ];

  /// Standard 12-tone equal temperament, rooted so that "A" lines up with
  /// the configured concert pitch (matches the original Semitone app).
  factory TuningScale.defaultTwelveTet() {
    final degs = [
      for (var i = 0; i < 12; i++)
        ScaleDegree(name: _chromaticNames[i], cents: i * 100.0),
    ];
    return TuningScale(
      name: '12-tone equal temperament',
      degrees: degs,
      rootIndex: _chromaticNames.indexOf('A'),
      rootOctave: 4,
    );
  }

  static const List<String> _diatonicNames = ['C', 'D', 'E', 'F', 'G', 'A', 'H'];
  static const List<double> _diatonicCents = [0, 200, 400, 500, 700, 900, 1100];

  /// The default starting point for a user-defined scale: the plain
  /// C-D-E-F-G-A-H (German note naming, H = B) diatonic scale, at its
  /// standard 12-tone-equal-temperament positions. Because the whole/half
  /// step pattern (W-W-H-W-W-W-H) isn't even, this already renders as an
  /// asymmetric "cake" out of the box, inviting the user to reshape it.
  factory TuningScale.defaultDiatonic() {
    final degs = [
      for (var i = 0; i < _diatonicNames.length; i++)
        ScaleDegree(name: _diatonicNames[i], cents: _diatonicCents[i]),
    ];
    return TuningScale(
      name: 'My scale',
      degrees: degs,
      rootIndex: _diatonicNames.indexOf('A'),
      rootOctave: 4,
    );
  }

  /// The lower boundary (start angle, in cents) of each degree's slice,
  /// i.e. the midpoint between it and its previous neighbour — the same
  /// circular Voronoi partition [match] uses internally. Together with the
  /// next entry (wrapping to +1200 after the last), this gives the cake
  /// wedge each degree owns.
  List<double> get sliceBoundaries {
    final n = degrees.length;
    if (n == 0) return const [];
    if (n == 1) return const [0];
    return List.generate(n, (i) {
      final prev = degrees[(i - 1) % n].cents - (i == 0 ? 1200 : 0);
      return (prev + degrees[i].cents) / 2;
    });
  }

  /// Match a detected [totalCentsFromReference] (i.e.
  /// `1200 * log2(freq / referenceFreq)`) against this scale, returning the
  /// nearest degree, its octave, and signed error in cents.
  ScaleMatch match(double totalCentsFromReference) {
    if (degrees.isEmpty) {
      return const ScaleMatch(degreeName: '?', octave: 0, errorCents: 0);
    }

    final rootCents = degrees[rootIndex].cents;
    final absoluteCents = totalCentsFromReference + rootCents;
    final octaveIndex = (absoluteCents / 1200).floor();
    final withinOctave = absoluteCents - octaveIndex * 1200;

    var bestIdx = 0;
    var bestOctaveDelta = 0;
    var bestError = double.infinity;

    for (var i = 0; i < degrees.length; i++) {
      final raw = withinOctave - degrees[i].cents;
      final octaveDelta = (raw / 1200).round();
      final wrapped = raw - octaveDelta * 1200;
      if (wrapped.abs() < bestError.abs()) {
        bestError = wrapped;
        bestIdx = i;
        bestOctaveDelta = octaveDelta;
      }
    }

    final finalOctave = rootOctave + octaveIndex + bestOctaveDelta;
    return ScaleMatch(
      degreeName: degrees[bestIdx].name,
      octave: finalOctave,
      errorCents: bestError,
    );
  }

  TuningScale copyWith({
    String? name,
    List<ScaleDegree>? degrees,
    int? rootIndex,
    int? rootOctave,
  }) {
    return TuningScale(
      name: name ?? this.name,
      degrees: degrees ?? this.degrees,
      rootIndex: rootIndex ?? this.rootIndex,
      rootOctave: rootOctave ?? this.rootOctave,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'degrees': degrees.map((d) => d.toJson()).toList(),
        'rootIndex': rootIndex,
        'rootOctave': rootOctave,
      };

  factory TuningScale.fromJson(Map<String, dynamic> json) {
    final degs = (json['degrees'] as List)
        .map((d) => ScaleDegree.fromJson(d as Map<String, dynamic>))
        .toList();
    var rootIndex = json['rootIndex'] as int? ?? 0;
    if (degs.isEmpty) {
      rootIndex = 0;
    } else {
      rootIndex = math.max(0, math.min(rootIndex, degs.length - 1));
    }
    return TuningScale(
      name: json['name'] as String? ?? 'Custom scale',
      degrees: degs,
      rootIndex: rootIndex,
      rootOctave: json['rootOctave'] as int? ?? 4,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory TuningScale.fromJsonString(String jsonStr) =>
      TuningScale.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
}
