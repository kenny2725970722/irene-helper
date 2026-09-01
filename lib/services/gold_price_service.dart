import 'dart:convert';
import 'package:http/http.dart' as http;

/// Current 9999/999 gold price per gram (HKD) from Luk Fook.
class GoldPrice {
  final String sellPrice; // 賣出(HKD) — what you pay to buy gold
  final String buyPrice; // 買入(HKD) — what you get selling gold back

  const GoldPrice({required this.sellPrice, required this.buyPrice});
}

const _goldPriceUrl = 'https://www.lukfook.com/api/goldprice';

/// Parse the Luk Fook gold price JSON body into a [GoldPrice].
GoldPrice parseGoldPrice(String jsonBody) {
  final json = jsonDecode(jsonBody) as Map<String, dynamic>;
  final hk = (json['data'] as Map<String, dynamic>)['hk'] as Map<String, dynamic>;
  final gram = (hk['data'] as Map<String, dynamic>)['9999/999金(克)'] as Map<String, dynamic>;
  return GoldPrice(
    sellPrice: gram['賣出(HKD)'] as String,
    buyPrice: gram['買入(HKD)'] as String,
  );
}

/// Fetch the current 9999/999 gold price (per gram, HKD) from Luk Fook.
Future<GoldPrice> fetchGoldPrice() async {
  final resp = await http.get(Uri.parse(_goldPriceUrl));
  if (resp.statusCode != 200) {
    throw Exception('Luk Fook gold price request failed: HTTP ${resp.statusCode}');
  }
  return parseGoldPrice(resp.body);
}
