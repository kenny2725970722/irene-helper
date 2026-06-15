import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/teaching_session.dart';
import '../models/period_record.dart';
import '../services/storage_service.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<TeachingSession> _sessions = [];
  List<PeriodRecord> _periods = [];
  bool _loading = true;

  // Exercise timetable
  Map<int, String> _timetable = {};
  static const _muscleEmojis = {
    'chest': '🏆', 'legs': '🦵', 'back': '🏋️',
    'shoulders': '💪', 'arms': '✊', 'cardio': '🏃', 'rest': '😴',
  };

  // Calendar state
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  Set<String> _exerciseDates = {};
  final Set<String> _waterDates = {};
  Set<String> _skincareDates = {};
  List<int> _skincareDays = [1, 3, 5]; // Mon, Wed, Fri default
  Set<String> _hobbyDates = {};
  Set<String> _financeDates = {};
  Set<String> _teachingDates = {};
  Set<String> _periodDates = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _dateStr(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _loadData() async {
    // Exercise timetable
    final ttData = await StorageService.loadList('exercise_timetable');
    if (ttData.isEmpty) {
      _timetable = {1: 'chest', 2: 'legs', 3: 'back', 4: 'shoulders', 5: 'arms', 6: 'cardio', 7: 'rest'};
    } else {
      _timetable = {for (var e in ttData) e['day'] as int: e['group'] as String};
    }

    // Teaching
    final sessionData = await StorageService.loadList('teaching_sessions');
    _sessions = sessionData.map((e) => TeachingSession.fromJson(e)).toList();
    _sessions.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    _teachingDates = _sessions.map((s) => _dateStr(s.dateTime)).toSet();

    // Period
    final periodData = await StorageService.loadList('period_records');
    _periods = periodData.map((e) => PeriodRecord.fromJson(e)).toList();
    _periods.sort((a, b) => b.startDate.compareTo(a.startDate));
    // Build set of all period days for calendar highlighting
    _periodDates = {};
    for (final p in _periods) {
      final end = p.endDate ?? p.startDate;
      var d = p.startDate;
      while (!d.isAfter(end)) {
        _periodDates.add(_dateStr(d));
        d = d.add(const Duration(days: 1));
      }
    }

    // Exercise check-ins
    final exerciseData = await StorageService.loadList('exercise_checkins');
    _exerciseDates = exerciseData.map((e) => e['date'] as String).toSet();

    // Water (today only from storage, but we track historically)
    final waterDate = await StorageService.loadString('water_date');
    final waterCount = await StorageService.loadInt('water_count');
    if (waterDate.isNotEmpty && waterCount >= 8) {
      _waterDates.add(waterDate);
    }

    // Skincare
    final skincareData = await StorageService.loadList('skincare_done');
    _skincareDates = skincareData.map((e) => e['date'] as String).toSet();
    final savedSkincareDays = await StorageService.loadList('skincare_days');
    if (savedSkincareDays.isNotEmpty) {
      _skincareDays = savedSkincareDays.map((e) => e['day'] as int).toList();
    }

    // Hobbies
    final hobbyData = await StorageService.loadList('hobbies');
    _hobbyDates = hobbyData.map((e) {
      final d = DateTime.parse(e['date'] as String);
      return _dateStr(d);
    }).toSet();

    // Finance
    final financeData = await StorageService.loadList('finance_entries');
    _financeDates = financeData.map((e) {
      final d = DateTime.parse(e['date'] as String);
      return _dateStr(d);
    }).toSet();

    setState(() => _loading = false);
  }

  // ── Day Status Calculator ──

  /// Returns a score for this date: 0=nothing, 1=some, 2=all done, 3=perfect
  int _dayStatus(DateTime day) {
    final ds = _dateStr(day);
    final weekday = day.weekday;
    int tasks = 0;
    int done = 0;

    // Exercise (not required on Sunday)
    if (weekday != DateTime.sunday) {
      tasks++;
      if (_exerciseDates.contains(ds)) done++;
    }

    // Water (always required)
    tasks++;
    if (_waterDates.contains(ds)) done++;

    // Skincare (user-selected days)
    if (_skincareDays.contains(weekday)) {
      tasks++;
      if (_skincareDates.contains(ds)) done++;
    }

    // Bonus: hobbies, finance, teaching — not required but show activity
    final hasBonus = _hobbyDates.contains(ds) || _financeDates.contains(ds) || _teachingDates.contains(ds);

    if (tasks == 0) return hasBonus ? 1 : 0; // Sunday with bonus = some
    if (done == tasks) return hasBonus ? 3 : 2; // all done
    if (done > 0) return 1; // some done
    return 0; // nothing done
  }

  // ── Calendar ──

  void _prevMonth() {
    setState(() {
      _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 1);
    });
  }

  Widget _buildCalendar() {
    final daysInMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_calendarMonth.year, _calendarMonth.month, 1).weekday; // 1=Mon, 7=Sun
    final today = DateTime.now();
    const weekHeaders = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Month header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left)),
                Text(
                  DateFormat('MMMM yyyy').format(_calendarMonth),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right)),
              ],
            ),
            const SizedBox(height: 8),

            // Day headers
            Row(
              children: weekHeaders.map((d) => Expanded(
                child: Center(
                  child: Text(d, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                ),
              )).toList(),
            ),
            const SizedBox(height: 4),

            // Day grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.75,
              ),
              itemCount: firstWeekday - 1 + daysInMonth,
              itemBuilder: (ctx, index) {
                final dayOffset = index - (firstWeekday - 1);
                if (dayOffset < 0) return const SizedBox();

                final day = dayOffset + 1;
                final date = DateTime(_calendarMonth.year, _calendarMonth.month, day);
                final isToday = _dateStr(date) == _dateStr(today);
                final isPeriodDay = _periodDates.contains(_dateStr(date));
                final status = date.isAfter(DateTime.now()) ? -1 : _dayStatus(date);

                return GestureDetector(
                  onTap: () {
                    // Show day summary
                    _showDaySummary(date, status);
                  },
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isPeriodDay
                          ? Colors.pink.shade100
                          : isToday
                              ? Colors.purple.shade50
                              : null,
                      borderRadius: BorderRadius.circular(8),
                      border: isPeriodDay
                          ? Border.all(color: Colors.pink.shade300, width: 1.5)
                          : isToday
                              ? Border.all(color: Colors.purple.shade300, width: 2)
                              : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            color: isToday ? Colors.purple.shade700 : null,
                          ),
                        ),
                        // Exercise emoji from timetable
                        Text(
                          _muscleEmojis[_timetable[date.weekday] ?? 'rest'] ?? '💪',
                          style: TextStyle(fontSize: 12),
                        ),
                        if (status >= 0)
                          _statusIcon(status),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Legend
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendItem('✅', 'All done', Colors.green),
                const SizedBox(width: 16),
                _legendItem('🟡', 'Partial', Colors.amber),
                const SizedBox(width: 16),
                _legendItem('⚪', 'Not yet', Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon(int status) {
    switch (status) {
      case 3: return const Text('⭐', style: TextStyle(fontSize: 12));
      case 2: return const Text('✅', style: TextStyle(fontSize: 11));
      case 1: return const Text('🟡', style: TextStyle(fontSize: 10));
      default: return Icon(Icons.circle_outlined, size: 10, color: Colors.grey.shade300);
    }
  }

  Widget _legendItem(String emoji, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  void _showDaySummary(DateTime date, int status) {
    final ds = _dateStr(date);
    final details = <String>[];

    // Show planned exercise for this day
    final group = _timetable[date.weekday] ?? 'rest';
    final emoji = _muscleEmojis[group] ?? '💪';
    final groupName = group[0].toUpperCase() + group.substring(1);
    if (_periodDates.contains(ds)) details.add('🩸 Period day');
    if (_exerciseDates.contains(ds)) {
      details.add('$emoji $groupName — Done! ✅');
    } else {
      details.add('$emoji $groupName (planned)');
    }
    if (_waterDates.contains(ds)) details.add('💧 8+ glasses water');
    if (_skincareDates.contains(ds)) details.add('🧖 Mask applied');
    if (_hobbyDates.contains(ds)) details.add('✍️ Hobby practiced');
    if (_financeDates.contains(ds)) details.add('💰 Transactions logged');
    if (_teachingDates.contains(ds)) details.add('📚 Teaching session');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('📅 ${DateFormat('MMM d, yyyy').format(date)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (status == 3)
              const Text('⭐ Perfect day!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))
            else if (status == 2)
              const Text('✅ All tasks done!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))
            else if (status == 1)
              Text('🟡 Some tasks done', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade700))
            else if (status == 0)
              const Text('⚪ Nothing logged', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            if (details.isEmpty)
              const Text('No activity recorded this day.', style: TextStyle(color: Colors.grey))
            else
              ...details.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(d, style: const TextStyle(fontSize: 15)),
              )),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  // ── Teaching ──
  Future<void> _addSession() async {
    final studentCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    DateTime date = DateTime.now();
    TimeOfDay time = const TimeOfDay(hour: 14, minute: 0);

    await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('📚 Add Teaching Session'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: studentCtrl, decoration: const InputDecoration(labelText: 'Student Name')),
              const SizedBox(height: 8),
              TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: 'Subject')),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx, initialDate: date,
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setDialog(() => date = picked);
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(DateFormat('MMM d, yyyy').format(date)),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(context: ctx, initialTime: time);
                      if (picked != null) setDialog(() => time = picked);
                    },
                    icon: const Icon(Icons.access_time),
                    label: Text(time.format(ctx)),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (studentCtrl.text.isEmpty || subjectCtrl.text.isEmpty) return;
                final session = TeachingSession(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  dateTime: DateTime(date.year, date.month, date.day, time.hour, time.minute),
                  studentName: studentCtrl.text,
                  subject: subjectCtrl.text,
                );
                setState(() {
                  _sessions.add(session);
                  _sessions.sort((a, b) => a.dateTime.compareTo(b.dateTime));
                  _teachingDates.add(_dateStr(session.dateTime));
                });
                StorageService.saveList('teaching_sessions', _sessions);
                Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteSession(TeachingSession s) {
    setState(() {
      _sessions.remove(s);
      _teachingDates = _sessions.map((t) => _dateStr(t.dateTime)).toSet();
    });
    StorageService.saveList('teaching_sessions', _sessions);
  }

  // ── Period ──
  Future<void> _logPeriod() async {
    DateTime startDate = DateTime.now();
    DateTime? endDate;
    String cramps = 'none';
    String flow = 'medium';
    final moodCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('🩸 Log Period'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx, initialDate: startDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 90)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setDialog(() => startDate = picked);
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text('Start: ${DateFormat('MMM d, yyyy').format(startDate)}'),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: endDate ?? startDate,
                      firstDate: startDate,
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setDialog(() => endDate = picked);
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(endDate != null
                      ? 'End: ${DateFormat('MMM d, yyyy').format(endDate!)}'
                      : 'End date (optional)'),
                ),
                if (endDate != null)
                  Text(
                    'Duration: ${endDate!.difference(startDate).inDays + 1} days',
                    style: TextStyle(fontSize: 12, color: Colors.pink.shade600),
                  ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: cramps,
                  items: ['none', 'mild', 'moderate', 'severe']
                      .map((c) => DropdownMenuItem(value: c, child: Text('Cramps: $c')))
                      .toList(),
                  onChanged: (v) => setDialog(() => cramps = v!),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: flow,
                  items: ['light', 'medium', 'heavy']
                      .map((f) => DropdownMenuItem(value: f, child: Text('Flow: $f')))
                      .toList(),
                  onChanged: (v) => setDialog(() => flow = v!),
                ),
                const SizedBox(height: 8),
                TextField(controller: moodCtrl, decoration: const InputDecoration(labelText: 'Mood (optional)')),
                const SizedBox(height: 8),
                TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes (optional)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final record = PeriodRecord(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  startDate: startDate, endDate: endDate,
                  cramps: cramps, flow: flow,
                  mood: moodCtrl.text, notes: notesCtrl.text,
                );
                setState(() {
                  _periods.insert(0, record);
                  _periods.sort((a, b) => b.startDate.compareTo(a.startDate));
                  // Update period dates set
                  final end = record.endDate ?? record.startDate;
                  var d = record.startDate;
                  while (!d.isAfter(end)) {
                    _periodDates.add(_dateStr(d));
                    d = d.add(const Duration(days: 1));
                  }
                });
                StorageService.saveList('period_records', _periods);
                Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String _predictNext() {
    if (_periods.isEmpty) return 'Not enough data';
    if (_periods.length == 1) {
      final next = _periods.first.startDate.add(const Duration(days: 28));
      return DateFormat('MMM d').format(next);
    }
    int totalDays = 0;
    for (int i = 0; i < _periods.length - 1; i++) {
      totalDays += _periods[i].startDate.difference(_periods[i + 1].startDate).inDays;
    }
    final avgCycle = (totalDays / (_periods.length - 1)).round();
    final next = _periods.first.startDate.add(Duration(days: avgCycle));
    return '${DateFormat('MMM d').format(next)} (${avgCycle}d cycle)';
  }

  String _avgLength() {
    final withEnd = _periods.where((p) => p.endDate != null).toList();
    if (withEnd.isEmpty) return '—';
    final total = withEnd.fold<int>(0, (sum, p) => sum + p.durationDays!);
    return '${(total / withEnd.length).toStringAsFixed(1)}d';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('📅 My Schedule'),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── MONTH CALENDAR ──
            _buildCalendar(),
            const SizedBox(height: 20),

            // ── TEACHING ──
            Row(
              children: [
                const Text('📚 Upcoming Teaching', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(onPressed: _addSession, icon: const Icon(Icons.add_circle, color: Colors.purple)),
              ],
            ),
            const SizedBox(height: 8),
            if (_sessions.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(child: Text('No teaching sessions yet.\nTap + to add one!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500))),
                ),
              ),
            ..._sessions.where((s) => s.dateTime.isAfter(DateTime.now().subtract(const Duration(hours: 1)))).map((s) => Card(
              child: Dismissible(
                key: Key(s.id),
                direction: DismissDirection.endToStart,
                background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: Colors.red, child: const Icon(Icons.delete, color: Colors.white)),
                onDismissed: (_) => _deleteSession(s),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: s.dateTime.isBefore(DateTime.now()) ? Colors.grey.shade200 : Colors.purple.shade100,
                    child: Text(s.subject[0].toUpperCase(), style: TextStyle(color: Colors.purple.shade700, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(s.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${DateFormat('EEE, MMM d • h:mm a').format(s.dateTime)} — ${s.subject}'),
                ),
              ),
            )),
            const SizedBox(height: 24),

            // ── PERIOD TRACKER ──
            Row(
              children: [
                const Text('🩸 Period Tracker', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _logPeriod,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Log'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pink.shade100, foregroundColor: Colors.pink.shade800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              color: Colors.pink.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _periodInfo('Last', _periods.isNotEmpty ? DateFormat('MMM d').format(_periods.first.startDate) : '—'),
                    _periodInfo('Predicted Next', _predictNext()),
                    _periodInfo('Avg Length', _avgLength()),
                    _periodInfo('Records', '${_periods.length}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_periods.isNotEmpty) ...[
              const Text('History', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ..._periods.take(6).map((p) => Card(
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(radius: 4, backgroundColor: _flowColor(p.flow)),
                  title: Text(
                    p.endDate != null
                        ? '${DateFormat('MMM d').format(p.startDate)} – ${DateFormat('MMM d, yyyy').format(p.endDate!)} (${p.durationDays}d)'
                        : DateFormat('MMMM d, yyyy').format(p.startDate),
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    [if (p.cramps != 'none') 'Cramps: ${p.cramps}', 'Flow: ${p.flow}', if (p.mood.isNotEmpty) 'Mood: ${p.mood}'].join(' • '),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Color _flowColor(String flow) {
    switch (flow) {
      case 'light': return Colors.pink.shade200;
      case 'medium': return Colors.pink.shade500;
      case 'heavy': return Colors.pink.shade800;
      default: return Colors.pink;
    }
  }

  Widget _periodInfo(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
