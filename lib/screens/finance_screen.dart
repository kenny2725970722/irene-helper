import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/finance_entry.dart';
import '../models/fee_item.dart';
import '../services/storage_service.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  List<FinanceEntry> _entries = [];
  List<FeeItem> _feeItems = [];
  bool _loading = true;

  static const _incomeCategories = ['Salary', 'Tutoring', 'Freelance', 'Other'];
  static const _expenseCategories = ['Food', 'Transport', 'Shopping', 'Bills', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final data = await StorageService.loadList('finance_entries');
    final feeData = await StorageService.loadList('fee_items');
    setState(() {
      _entries = data.map((e) => FinanceEntry.fromJson(e)).toList();
      _entries.sort((a, b) => b.date.compareTo(a.date)); // newest first
      _feeItems = feeData.map((e) => FeeItem.fromJson(e)).toList();
      _feeItems.sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
      _loading = false;
    });
  }

  Future<void> _saveEntries() async {
    await StorageService.saveList('finance_entries', _entries);
  }

  Future<void> _saveFeeItems() async {
    await StorageService.saveList('fee_items', _feeItems);
  }

  double get _todayIncome {
    final today = DateTime.now();
    return _entries
        .where((e) => e.isIncome && _isSameDay(e.date, today))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get _todayExpenses {
    final today = DateTime.now();
    return _entries
        .where((e) => !e.isIncome && _isSameDay(e.date, today))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showAddDialog({required bool isIncome}) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String category = isIncome ? _incomeCategories.first : _expenseCategories.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(isIncome ? '💰 Add Income' : '💸 Add Expense'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '\$ ',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                items: (isIncome ? _incomeCategories : _expenseCategories)
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setDialog(() => category = val!),
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text);
                if (amount == null || amount <= 0) return;
                setState(() {
                  _entries.insert(0, FinanceEntry(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    amount: amount,
                    isIncome: isIncome,
                    category: category,
                    note: noteCtrl.text,
                    date: DateTime.now(),
                  ));
                });
                _saveEntries();
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteEntry(FinanceEntry entry) {
    setState(() => _entries.remove(entry));
    _saveEntries();
  }

  void _showAddFeeDialog() {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('\u{1F393} Add Fee Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Student Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '\$ ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountCtrl.text);
              if (amount == null || amount <= 0 || nameCtrl.text.isEmpty) return;
              setState(() {
                _feeItems.insert(0, FeeItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  studentName: nameCtrl.text.trim(),
                  amount: amount,
                  note: noteCtrl.text,
                  dateCreated: DateTime.now(),
                ));
              });
              _saveFeeItems();
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _markFeePaid(FeeItem item) {
    if (item.isPaid) return; // no-op if already paid

    // Create linked finance entry
    final entryId = DateTime.now().millisecondsSinceEpoch.toString();
    final financeEntry = FinanceEntry(
      id: entryId,
      amount: item.amount,
      isIncome: true,
      category: 'Tutoring',
      note: 'Paid by ${item.studentName}',
      date: DateTime.now(),
    );

    setState(() {
      // Update fee item to paid
      final idx = _feeItems.indexOf(item);
      _feeItems[idx] = item.copyWith(
        isPaid: true,
        datePaid: DateTime.now(),
        linkedEntryId: entryId,
      );

      // Add income entry
      _entries.insert(0, financeEntry);
    });

    _saveFeeItems();
    _saveEntries();
  }

  void _deleteFeeItem(FeeItem item) {
    setState(() {
      _feeItems.remove(item);
    });
    _saveFeeItems();
  }

  void _undoFeePayment(FeeItem item) {
    setState(() {
      // Remove the linked finance entry
      if (item.linkedEntryId != null) {
        _entries.removeWhere((e) => e.id == item.linkedEntryId);
      }

      // Revert fee item to unpaid
      final idx = _feeItems.indexOf(item);
      _feeItems[idx] = item.copyWith(
        isPaid: false,
        clearDatePaid: true,
        clearLinkedEntryId: true,
      );
    });

    _saveFeeItems();
    _saveEntries();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final net = _todayIncome - _todayExpenses;
    final todayEntries = _entries.where((e) => _isSameDay(e.date, DateTime.now())).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('💰 Daily Finance'),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── Summary Card ──
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade400, Colors.teal.shade700],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  'Net Today: ${net >= 0 ? '+' : ''}\$${net.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _summaryItem('💵 Income', '\$${_todayIncome.toStringAsFixed(0)}', Colors.green.shade200),
                    _summaryItem('💸 Expenses', '\$${_todayExpenses.toStringAsFixed(0)}', Colors.red.shade200),
                  ],
                ),
              ],
            ),
          ),

          // ── Tutoring Fee Checklist ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('\u{1F393} Tutoring Fees', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                const Spacer(),
                IconButton(
                  onPressed: _showAddFeeDialog,
                  icon: const Icon(Icons.add_circle, color: Colors.teal),
                ),
              ],
            ),
          ),
          // Pending fees
          ..._feeItems.where((f) => !f.isPaid).map((item) => Dismissible(
            key: Key(item.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.red,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (_) => _deleteFeeItem(item),
            child: ListTile(
              leading: InkWell(
                onTap: () => _markFeePaid(item),
                child: Icon(Icons.check_box_outline_blank, color: Colors.grey.shade400),
              ),
              title: Text(item.studentName, style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(
                item.note.isNotEmpty ? item.note : DateFormat('MMM d').format(item.dateCreated),
              ),
              trailing: Text(
                '\$${item.amount.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange.shade700),
              ),
            ),
          )),
          // Paid fees (collapsible)
          if (_feeItems.any((f) => f.isPaid))
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              title: Text(
                '✅ Paid (${_feeItems.where((f) => f.isPaid).length})',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              children: _feeItems
                  .where((f) => f.isPaid)
                  .map((item) => Dismissible(
                    key: Key('paid_${item.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Colors.orange,
                      child: const Icon(Icons.undo, color: Colors.white),
                    ),
                    onDismissed: (_) => _undoFeePayment(item),
                    child: ListTile(
                      leading: Icon(Icons.check_box, color: Colors.green.shade600),
                      title: Text(
                        item.studentName,
                        style: TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey.shade500),
                      ),
                      subtitle: Text(
                        'Paid ${item.datePaid != null ? DateFormat('MMM d').format(item.datePaid!) : ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      ),
                      trailing: Text(
                        '\$${item.amount.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade600),
                      ),
                    ),
                  ))
                  .toList(),
            ),
          const SizedBox(height: 8),
          // ── Add Buttons ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showAddDialog(isIncome: true),
                icon: const Icon(Icons.add_circle, color: Colors.white),
                label: const Text('Income'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showAddDialog(isIncome: false),
                icon: const Icon(Icons.remove_circle, color: Colors.white),
                label: const Text('Expense'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white),
              ),
            ],
          ),

          // ── Transaction List ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text('Today\'s Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                const Spacer(),
                Text('${todayEntries.length} entries', style: TextStyle(color: Colors.grey.shade500)),
              ],
            ),
          ),
          Expanded(
            child: todayEntries.isEmpty
                ? Center(child: Text('No transactions today', style: TextStyle(color: Colors.grey.shade400)))
                : ListView.builder(
                    itemCount: todayEntries.length,
                    itemBuilder: (ctx, i) {
                      final entry = todayEntries[i];
                      return Dismissible(
                        key: Key(entry.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _deleteEntry(entry),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: entry.isIncome ? Colors.green.shade100 : Colors.red.shade100,
                            child: Text(entry.isIncome ? '+' : '-', style: TextStyle(color: entry.isIncome ? Colors.green : Colors.red)),
                          ),
                          title: Text(entry.category),
                          subtitle: Text(entry.note.isNotEmpty ? entry.note : DateFormat('h:mm a').format(entry.date)),
                          trailing: Text(
                            '${entry.isIncome ? '+' : '-'}\$${entry.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: entry.isIncome ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 14)),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}
