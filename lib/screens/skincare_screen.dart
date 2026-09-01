import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/promo_entry.dart';
import '../models/price_entry.dart';
import '../services/storage_service.dart';

const _retailers = ['Sasa', 'Olive Young', 'Mannings', 'Watsons', 'ColorMix', 'OpBeauty'];
const _retailerEmojis = {
  'Sasa': '💄',
  'Olive Young': '🧴',
  'Mannings': '💊',
  'Watsons': '🛒',
  'ColorMix': '💅',
  'OpBeauty': '✨',
};

class SkincareScreen extends StatefulWidget {
  const SkincareScreen({super.key});

  @override
  State<SkincareScreen> createState() => _SkincareScreenState();
}

class _SkincareScreenState extends State<SkincareScreen> {
  List<PromoEntry> _promos = [];
  List<PriceEntry> _prices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final promoData = await StorageService.loadList('skincare_promos');
    final priceData = await StorageService.loadList('skincare_prices');
    setState(() {
      _promos = promoData.map((e) => PromoEntry.fromJson(e)).toList();
      _promos.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      _prices = priceData.map((e) => PriceEntry.fromJson(e)).toList();
      _prices.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      _loading = false;
    });
  }

  Future<void> _savePromos() async {
    await StorageService.saveList('skincare_promos', _promos);
  }

  Future<void> _savePrices() async {
    await StorageService.saveList('skincare_prices', _prices);
  }

  void _showAddPromoDialog() {
    final titleCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final linkCtrl = TextEditingController();
    String retailer = _retailers.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('✨ Add Promo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: retailer,
                items: _retailers
                    .map((r) => DropdownMenuItem(value: r, child: Text('${_retailerEmojis[r]} $r')))
                    .toList(),
                onChanged: (val) => setDialog(() => retailer = val!),
                decoration: const InputDecoration(labelText: 'Retailer'),
              ),
              const SizedBox(height: 12),
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 12),
              TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Note (optional)')),
              const SizedBox(height: 12),
              TextField(
                controller: linkCtrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Link (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                HapticFeedback.lightImpact();
                setState(() {
                  _promos.insert(0, PromoEntry(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    retailer: retailer,
                    title: titleCtrl.text.trim(),
                    note: noteCtrl.text.trim(),
                    link: linkCtrl.text.trim(),
                    dateAdded: DateTime.now(),
                  ));
                });
                _savePromos();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✨ Promo added'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPriceDialog() {
    final productCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String retailer = _retailers.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('💰 Add Product Price'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: productCtrl, decoration: const InputDecoration(labelText: 'Product Name')),
              const SizedBox(height: 12),
              TextField(controller: brandCtrl, decoration: const InputDecoration(labelText: 'Brand (optional)')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: retailer,
                items: _retailers
                    .map((r) => DropdownMenuItem(value: r, child: Text('${_retailerEmojis[r]} $r')))
                    .toList(),
                onChanged: (val) => setDialog(() => retailer = val!),
                decoration: const InputDecoration(labelText: 'Retailer'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price', prefixText: '\$ '),
              ),
              const SizedBox(height: 12),
              TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Note (optional)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final price = double.tryParse(priceCtrl.text);
                if (productCtrl.text.trim().isEmpty || price == null || price <= 0) return;
                HapticFeedback.lightImpact();
                setState(() {
                  _prices.insert(0, PriceEntry(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    product: productCtrl.text.trim(),
                    brand: brandCtrl.text.trim(),
                    retailer: retailer,
                    price: price,
                    note: noteCtrl.text.trim(),
                    dateAdded: DateTime.now(),
                  ));
                });
                _savePrices();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('💰 Price added'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deletePromo(PromoEntry entry) {
    HapticFeedback.heavyImpact();
    setState(() => _promos.remove(entry));
    _savePromos();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🗑 Promo deleted'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating),
    );
  }

  void _deletePrice(PriceEntry entry) {
    HapticFeedback.lightImpact();
    setState(() => _prices.remove(entry));
    _savePrices();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🗑 Price deleted'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openLink(String url) async {
    var u = url.trim();
    if (u.isEmpty) return;
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    final uri = Uri.tryParse(u);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _priceStr(double p) {
    return p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toStringAsFixed(2);
  }

  Future<bool> _confirmDelete(String title, String message) async {
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final grouped = <String, List<PriceEntry>>{};
    for (final p in _prices) {
      grouped.putIfAbsent(p.product, () => []).add(p);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🧴 Skincare Deals'),
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
            // ── Promos ──
            Row(
              children: [
                const Text('✨ Promos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(onPressed: _showAddPromoDialog, icon: const Icon(Icons.add_circle, color: Colors.teal)),
              ],
            ),
            const SizedBox(height: 8),
            if (_promos.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(child: Text('No promos yet.\nTap + to add one!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500))),
                ),
              )
            else
              ..._promos.map((p) => Card(
                child: Dismissible(
                  key: Key(p.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) => _confirmDelete('Delete promo?', 'Remove "${p.title}"?'),
                  onDismissed: (_) => _deletePromo(p),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.shade50,
                      child: Text(_retailerEmojis[p.retailer] ?? '🧴'),
                    ),
                    title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      '${p.retailer}${p.note.isNotEmpty ? ' · ${p.note}' : ''} · ${DateFormat('MMM d').format(p.dateAdded)}',
                    ),
                    trailing: p.link.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.open_in_new, color: Colors.teal),
                            onPressed: () => _openLink(p.link),
                          )
                        : null,
                  ),
                ),
              )),
            const SizedBox(height: 24),

            // ── Product Price Comparison ──
            Row(
              children: [
                const Text('💰 Price Comparison', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(onPressed: _showAddPriceDialog, icon: const Icon(Icons.add_circle, color: Colors.teal)),
              ],
            ),
            const SizedBox(height: 8),
            if (_prices.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(child: Text('No prices yet.\nTap + to add a product!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500))),
                ),
              )
            else
              ...grouped.entries.map((e) {
                final entries = e.value;
                final brand = entries.first.brand;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          brand.isNotEmpty ? '$brand · ${e.key}' : e.key,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        ...entries.map((p) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Text('${_retailerEmojis[p.retailer] ?? ''} ${p.retailer}', style: const TextStyle(fontSize: 14)),
                              const Spacer(),
                              Text('\$${_priceStr(p.price)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _deletePrice(p),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
