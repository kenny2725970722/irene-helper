import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const _incomeMethods = ['Bank Transfer', 'Cash', 'PayMe', 'Check', 'Other'];
  static const _expenseMethods = ['Credit Card', 'Cash', 'PayMe', 'Bank Transfer', 'Other'];
  static const _methodEmojis = {
    'Credit Card': '💳', 'Cash': '💵', 'PayMe': '📱',
    'Bank Transfer': '🏦', 'Check': '📝', 'Other': '💰',
  };

  DateTime _selectedDate = DateTime.now();

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
    return _entries
        .where((e) => e.isIncome && _isSameDay(e.date, _selectedDate))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get _todayExpenses {
    return _entries
        .where((e) => !e.isIncome && _isSameDay(e.date, _selectedDate))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showAddDialog({required bool isIncome}) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String category = isIncome ? _incomeCategories.first : _expenseCategories.first;
    String paymentMethod = isIncome ? _incomeMethods.first : _expenseMethods.first;

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
              DropdownButtonFormField<String>(
                initialValue: paymentMethod,
                items: (isIncome ? _incomeMethods : _expenseMethods)
                    .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text('${_methodEmojis[m] ?? '💰'} $m')))
                    .toList(),
                onChanged: (val) => setDialog(() => paymentMethod = val!),
                decoration: const InputDecoration(labelText: 'Payment Method'),
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
                HapticFeedback.lightImpact();
                setState(() {
                  _entries.insert(0, FinanceEntry(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    amount: amount,
                    isIncome: isIncome,
                    category: category,
                    note: noteCtrl.text,
                    date: DateTime.now(),
                    paymentMethod: paymentMethod,
                  ));
                });
                _saveEntries();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ ${isIncome ? "Income" : "Expense"} added — \$${amount.toStringAsFixed(2)}'), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteEntry(FinanceEntry entry) {
    HapticFeedback.heavyImpact();
    setState(() => _entries.remove(entry));
    _saveEntries();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('🗑 Entry deleted'), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating),
    );
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
              HapticFeedback.lightImpact();
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('📚 Fee added for ${nameCtrl.text.trim()}'), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _markFeePaid(FeeItem item) {
    if (item.isPaid) return;
    HapticFeedback.mediumImpact();

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
      final idx = _feeItems.indexOf(item);
      _feeItems[idx] = item.copyWith(
        isPaid: true,
        datePaid: DateTime.now(),
        linkedEntryId: entryId,
      );
      _entries.insert(0, financeEntry);
    });

    _saveFeeItems();
    _saveEntries();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Marked paid — \$${item.amount.toStringAsFixed(0)}'), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating),
    );
  }

  void _deleteFeeItem(FeeItem item) {
    HapticFeedback.heavyImpact();
    setState(() => _feeItems.remove(item));
    _saveFeeItems();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('🗑 Fee item deleted'), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating),
    );
  }

  void _undoFeePayment(FeeItem item) {
    HapticFeedback.mediumImpact();
    setState(() {
      if (item.linkedEntryId != null) {
        _entries.removeWhere((e) => e.id == item.linkedEntryId);
      }
      final idx = _feeItems.indexOf(item);
      _feeItems[idx] = item.copyWith(
        isPaid: false,
        clearDatePaid: true,
        clearLinkedEntryId: true,
      );
    });
    _saveFeeItems();
    _saveEntries();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('↩ Payment undone'), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final net = _todayIncome - _todayExpenses;
    final todayEntries = _entries.where((e) => _isSameDay(e.date, _selectedDate)).toList();
    final isToday = _isSameDay(_selectedDate, DateTime.now());
    final isFuture = _selectedDate.isAfter(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('💰 Daily Finance'),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.mediumImpact();
          await _loadEntries();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                  '${isToday ? "Net Today" : "Net on ${DateFormat('MMM d').format(_selectedDate)}"}: ${net >= 0 ? '+' : ''}\$${net.toStringAsFixed(2)}',
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
            confirmDismiss: (_) => _confirmDismiss('Delete fee?', 'Remove ${item.studentName}\'s fee?'),
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
                    confirmDismiss: (_) => _confirmDismiss('Undo payment?', 'Mark ${item.studentName} as unpaid?'),
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

          // ── Date Navigation ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
                  },
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedDate = DateTime.now());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isToday ? Colors.teal.shade100 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      isToday ? 'Today' : DateFormat('EEE, MMM d').format(_selectedDate),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isToday ? Colors.teal.shade700 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: isFuture ? null : () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
                  },
                ),
              ],
            ),
          ),

          // ── Transaction List ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  isToday ? 'Today\'s Transactions' : 'Transactions — ${DateFormat('MMM d, yyyy').format(_selectedDate)}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                ),
                const Spacer(),
                Text('${todayEntries.length} entries', style: TextStyle(color: Colors.grey.shade500)),
              ],
            ),
          ),
          if (todayEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No transactions today', style: TextStyle(color: Colors.grey.shade400))),
            ),
          ...todayEntries.map((entry) => Dismissible(
            key: Key(entry.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.red,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (_) => _confirmDismiss('Delete entry?', 'Remove \$${entry.amount.toStringAsFixed(2)} ${entry.isIncome ? "income" : "expense"}?'),
            onDismissed: (_) => _deleteEntry(entry),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: entry.isIncome ? Colors.green.shade100 : Colors.red.shade100,
                child: Text(entry.isIncome ? '+' : '-', style: TextStyle(color: entry.isIncome ? Colors.green : Colors.red)),
              ),
              title: Text(entry.category),
              subtitle: Text(
                '${_methodEmojis[entry.paymentMethod] ?? '💰'} ${entry.paymentMethod}${entry.note.isNotEmpty ? ' • ${entry.note}' : ''} • ${DateFormat('h:mm a').format(entry.date)}',
              ),
              trailing: Text(
                '${entry.isIncome ? '+' : '-'}\$${entry.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: entry.isIncome ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ),
          )).toList(),
        ],
      ),
    ),
    );
  }

  Future<bool> _confirmDismiss(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
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
