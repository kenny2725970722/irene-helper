import 'dart:math';
import 'package:flutter/material.dart';

/// Draws the plant on a Canvas.
///
/// [growth] goes from 0.0 (seed in soil) to 1.0 (full plant with flower).
/// [isWithered] turns the plant brown/grey when the user abandoned focus.
class PlantPainter extends CustomPainter {
  final double growth;
  final bool isWithered;

  PlantPainter({required this.growth, this.isWithered = false});

  @override
  void paint(Canvas canvas, Size size) {
    // Colors change when withered
    final stemColor = isWithered ? const Color(0xFF8B7355) : const Color(0xFF2E7D32);
    final leafColor = isWithered ? const Color(0xFFA0926B) : const Color(0xFF4CAF50);
    final flowerColor = isWithered ? Colors.grey.shade400 : Colors.pink.shade300;
    final potColor = isWithered ? const Color(0xFF6D4C41) : const Color(0xFF8D6E63);

    // The paint "brush" — shared, we change its properties as we draw
    final paint = Paint()..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final potTop = size.height * 0.82; // pot sits near the bottom

    // ── POT (always drawn) ──
    _drawPot(canvas, paint, centerX, potTop, potColor);

    if (growth <= 0) return; // nothing above soil yet

    // ── STEM (grows upward) ──
    final maxStemHeight = size.height * 0.45;
    final stemHeight = maxStemHeight * growth;

    paint.color = stemColor;
    paint.strokeWidth = growth < 0.3 ? 3.0 : 4.5; // stem thickens as it grows
    paint.style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(centerX, potTop - 10), // starts inside the pot
      Offset(centerX, potTop - 10 - stemHeight), // grows UP
      paint,
    );
    paint.style = PaintingStyle.fill;

    // ── LEAF PAIR 1 (appears when growth >= 0.2) ──
    if (growth >= 0.2) {
      _drawLeaf(canvas, paint, centerX, potTop - 10 - stemHeight * 0.4,
          leafColor, -0.35, isWithered, growth);
      _drawLeaf(canvas, paint, centerX, potTop - 10 - stemHeight * 0.4 + 8,
          leafColor, 0.35, isWithered, growth);
    }

    // ── LEAF PAIR 2 (appears when growth >= 0.5) ──
    if (growth >= 0.5) {
      _drawLeaf(canvas, paint, centerX, potTop - 10 - stemHeight * 0.6,
          leafColor, -0.3, isWithered, growth);
      _drawLeaf(canvas, paint, centerX, potTop - 10 - stemHeight * 0.6 + 10,
          leafColor, 0.3, isWithered, growth);
    }

    // ── LEAF PAIR 3 (appears when growth >= 0.75) ──
    if (growth >= 0.75) {
      _drawLeaf(canvas, paint, centerX, potTop - 10 - stemHeight * 0.8,
          leafColor, -0.25, isWithered, growth);
      _drawLeaf(canvas, paint, centerX, potTop - 10 - stemHeight * 0.8 + 12,
          leafColor, 0.25, isWithered, growth);
    }

    // ── FLOWER (blooms at growth >= 0.9) ──
    if (growth >= 0.9) {
      final flowerCenter = Offset(centerX, potTop - 10 - stemHeight);
      _drawFlower(canvas, paint, flowerCenter, flowerColor, isWithered);
    }
  }

  /// Draws the simple terracotta pot
  void _drawPot(Canvas canvas, Paint paint, double centerX, double potTop, Color color) {
    paint.color = color;

    // Pot body (a trapezoid — wider at top, narrower at bottom)
    final potPath = Path()
      ..moveTo(centerX - 28, potTop) // top-left
      ..lineTo(centerX + 28, potTop) // top-right
      ..lineTo(centerX + 20, potTop + 45) // bottom-right
      ..lineTo(centerX - 20, potTop + 45) // bottom-left
      ..close();
    canvas.drawPath(potPath, paint);

    // Pot rim
    paint.color = color.withValues(alpha: 0.8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(centerX, potTop - 3), width: 62, height: 12),
        const Radius.circular(4),
      ),
      paint,
    );

    // Soil (dark brown oval on top of pot)
    paint.color = const Color(0xFF3E2723);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(centerX, potTop + 2), width: 52, height: 8),
      paint,
    );
  }

  /// Draws one leaf. Withered = droops down.
  void _drawLeaf(Canvas canvas, Paint paint, double centerX, double y,
      Color color, double baseAngle, bool isWithered, double growth) {
    final leafSize = 14.0 * growth.clamp(0.0, 1.0);

    canvas.save();
    canvas.translate(centerX, y);
    // When withered, leaves droop downward (larger positive angle)
    canvas.rotate(isWithered ? 1.2 : baseAngle);
    paint.color = color;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(baseAngle < 0 ? -leafSize * 0.7 : leafSize * 0.7, 0),
        width: leafSize * 1.8,
        height: leafSize * 0.6,
      ),
      paint,
    );
    canvas.restore();
  }

  /// Draws a simple 5-petal flower
  void _drawFlower(Canvas canvas, Paint paint, Offset center, Color color, bool isWithered) {
    // Center
    paint.color = isWithered ? Colors.brown.shade400 : Colors.yellow.shade600;
    canvas.drawCircle(center, 6, paint);

    // 5 petals around the center
    paint.color = color;
    for (int i = 0; i < 5; i++) {
      final angle = (i * 72 - 90) * (pi / 180); // start from top
      final petalCenter = Offset(
        center.dx + cos(angle) * 10,
        center.dy + sin(angle) * 10,
      );
      canvas.drawCircle(petalCenter, 7, paint);
    }
  }

  @override
  bool shouldRepaint(PlantPainter oldDelegate) {
    return oldDelegate.growth != growth || oldDelegate.isWithered != isWithered;
  }
}
