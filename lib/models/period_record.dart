/// A period tracking record (one per cycle).
class PeriodRecord {
  final String id;
  final DateTime startDate;
  final DateTime? endDate; // null if period is ongoing or not set
  final String cramps; // none, mild, moderate, severe
  final String flow; // light, medium, heavy
  final String mood;
  final String notes;

  PeriodRecord({
    required this.id,
    required this.startDate,
    this.endDate,
    this.cramps = 'none',
    this.flow = 'medium',
    this.mood = '',
    this.notes = '',
  });

  /// Duration in days, or null if endDate is not set.
  int? get durationDays =>
      endDate != null ? endDate!.difference(startDate).inDays + 1 : null;

  factory PeriodRecord.fromJson(Map<String, dynamic> json) {
    return PeriodRecord(
      id: json['id'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      cramps: json['cramps'] as String? ?? 'none',
      flow: json['flow'] as String? ?? 'medium',
      mood: json['mood'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'cramps': cramps,
      'flow': flow,
      'mood': mood,
      'notes': notes,
    };
  }
}
