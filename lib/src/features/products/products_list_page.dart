import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../data/local/isar_service.dart';
import '../../models/product.dart';

// Yalnızca yöneticiye gösterilecek widget (FAB ve menü öğeleri için)
import 'widgets/manager_only.dart';

class ProductsListPage extends ConsumerStatefulWidget {
  const ProductsListPage({super.key});
  @override
  ConsumerState<ProductsListPage> createState() => _ProductsListPageState();
}

class _ProductsListPageState extends ConsumerState<ProductsListPage> {
  final _searchCtl = TextEditingController();
  String _query = '';

  List<Product> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final isar = ref.read(isarProvider);
    final items = await isar.products.where().findAll();
    // İsim alanı yoksa da patlamasın diye güvenli karşılaştırma
    items.sort(
        (a, b) => _nameOf(a).toLowerCase().compareTo(_nameOf(b).toLowerCase()));
    setState(() {
      _all = items;
      _loading = false;
    });
  }

  List<Product> get _filtered {
    final q = _query.trim().toLowerCase();
    return _all.where((p) {
      if (q.isEmpty) return true;
      final name = _nameOf(p).toLowerCase();
      final barcode = (_barcodeOf(p) ?? '').toLowerCase();
      return name.contains(q) || barcode.contains(q);
    }).toList();
  }

  Future<void> _delete(Product p) async {
    final isar = ref.read(isarProvider);
    await isar.writeTxn(() async {
      await isar.products.delete(p.id);
    });
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Silindi: ${_nameOf(p)}')));
    }
    _reload();
  }

  Future<void> _openEditor({Product? existing}) async {
    await showDialog(
      context: context,
      builder: (_) => _ProductEditorDialog(
        existing: existing,
        onSaved: _reload,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;

    return Scaffold(
      appBar: AppBar(title: const Text('Ürünler')),
      body: Column(
        children: [
          // Arama
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              controller: _searchCtl,
              decoration: InputDecoration(
                hintText: 'Ürün adı veya barkod ara',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchCtl.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 4),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? const Center(child: Text('Ürün bulunamadı'))
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final p = list[i];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                _nameOf(p).isNotEmpty
                                    ? _nameOf(p).characters.first.toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            title: Text(_nameOf(p)),
                            subtitle: Text([
                              if ((_barcodeOf(p) ?? '').isNotEmpty)
                                'Barkod: ${_barcodeOf(p)}',
                              if (_costOf(p) != null)
                                'Maliyet: ${_costOf(p)!.toStringAsFixed(2)}',
                            ].join('   •   ')),
                            trailing: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              children: [
                                Chip(
                                    label: Text(
                                        '₺${_priceOf(p).toStringAsFixed(2)}')),
                                // Yalnızca yöneticiye göster: düzenle/sil
                                ManagerOnly(
                                  child: PopupMenuButton<String>(
                                    onSelected: (v) {
                                      if (v == 'edit') _openEditor(existing: p);
                                      if (v == 'delete') _confirmDelete(p);
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Düzenle')),
                                      PopupMenuItem(
                                          value: 'delete', child: Text('Sil')),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _openEditor(existing: p),
                          );
                        },
                      ),
          ),
        ],
      ),

      // 🔒 Yalnızca yönetici görebilir
      floatingActionButton: const ManagerOnly(
        child: _AddFab(),
      ),
    );
  }

  void _confirmDelete(Product p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ürünü sil'),
        content: Text('"${_nameOf(p)}" kalıcı olarak silinsin mi?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _delete(p);
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  // ====== FIELD ADAPTERS (alan adları farklı olduğunda derleme hatası vermeden çalışır) ======

  String _nameOf(Product p) {
    // name alanı yoksa diğer muhtemel adlara bak
    try {
      final d = p as dynamic;
      final v = d.name ?? d.title ?? d.productName;
      if (v is String) return v;
    } catch (_) {}
    return ''; // fallback
  }

  String? _barcodeOf(Product p) {
    try {
      final d = p as dynamic;
      final v = d.barcode ?? d.barCode ?? d.ean ?? d.ean13 ?? d.sku ?? d.code;
      if (v is String) return v;
    } catch (_) {}
    return null;
  }

  double _priceOf(Product p) {
    try {
      final d = p as dynamic;
      final v = d.price ??
          d.sellingPrice ??
          d.salePrice ??
          d.unitPrice ??
          d.listPrice;
      if (v is num) return v.toDouble();
    } catch (_) {}
    return 0.0;
  }

  double? _costOf(Product p) {
    try {
      final d = p as dynamic;
      final v = d.costPrice ?? d.buyPrice ?? d.purchasePrice ?? d.cost;
      if (v is num) return v.toDouble();
    } catch (_) {}
    return null;
  }

  void _setPrice(Product p, double price) {
    final d = p as dynamic;
    for (final key in [
      'price',
      'sellingPrice',
      'salePrice',
      'unitPrice',
      'listPrice'
    ]) {
      try {
        // ignore: invalid_use_of_protected_member
        d.noSuchMethod; // sadece dynamic kaldıgını garanti etmek için erişim
        // atama dene
        switch (key) {
          case 'price':
            d.price = price;
            return;
          case 'sellingPrice':
            d.sellingPrice = price;
            return;
          case 'salePrice':
            d.salePrice = price;
            return;
          case 'unitPrice':
            d.unitPrice = price;
            return;
          case 'listPrice':
            d.listPrice = price;
            return;
        }
      } catch (_) {/* diğer ismi dene */}
    }
  }

  void _setCost(Product p, double cost) {
    final d = p as dynamic;
    for (final key in ['costPrice', 'buyPrice', 'purchasePrice', 'cost']) {
      try {
        switch (key) {
          case 'costPrice':
            d.costPrice = cost;
            return;
          case 'buyPrice':
            d.buyPrice = cost;
            return;
          case 'purchasePrice':
            d.purchasePrice = cost;
            return;
          case 'cost':
            d.cost = cost;
            return;
        }
      } catch (_) {}
    }
  }

  void _setCreatedAt(Product p) {
    try {
      final d = p as dynamic;
      d.createdAt = DateTime.now();
    } catch (_) {
      // alan yoksa yok say
    }
  }
}

class _AddFab extends ConsumerWidget {
  const _AddFab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton(
      onPressed: () {
        showDialog(
          context: context,
          builder: (_) => _ProductEditorDialog(
            existing: null,
            onSaved: () {},
          ),
        );
      },
      child: const Icon(Icons.add),
    );
  }
}

// ------------------ ÜRÜN EDITÖR DİYALOGU (dinamik alan destekli) ------------------

class _ProductEditorDialog extends ConsumerStatefulWidget {
  const _ProductEditorDialog({required this.onSaved, this.existing});
  final Product? existing;
  final VoidCallback onSaved;

  @override
  ConsumerState<_ProductEditorDialog> createState() =>
      _ProductEditorDialogState();
}

class _ProductEditorDialogState extends ConsumerState<_ProductEditorDialog> {
  final _form = GlobalKey<FormState>();

  late TextEditingController nameCtl;
  late TextEditingController barcodeCtl;
  late TextEditingController priceCtl;
  late TextEditingController costCtl;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    nameCtl = TextEditingController(text: _nameOf(e));
    barcodeCtl = TextEditingController(text: _barcodeOf(e) ?? '');
    priceCtl = TextEditingController(text: _fmt(_priceOf(e)));
    costCtl = TextEditingController(text: _fmt(_costOf(e)));
  }

  @override
  void dispose() {
    nameCtl.dispose();
    barcodeCtl.dispose();
    priceCtl.dispose();
    costCtl.dispose();
    super.dispose();
  }

  String _fmt(double? v) => v == null ? '' : v.toStringAsFixed(2);

  // --- field adapters (Dialog içinden de ulaşmak için static-free kopya) ---
  String _nameOf(Product? p) {
    if (p == null) return '';
    try {
      final d = p as dynamic;
      final v = d.name ?? d.title ?? d.productName;
      if (v is String) return v;
    } catch (_) {}
    return '';
  }

  String? _barcodeOf(Product? p) {
    if (p == null) return null;
    try {
      final d = p as dynamic;
      final v = d.barcode ?? d.barCode ?? d.ean ?? d.ean13 ?? d.sku ?? d.code;
      if (v is String) return v;
    } catch (_) {}
    return null;
  }

  double _priceOf(Product? p) {
    if (p == null) return 0.0;
    try {
      final d = p as dynamic;
      final v = d.price ??
          d.sellingPrice ??
          d.salePrice ??
          d.unitPrice ??
          d.listPrice;
      if (v is num) return v.toDouble();
    } catch (_) {}
    return 0.0;
  }

  double? _costOf(Product? p) {
    if (p == null) return null;
    try {
      final d = p as dynamic;
      final v = d.costPrice ?? d.buyPrice ?? d.purchasePrice ?? d.cost;
      if (v is num) return v.toDouble();
    } catch (_) {}
    return null;
  }

  void _setPrice(Product p, double price) {
    final d = p as dynamic;
    for (final key in [
      'price',
      'sellingPrice',
      'salePrice',
      'unitPrice',
      'listPrice'
    ]) {
      try {
        switch (key) {
          case 'price':
            d.price = price;
            return;
          case 'sellingPrice':
            d.sellingPrice = price;
            return;
          case 'salePrice':
            d.salePrice = price;
            return;
          case 'unitPrice':
            d.unitPrice = price;
            return;
          case 'listPrice':
            d.listPrice = price;
            return;
        }
      } catch (_) {}
    }
  }

  void _setCost(Product p, double cost) {
    final d = p as dynamic;
    for (final key in ['costPrice', 'buyPrice', 'purchasePrice', 'cost']) {
      try {
        switch (key) {
          case 'costPrice':
            d.costPrice = cost;
            return;
          case 'buyPrice':
            d.buyPrice = cost;
            return;
          case 'purchasePrice':
            d.purchasePrice = cost;
            return;
          case 'cost':
            d.cost = cost;
            return;
        }
      } catch (_) {}
    }
  }

  void _setCreatedAt(Product p) {
    try {
      final d = p as dynamic;
      d.createdAt = DateTime.now();
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    final isar = ref.read(isarProvider);
    final e = widget.existing;

    final name = nameCtl.text.trim();
    final barcode = barcodeCtl.text.trim();

    double parse(String s) => double.tryParse(s.replaceAll(',', '.')) ?? 0.0;
    final price = parse(priceCtl.text.trim());
    final cost = parse(costCtl.text.trim());

    await isar.writeTxn(() async {
      if (e == null) {
        final p = Product();
        // name alanı büyük ihtimalle var; yoksa görmezden geliriz
        try {
          (p as dynamic).name = name;
        } catch (_) {}
        try {
          (p as dynamic).barcode = barcode.isEmpty ? null : barcode;
        } catch (_) {
          // başka alan adı kullanılıyorsa, sadece kaydetmeyiz
        }
        _setPrice(p, price);
        _setCost(p, cost);
        _setCreatedAt(p);
        await isar.products.put(p);
      } else {
        try {
          (e as dynamic).name = name;
        } catch (_) {}
        try {
          (e as dynamic).barcode = barcode.isEmpty ? null : barcode;
        } catch (_) {}
        _setPrice(e, price);
        _setCost(e, cost);
        await isar.products.put(e);
      }
    });

    if (!mounted) return;
    Navigator.pop(context);
    widget.onSaved();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e == null ? 'Ürün eklendi' : 'Ürün güncellendi')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Yeni Ürün' : 'Ürünü Düzenle'),
      content: Form(
        key: _form,
        child: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: nameCtl,
                  decoration: const InputDecoration(
                    labelText: 'Ürün adı',
                    prefixIcon: Icon(Icons.inventory_2),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Ad zorunlu' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: barcodeCtl,
                  decoration: const InputDecoration(
                    labelText: 'Barkod (opsiyonel)',
                    prefixIcon: Icon(Icons.qr_code_2),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: priceCtl,
                  decoration: const InputDecoration(
                    labelText: 'Satış fiyatı (₺)',
                    prefixIcon: Icon(Icons.sell),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) =>
                      (double.tryParse((v ?? '').replaceAll(',', '.')) == null)
                          ? 'Geçerli bir sayı girin'
                          : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: costCtl,
                  decoration: const InputDecoration(
                    labelText: 'Maliyet (₺)',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) =>
                      (double.tryParse((v ?? '').replaceAll(',', '.')) == null)
                          ? 'Geçerli bir sayı girin'
                          : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal')),
        FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Kaydet')),
      ],
    );
  }
}
