import 'package:flutter/material.dart';

import '../theme/semitone_theme.dart';

/// Visualizes tuning error in cents as a horizontal bar with a centre
/// reference marker, mirroring the original app's CentErrorView.
class CentErrorBar extends StatelessWidget {
  const CentErrorBar({super.key, required this.errorCents, this.height = 56});

  /// Signed error in cents, typically in [-50, 50].
  final double errorCents;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _CentErrorPainter(errorCents / 100),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${errorCents >= 0 ? '+' : ''}${errorCents.toStringAsFixed(2)} cents',
            style: TextStyle(
              color: errorCents.abs() < 5
                  ? SemitoneColors.blue
                  : SemitoneColors.white,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}

class _CentErrorPainter extends CustomPainter {
  _CentErrorPainter(this.error);

  /// Normalized error in [-0.5, 0.5] range (1.0 == full semitone).
  final double error;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = SemitoneColors.grey1;
    canvas.drawRect(Offset.zero & size, bg);

    final middle = size.width / 2;
    final centerPaint = Paint()
      ..color = SemitoneColors.white
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(middle, 0),
      Offset(middle, size.height / 4),
      centerPaint,
    );
    canvas.drawLine(
      Offset(middle, size.height * 3 / 4),
      Offset(middle, size.height),
      centerPaint,
    );

    final clamped = error.clamp(-0.5, 0.5);
    final xpos = middle + clamped * size.width;
    final linePaint = Paint()
      ..color = SemitoneColors.red
      ..strokeWidth = 3;
    canvas.drawLine(Offset(xpos, 0), Offset(xpos, size.height), linePaint);
  }

  @override
  bool shouldRepaint(covariant _CentErrorPainter oldDelegate) =>
      oldDelegate.error != error;
}
