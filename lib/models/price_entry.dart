/// A single product's price at a specific retailer (manually curated).
class PriceEntry {
  final String id;
  final String product;
  final String brand;
  final String retailer;
  final double price;
  final String note;
  final DateTime dateAdded;

  PriceEntry({
    required this.id,
    required this.product,
    required this.brand,
    required this.retailer,
    required this.price,
    this.note = '',
    required this.dateAdded,
  });

  factory PriceEntry.fromJson(Map<String, dynamic> json) {
    return PriceEntry(
      id: json['id'] as String,
      product: json['product'] as String,
      brand: json['brand'] as String,
      retailer: json['retailer'] as String,
      price: (json['price'] as num).toDouble(),
      note: json['note'] as String? ?? '',
      dateAdded: DateTime.parse(json['dateAdded'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product': product,
      'brand': brand,
      'retailer': retailer,
      'price': price,
      'note': note,
      'dateAdded': dateAdded.toIso8601String(),
    };
  }
}
