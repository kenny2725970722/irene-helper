# Tutoring Fee Checklist — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a fee checklist to the Finance screen so the user can track which parents have paid tutorial fees. Marking a fee as paid auto-creates a "Tutoring" income entry.

**Architecture:** A new `FeeItem` model (same JSON pattern as `FinanceEntry`) stored in SharedPreferences under key `fee_items`. A new checklist section widget added to the existing `FinanceScreen` between the summary card and the add-buttons row. Checkbox tap triggers immediate payment → creates `FinanceEntry` → saves both.

**Tech Stack:** Flutter/Dart, SharedPreferences (existing StorageService), intl (existing)

---

## File Map

| Action | File | Purpose |
|--------|------|---------|
| Create | `lib/models/fee_item.dart` | FeeItem model with JSON serialization |
| Modify | `lib/screens/finance_screen.dart` | Add checklist section, add dialog, payment logic |

---

### Task 1: Create FeeItem Model

**Files:**
- Create: `lib/models/fee_item.dart`

- [ ] **Step 1: Write the model**

```dart
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
      linkedEntryId: clearLinkedEntryId ? null : (linkedEntryId ?? this.linkedEntryId),
    );
  }
}
```

- [ ] **Step 2: Verify the file compiles**

Run: `cd my_first_app && flutter analyze lib/models/fee_item.dart`
Expected: No issues found.

---

### Task 2: Add Fee Checklist to Finance Screen

**Files:**
- Modify: `lib/screens/finance_screen.dart`

**What changes:**
1. New import for `FeeItem` model
2. New state: `List<FeeItem> _feeItems`, loaded from `fee_items` key
3. Load fee items in `_loadEntries()`
4. New methods: `_addFeeItem()`, `_markFeePaid(FeeItem)`, `_deleteFeeItem(FeeItem)`, `_undoFeePayment(FeeItem)`
5. New section widget in `build()` between summary card and add-buttons row

- [ ] **Step 1: Add import at top of file**

```dart
import '../models/fee_item.dart';
```

Add this line after the existing `import '../models/finance_entry.dart';` line (line 3).

- [ ] **Step 2: Add fee items state and loading**

Add after `List<FinanceEntry> _entries = [];` (line 14):

```dart
List<FeeItem> _feeItems = [];
```

- [ ] **Step 3: Load fee items in `_loadEntries()`**

Add inside `_loadEntries()`, after the finance entries loading (after `_entries.sort(...)` line):

```dart
final feeData = await StorageService.loadList('fee_items');
_feeItems = feeData.map((e) => FeeItem.fromJson(e)).toList();
_feeItems.sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
```

- [ ] **Step 4: Add `_saveFeeItems()` helper method**

Add after `_saveEntries()`:

```dart
Future<void> _saveFeeItems() async {
  await StorageService.saveList('fee_items', _feeItems);
}
```

- [ ] **Step 5: Add `_addFeeItem()` dialog method**

Add after `_saveFeeItems()`:

```dart
void _showAddFeeDialog() {
  final nameCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('🎓 Add Fee Item'),
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
```

- [ ] **Step 6: Add `_markFeePaid()` method**

Add after `_showAddFeeDialog()`:

```dart
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
```

- [ ] **Step 7: Add `_deleteFeeItem()` method (delete pending)**

Add after `_markFeePaid()`:

```dart
void _deleteFeeItem(FeeItem item) {
  setState(() {
    _feeItems.remove(item);
  });
  _saveFeeItems();
}
```

- [ ] **Step 8: Add `_undoFeePayment()` method (undo paid)**

Add after `_deleteFeeItem()`:

```dart
void _undoFeePayment(FeeItem item) {
  // Remove the linked finance entry
  if (item.linkedEntryId != null) {
    _entries.removeWhere((e) => e.id == item.linkedEntryId);
  }

  setState(() {
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
```

- [ ] **Step 9: Add fee checklist section widget in `build()`**

Insert the fee checklist section between the summary card container (closing after `_summaryItem` row) and the add-buttons row. Replace this line:

```dart
          // ── Add Buttons ──
```

With the fee section inserted before it:

```dart
          // ── Tutoring Fee Checklist ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('🎓 Tutoring Fees', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
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
```

Note: The last line `// ── Add Buttons ──` is the existing line that was there — the fee section goes immediately above it.

- [ ] **Step 10: Verify the file compiles and analyzes clean**

Run: `cd my_first_app && flutter analyze lib/screens/finance_screen.dart`
Expected: No issues found.

---

### Task 3: End-to-End Verification

- [ ] **Step 1: Run the app on iOS simulator**

Run: `cd my_first_app && flutter run`

- [ ] **Step 2: Manual test checklist**

1. Tap Finance tab
2. Verify "🎓 Tutoring Fees" section appears between summary card and add buttons
3. Tap "+" button → add a fee: "Test Student", $100
4. Verify the fee appears with an unchecked box
5. Tap the checkbox → verify it moves to "✅ Paid" section
6. Verify a "Tutoring" income entry appears in Today's Transactions with "+$100" and note "Paid by Test Student"
7. Verify the summary card income updates
8. Expand paid section → swipe left on the paid item → verify it reverts to pending and the income entry disappears
9. Swipe left on a pending item → verify it deletes completely

- [ ] **Step 3: Commit**

```bash
cd my_first_app
git add lib/models/fee_item.dart lib/screens/finance_screen.dart docs/superpowers/specs/2026-06-03-tutoring-fee-checklist-design.md
git commit -m "feat: add tutoring fee checklist with auto-linked income entries"
```
