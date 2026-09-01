import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/models/promo_entry.dart';
import 'package:my_first_app/models/price_entry.dart';

void main() {
  group('PromoEntry', () {
    test('serializes and deserializes', () {
      final entry = PromoEntry(
        id: '1',
        retailer: 'Sasa',
        title: '20% off',
        note: 'limited time',
        link: 'https://example.com',
        dateAdded: DateTime(2026, 9, 2, 10, 30),
      );

      final restored = PromoEntry.fromJson(entry.toJson());

      expect(restored.id, '1');
      expect(restored.retailer, 'Sasa');
      expect(restored.title, '20% off');
      expect(restored.note, 'limited time');
      expect(restored.link, 'https://example.com');
      expect(restored.dateAdded, DateTime(2026, 9, 2, 10, 30));
    });
  });

  group('PriceEntry', () {
    test('serializes and deserializes', () {
      final entry = PriceEntry(
        id: '2',
        product: 'Serum',
        brand: 'BrandX',
        retailer: 'Watsons',
        price: 99.5,
        note: '',
        dateAdded: DateTime(2026, 9, 2),
      );

      final restored = PriceEntry.fromJson(entry.toJson());

      expect(restored.id, '2');
      expect(restored.product, 'Serum');
      expect(restored.brand, 'BrandX');
      expect(restored.retailer, 'Watsons');
      expect(restored.price, 99.5);
      expect(restored.note, '');
      expect(restored.dateAdded, DateTime(2026, 9, 2));
    });
  });
}
