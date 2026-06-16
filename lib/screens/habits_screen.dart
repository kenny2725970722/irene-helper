import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/hobby_record.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  int _waterCount = 0;
  String _waterDate = '';
  List<String> _skincareDates = [];
  List<int> _skincareDays = [1, 3, 5]; // Mon=1, Wed=3, Fri=5 (default)
  List<HobbyRecord> _hobbies = [];
  bool _loading = true;
  bool _waterNotifyOn = false;
  bool _skincareNotifyOn = false;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _dayFullNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Water
    final savedDate = await StorageService.loadString('water_date');
    final count = await StorageService.loadInt('water_count');
    if (savedDate == todayStr) {
      _waterCount = count;
    } else {
      _waterCount = 0; // reset for new day
    }
    _waterDate = todayStr;

    // Skincare
    final skincare = await StorageService.loadList('skincare_done');
    _skincareDates = skincare.map((e) => e['date'] as String).toList();
    // Load saved skincare days
    final savedDays = await StorageService.loadList('skincare_days');
    if (savedDays.isNotEmpty) {
      _skincareDays = savedDays.map((e) => e['day'] as int).toList();
      _skincareDays.sort();
    }

    // Hobbies
    final hobbyData = await StorageService.loadList('hobbies');
    _hobbies = hobbyData.map((e) => HobbyRecord.fromJson(e)).toList();
    _hobbies.sort((a, b) => b.date.compareTo(a.date));

    // Notification preferences
    _waterNotifyOn = await StorageService.loadInt('water_notify') == 1;
    _skincareNotifyOn = await StorageService.loadInt('skincare_notify') == 1;

    setState(() => _loading = false);
  }

  Future<void> _drinkWater() async {
    if (_waterCount >= 8) return;
    HapticFeedback.lightImpact();
    setState(() => _waterCount++);
    await StorageService.saveInt('water_count', _waterCount);
    await StorageService.saveString('water_date', _waterDate);
    if (_waterCount >= 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 8 glasses! Hydration goal reached!'), duration: Duration(seconds: 3), behavior: SnackBarBehavior.floating),
      );
    }
  }

  List<String> get _maskDaysThisWeek {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return _skincareDays.map((day) {
      final date = monday.add(Duration(days: day - 1));
      return DateFormat('yyyy-MM-dd').format(date);
    }).toList();
  }

  String get _skincareDaysLabel {
    return _skincareDays.map((d) => _dayNames[d - 1]).join(' • ');
  }

  Future<void> _toggleSkincare(String date) async {
    HapticFeedback.selectionClick();
    setState(() {
      if (_skincareDates.contains(date)) {
        _skincareDates.remove(date);
      } else {
        _skincareDates.add(date);
      }
    });
    await StorageService.saveList(
      'skincare_done',
      _skincareDates.map((d) => {'date': d}).toList(),
    );
    final done = _maskDaysThisWeek.where((d) => _skincareDates.contains(d)).length;
    if (done == _skincareDays.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🧖 All skincare done this week!'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _editSkincareDays() async {
    final selected = Set<int>.from(_skincareDays);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('🧖 Skincare Days'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(7, (i) {
              final day = i + 1;
              return CheckboxListTile(
                value: selected.contains(day),
                title: Text(_dayFullNames[i]),
                onChanged: (val) {
                  setDialog(() {
                    if (val == true) {
                      selected.add(day);
                    } else {
                      selected.remove(day);
                    }
                  });
                },
              );
            }),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selected.isEmpty
                  ? null
                  : () {
                      setState(() {
                        _skincareDays = selected.toList()..sort();
                      });
                      StorageService.saveList(
                        'skincare_days',
                        _skincareDays.map((d) => {'day': d}).toList(),
                      );
                      Navigator.pop(ctx);
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addHobbyLog() async {
    final nameCtrl = TextEditingController(text: 'Calligraphy');
    final notesCtrl = TextEditingController();
    DateTime practiceDate = DateTime.now();
    int hours = 1;
    int minutes = 0;

    await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('✍️ Log Practice'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Hobby name'),
                ),
                const SizedBox(height: 12),
                // Date picker
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: practiceDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setDialog(() => practiceDate = picked);
                  },
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(DateFormat('MMM d, yyyy').format(practiceDate)),
                ),
                const SizedBox(height: 12),
                // Duration picker
                const Text('Time practiced', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Hours picker
                    Column(
                      children: [
                        const Text('Hours', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        SizedBox(
                          height: 120,
                          width: 70,
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 36,
                            diameterRatio: 1.8,
                            onSelectedItemChanged: (i) => hours = i,
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 25,
                              builder: (ctx, i) => Center(
                                child: Text(
                                  '$i',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: i == hours ? Colors.teal : Colors.grey.shade400,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Text(' : ', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    ),
                    // Minutes picker
                    Column(
                      children: [
                        const Text('Min', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        SizedBox(
                          height: 120,
                          width: 70,
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 36,
                            diameterRatio: 1.8,
                            onSelectedItemChanged: (i) => minutes = i * 5,
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 12,
                              builder: (ctx, i) => Center(
                                child: Text(
                                  '${i * 5}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: i * 5 == minutes ? Colors.teal : Colors.grey.shade400,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isEmpty || (hours == 0 && minutes == 0)) return;
                final totalHours = hours + (minutes / 60.0);
                final dateTime = DateTime(
                  practiceDate.year, practiceDate.month, practiceDate.day,
                  DateTime.now().hour, DateTime.now().minute,
                );
                HapticFeedback.mediumImpact();
                setState(() {
                  _hobbies.insert(0, HobbyRecord(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    hobbyName: nameCtrl.text,
                    hours: totalHours,
                    notes: notesCtrl.text,
                    date: dateTime,
                  ));
                });
                StorageService.saveList('hobbies', _hobbies);
                Navigator.pop(ctx, true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✍️ ${nameCtrl.text} — ${totalHours.toStringAsFixed(1)}h logged'), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Group hobbies by name for totals
    final hobbyTotals = <String, double>{};
    for (final h in _hobbies) {
      hobbyTotals[h.hobbyName] = (hobbyTotals[h.hobbyName] ?? 0) + h.hours;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('💧 Daily Habits'),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.mediumImpact();
          await _loadData();
        },
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── WATER ──
            _buildSectionCard(
              title: '💧 Water',
              subtitle: 'Stay hydrated — hourly reminders',
              trailing: Switch(
                value: _waterNotifyOn,
                activeTrackColor: Colors.blue.shade200,
                activeThumbColor: Colors.blue,
                onChanged: (val) async {
                  setState(() => _waterNotifyOn = val);
                  await StorageService.saveInt('water_notify', val ? 1 : 0);
                  if (val) {
                    await NotificationService.scheduleWaterReminders();
                  } else {
                    await NotificationService.cancelWaterReminders();
                  }
                },
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(8, (i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: GestureDetector(
                        onTap: () {
                          if (i < _waterCount) {
                            HapticFeedback.selectionClick();
                            setState(() => _waterCount--);
                            StorageService.saveInt('water_count', _waterCount);
                          }
                        },
                        child: Icon(
                          i < _waterCount ? Icons.water_drop : Icons.water_drop_outlined,
                          size: 32,
                          color: i < _waterCount ? Colors.blue : Colors.grey.shade300,
                        ),
                      ),
                    )),
                  ),
                  const SizedBox(height: 4),
                  Text('$_waterCount / 8 glasses today', style: TextStyle(color: Colors.grey.shade600)),
                  Text('Tap a drop to undo', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _waterCount >= 8 ? null : _drinkWater,
                    icon: const Icon(Icons.local_drink),
                    label: Text(_waterCount >= 8 ? 'Done for today! 🎉' : 'I Drank Water!'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── SKINCARE ──
            _buildSectionCard(
              title: '🧖 Skincare',
              subtitle: 'Cleansing mask — $_skincareDaysLabel',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _editSkincareDays,
                    icon: const Icon(Icons.edit_calendar, size: 20),
                    color: Colors.pink.shade400,
                    tooltip: 'Edit days',
                  ),
                  Switch(
                    value: _skincareNotifyOn,
                    activeTrackColor: Colors.pink.shade200,
                    activeThumbColor: Colors.pink,
                    onChanged: (val) async {
                      setState(() => _skincareNotifyOn = val);
                      await StorageService.saveInt('skincare_notify', val ? 1 : 0);
                      if (val) {
                        await NotificationService.scheduleSkincareReminders();
                      } else {
                        await NotificationService.cancelSkincareReminders();
                      }
                    },
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _maskDaysThisWeek.map((dateStr) {
                      final date = DateTime.parse(dateStr);
                      final isDone = _skincareDates.contains(dateStr);
                      return GestureDetector(
                        onTap: () => _toggleSkincare(dateStr),
                        child: Column(
                          children: [
                            Text(DateFormat('E').format(date), style: TextStyle(color: Colors.grey.shade600)),
                            const SizedBox(height: 4),
                            Icon(
                              isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: isDone ? Colors.pink : Colors.grey.shade300,
                              size: 32,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_maskDaysThisWeek.where((d) => _skincareDates.contains(d)).length} / ${_skincareDays.length} done this week',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── HOBBIES ──
            _buildSectionCard(
              title: '✍️ Hobbies',
              subtitle: 'Track your practice time',
              child: Column(
                children: [
                  if (hobbyTotals.isNotEmpty)
                    ...hobbyTotals.entries.map((e) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.star, color: Colors.amber),
                      title: Text(e.key),
                      trailing: Text('${e.value.toStringAsFixed(1)} hrs', style: const TextStyle(fontWeight: FontWeight.bold)),
                    )),
                  if (hobbyTotals.isEmpty)
                    Text('No hobbies logged yet', style: TextStyle(color: Colors.grey.shade400)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _addHobbyLog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Practice Log'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                if (trailing != null) trailing,
              ],
            ),
            Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
