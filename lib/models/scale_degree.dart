/// A single named tone height within one octave, expressed in cents
/// (0-1200) above the tuning scale's root.
class ScaleDegree {
  const ScaleDegree({required this.name, required this.cents});

  final String name;

  /// Position within the octave, in cents, 0 <= cents < 1200.
  final double cents;

  ScaleDegree copyWith({String? name, double? cents}) => ScaleDegree(
        name: name ?? this.name,
        cents: cents ?? this.cents,
      );

  Map<String, dynamic> toJson() => {'name': name, 'cents': cents};

  factory ScaleDegree.fromJson(Map<String, dynamic> json) => ScaleDegree(
        name: json['name'] as String,
        cents: (json['cents'] as num).toDouble(),
      );

  @override
  String toString() => 'ScaleDegree($name, ${cents}c)';
}
