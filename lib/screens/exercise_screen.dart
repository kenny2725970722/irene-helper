import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/workout_log.dart';
import '../services/storage_service.dart';

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  // Timetable: day(1=Mon..7=Sun) → muscle group name
  Map<int, String> _timetable = {};
  // Custom exercises per day
  Map<int, List<String>> _customExercises = {};
  // Today's workout logs
  List<WorkoutLog> _workoutLogs = [];
  // Check-ins
  List<String> _checkedInDates = [];
  bool _checkedInToday = false;
  // UI state
  final Set<int> _expandedExercises = {};
  bool _loading = true;
  bool _editMode = false;
  String? _selectedGroup; // null = use today's timetable

  // Rest timer
  int _restSeconds = 0;
  int _restTotal = 60;
  bool _restRunning = false;
  Timer? _restTimer;

  // All possible muscle groups
  static const _muscleGroups = ['chest', 'legs', 'back', 'shoulders', 'arms', 'cardio', 'rest'];
  static const _muscleEmojis = {
    'chest': '🏆', 'legs': '🦵', 'back': '🏋️',
    'shoulders': '💪', 'arms': '✊', 'cardio': '🏃', 'rest': '😴',
  };

  // Default exercises per muscle group
  static const _defaultExercises = {
    'chest': ['Bench Press', 'Incline Dumbbell Press', 'Cable Flyes', 'Push-Ups', 'Dips'],
    'legs': ['Squats', 'Lunges', 'Leg Press', 'Calf Raises', 'Romanian Deadlift'],
    'back': ['Pull-Ups', 'Barbell Row', 'Lat Pulldown', 'Face Pulls', 'Deadlift'],
    'shoulders': ['Overhead Press', 'Lateral Raise', 'Front Raise', 'Rear Delt Fly', 'Shrugs'],
    'arms': ['Barbell Curl', 'Tricep Pushdown', 'Hammer Curl', 'Skull Crushers', 'Preacher Curl'],
    'cardio': ['30 min Run', 'Jump Rope', 'Cycling', 'Stretching'],
    'rest': ['Light stretching', 'Foam rolling', 'Walk outdoors', 'Recovery! 🌸'],
  };

  // Default timetable
  static const _defaultTimetable = {
    1: 'chest', 2: 'legs', 3: 'back', 4: 'shoulders', 5: 'arms', 6: 'cardio', 7: 'rest',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  String _dateStr(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _loadData() async {
    // Timetable
    final ttData = await StorageService.loadList('exercise_timetable');
    if (ttData.isEmpty) {
      _timetable = Map.from(_defaultTimetable);
    } else {
      _timetable = {for (var e in ttData) e['day'] as int: e['group'] as String};
    }

    // Custom exercises
    final exData = await StorageService.loadList('exercise_routine');
    if (exData.isEmpty) {
      _customExercises = {};
    } else {
      _customExercises = {};
      for (var e in exData) {
        _customExercises[e['day'] as int] = List<String>.from(e['exercises'] as List);
      }
    }

    // Workout logs
    final logData = await StorageService.loadList('workout_logs');
    _workoutLogs = logData.map((e) => WorkoutLog.fromJson(e)).toList()
      ..sort((a, b) => a.setNumber.compareTo(b.setNumber));

    // Check-ins
    final chkData = await StorageService.loadList('exercise_checkins');
    final todayStr = _dateStr(DateTime.now());
    _checkedInDates = chkData.map((e) => e['date'] as String).toList();
    _checkedInToday = _checkedInDates.contains(todayStr);

    setState(() => _loading = false);
  }

  // ── Today's data ──

  int get _today => DateTime.now().weekday;
  String get _activeGroup => _selectedGroup ?? (_timetable[_today] ?? 'rest');
  String get _activeEmoji => _muscleEmojis[_activeGroup] ?? '💪';
  String get _activeTitle => '${_activeGroup.toUpperCase()} DAY';
  bool get _isOverridden => _selectedGroup != null && _selectedGroup != (_timetable[_today] ?? 'rest');

  List<String> get _todayExercises {
    // Use selected group for exercise list, but day-based for custom exercise storage
    final day = _selectedGroup != null ? _today : _today;
    if (_customExercises.containsKey(day)) return _customExercises[day]!;
    // For overridden day, use default exercises for that muscle group
    return List.from(_defaultExercises[_activeGroup] ?? ['Rest & recover! 🌸']);
  }

  List<WorkoutLog> _logsFor(String exercise) {
    return _workoutLogs.where((l) => l.exerciseName == exercise).toList();
  }

  // ── Save helpers ──

  Future<void> _saveTimetable() async {
    await StorageService.saveList(
      'exercise_timetable',
      _timetable.entries.map((e) => {'day': e.key, 'group': e.value}).toList(),
    );
  }

  Future<void> _saveExercises() async {
    await StorageService.saveList(
      'exercise_routine',
      _customExercises.entries.map((e) => {'day': e.key, 'exercises': e.value}).toList(),
    );
  }

  Future<void> _saveLogs() async {
    await StorageService.saveList('workout_logs', _workoutLogs);
  }

  // ── Timetable dialog ──

  void _showTimetable() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('📅 Weekly Timetable'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [1, 2, 3, 4, 5, 6, 7].map((day) {
                final dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 40, child: Text(dayNames[day], style: const TextStyle(fontWeight: FontWeight.bold))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _timetable[day] ?? 'rest',
                          items: _muscleGroups.map((g) => DropdownMenuItem(
                            value: g,
                            child: Text('${_muscleEmojis[g]} ${g[0].toUpperCase()}${g.substring(1)}'),
                          )).toList(),
                          onChanged: (v) => setDialog(() => _timetable[day] = v!),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                setState(() {});
                _saveTimetable();
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Add/Edit exercises ──

  void _addExercise() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('✏️ Add Exercise'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Exercise name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.isEmpty) return;
              setState(() {
                _customExercises.putIfAbsent(_today, () => []);
                _customExercises[_today]!.add(ctrl.text);
              });
              _saveExercises();
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _renameExercise(int index) {
    final ctrl = TextEditingController(text: _todayExercises[index]);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('✏️ Rename Exercise'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.isEmpty) return;
              setState(() {
                _customExercises.putIfAbsent(_today, () => List.from(_todayExercises));
                _customExercises[_today]![index] = ctrl.text;
              });
              _saveExercises();
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteExercise(int index) {
    setState(() {
      _customExercises.putIfAbsent(_today, () => List.from(_todayExercises));
      _customExercises[_today]!.removeAt(index);
    });
    _saveExercises();
  }

  // ── Weight/Rep logging ──

  void _logSet(String exerciseName, int setNum) {
    final weightCtrl = TextEditingController();
    final repsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$exerciseName — Set $setNum'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: weightCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Weight (lbs)'),
              ),
            ),
            const SizedBox(width: 12),
            const Text('×', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: repsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Reps'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final w = double.tryParse(weightCtrl.text);
              final r = int.tryParse(repsCtrl.text);
              if (w == null || r == null) return;
              setState(() {
                _workoutLogs.add(WorkoutLog(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  exerciseName: exerciseName,
                  weight: w,
                  reps: r,
                  setNumber: setNum,
                  date: DateTime.now(),
                ));
              });
              _saveLogs();
              Navigator.pop(ctx);
            },
            child: const Text('Log Set'),
          ),
        ],
      ),
    );
  }

  void _deleteSet(WorkoutLog log) {
    setState(() {
      _workoutLogs.remove(log);
    });
    _saveLogs();
  }

  // ── Rest Timer ──

  void _startRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _restSeconds = _restTotal;
      _restRunning = true;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_restSeconds > 0) {
          _restSeconds--;
        } else {
          _restRunning = false;
          timer.cancel();
        }
      });
    });
  }

  void _pauseRestTimer() {
    _restTimer?.cancel();
    setState(() => _restRunning = false);
  }

  void _resetRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _restRunning = false;
      _restSeconds = 0;
    });
  }

  String _restProgress() {
    if (_restTotal == 0) return '0.0';
    return ((_restTotal - _restSeconds) / _restTotal).clamp(0.0, 1.0).toStringAsFixed(2);
  }

  // ── Check-in ──

  Future<void> _checkIn() async {
    final todayStr = _dateStr(DateTime.now());
    setState(() {
      _checkedInDates.add(todayStr);
      _checkedInToday = true;
    });
    await StorageService.saveList('exercise_checkins', _checkedInDates.map((d) => {'date': d}).toList());
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final themeColor = Colors.teal;
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('💪 Exercise'),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Weekly Timetable',
            onPressed: _showTimetable,
          ),
          IconButton(
            icon: Icon(_editMode ? Icons.check : Icons.edit),
            tooltip: _editMode ? 'Done editing' : 'Edit exercises',
            onPressed: () => setState(() => _editMode = !_editMode),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Today's Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [themeColor.shade400, themeColor.shade700]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(_activeEmoji, style: const TextStyle(fontSize: 42)),
                  const SizedBox(height: 4),
                  Text(_activeTitle, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(DateFormat('EEEE').format(DateTime.now()), style: TextStyle(fontSize: 15, color: Colors.white70)),
                ],
              ),
            ),
            // ── Override indicator ──
            if (_isOverridden)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '(overriding ${_muscleEmojis[_timetable[_today] ?? 'rest']} ${(_timetable[_today] ?? 'rest').toUpperCase()} day)',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 8),

            // ── Day Picker Chips ──
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _muscleGroups.where((g) => g != 'rest').map((group) {
                  final isSelected = _activeGroup == group;
                  final isScheduled = (_timetable[_today] ?? 'rest') == group;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_muscleEmojis[group]!, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(group[0].toUpperCase() + group.substring(1),
                              style: const TextStyle(fontSize: 12)),
                          if (isScheduled) const Text(' 📅', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedGroup = group;
                          } else {
                            _selectedGroup = null; // revert to timetable
                          }
                        });
                      },
                      selectedColor: Colors.deepOrange.shade100,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // ── Exercise Cards ──
            ...List.generate(_todayExercises.length, (i) {
              final ex = _todayExercises[i];
              final isExpanded = _expandedExercises.contains(i);
              final logs = _logsFor(ex);

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    // Header row
                    ListTile(
                      leading: Icon(Icons.fitness_center, color: themeColor),
                      title: Text(ex, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_editMode)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              onPressed: () => _deleteExercise(i),
                            ),
                          if (_editMode)
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _renameExercise(i),
                            ),
                          if (logs.isNotEmpty)
                            Text('${logs.length} sets', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                          const SizedBox(width: 4),
                          Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                      onTap: _editMode ? null : () => setState(() {
                        isExpanded ? _expandedExercises.remove(i) : _expandedExercises.add(i);
                      }),
                    ),

                    // Expanded: show logged sets
                    if (isExpanded) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            ...List.generate(logs.length, (j) {
                              final log = logs[j];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Text('Set ${log.setNumber}: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                    Text('${log.weight.toStringAsFixed(0)} lbs × ${log.reps} reps',
                                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: () => _deleteSet(log),
                                      child: const Icon(Icons.close, color: Colors.red, size: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _logSet(ex, logs.length + 1),
                                icon: const Icon(Icons.add, size: 18),
                                label: Text('Add Set ${logs.length + 1}'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),

            // ── Add Exercise ──
            if (_editMode)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _addExercise,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Exercise'),
                  ),
                ),
              ),
            const SizedBox(height: 8),

            // ── Rest Timer ──
            Card(
              color: _restRunning ? Colors.blue.shade50 : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text('⏱️', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(
                          _restRunning ? 'Rest: ${_restSeconds}s' : 'Rest Timer',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (_restRunning)
                          TextButton(onPressed: _pauseRestTimer, child: const Text('Stop'))
                        else
                          TextButton(onPressed: _startRestTimer, child: const Text('▶ Start')),
                      ],
                    ),
                    if (_restRunning) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: double.parse(_restProgress()),
                        backgroundColor: Colors.grey.shade200,
                        color: Colors.blue,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [60, 90, 120].map((t) {
                        final isActive = _restTotal == t;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text('${t}s'),
                            selected: isActive,
                            onSelected: (_) => setState(() { _restTotal = t; _resetRestTimer(); }),
                            selectedColor: Colors.blue.shade100,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Check-In Button ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _checkedInToday ? null : _checkIn,
                icon: Icon(_checkedInToday ? Icons.check_circle : Icons.fitness_center, size: 28),
                label: Text(_checkedInToday ? '✅ Workout Complete!' : 'I WORKED OUT TODAY!',
                    style: const TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _checkedInToday ? Colors.green : themeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  disabledBackgroundColor: Colors.green.shade300,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Weekly Streak ──
            Text('This Week', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (i) {
                final day = DateTime.now().subtract(Duration(days: DateTime.now().weekday - i - 1));
                final dayStr = _dateStr(day);
                final checked = _checkedInDates.contains(dayStr);
                return Column(
                  children: [
                    Text(weekDays[i], style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    const SizedBox(height: 4),
                    Icon(
                      checked ? Icons.check_circle : Icons.circle_outlined,
                      color: checked ? Colors.green : Colors.grey.shade300,
                      size: 20,
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
