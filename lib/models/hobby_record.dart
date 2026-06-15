/// A hobby practice log entry.
class HobbyRecord {
  final String id;
  final String hobbyName;
  final double hours;
  final String notes;
  final DateTime date;

  HobbyRecord({
    required this.id,
    required this.hobbyName,
    required this.hours,
    this.notes = '',
    required this.date,
  });

  factory HobbyRecord.fromJson(Map<String, dynamic> json) {
    return HobbyRecord(
      id: json['id'] as String,
      hobbyName: json['hobbyName'] as String,
      hours: (json['hours'] as num).toDouble(),
      notes: json['notes'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hobbyName': hobbyName,
      'hours': hours,
      'notes': notes,
      'date': date.toIso8601String(),
    };
  }
}
