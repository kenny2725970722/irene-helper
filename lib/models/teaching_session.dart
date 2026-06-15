/// A scheduled teaching session.
class TeachingSession {
  final String id;
  final DateTime dateTime;
  final String studentName;
  final String subject;

  TeachingSession({
    required this.id,
    required this.dateTime,
    required this.studentName,
    required this.subject,
  });

  factory TeachingSession.fromJson(Map<String, dynamic> json) {
    return TeachingSession(
      id: json['id'] as String,
      dateTime: DateTime.parse(json['dateTime'] as String),
      studentName: json['studentName'] as String,
      subject: json['subject'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dateTime': dateTime.toIso8601String(),
      'studentName': studentName,
      'subject': subject,
    };
  }
}
