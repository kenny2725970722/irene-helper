import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'models/gold_price_point.dart';

/// The chart draws two series and the card's legend has to name the same
/// colours, so the pair is defined once, here. `Colors.x.shadeN` is a getter
/// rather than a const expression, hence `final`.
final Color goldSellLineColor = Colors.teal.shade600;
final Color goldBuyLineColor = Colors.deepOrange.shade700;

/// Draws the gold sell and buy prices as filled polylines.
///
/// The x-axis is a fixed calendar window of [days] days ending at [today]
/// rather than the points themselves, so days with no reading stay an honest
/// gap and the lines grow from left to right as history accumulates.
class GoldChartPainter extends CustomPainter {
  final List<GoldPricePoint> points;
  final int days;
  final DateTime today;
  final Color sellColor;
  final Color buyColor;

  const GoldChartPainter({
    required this.points,
    required this.days,
    required this.today,
    required this.sellColor,
    required this.buyColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // One scale shared by both series. Giving each its own range would draw two
    // near-identical lines — the shop's margin is small next to the price — and
    // comparing them is the whole point of showing both.
    final sells = points.map((p) => p.sell);
    final buys = points.map((p) => p.buy);
    var lo = min(sells.reduce(min), buys.reduce(min));
    var hi = max(sells.reduce(max), buys.reduce(max));
    if (hi - lo < 0.01) {
      // A single point, or a price that has not moved, would divide by zero.
      final mid = (hi + lo) / 2;
      lo = mid * 0.99;
      hi = mid * 1.01;
    }
    final padding = (hi - lo) * 0.12;
    lo -= padding;
    hi += padding;

    final windowStart = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: days - 1));
    final span = (days - 1).toDouble();

    // Inset the plot so the extreme-most points — a lone reading today, a new
    // high — are drawn whole rather than clipped by the canvas edge.
    final plot = Rect.fromLTWH(5, 5, size.width - 10, size.height - 10);

    Offset at(double value, DateTime date) {
      final day = DateTime(date.year, date.month, date.day);
      final x = (day.difference(windowStart).inDays / span).clamp(0.0, 1.0);
      final y = ((hi - value) / (hi - lo)).clamp(0.0, 1.0);
      return Offset(plot.left + x * plot.width, plot.top + y * plot.height);
    }

    void drawSeries(double Function(GoldPricePoint) value, Color color,
        {bool fill = false}) {
      final offsets = [for (final p in points) at(value(p), p.date)];

      if (offsets.length > 1) {
        final line = Path()..moveTo(offsets.first.dx, offsets.first.dy);
        for (final o in offsets.skip(1)) {
          line.lineTo(o.dx, o.dy);
        }

        if (fill) {
          final area = Path.from(line)
            ..lineTo(offsets.last.dx, plot.bottom)
            ..lineTo(offsets.first.dx, plot.bottom)
            ..close();
          canvas.drawPath(
            area,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withValues(alpha: 0.20), color.withValues(alpha: 0)],
              ).createShader(Offset.zero & size),
          );
        }

        canvas.drawPath(
          line,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = color,
        );
      }

      // Mark each series' own extremes so a nearly flat line still says
      // something.
      var lowest = 0;
      var highest = 0;
      for (var i = 1; i < points.length; i++) {
        if (value(points[i]) < value(points[lowest])) lowest = i;
        if (value(points[i]) > value(points[highest])) highest = i;
      }
      final dot = Paint()..color = color;
      canvas.drawCircle(offsets[lowest], 3, dot);
      if (highest != lowest) canvas.drawCircle(offsets[highest], 3, dot);
    }

    // Buy last, so it stays legible where it crosses the sell fill.
    drawSeries((p) => p.sell, sellColor, fill: true);
    drawSeries((p) => p.buy, buyColor);
  }

  @override
  bool shouldRepaint(covariant GoldChartPainter oldDelegate) =>
      !listEquals(oldDelegate.points, points) ||
      oldDelegate.days != days ||
      oldDelegate.today != today ||
      oldDelegate.sellColor != sellColor ||
      oldDelegate.buyColor != buyColor;
}
