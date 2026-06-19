/// A single income or expense entry.
class FinanceEntry {
  final String id;
  final double amount;
  final bool isIncome; // true = income, false = expense
  final String category;
  final String note;
  final DateTime date;
  final String paymentMethod; // e.g. Cash, Credit Card, PayMe, Bank Transfer

  FinanceEntry({
    required this.id,
    required this.amount,
    required this.isIncome,
    required this.category,
    this.note = '',
    required this.date,
    this.paymentMethod = 'Cash',
  });

  /// Create from JSON (stored in SharedPreferences)
  factory FinanceEntry.fromJson(Map<String, dynamic> json) {
    return FinanceEntry(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      isIncome: json['isIncome'] as bool,
      category: json['category'] as String,
      note: json['note'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
      paymentMethod: json['paymentMethod'] as String? ?? 'Cash',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'isIncome': isIncome,
      'category': category,
      'note': note,
      'date': date.toIso8601String(),
      'paymentMethod': paymentMethod,
    };
  }
}
