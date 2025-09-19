import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';
import '../../data/local/isar_service.dart';
import '../../models/product.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});
  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  double todayTotal = 0;
  double weekTotal = 0;
  List<_TopItem> topItems = const [];
  List<Product> critical = const [];
  bool loading = true;

  String money(num v) => NumberFormat.simpleCurrency().format(v);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final isar = ref.read(isarProvider);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrow = todayStart.add(const Duration(days: 1));
    final weekStart = todayStart.subtract(const Duration(days: 6));

    // Bugün toplam
    final todaySales = await isar.sales
        .filter()
        .createdAtBetween(todayStart, tomorrow,
            includeLower: true, includeUpper: false)
        .findAll();
    final todaySum = todaySales.fold<double>(0, (s, e) => s + e.total);

    // Hafta toplam
    final weekSales = await isar.sales
        .filter()
        .createdAtBetween(weekStart, tomorrow,
            includeLower: true, includeUpper: false)
        .findAll();
    final weekSum = weekSales.fold<double>(0, (s, e) => s + e.total);

    // Haftanın top ürünleri (satış kalemlerinden)
    final weekSaleIds = weekSales.map((e) => e.id).toSet();
    final allItems = await isar.saleItems.where().findAll();
    final qtyByProduct = <int, int>{};
    for (final it in allItems) {
      if (weekSaleIds.contains(it.saleId)) {
        qtyByProduct.update(it.productId, (v) => v + it.qty,
            ifAbsent: () => it.qty);
      }
    }
    final sorted = qtyByProduct.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topIds = sorted.take(10).map((e) => e.key).toList();

    final products = await isar.products.where().findAll();
    final nameById = {for (final p in products) p.id: p.name};
    final criticalList =
        products.where((p) => p.stockQty <= p.minStock).toList();

    setState(() {
      todayTotal = todaySum;
      weekTotal = weekSum;
      topItems = [
        for (final e in sorted.take(10))
          _TopItem(nameById[e.key] ?? '#${e.key}', e.value)
      ];
      critical = criticalList;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
            title: const Text('Bugün Ciro'), trailing: Text(money(todayTotal))),
        const Divider(),
        ListTile(
            title: const Text('Bu Hafta Ciro (7 gün)'),
            trailing: Text(money(weekTotal))),
        const Divider(),
        const ListTile(title: Text('En Çok Satanlar (7 gün)')),
        ...topItems.map((t) => ListTile(
              title: Text(t.name),
              trailing: Text('adet: ${t.qty}'),
            )),
        if (topItems.isEmpty) const ListTile(subtitle: Text('- veri yok -')),
        const Divider(),
        const ListTile(title: Text('Kritik Stok (≤ min)')),
        ...critical.map((p) => ListTile(
              title: Text(p.name),
              subtitle: Text('Stok: ${p.stockQty} / Min: ${p.minStock}'),
            )),
        if (critical.isEmpty) const ListTile(subtitle: Text('- ürün yok -')),
      ],
    );
  }
}

class _TopItem {
  final String name;
  final int qty;
  _TopItem(this.name, this.qty);
}
