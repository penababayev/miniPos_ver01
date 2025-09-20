import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/repos/product_repo.dart';
import '../../data/repos/sale_repo.dart';
import '../../data/local/pos_hold_store.dart';
import '../../data/local/product_meta_store.dart';
import '../../data/local/debt_ledger_store.dart';

import '../../models/sale_item.dart';
import '../../models/product.dart';
import '../ledger/debt_ledger_page.dart';

// ✅ Lisans
import '../../core/license_service.dart';
import '../../core/license_banner.dart';

class POSPage extends ConsumerStatefulWidget {
  const POSPage({super.key});
  @override
  ConsumerState<POSPage> createState() => _POSPageState();
}

class _POSPageState extends ConsumerState<POSPage> {
  // Aktif sepet
  final List<SaleItem> cart = [];
  final Map<int, String> names = {};
  final Map<int, int> stocks = {};
  final meta = ProductMetaStore();

  // Bekleyenler
  int holdsCount = 0;
  final store = PosHoldStore();

  // İndirim (TL)
  double discount = 0;

  // Ödeme tipi
  String paymentType = 'cash'; // cash | card | credit

  @override
  void initState() {
    super.initState();
    store.list().then((v) => setState(() => holdsCount = v.length));
    meta.init();
  }

  double get subtotal => cart.fold(0.0, (s, e) => s + e.lineTotal);
  double get total => (subtotal - discount).clamp(0, double.infinity);

  // ---------- Sepet işlemleri ----------
  void _addToCart(Product p, {int qty = 1}) {
    final idx = cart.indexWhere((e) => e.productId == p.id);
    final currentQty = idx >= 0 ? cart[idx].qty : 0;

    if (currentQty + qty > p.stockQty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Stok yetersiz: ${p.name} (stok: ${p.stockQty})')),
      );
      return;
    }

    if (idx >= 0) {
      cart[idx].qty += qty;
      cart[idx].lineTotal = cart[idx].qty * cart[idx].unitPrice;
    } else {
      final s = SaleItem()
        ..productId = p.id
        ..qty = qty
        ..unitPrice = p.salePrice
        ..lineTotal = p.salePrice * qty;
      cart.add(s);
      names[p.id] = p.name;
      stocks[p.id] = p.stockQty;
    }
    setState(() {});
  }

  void _removeLine(int i) {
    cart.removeAt(i);
    setState(() {});
  }

  // ---------- Barkod & Arama ----------
  Future<void> _scan() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ScannerSheet(onDetected: (code) async {
        final p = await ref.read(productRepoProvider).byBarcode(code);
        if (p != null) {
          _openAddDialog(p);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Barkod bulunamadı: $code')));
          }
        }
      }),
    );
  }

  Future<void> _openSearch() async {
    final selected = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _SearchSheet(),
    );
    if (selected != null) {
      _openAddDialog(selected);
    }
  }

  Future<void> _openAddDialog(Product p) async {
    final unit = await meta.getUnit(p.id) ?? 'adet';
    final imgB64 = await meta.getImageBase64(p.id);
    final res = await showDialog<_AddResult>(
      context: context,
      builder: (_) => _AddDialog(product: p, unit: unit, imgB64: imgB64),
    );
    if (res == null) return;
    _addToCart(p, qty: res.qty);
  }

  // ---------- İndirim ----------
  Future<void> _openDiscount() async {
    final ctrl = TextEditingController(text: discount.toStringAsFixed(2));
    final percentCtrl = TextEditingController(text: '0');
    final res = await showDialog<double?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('İndirim'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('TL İndirimi'),
              subtitle: TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(prefixText: '₺ '),
              ),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('% İndirimi'),
              subtitle: TextField(
                controller: percentCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(suffixText: '%'),
              ),
              trailing: FilledButton(
                onPressed: () {
                  final p =
                      double.tryParse(percentCtrl.text.replaceAll(',', '.')) ??
                          0;
                  final d = (subtotal * p / 100).clamp(0, subtotal);
                  Navigator.pop(context, d);
                },
                child: const Text('Uygula'),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () {
                  final d = (subtotal - subtotal.floor()).clamp(0, subtotal);
                  Navigator.pop(context, d); // tam liraya indir
                },
                icon: const Icon(Icons.compress_rounded),
                label: const Text('Tam liraya indir'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () {
              final d = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;
              Navigator.pop(context, d.clamp(0, subtotal));
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (res != null) setState(() => discount = res);
  }

  // ---------- Park / Bekleyenler ----------
  Future<void> _parkCurrent({String? title}) async {
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sepet boş.')));
      return;
    }
    final t = title ?? 'Müşteri ${(await store.list()).length + 1}';
    final items = cart
        .map((e) => HeldCartItem(
            productId: e.productId, qty: e.qty, unitPrice: e.unitPrice))
        .toList();
    final held = HeldCart(
        id: store.newId(), title: t, createdAt: DateTime.now(), items: items);
    await store.save(held);
    cart.clear();
    names.clear();
    stocks.clear();
    setState(() {});
    setState(() async => holdsCount = (await store.list()).length);
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Beklemeye alındı: $t')));
  }

  Future<void> _openHolds() async {
    final action = await showModalBottomSheet<_HoldAction>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _HoldsSheet(),
    );
    if (action == null) return;

    cart.clear();
    names.clear();
    stocks.clear();
    for (final it in action.cart.items) {
      final p =
          await ref.read(productRepoProvider).isar.products.get(it.productId);
      if (p == null) continue;
      final s = SaleItem()
        ..productId = it.productId
        ..qty = it.qty
        ..unitPrice = it.unitPrice
        ..lineTotal = it.unitPrice * it.qty;
      cart.add(s);
      names[p.id] = p.name;
      stocks[p.id] = p.stockQty;
    }
    await store.remove(action.cart.id);
    setState(() {});
    setState(() async => holdsCount = (await store.list()).length);
  }

  // ---------- Kaydet (ödeme + borç defteri) ----------
  Future<void> _checkout() async {
    // ✅ Lisans kontrolü
    final lic = await LicenseService().current();
    if (!lic.isActive) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Abonelik pasif. Satış kaydetmek için anahtar girin.')),
        );
      }
      return;
    }

    if (cart.isEmpty) return;

    String pay = paymentType;
    String? custName;
    String? phone;
    String? note;

    await showDialog<void>(
      context: context,
      builder: (_) {
        final cn = TextEditingController();
        final ph = TextEditingController();
        final nt = TextEditingController();
        return StatefulBuilder(builder: (context, setS) {
          return AlertDialog(
            title: const Text('Ödeme & İndirim'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('Ara Toplam: ${subtotal.toStringAsFixed(2)}'),
                  subtitle: Text(
                      'İndirim: ${discount.toStringAsFixed(2)}  →  Toplam: ${total.toStringAsFixed(2)}'),
                  trailing: OutlinedButton.icon(
                      onPressed: _openDiscount,
                      icon: const Icon(Icons.local_offer_outlined),
                      label: const Text('İndirim')),
                ),
                const Divider(),
                RadioListTile(
                    value: 'cash',
                    groupValue: pay,
                    onChanged: (v) => setS(() => pay = 'cash'),
                    title: const Text('Nakit')),
                RadioListTile(
                    value: 'card',
                    groupValue: pay,
                    onChanged: (v) => setS(() => pay = 'card'),
                    title: const Text('Kart')),
                RadioListTile(
                    value: 'credit',
                    groupValue: pay,
                    onChanged: (v) => setS(() => pay = 'credit'),
                    title: const Text('Borç Defteri')),
                if (pay == 'credit') ...[
                  const SizedBox(height: 8),
                  TextField(
                      controller: cn,
                      decoration:
                          const InputDecoration(labelText: 'Müşteri adı')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: ph,
                      decoration: const InputDecoration(
                          labelText: 'Telefon (opsiyonel)')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: nt,
                      decoration:
                          const InputDecoration(labelText: 'Not (opsiyonel)')),
                  const SizedBox(height: 6),
                  const Text(
                      'Not: Borç defterine yazsan da stok düşer ve satış kaydı oluşur.'),
                ],
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Vazgeç')),
              FilledButton(
                onPressed: () {
                  if (pay == 'credit') {
                    custName =
                        cn.text.trim().isEmpty ? 'Müşteri' : cn.text.trim();
                    phone = ph.text.trim().isEmpty ? null : ph.text.trim();
                    note = nt.text.trim().isEmpty ? null : nt.text.trim();
                  }
                  Navigator.pop(context);
                },
                child: const Text('Onayla'),
              ),
            ],
          );
        });
      },
    );

    if (!mounted) return;

    final saleId = await ref
        .read(saleRepoProvider)
        .createSale(cart, paymentType: pay, discount: discount);

    if (pay == 'credit') {
      final ledger = DebtLedgerStore();
      await ledger.add(DebtEntry(
        id: ledger.newId(),
        saleId: saleId,
        customerName: custName ?? 'Müşteri',
        phone: phone,
        note: note,
        amount: total,
        createdAt: DateTime.now(),
      ));
    }

    cart.clear();
    names.clear();
    stocks.clear();
    discount = 0;
    setState(() {});
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Satış kaydedildi.')));
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Üst bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                      onPressed: _scan,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Barkod Tara')),
                  OutlinedButton.icon(
                      onPressed: _openSearch,
                      icon: const Icon(Icons.search),
                      label: const Text('Ürün Ara')),
                  OutlinedButton.icon(
                      onPressed: () => _parkCurrent(),
                      icon: const Icon(Icons.pause_circle_outline),
                      label: const Text('Park Et')),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const DebtLedgerPage()));
                    },
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    label: const Text('Borç Defteri'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openHolds,
                    icon: const Icon(Icons.people_outline),
                    label: Text('Bekleyenler ($holdsCount)'),
                  ),
                  const SizedBox(width: 8),
                  Text('Ara Toplam: ${subtotal.toStringAsFixed(2)}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  if (discount > 0)
                    Text('  İnd.: -${discount.toStringAsFixed(2)}',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: Colors.red)),
                  Text('  Toplam: ${total.toStringAsFixed(2)}',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  FilledButton(
                      onPressed: cart.isEmpty ? null : _checkout,
                      child: const Text('Kaydet')),
                ],
              ),
            ),
          ),
        ),

        // ✅ Lisans uyarı bandı
        const LicenseBanner(),

        // Sepet
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            itemCount: cart.length,
            itemBuilder: (c, i) {
              final it = cart[i];
              final name = names[it.productId] ?? 'Ürün #${it.productId}';
              return Card(
                child: ListTile(
                  title: Text(name),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        Chip(label: Text('Adet: ${it.qty}')),
                        Chip(
                            label: Text(
                                'Birim: ${it.unitPrice.toStringAsFixed(2)}')),
                        Chip(
                            label: Text(
                                'Tutar: ${it.lineTotal.toStringAsFixed(2)}')),
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Sil',
                        onPressed: () => _removeLine(i),
                        icon: const Icon(Icons.delete_outline),
                      ),
                      IconButton(
                        tooltip: 'Azalt',
                        onPressed: () {
                          setState(() {
                            if (it.qty > 1) {
                              it.qty -= 1;
                              it.lineTotal = it.qty * it.unitPrice;
                            }
                          });
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(it.qty.toString(),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      IconButton(
                        tooltip: 'Artır',
                        onPressed: () {
                          setState(() {
                            it.qty += 1;
                            it.lineTotal = it.qty * it.unitPrice;
                          });
                        },
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ----------------- ÜRÜN EKLEME DİYALOĞU -----------------
class _AddResult {
  final int qty;
  _AddResult(this.qty);
}

class _AddDialog extends StatelessWidget {
  final Product product;
  final String unit;
  final String? imgB64;
  const _AddDialog({required this.product, required this.unit, this.imgB64});

  @override
  Widget build(BuildContext context) {
    final qty = ValueNotifier<int>(1);
    final bytes = ProductMetaStore.decodeImage(imgB64);

    return AlertDialog(
      title: Text(product.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (bytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(bytes,
                  height: 120, width: 160, fit: BoxFit.cover),
            )
          else
            Container(
              height: 120,
              width: 160,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.image_outlined, size: 32),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text('Birim: $unit')),
              const SizedBox(width: 8),
              Text('Birim fiyat: ${product.salePrice.toStringAsFixed(2)}'),
            ],
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<int>(
            valueListenable: qty,
            builder: (_, v, __) {
              return Row(
                children: [
                  IconButton(
                      onPressed: () {
                        if (v > 1) qty.value = v - 1;
                      },
                      icon: const Icon(Icons.remove_circle_outline)),
                  Expanded(
                    child: TextFormField(
                      key: ValueKey(v),
                      initialValue: v.toString(),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(labelText: 'Miktar'),
                      onChanged: (t) {
                        final x = int.tryParse(t) ?? 1;
                        qty.value = x <= 0 ? 1 : x;
                      },
                    ),
                  ),
                  IconButton(
                      onPressed: () => qty.value = v + 1,
                      icon: const Icon(Icons.add_circle_outline)),
                ],
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _AddResult(qty.value)),
          child: const Text('Ekle'),
        ),
      ],
    );
  }
}

// ----------------- ARA -----------------
class _SearchSheet extends ConsumerStatefulWidget {
  const _SearchSheet();
  @override
  ConsumerState<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends ConsumerState<_SearchSheet> {
  final TextEditingController _q = TextEditingController();
  Timer? _debounce;
  List<Product> results = [];
  bool loading = true;

  Future<void> _run(String query) async {
    final repo = ref.read(productRepoProvider);
    final list = query.trim().isEmpty
        ? await repo.all()
        : await repo.search(query.trim());
    if (!mounted) return;
    setState(() {
      results = list;
      loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _run('');
    _q.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () => _run(_q.text));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _q,
              autofocus: true,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'İsim veya barkod ile ara...'),
            ),
          ),
          if (loading) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (c, i) {
                final p = results[i];
                return FutureBuilder(
                  future: ProductMetaStore().getImageBase64(p.id),
                  builder: (_, snap) {
                    final bytes =
                        ProductMetaStore.decodeImage(snap.data as String?);
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundImage:
                              bytes != null ? MemoryImage(bytes) : null,
                          child: bytes == null
                              ? const Icon(Icons.inventory_2)
                              : null,
                        ),
                        title: Text(p.name),
                        subtitle: Wrap(spacing: 8, children: [
                          Chip(
                              label:
                                  Text('₺${p.salePrice.toStringAsFixed(2)}')),
                          Chip(label: Text('Stok: ${p.stockQty}')),
                          Chip(label: Text('Barkod: ${p.barcode ?? '-'}')),
                        ]),
                        trailing: const Icon(Icons.add_circle_outline),
                        onTap: () => Navigator.pop(context, p),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------- Bekleyenler -----------------
enum HoldActionType { resumeReplace }

class _HoldAction {
  final HeldCart cart;
  final HoldActionType type;
  _HoldAction(this.cart, this.type);
}

class _HoldsSheet extends StatefulWidget {
  const _HoldsSheet();
  @override
  State<_HoldsSheet> createState() => _HoldsSheetState();
}

class _HoldsSheetState extends State<_HoldsSheet> {
  final store = PosHoldStore();
  Future<List<HeldCart>>? _f;
  @override
  void initState() {
    super.initState();
    _f = store.list();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<HeldCart>>(
        future: _f,
        builder: (context, snap) {
          final list = snap.data ?? [];
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(children: [
              const SizedBox(height: 8),
              Container(
                  height: 4,
                  width: 44,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 8),
              ListTile(
                  title: const Text('Bekleyen Satışlar'),
                  trailing: Text('${list.length} adet')),
              const Divider(height: 1),
              Expanded(
                child: snap.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : list.isEmpty
                        ? const Center(child: Text('Bekleyen satış yok'))
                        : ListView.separated(
                            itemCount: list.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final h = list[i];
                              return ListTile(
                                title: Text(h.title),
                                subtitle: Text(
                                    'Kalem: ${h.lines}  Adet: ${h.qtyTotal}  Tutar: ${h.total.toStringAsFixed(2)}\n${h.createdAt}'),
                                isThreeLine: true,
                                onTap: () => Navigator.pop(
                                    context,
                                    _HoldAction(
                                        h, HoldActionType.resumeReplace)),
                              );
                            },
                          ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

// Barkod tarama alt sayfası (bottom sheet)
class _ScannerSheet extends StatefulWidget {
  final void Function(String code) onDetected;
  const _ScannerSheet({required this.onDetected});

  @override
  State<_ScannerSheet> createState() => _ScannerSheetState();
}

class _ScannerSheetState extends State<_ScannerSheet> {
  bool handled = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (handled) return;
              final codes = capture.barcodes;
              if (codes.isNotEmpty) {
                final raw = codes.first.rawValue;
                if (raw != null) {
                  handled = true;
                  Navigator.pop(context);
                  widget.onDetected(raw);
                }
              }
            },
          ),
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
