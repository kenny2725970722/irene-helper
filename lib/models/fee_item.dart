/// A tutoring fee to collect from a parent/student.
class FeeItem {
  final String id;
  final String studentName;
  final double amount;
  final String note;
  final bool isPaid;
  final DateTime dateCreated;
  final DateTime? datePaid;
  final String? linkedEntryId; // finance entry ID for undo support

  FeeItem({
    required this.id,
    required this.studentName,
    required this.amount,
    this.note = '',
    this.isPaid = false,
    required this.dateCreated,
    this.datePaid,
    this.linkedEntryId,
  });

  factory FeeItem.fromJson(Map<String, dynamic> json) {
    return FeeItem(
      id: json['id'] as String,
      studentName: json['studentName'] as String,
      amount: (json['amount'] as num).toDouble(),
      note: json['note'] as String? ?? '',
      isPaid: json['isPaid'] as bool,
      dateCreated: DateTime.parse(json['dateCreated'] as String),
      datePaid: json['datePaid'] != null
          ? DateTime.parse(json['datePaid'] as String)
          : null,
      linkedEntryId: json['linkedEntryId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentName': studentName,
      'amount': amount,
      'note': note,
      'isPaid': isPaid,
      'dateCreated': dateCreated.toIso8601String(),
      'datePaid': datePaid?.toIso8601String(),
      'linkedEntryId': linkedEntryId,
    };
  }

  /// Return a copy with the given fields replaced (used for marking paid).
  FeeItem copyWith({
    String? id,
    String? studentName,
    double? amount,
    String? note,
    bool? isPaid,
    DateTime? dateCreated,
    DateTime? datePaid,
    String? linkedEntryId,
    bool clearLinkedEntryId = false,
    bool clearDatePaid = false,
  }) {
    return FeeItem(
      id: id ?? this.id,
      studentName: studentName ?? this.studentName,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      isPaid: isPaid ?? this.isPaid,
      dateCreated: dateCreated ?? this.dateCreated,
      datePaid: clearDatePaid ? null : (datePaid ?? this.datePaid),
      linkedEntryId:
          clearLinkedEntryId ? null : (linkedEntryId ?? this.linkedEntryId),
    );
  }
}
