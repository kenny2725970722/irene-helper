import 'package:intl/intl.dart';

/// One day's 9999/999 gold price per gram (HKD) — the unit of price history.
class GoldPricePoint {
  final DateTime date;
  final double sell;
  final double buy;

  const GoldPricePoint({
    required this.date,
    required this.sell,
    required this.buy,
  });

  factory GoldPricePoint.fromJson(Map<String, dynamic> json) {
    return GoldPricePoint(
      date: DateTime.parse(json['date'] as String),
      sell: (json['sell'] as num).toDouble(),
      buy: (json['buy'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'sell': sell,
      'buy': buy,
    };
  }
}

/// The API sends prices as strings with thousands separators, e.g. "1,326.70".
double goldPriceValue(String raw) => double.parse(raw.replaceAll(',', ''));

String _dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Merge [point] into [history], keeping one point per day and at most
/// [maxDays] days. A later reading on a day that is already recorded replaces
/// the earlier one, so refreshing repeatedly still yields one point per day.
List<GoldPricePoint> recordPoint(
  List<GoldPricePoint> history,
  GoldPricePoint point, {
  int maxDays = 30,
}) {
  final key = _dayKey(point.date);
  final merged = [
    for (final p in history)
      if (_dayKey(p.date) != key) p,
    point,
  ]..sort((a, b) => a.date.compareTo(b.date));
  if (merged.length <= maxDays) return merged;
  return merged.sublist(merged.length - maxDays);
}
