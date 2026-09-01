import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/services/gold_price_service.dart';

void main() {
  group('parseGoldPrice', () {
    test('parses 9999/999 gold gram prices from Luk Fook JSON', () {
      const jsonBody = '''
      {
        "status": 1,
        "data": {
          "hk": {
            "label": "香港金價",
            "data": {
              "9999/999金(克)": {
                "賣出(HKD)": "1,323.80",
                "買入(HKD)": "1,055.10"
              }
            }
          }
        }
      }
      ''';

      final price = parseGoldPrice(jsonBody);

      expect(price.sellPrice, '1,323.80');
      expect(price.buyPrice, '1,055.10');
    });
  });
}
