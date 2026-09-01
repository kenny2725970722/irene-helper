/// A skincare promotion from a retailer (manually curated).
class PromoEntry {
  final String id;
  final String retailer;
  final String title;
  final String note;
  final String link;
  final DateTime dateAdded;

  PromoEntry({
    required this.id,
    required this.retailer,
    required this.title,
    this.note = '',
    this.link = '',
    required this.dateAdded,
  });

  factory PromoEntry.fromJson(Map<String, dynamic> json) {
    return PromoEntry(
      id: json['id'] as String,
      retailer: json['retailer'] as String,
      title: json['title'] as String,
      note: json['note'] as String? ?? '',
      link: json['link'] as String? ?? '',
      dateAdded: DateTime.parse(json['dateAdded'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'retailer': retailer,
      'title': title,
      'note': note,
      'link': link,
      'dateAdded': dateAdded.toIso8601String(),
    };
  }
}
