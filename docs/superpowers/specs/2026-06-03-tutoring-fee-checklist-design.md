# Tutoring Fee Checklist — Design Spec

**Date:** 2026-06-03
**Context:** Add a fee checklist to the Finance screen so the user can track which parents have paid tutorial fees. Marking a fee as paid auto-creates an income entry.

---

## Data Model

### FeeItem (new)

```dart
class FeeItem {
  final String id;           // timestamp-based unique ID
  final String studentName;
  final double amount;
  final String note;         // optional
  final bool isPaid;
  final DateTime dateCreated;
  final DateTime? datePaid;       // null if unpaid
  final String? linkedEntryId;   // finance entry ID for undo support
}
```

- Stored in SharedPreferences under key `fee_items`
- Follows same JSON serialize/deserialize pattern as `FinanceEntry`

---

## UI Layout

Added as a new section inside the existing Finance screen, between the summary card and the add-buttons row:

```
Summary Card (existing)
        ↓
🎓 Tutoring Fees  [+Add]     ← NEW
  ☐ Student - $X             ← pending, tap to mark paid
  ✅ Paid (N recent)     ▼   ← collapsible history
        ↓
[+ Income] [+ Expense]       ← existing
        ↓
Today's Transactions          ← existing
```

---

## Interactions

| Action | Result |
|--------|--------|
| Tap [+] button | Opens add dialog (student name, amount, note) |
| Tap checkbox on pending item | Marks paid, auto-creates `FinanceEntry` (income, category "Tutoring") |
| Swipe left on pending item | Deletes fee item (no finance entry created) |
| Swipe left on paid item | Undo — deletes linked finance entry, reverts to unpaid |
| Tap already-paid checkbox | No-op |

---

## Auto-Link Behavior

When a `FeeItem` is marked paid:
1. `FeeItem.isPaid` → `true`, `datePaid` → now
2. A `FinanceEntry` is created:
   - `amount` = FeeItem.amount
   - `isIncome` = true
   - `category` = "Tutoring"
   - `note` = "Paid by [studentName]"
   - `date` = now
3. Both are saved to their respective SharedPreferences keys

---

## Edge Cases

- **Duplicate prevention:** Paid items cannot be paid again
- **Manual deletion:** If user deletes the finance entry from the transaction list, the FeeItem stays paid (no back-link)
- **Undo reliability:** Undo removes the finance entry using the stored `linkedEntryId`

---

## Files to Modify

| File | Change |
|------|--------|
| `lib/models/fee_item.dart` | **New** — FeeItem model |
| `lib/screens/finance_screen.dart` | Add fee checklist section, add dialog, checkbox logic |
| `lib/services/storage_service.dart` | No changes needed (generic saveList/loadList works) |
