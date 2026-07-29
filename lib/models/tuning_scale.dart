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
/// interpret a detected pitch. Every scale the tuner can use — standard
/// chromatic, a Byzantine chant genus, or a user's own — is one of these;
/// there's no separate "default" kind, only which scales happen to be
/// saved (see `assets/scales/` and `loadPresetScales()` for the ones
/// offered out of the box).
class TuningScale {
  TuningScale({
    String? id,
    required this.name,
    required List<ScaleDegree> degrees,
    this.rootIndex = 0,
    this.rootOctave = 4,
    this.baseFrequency = 440,
  })  : id = id ?? _generateId(),
        degrees = List.unmodifiable(
          [...degrees]..sort((a, b) => a.cents.compareTo(b.cents)),
        );

  /// Stable identity used to select/store/update this scale independently
  /// of its (user-editable, possibly duplicated) name.
  final String id;

  static int _idCounter = 0;
  static String _generateId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  final String name;

  /// Degrees sorted ascending by cents, each in [0, 1200).
  final List<ScaleDegree> degrees;

  /// Index (into the *sorted* [degrees]) of the degree that lines up with
  /// [baseFrequency] at [rootOctave].
  final int rootIndex;

  /// Octave number assigned to [rootIndex] when the detected pitch exactly
  /// matches [baseFrequency].
  final int rootOctave;

  /// The pitch, in Hz, of the degree at [rootIndex]. Each scale carries its
  /// own base pitch rather than sharing one global "concert pitch" — e.g.
  /// standard 12-TET tracks the app's concert-A setting, but a scale with
  /// no fixed concert pitch (such as a Byzantine chant genus, rooted on
  /// whatever frequency the *vasi* happens to be) can be tuned
  /// independently of it and of every other saved scale.
  final double baseFrequency;

  /// A content-free placeholder (no degrees) for defensive fallbacks —
  /// e.g. a hot path that needs *some* scale instance before an async
  /// load of the real ones has resolved. [match] and [matchFrequency]
  /// handle empty [degrees] gracefully, returning a "?" match rather than
  /// throwing.
  factory TuningScale.empty() => TuningScale(name: '', degrees: const []);

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

  /// Match a detected fundamental frequency in Hz against this scale,
  /// converting it to cents relative to [baseFrequency] and delegating to
  /// [match].
  ScaleMatch matchFrequency(double freq) {
    final totalCents = 1200 * (math.log(freq / baseFrequency) / math.ln2);
    return match(totalCents);
  }

  /// Match a detected [totalCentsFromReference] (i.e.
  /// `1200 * log2(freq / baseFrequency)`) against this scale, returning the
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
    double? baseFrequency,
  }) {
    return TuningScale(
      id: id,
      name: name ?? this.name,
      degrees: degrees ?? this.degrees,
      rootIndex: rootIndex ?? this.rootIndex,
      rootOctave: rootOctave ?? this.rootOctave,
      baseFrequency: baseFrequency ?? this.baseFrequency,
    );
  }

  /// A copy with a fresh [id], for duplicating a whole scale (as opposed to
  /// [copyWith], which preserves identity for in-place edits).
  TuningScale duplicate({String? name}) {
    return TuningScale(
      name: name ?? '${this.name} (copy)',
      degrees: degrees,
      rootIndex: rootIndex,
      rootOctave: rootOctave,
      baseFrequency: baseFrequency,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'degrees': degrees.map((d) => d.toJson()).toList(),
        'rootIndex': rootIndex,
        'rootOctave': rootOctave,
        'baseFrequency': baseFrequency,
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
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'Custom scale',
      degrees: degs,
      rootIndex: rootIndex,
      rootOctave: json['rootOctave'] as int? ?? 4,
      baseFrequency: (json['baseFrequency'] as num?)?.toDouble() ?? 440,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory TuningScale.fromJsonString(String jsonStr) =>
      TuningScale.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
}
