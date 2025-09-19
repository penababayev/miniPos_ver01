import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../data/repos/product_repo.dart';
import '../../data/repos/sale_repo.dart';
import '../../models/sale_item.dart';
import '../../models/product.dart';

class POSPage extends ConsumerStatefulWidget {
  const POSPage({super.key});
  @override
  ConsumerState<POSPage> createState() => _POSPageState();
}

class _POSPageState extends ConsumerState<POSPage> {
  final List<SaleItem> cart = [];
  final Map<int, String> names = {}; // UI için ürün adları
  final Map<int, int> stocks = {}; // mevcut stok

  void _addToCart(Product p) {
    final idx = cart.indexWhere((e) => e.productId == p.id);

    // stok kontrolü
    final currentQty = idx >= 0 ? cart[idx].qty : 0;
    if (currentQty + 1 > p.stockQty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Stok yetersiz: ${p.name} (stok: ${p.stockQty})')),
      );
      return;
    }

    if (idx >= 0) {
      cart[idx].qty += 1;
      cart[idx].lineTotal = cart[idx].qty * cart[idx].unitPrice;
    } else {
      final s = SaleItem()
        ..productId = p.id
        ..qty = 1
        ..unitPrice = p.salePrice
        ..lineTotal = p.salePrice;
      cart.add(s);
      names[p.id] = p.name;
      stocks[p.id] = p.stockQty;
    }
    setState(() {});
  }

  double get total => cart.fold(0, (s, e) => s + e.lineTotal);

  Future<void> _scan() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ScannerSheet(onDetected: (code) async {
        final p = await ref.read(productRepoProvider).byBarcode(code);
        if (p != null) {
          _addToCart(p);
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
      _addToCart(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                  onPressed: _scan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Barkod Tara')),
              FilledButton.icon(
                  onPressed: _openSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Ürün Ara')),
              Text('Toplam: ${total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge),
              FilledButton(
                onPressed: cart.isEmpty
                    ? null
                    : () async {
                        await ref.read(saleRepoProvider).createSale(cart);
                        cart.clear();
                        names.clear();
                        stocks.clear();
                        if (mounted) setState(() {});
                      },
                child: const Text('Satışı Kaydet'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: cart.length,
            itemBuilder: (c, i) {
              final it = cart[i];
              final name = names[it.productId] ?? 'Ürün #${it.productId}';
              final stok = stocks[it.productId];
              return ListTile(
                title: Text(name),
                subtitle: Text(
                    'Adet: ${it.qty}  x  ${it.unitPrice.toStringAsFixed(2)}' +
                        (stok != null ? '  |  Stok: $stok' : '')),
                trailing: Text(it.lineTotal.toStringAsFixed(2)),
                onTap: () {
                  final allowed = stok == null || it.qty + 1 <= stok;
                  if (!allowed) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Stok yetersiz: $name')));
                    return;
                  }
                  setState(() {
                    it.qty += 1;
                    it.lineTotal = it.qty * it.unitPrice;
                  });
                },
                onLongPress: () {
                  setState(() {
                    if (it.qty > 1) {
                      it.qty -= 1;
                      it.lineTotal = it.qty * it.unitPrice;
                    } else {
                      cart.removeAt(i);
                      names.remove(it.productId);
                      stocks.remove(it.productId);
                    }
                  });
                },
              );
            },
          ),
        )
      ],
    );
  }
}

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
          MobileScanner(onDetect: (capture) {
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
          }),
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          )
        ],
      ),
    );
  }
}

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
      height: MediaQuery.of(context).size.height * 0.80,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _q,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'İsim veya barkod ile ara...',
              ),
            ),
          ),
          if (loading) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (c, i) {
                final p = results[i];
                return ListTile(
                  title: Text(p.name),
                  subtitle: Text(
                      'Barkod: ${p.barcode ?? '-'} | Fiyat: ${p.salePrice.toStringAsFixed(2)} | Stok: ${p.stockQty}'),
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: () => Navigator.pop(context, p),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
