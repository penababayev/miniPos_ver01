import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:excel/excel.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../data/local/isar_service.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';
import '../../models/product.dart';

// Kaydetme yardımcıları
import 'xlsx_saver_io.dart' if (dart.library.html) 'xlsx_saver_web.dart';
import 'csv_saver_io.dart' if (dart.library.html) 'csv_saver_web.dart';

// ✅ Lisans
import '../../core/license_service.dart';
import '../../core/license_banner.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});
  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

enum QuickRange { today, thisWeek, thisMonth, custom }

class PeriodReport {
  final String label;
  final DateTime start;
  final DateTime end;
  final List<Sale> sales;
  final int salesCount;
  final int itemsSold;
  final double subtotal; // satır toplamları
  final double totalRevenue; // satış toplamları (iskontolu)
  final double discountTotal; // subtotal - totalRevenue
  final double avgTicket;
  final double avgItemsPerSale;
  final Map<String, int> payCounts;
  final Map<String, double> payTotals;
  final Map<int, int> hourSalesCount; // 0..23
  final Map<int, double> hourRevenue; // 0..23
  final List<TopProduct> topProducts; // sıralı
  final double grossProfit; // (unitPrice - costPrice) * qty

  PeriodReport({
    required this.label,
    required this.start,
    required this.end,
    required this.sales,
    required this.salesCount,
    required this.itemsSold,
    required this.subtotal,
    required this.totalRevenue,
    required this.discountTotal,
    required this.avgTicket,
    required this.avgItemsPerSale,
    required this.payCounts,
    required this.payTotals,
    required this.hourSalesCount,
    required this.hourRevenue,
    required this.topProducts,
    required this.grossProfit,
  });
}

class TopProduct {
  final int productId;
  final String name;
  final int qty;
  final double revenue;
  final double profit;
  TopProduct({
    required this.productId,
    required this.name,
    required this.qty,
    required this.revenue,
    required this.profit,
  });
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  QuickRange range = QuickRange.today;
  DateTimeRange? customRange;
  PeriodReport? pr; // aktif aralık raporu

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmt(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  (DateTime, DateTime, String) _rangeDates(QuickRange r,
      {DateTimeRange? custom}) {
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    switch (r) {
      case QuickRange.today:
        return (dayStart, dayStart.add(const Duration(days: 1)), 'Bugün');
      case QuickRange.thisWeek:
        final weekStart = dayStart
            .subtract(Duration(days: dayStart.weekday - 1)); // Pazartesi
        final weekEnd = weekStart.add(const Duration(days: 7));
        return (weekStart, weekEnd, 'Bu Hafta');
      case QuickRange.thisMonth:
        final mStart = DateTime(now.year, now.month, 1);
        final mEnd = DateTime(now.year, now.month + 1, 1);
        return (mStart, mEnd, 'Bu Ay');
      case QuickRange.custom:
        final r = custom ??
            DateTimeRange(
                start: dayStart.subtract(const Duration(days: 7)),
                end: dayStart);
        final s = DateTime(r.start.year, r.start.month, r.start.day);
        final e = DateTime(r.end.year, r.end.month, r.end.day)
            .add(const Duration(days: 1));
        return (
          s,
          e,
          '${r.start.toString().substring(0, 10)} → ${r.end.toString().substring(0, 10)}'
        );
    }
  }

  Future<void> _load() async {
    final isar = ref.read(isarProvider);
    final (start, end, label) = _rangeDates(range, custom: customRange);
    final sales = await isar.sales
        .filter()
        .createdAtGreaterThan(start, include: true)
        .and()
        .createdAtLessThan(end, include: false)
        .findAll();

    sales.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final payCounts = <String, int>{};
    final payTotals = <String, double>{};
    for (final s in sales) {
      final p = s.paymentType ?? 'other';
      payCounts[p] = (payCounts[p] ?? 0) + 1;
      payTotals[p] = (payTotals[p] ?? 0.0) + s.total;
    }

    // Satır toplamları, adetler, kâr, top ürünler, saatler
    final hourSalesCount = <int, int>{};
    final hourRevenue = <int, double>{};
    final topMapQty = <int, int>{};
    final topMapRev = <int, double>{};
    final topMapProfit = <int, double>{};
    final productCache = <int, Product?>{};
    int itemsSold = 0;
    double subtotal = 0.0;
    double grossProfit = 0.0;

    for (final s in sales) {
      final h = s.createdAt.hour;
      hourSalesCount[h] = (hourSalesCount[h] ?? 0) + 1;
      hourRevenue[h] = (hourRevenue[h] ?? 0.0) + s.total;

      final lines = await isar.saleItems.filter().saleIdEqualTo(s.id).findAll();
      for (final it in lines) {
        itemsSold += it.qty;
        subtotal += it.lineTotal;
        // kâr
        final pid = it.productId;
        var p = productCache[pid];
        p ??= await isar.products.get(pid);
        productCache[pid] = p;
        final cost = p?.costPrice ?? 0.0;
        final profitPerUnit = (it.unitPrice - cost);
        final lineProfit = profitPerUnit * it.qty;
        grossProfit += lineProfit;

        // top ürünler
        topMapQty[pid] = (topMapQty[pid] ?? 0) + it.qty;
        topMapRev[pid] = (topMapRev[pid] ?? 0.0) + it.lineTotal;
        topMapProfit[pid] = (topMapProfit[pid] ?? 0.0) + lineProfit;
      }
    }

    final totalRevenue = sales.fold(0.0, (s, e) => s + e.total);
    final discountTotal =
        (subtotal - totalRevenue).clamp(0.0, double.infinity).toDouble();

    final salesCount = sales.length;
    final avgTicket = salesCount > 0 ? totalRevenue / salesCount : 0.0;
    final avgItemsPerSale = salesCount > 0 ? itemsSold / salesCount : 0.0;

    final topProducts = <TopProduct>[];
    for (final pid in topMapQty.keys) {
      final p = productCache[pid] ?? await isar.products.get(pid);
      final name = p?.name ?? 'Ürün #$pid';
      topProducts.add(TopProduct(
        productId: pid,
        name: name,
        qty: topMapQty[pid] ?? 0,
        revenue: topMapRev[pid] ?? 0.0,
        profit: topMapProfit[pid] ?? 0.0,
      ));
    }
    topProducts.sort((a, b) => b.qty.compareTo(a.qty));
    final top10 = topProducts.take(10).toList();

    setState(() {
      pr = PeriodReport(
        label: label,
        start: start,
        end: end,
        sales: sales,
        salesCount: salesCount,
        itemsSold: itemsSold,
        subtotal: subtotal,
        totalRevenue: totalRevenue,
        discountTotal: discountTotal,
        avgTicket: avgTicket,
        avgItemsPerSale: avgItemsPerSale,
        payCounts: payCounts,
        payTotals: payTotals,
        hourSalesCount: hourSalesCount,
        hourRevenue: hourRevenue,
        topProducts: top10,
        grossProfit: grossProfit,
      );
    });
  }

  // ---------- Exporters (lisans kontrollü) ----------
  Future<void> _exportSummaryXlsx(PeriodReport r) async {
    final lic = await LicenseService().current();
    if (!lic.isActive) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Abonelik pasif. XLSX dışa aktarma için anahtar girin.')),
        );
      }
      return;
    }

    final excel = Excel.createExcel();
    final s = excel['Summary'];

    List<CellValue> _row(List<dynamic> cells) {
      return cells.map<CellValue>((v) {
        if (v == null) return TextCellValue('');
        if (v is int) return IntCellValue(v);
        if (v is double) return DoubleCellValue(v);
        return TextCellValue(v.toString());
      }).toList();
    }

    s.appendRow(_row(['Rapor', r.label]));
    s.appendRow(_row(['Aralık', '${_fmt(r.start)} → ${_fmt(r.end)}']));
    s.appendRow(_row(['Fiş', r.salesCount]));
    s.appendRow(_row(['Satılan Adet', r.itemsSold]));
    s.appendRow(_row(['Ortalama Fiş', r.avgTicket]));
    s.appendRow(_row(['Ortalama Ürün/Fiş', r.avgItemsPerSale]));
    s.appendRow(_row(['Toplam Ciro', r.totalRevenue]));
    s.appendRow(_row(['Satır Toplamı', r.subtotal]));
    s.appendRow(_row(['İskonto', r.discountTotal]));
    s.appendRow(_row(['Brüt Kâr (tahmini)', r.grossProfit]));
    s.appendRow(_row(['']));

    s.appendRow(_row(['Ödeme Türü', 'Fiş', 'Tutar']));
    for (final k in r.payCounts.keys) {
      s.appendRow(_row([k, r.payCounts[k]!, r.payTotals[k] ?? 0.0]));
    }

    final tp = excel['Top_Products'];
    tp.appendRow(_row(['#', 'Ürün', 'Adet', 'Ciro', 'Kâr']));
    for (var i = 0; i < r.topProducts.length; i++) {
      final t = r.topProducts[i];
      tp.appendRow(_row([i + 1, t.name, t.qty, t.revenue, t.profit]));
    }

    final bytes = Uint8List.fromList(excel.save()!);
    await saveXlsx(
        bytes, 'rapor_${r.label.replaceAll(' ', '_').toLowerCase()}.xlsx');

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('XLSX indirildi.')));
    }
  }

  Future<void> _exportSummaryCsv(PeriodReport r) async {
    final lic = await LicenseService().current();
    if (!lic.isActive) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Abonelik pasif. CSV dışa aktarma için anahtar girin.')),
        );
      }
      return;
    }

    String csvSafe(String v) => '"${v.replaceAll('"', '""')}"';
    final sb = StringBuffer();
    sb.writeln('Rapor;${csvSafe(r.label)}');
    sb.writeln('Aralık;${_fmt(r.start)} → ${_fmt(r.end)}');
    sb.writeln('Fiş;${r.salesCount}');
    sb.writeln('Satılan Adet;${r.itemsSold}');
    sb.writeln('Ortalama Fiş;${r.avgTicket.toStringAsFixed(2)}');
    sb.writeln('Ortalama Ürün/Fiş;${r.avgItemsPerSale.toStringAsFixed(2)}');
    sb.writeln('Toplam Ciro;${r.totalRevenue.toStringAsFixed(2)}');
    sb.writeln('Satır Toplamı;${r.subtotal.toStringAsFixed(2)}');
    sb.writeln('İskonto;${r.discountTotal.toStringAsFixed(2)}');
    sb.writeln('Brüt Kâr;${r.grossProfit.toStringAsFixed(2)}');
    sb.writeln('');
    sb.writeln('Ödeme Türü;Fiş;Tutar');
    for (final k in r.payCounts.keys) {
      sb.writeln(
          '$k;${r.payCounts[k]};${(r.payTotals[k] ?? 0).toStringAsFixed(2)}');
    }
    sb.writeln('');
    sb.writeln('#;Ürün;Adet;Ciro;Kâr');
    for (var i = 0; i < r.topProducts.length; i++) {
      final t = r.topProducts[i];
      sb.writeln(
          '${i + 1};${csvSafe(t.name)};${t.qty};${t.revenue.toStringAsFixed(2)};${t.profit.toStringAsFixed(2)}');
    }

    await saveCsv(sb.toString(),
        'rapor_${r.label.replaceAll(' ', '_').toLowerCase()}.csv');
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('CSV indirildi.')));
    }
  }

  // Satış detay listesi (modal)
  void _openSalesList(PeriodReport r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SalesListSheet(report: r, fmt: _fmt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = pr;
    return Scaffold(
      appBar: AppBar(title: const Text('Raporlar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        children: [
          const LicenseBanner(),

          // Hızlı aralık seçimleri
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Aralık:'),
                  ChoiceChip(
                    label: const Text('Bugün'),
                    selected: range == QuickRange.today,
                    onSelected: (_) => setState(() {
                      range = QuickRange.today;
                      _load();
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Bu Hafta'),
                    selected: range == QuickRange.thisWeek,
                    onSelected: (_) => setState(() {
                      range = QuickRange.thisWeek;
                      _load();
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Bu Ay'),
                    selected: range == QuickRange.thisMonth,
                    onSelected: (_) => setState(() {
                      range = QuickRange.thisMonth;
                      _load();
                    }),
                  ),
                  ChoiceChip(
                    label: Text(customRange == null
                        ? 'Özel'
                        : 'Özel: ${customRange!.start.toString().substring(0, 10)} → ${customRange!.end.toString().substring(0, 10)}'),
                    selected: range == QuickRange.custom,
                    onSelected: (_) async {
                      final now = DateTime.now();
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020, 1, 1),
                        lastDate: DateTime(2100, 1, 1),
                        initialDateRange: customRange ??
                            DateTimeRange(
                                start: now.subtract(const Duration(days: 7)),
                                end: now),
                      );
                      if (picked != null) {
                        setState(() {
                          range = QuickRange.custom;
                          customRange = picked;
                        });
                        _load();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          if (r == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            _reportCard(r),
        ],
      ),
    );
  }

  Widget _reportCard(PeriodReport r) {
    final busiestHour = r.hourRevenue.entries.isEmpty
        ? null
        : r.hourRevenue.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key;

    return Card(
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withOpacity(.35),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ListTile(
              title: Text('Z Raporu — ${r.label}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                  'Açılış: ${_fmt(r.start)}   •   Kapanış: ${_fmt(r.end)}'),
              trailing: Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                      onPressed: () => _exportSummaryCsv(r),
                      icon: const Icon(Icons.file_download),
                      label: const Text('CSV')),
                  FilledButton.icon(
                      onPressed: () => _exportSummaryXlsx(r),
                      icon: const Icon(Icons.grid_on),
                      label: const Text('XLSX')),
                ],
              ),
            ),
            const Divider(),

            // Özet metrikler
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _chip(context, 'Fiş: ${r.salesCount}'),
                _chip(context, 'Adet: ${r.itemsSold}'),
                _chip(context, 'Ort. Fiş: ${r.avgTicket.toStringAsFixed(2)}'),
                _chip(context,
                    'Ort. Ürün/Fiş: ${r.avgItemsPerSale.toStringAsFixed(2)}'),
                _chip(context, 'Ciro: ${r.totalRevenue.toStringAsFixed(2)}'),
                _chip(
                    context, 'Satır Toplamı: ${r.subtotal.toStringAsFixed(2)}'),
                _chip(
                    context, 'İskonto: ${r.discountTotal.toStringAsFixed(2)}'),
                _chip(context, 'Brüt Kâr: ${r.grossProfit.toStringAsFixed(2)}'),
                if (busiestHour != null)
                  _chip(context,
                      'Yoğun Saat: ${busiestHour.toString().padLeft(2, '0')}:00'),
              ],
            ),

            const SizedBox(height: 10),

            // 📊 Saatlik Ciro (Bar chart)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Saatlik Ciro (₺)',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: _HourlyBarChart(data: r.hourRevenue),
            ),

            const SizedBox(height: 14),

            // 💳 Ödeme Kırılımı (Pie chart)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Ödeme Türleri',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: _PaymentPieChart(totals: r.payTotals),
            ),

            const SizedBox(height: 12),

            // En çok satanlar
            Align(
              alignment: Alignment.centerLeft,
              child: Text('En Çok Satan 10 Ürün',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 6),
            if (r.topProducts.isEmpty)
              const Text('Bu aralıkta ürün satışı bulunmuyor.')
            else
              Column(
                children: r.topProducts.map((t) {
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                        radius: 12,
                        child: Text('${r.topProducts.indexOf(t) + 1}')),
                    title: Text(t.name),
                    subtitle: Wrap(
                      spacing: 8,
                      children: [
                        Chip(label: Text('Adet: ${t.qty}')),
                        Chip(
                            label:
                                Text('Ciro: ${t.revenue.toStringAsFixed(2)}')),
                        Chip(
                            label: Text('Kâr: ${t.profit.toStringAsFixed(2)}')),
                      ],
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _openSalesList(r),
                icon: const Icon(Icons.receipt_long),
                label: const Text('Satış Listesi'),
              ),
            )
          ],
        ),
      ),
    );
  }

  String _payLabel(String k) {
    switch (k) {
      case 'cash':
        return 'Nakit';
      case 'card':
        return 'Kart';
      case 'credit':
        return 'Borç';
      default:
        return k;
    }
  }

  Widget _chip(BuildContext context, String label) {
    return Chip(
      label: Text(label),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    );
  }
}

// ------------------ SATIŞ LİSTESİ ALT SAYFA ------------------

class _SalesListSheet extends StatelessWidget {
  final PeriodReport report;
  final String Function(DateTime) fmt;
  const _SalesListSheet({required this.report, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final sales = report.sales;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
              height: 4,
              width: 44,
              decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 8),
          ListTile(
            title: Text('Satış Listesi — ${report.label}'),
            subtitle: Text('${fmt(report.start)} → ${fmt(report.end)}'),
            trailing: Text('Toplam: ${report.totalRevenue.toStringAsFixed(2)}'),
          ),
          const Divider(height: 1),
          Expanded(
            child: sales.isEmpty
                ? const Center(child: Text('Kayıt yok'))
                : ListView.separated(
                    itemCount: sales.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final s = sales[i];
                      return ListTile(
                        title: Text(
                            'Satış #${s.id} — ${s.total.toStringAsFixed(2)}'),
                        subtitle: Text(
                            '${fmt(s.createdAt)} • ${_payLabel(s.paymentType ?? '')}'),
                        leading: const Icon(Icons.receipt_long),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _payLabel(String k) {
    switch (k) {
      case 'cash':
        return 'Nakit';
      case 'card':
        return 'Kart';
      case 'credit':
        return 'Borç';
      default:
        return k.isEmpty ? '-' : k;
    }
  }
}

// ------------------ GRAFİK WIDGET'LARI ------------------

class _HourlyBarChart extends StatelessWidget {
  final Map<int, double> data; // hour -> revenue
  const _HourlyBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    // 0..23 saatleri sırayla, olmayanları 0 yap
    final hours = List.generate(24, (i) => i);
    final values = hours.map((h) => (data[h] ?? 0.0)).toList();
    final maxY = (values.fold<double>(0.0, (m, v) => v > m ? v : m) * 1.2)
        .clamp(10.0, double.infinity);

    return BarChart(
      BarChartData(
        maxY: maxY,
        gridData: FlGridData(show: true, horizontalInterval: maxY / 4),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final h = group.x;
              return BarTooltipItem(
                '${h.toString().padLeft(2, '0')}:00\n₺${rod.toY.toStringAsFixed(2)}',
                const TextStyle(fontWeight: FontWeight.w600),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: maxY / 4,
              getTitlesWidget: (v, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(v.toInt().toString()),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 2,
              getTitlesWidget: (v, meta) {
                final h = v.toInt();
                if (h % 2 != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${h.toString().padLeft(2, '0')}'),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < hours.length; i++)
            BarChartGroupData(
              x: hours[i],
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  width: 8,
                  borderRadius: BorderRadius.circular(2),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PaymentPieChart extends StatelessWidget {
  final Map<String, double> totals; // type -> amount
  const _PaymentPieChart({required this.totals});

  @override
  Widget build(BuildContext context) {
    final data = Map<String, double>.from(totals);
    data.removeWhere((k, v) => v == 0);

    final total = data.values.fold<double>(0.0, (s, v) => s + v);
    if (total <= 0) {
      return const Center(child: Text('Ödeme kaydı yok'));
    }

    final colors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.tertiary,
      Theme.of(context).colorScheme.error,
    ];

    final keys = data.keys.toList();
    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 32,
              sectionsSpace: 2,
              sections: [
                for (var i = 0; i < keys.length; i++)
                  PieChartSectionData(
                    value: data[keys[i]]!,
                    color: colors[i % colors.length],
                    title:
                        '${(data[keys[i]]! * 100 / total).toStringAsFixed(0)}%',
                    radius: 70,
                    titleStyle: const TextStyle(
                        fontWeight: FontWeight.w700, color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < keys.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                            color: colors[i % colors.length],
                            borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 6),
                    Text(_payLabel(keys[i])),
                    const SizedBox(width: 6),
                    Text('₺${data[keys[i]]!.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  String _payLabel(String k) {
    switch (k) {
      case 'cash':
        return 'Nakit';
      case 'card':
        return 'Kart';
      case 'credit':
        return 'Borç';
      default:
        return k;
    }
  }
}
