import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/wheel.dart';
import '../services/storage_service.dart';
import 'wheel_edit_screen.dart';
import 'wheel_spin_screen.dart';

/// Catch-all tab — currently home to the decision wheels.
class OtherScreen extends StatefulWidget {
  const OtherScreen({super.key});

  @override
  State<OtherScreen> createState() => _OtherScreenState();
}

class _OtherScreenState extends State<OtherScreen> {
  static const _storageKey = 'wheels';
  static const _sampleName = '今天吃什麼';
  static const _sampleOptions = ['火鍋', '壽司', '拉麵', '水餃', '燒烤'];

  List<Wheel> _wheels = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    var wheels = <Wheel>[];
    try {
      final data = await StorageService.loadList(_storageKey);
      wheels = data.map((e) => Wheel.fromJson(e)).toList();
    } catch (_) {
      wheels = [];
    }

    // Deleting every wheel brings the sample back, so the tab is never empty.
    if (wheels.isEmpty) {
      wheels = [
        Wheel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: _sampleName,
          options: List.of(_sampleOptions),
        ),
      ];
      await StorageService.saveList(_storageKey, wheels);
    }

    if (!mounted) return;
    setState(() {
      _wheels = wheels;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await StorageService.saveList(_storageKey, _wheels);
  }

  Future<void> _openSpin(Wheel wheel) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WheelSpinScreen(
          wheel: wheel,
          onChanged: (updated) {
            final i = _wheels.indexWhere((w) => w.id == updated.id);
            if (i < 0) return;
            setState(() => _wheels[i] = updated);
            _save();
          },
        ),
      ),
    );
  }

  Future<void> _editWheel(Wheel? wheel) async {
    final result = await Navigator.of(context).push<Wheel>(
      MaterialPageRoute(builder: (_) => WheelEditScreen(wheel: wheel)),
    );
    if (result == null || !mounted) return;

    final i = _wheels.indexWhere((w) => w.id == result.id);
    setState(() {
      if (i < 0) {
        _wheels.add(result);
      } else {
        _wheels[i] = result;
      }
    });
    await _save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(i < 0 ? '✅ 已新增轉盤' : '✅ 已儲存變更'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteWheel(Wheel wheel) async {
    HapticFeedback.heavyImpact();
    setState(() => _wheels.removeWhere((w) => w.id == wheel.id));
    await _save();

    if (_wheels.isEmpty) {
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑 已刪除全部轉盤，已重建範例'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🗑 已刪除轉盤'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _confirmDelete(Wheel wheel) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除轉盤？'),
        content: Text('確定要刪除「${wheel.name}」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🧰 Other'),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.mediumImpact();
          await _loadData();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              '🎡 決策轉盤',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '選擇困難的時候，交給轉盤',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 12),
            ..._wheels.map(
              (w) => Card(
                elevation: 2,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Dismissible(
                  key: Key(w.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) => _confirmDelete(w),
                  onDismissed: (_) => _deleteWheel(w),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.shade50,
                      child: const Text('🎡'),
                    ),
                    title: Text(
                      w.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text('${w.options.length} 個選項'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          color: Colors.teal,
                          tooltip: '編輯轉盤',
                          onPressed: () => _editWheel(w),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => _openSpin(w),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _editWheel(null),
              icon: const Icon(Icons.add),
              label: const Text('新增轉盤'),
            ),
          ],
        ),
      ),
    );
  }
}
