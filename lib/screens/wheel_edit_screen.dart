import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/wheel.dart';

/// Creates a wheel when [wheel] is null, edits it otherwise.
///
/// Pops the finished [Wheel], or null if the user backs out.
class WheelEditScreen extends StatefulWidget {
  final Wheel? wheel;

  const WheelEditScreen({super.key, this.wheel});

  @override
  State<WheelEditScreen> createState() => _WheelEditScreenState();
}

class _WheelEditScreenState extends State<WheelEditScreen> {
  late final TextEditingController _nameCtrl;
  final List<TextEditingController> _optionCtrls = [];

  bool get _isNew => widget.wheel == null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.wheel?.name ?? '');
    for (final o in widget.wheel?.options ?? const <String>[]) {
      _optionCtrls.add(TextEditingController(text: o));
    }
    if (_optionCtrls.isEmpty) {
      _optionCtrls
        ..add(TextEditingController())
        ..add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _cleanOptions => _optionCtrls
      .map((c) => c.text.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  bool get _canSave =>
      _nameCtrl.text.trim().isNotEmpty && _cleanOptions.isNotEmpty;

  void _save() {
    if (!_canSave) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(Wheel(
      id: widget.wheel?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      options: _cleanOptions,
    ));
  }

  void _removeOption(int i) {
    final removed = _optionCtrls.removeAt(i);
    setState(() {});
    // The field is still mounted this frame; dispose once it is gone.
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_nameCtrl, ..._optionCtrls]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? '🎡 新增轉盤' : '🎡 編輯轉盤'),
          centerTitle: true,
          backgroundColor: Colors.teal.shade700,
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: _isNew,
              decoration: const InputDecoration(
                labelText: '轉盤名稱',
                hintText: '例如：今天吃什麼',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text(
                  '選項',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_cleanOptions.length} 個',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(_optionCtrls.length, _buildOptionRow),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () =>
                  setState(() => _optionCtrls.add(TextEditingController())),
              icon: const Icon(Icons.add),
              label: const Text('新增選項'),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _canSave ? _save : null,
              icon: const Icon(Icons.check),
              label: const Text('儲存'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionRow(int i) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _optionCtrls[i],
              decoration: InputDecoration(
                hintText: '選項 ${i + 1}',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
            tooltip: '刪除選項',
            onPressed: _optionCtrls.length <= 1 ? null : () => _removeOption(i),
          ),
        ],
      ),
    );
  }
}
