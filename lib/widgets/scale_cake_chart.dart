import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/scale_degree.dart';
import '../models/tuning_scale.dart';
import '../theme/semitone_theme.dart';

/// Renders a [TuningScale] as a "cake": a circle sliced into one wedge per
/// tone, sized by how much of the octave (in cents) it covers. Tapping a
/// wedge selects that degree.
class ScaleCakeChart extends StatelessWidget {
  const ScaleCakeChart({
    super.key,
    required this.scale,
    this.selectedIndex,
    this.onSelect,
    this.size = 240,
  });

  final TuningScale scale;
  final int? selectedIndex;
  final ValueChanged<int>? onSelect;
  final double size;

  @override
  Widget build(BuildContext context) {
    final degrees = scale.degrees;
    if (degrees.isEmpty) {
      return SizedBox(
        height: size,
        child: Center(
          child: Text(
            AppLocalizations.of(context)!.noToneHeightsDefined,
            style: const TextStyle(color: SemitoneColors.grey4),
          ),
        ),
      );
    }

    final boundaries = scale.sliceBoundaries;

    return GestureDetector(
      onTapUp: (details) {
        if (onSelect == null) return;
        final box = context.findRenderObject() as RenderBox;
        final local = box.globalToLocal(details.globalPosition);
        final center = Offset(size / 2, size / 2);
        final vector = local - center;
        if (vector.distance > size / 2) return;
        // atan2 with y flipped (canvas y grows downward), 0 rad = 12 o'clock.
        var angle = math.atan2(vector.dx, -vector.dy);
        if (angle < 0) angle += 2 * math.pi;
        final cents = angle / (2 * math.pi) * 1200;
        final index = _sliceForCents(boundaries, cents);
        if (index != null) onSelect!(index);
      },
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _CakePainter(
            degrees: degrees,
            boundaries: boundaries,
            selectedIndex: selectedIndex,
            rootIndex: scale.rootIndex,
          ),
        ),
      ),
    );
  }

  int? _sliceForCents(List<double> boundaries, double cents) {
    final n = boundaries.length;
    for (var i = 0; i < n; i++) {
      final start = boundaries[i];
      final end = i + 1 < n ? boundaries[i + 1] : boundaries[0] + 1200;
      final normalizedCents = cents < start ? cents + 1200 : cents;
      if (normalizedCents >= start && normalizedCents < end) return i;
    }
    return null;
  }
}

class _CakePainter extends CustomPainter {
  _CakePainter({
    required this.degrees,
    required this.boundaries,
    required this.selectedIndex,
    required this.rootIndex,
  });

  final List<ScaleDegree> degrees;
  final List<double> boundaries;
  final int? selectedIndex;
  final int rootIndex;

  static const _startOffset = -math.pi / 2; // 0 cents at 12 o'clock

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final n = degrees.length;

    for (var i = 0; i < n; i++) {
      final start = boundaries[i];
      final end = i + 1 < n ? boundaries[i + 1] : boundaries[0] + 1200;
      final startAngle = _startOffset + start / 1200 * 2 * math.pi;
      final sweep = (end - start) / 1200 * 2 * math.pi;

      final isSelected = selectedIndex == i;
      final hue = (i * 360 / math.max(n, 1)) % 360;
      final color = HSVColor.fromAHSV(
        1,
        hue,
        i == rootIndex ? 0.55 : 0.4,
        isSelected ? 0.95 : 0.75,
      ).toColor();

      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = color;
      canvas.drawArc(rect, startAngle, sweep, true, fill);

      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 3 : 1.5
        ..color = SemitoneColors.black;
      canvas.drawArc(rect, startAngle, sweep, true, stroke);

      // Label at the mid-angle of the wedge.
      final midAngle = startAngle + sweep / 2;
      final labelRadius = radius * 0.68;
      final labelPos =
          center + Offset(math.cos(midAngle), math.sin(midAngle)) * labelRadius;

      final textPainter = TextPainter(
        text: TextSpan(
          text: degrees[i].name,
          style: TextStyle(
            color: SemitoneColors.black,
            fontSize: isSelected ? 16 : 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        labelPos - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }

    // Center hole for a donut look.
    final holePaint = Paint()..color = SemitoneColors.black;
    canvas.drawCircle(center, radius * 0.22, holePaint);
    final holeStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = SemitoneColors.grey3;
    canvas.drawCircle(center, radius * 0.22, holeStroke);
  }

  @override
  bool shouldRepaint(covariant _CakePainter oldDelegate) {
    return oldDelegate.degrees != degrees ||
        oldDelegate.boundaries != boundaries ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.rootIndex != rootIndex;
  }
}
