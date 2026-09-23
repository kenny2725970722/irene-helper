import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'wheel_math.dart';

/// Slice colours, cycled when there are more options than entries.
///
/// All dark enough to carry white label text.
const List<Color> kWheelPalette = [
  Color(0xFF00897B), // teal
  Color(0xFFEF6C00), // orange
  Color(0xFF3949AB), // indigo
  Color(0xFFD81B60), // pink
  Color(0xFF43A047), // green
  Color(0xFF8E24AA), // purple
  Color(0xFF6D4C41), // brown
  Color(0xFF546E7A), // blue grey
  Color(0xFFE53935), // red
  Color(0xFF00ACC1), // cyan
];

Color sliceColor(int i) => kWheelPalette[i % kWheelPalette.length];

/// Draws the wheel at rotation zero; the spin is applied outside by
/// [Transform.rotate], so this never repaints mid-animation.
class WheelPainter extends CustomPainter {
  final List<String> options;

  WheelPainter({required this.options});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 2;
    if (radius <= 0) return;

    final fill = Paint()..style = PaintingStyle.fill;

    if (options.isEmpty) {
      canvas.drawCircle(center, radius, fill..color = Colors.grey.shade400);
      return;
    }

    final n = options.length;
    final s = sliceAngle(n);

    if (n == 1) {
      // A 2*pi arc degenerates on Skia; draw it as a circle instead.
      canvas.drawCircle(center, radius, fill..color = sliceColor(0));
      _drawLabel(canvas, center, radius, 0, n, options.first);
      return;
    }

    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < n; i++) {
      canvas.drawArc(rect, i * s, s, true, fill..color = sliceColor(i));
    }

    final line = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    for (var i = 0; i < n; i++) {
      final edge = i * s;
      canvas.drawLine(
        center,
        center + Offset(cos(edge), sin(edge)) * radius,
        line,
      );
    }

    for (var i = 0; i < n; i++) {
      _drawLabel(canvas, center, radius, i, n, options[i]);
    }
  }

  void _drawLabel(
    Canvas canvas,
    Offset center,
    double radius,
    int i,
    int n,
    String text,
  ) {
    final s = sliceAngle(n);
    final a = sliceCenter(i, n);
    final labelRadius = radius * 0.62;

    // Widest text that still fits between this slice's two edges.
    final tangential = 2 * labelRadius * sin(s / 2) * 0.9;
    final fontSize =
        min(radius * 0.16, tangential * 0.55).clamp(7.0, 16.0).toDouble();

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: tangential);

    canvas.save();
    canvas.translate(
      center.dx + labelRadius * cos(a),
      center.dy + labelRadius * sin(a),
    );
    // Left-half labels would otherwise read upside down.
    canvas.rotate(cos(a) < 0 ? a + pi : a);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(WheelPainter oldDelegate) =>
      !listEquals(oldDelegate.options, options);
}
