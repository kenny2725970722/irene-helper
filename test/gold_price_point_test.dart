import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/models/gold_price_point.dart';

GoldPricePoint _point(DateTime date, double sell) =>
    GoldPricePoint(date: date, sell: sell, buy: sell - 200);

void main() {
  group('goldPriceValue', () {
    test('strips thousands separators', () {
      expect(goldPriceValue('1,326.70'), 1326.7);
      expect(goldPriceValue('1,058.00'), 1058.0);
      expect(goldPriceValue('49,657'), 49657);
      expect(goldPriceValue('950'), 950);
    });
  });

  group('GoldPricePoint', () {
    test('serializes and deserializes', () {
      final point = GoldPricePoint(
        date: DateTime(2026, 9, 23),
        sell: 1326.7,
        buy: 1058.0,
      );

      final restored = GoldPricePoint.fromJson(point.toJson());

      expect(restored.date, DateTime(2026, 9, 23));
      expect(restored.sell, 1326.7);
      expect(restored.buy, 1058.0);
    });
  });

  group('recordPoint', () {
    test('adds the first point', () {
      final history = recordPoint([], _point(DateTime(2026, 9, 23), 1326.7));

      expect(history, hasLength(1));
      expect(history.single.sell, 1326.7);
    });

    test('a later reading on the same day replaces the earlier one', () {
      final history = recordPoint(
        recordPoint([], _point(DateTime(2026, 9, 23, 9), 1300)),
        _point(DateTime(2026, 9, 23, 18), 1326.7),
      );

      expect(history, hasLength(1));
      expect(history.single.sell, 1326.7);
    });

    test('sorts points by date ascending', () {
      final history = recordPoint(
        [_point(DateTime(2026, 9, 23), 1300)],
        _point(DateTime(2026, 9, 21), 1280),
      );

      expect(history.map((p) => p.date.day), [21, 23]);
    });

    test('keeps only the newest 30 days', () {
      var history = <GoldPricePoint>[];
      for (var i = 0; i < 35; i++) {
        history = recordPoint(history, _point(DateTime(2026, 1, 1 + i), (1000 + i).toDouble()));
      }

      expect(history, hasLength(30));
      expect(history.first.date, DateTime(2026, 1, 6));
      expect(history.last.date, DateTime(2026, 2, 4));
      expect(history.first.sell, 1005);
    });
  });
}
