/// A single set logged during a workout.
class WorkoutLog {
  final String id;
  final String exerciseName;
  final double weight; // in lbs
  final int reps;
  final int setNumber;
  final DateTime date;

  WorkoutLog({
    required this.id,
    required this.exerciseName,
    required this.weight,
    required this.reps,
    required this.setNumber,
    required this.date,
  });

  factory WorkoutLog.fromJson(Map<String, dynamic> json) {
    return WorkoutLog(
      id: json['id'] as String,
      exerciseName: json['exerciseName'] as String,
      weight: (json['weight'] as num).toDouble(),
      reps: json['reps'] as int,
      setNumber: json['setNumber'] as int,
      date: DateTime.parse(json['date'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exerciseName': exerciseName,
      'weight': weight,
      'reps': reps,
      'setNumber': setNumber,
      'date': date.toIso8601String(),
    };
  }
}
