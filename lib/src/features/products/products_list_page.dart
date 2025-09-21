import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../data/local/isar_service.dart';
import '../../core/auth_controller.dart';
import '../../models/app_user.dart';
import '../../models/product.dart';

class ProductsListPage extends ConsumerStatefulWidget {
  const ProductsListPage({super.key});

  @override
  ConsumerState<ProductsListPage> createState() => _ProductsListPageState();
}

class _ProductsListPageState extends ConsumerState<ProductsListPage> {
  final _q = TextEditingController();
  bool _loading = true;
  List<Product> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
    _q.addListener(_load);
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Isar get _isar => ref.read(isarProvider);

  Future<void> _load() async {
    setState(() => _loading = true);

    final all = await _isar.products
        .where()
        .findAll(); // sortByName kullanma -> her modelde yok
    final text = _q.text.trim().toLowerCase();

    List<Product> list = all;
    if (text.isNotEmpty) {
      list = all.where((p) {
        final name =
            (_get<String>(p, const ['name', 'title', 'productName']) ?? '')
                .toLowerCase();
        final bc = (_get<String>(
                    p, const ['barcode', 'barCode', 'ean', 'sku', 'code']) ??
                '')
            .toLowerCase();
        return name.contains(text) || bc.contains(text);
      }).toList();
    }

    list.sort((a, b) {
      final an = _get<String>(a, const ['name', 'title', 'productName']) ?? '';
      final bn = _get<String>(b, const ['name', 'title', 'productName']) ?? '';
      return an.compareTo(bn);
    });

    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _addOrEdit({Product? product}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ProductEditorSheet(initial: product),
    );
    if (ok == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(product == null ? 'Ürün eklendi' : 'Ürün güncellendi')),
      );
    }
  }

  Future<void> _delete(Product p) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Silinsin mi?'),
        content: Text('"${_get<String>(p, const [
                  'name'
                ]) ?? '(adsız)'}" ürünü silinecek.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (yes != true) return;
    await _isar.writeTxn(() async => _isar.products.delete(p.id));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).user;
    final canEdit = me?.role == UserRole.manager;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Ürünler',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (canEdit)
                  FilledButton.icon(
                    onPressed: () => _addOrEdit(),
                    icon: const Icon(Icons.add),
                    label: const Text('Yeni Ürün'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _q,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Ürün adı veya barkod ara',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Ürün bulunamadı'),
                              const SizedBox(height: 8),
                              if (canEdit)
                                OutlinedButton.icon(
                                  onPressed: () => _addOrEdit(),
                                  icon: const Icon(Icons.add),
                                  label: const Text('İlk ürünü ekle'),
                                ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final p = _items[i];
                            final name = _get<String>(p,
                                    const ['name', 'title', 'productName']) ??
                                '(adsız)';
                            final barcode = _get<String>(p, const [
                              'barcode',
                              'barCode',
                              'ean',
                              'sku',
                              'code'
                            ]);
                            final unit = _get<String>(p, const [
                                  'unit',
                                  'uom',
                                  'measure',
                                  'measureUnit'
                                ]) ??
                                '';
                            final price = (_get<num>(p, const [
                                  'price',
                                  'sellingPrice',
                                  'salePrice',
                                  'unitPrice',
                                  'listPrice'
                                ])?.toDouble()) ??
                                0.0;

                            return ListTile(
                              leading: const Icon(Icons.inventory_2),
                              title: Text(name),
                              subtitle: Text([
                                if ((barcode ?? '').isNotEmpty)
                                  'Barkod: $barcode',
                                if (unit.isNotEmpty) 'Birim: $unit',
                              ].join(' • ')),
                              trailing: Text(price.toStringAsFixed(2)),
                              onTap:
                                  canEdit ? () => _addOrEdit(product: p) : null,
                              onLongPress: canEdit ? () => _delete(p) : null,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _addOrEdit(),
              icon: const Icon(Icons.add),
              label: const Text('Ürün'),
            )
          : null,
    );
  }
}

/// Ürün ekleme/düzenleme sayfası (bottom sheet)
class ProductEditorSheet extends ConsumerStatefulWidget {
  const ProductEditorSheet({super.key, this.initial});
  final Product? initial;

  @override
  ConsumerState<ProductEditorSheet> createState() => _ProductEditorSheetState();
}

class _ProductEditorSheetState extends ConsumerState<ProductEditorSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController nameCtrl;
  late final TextEditingController barcodeCtrl;
  late final TextEditingController priceCtrl;
  late final TextEditingController costCtrl;
  String unit = 'adet';

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    nameCtrl = TextEditingController(
        text: p == null
            ? ''
            : _get<String>(p, const ['name', 'title', 'productName']) ?? '');
    barcodeCtrl = TextEditingController(
        text: p == null
            ? ''
            : _get<String>(
                    p, const ['barcode', 'barCode', 'ean', 'sku', 'code']) ??
                '');
    final price = p == null
        ? null
        : _get<num>(p, const [
            'price',
            'sellingPrice',
            'salePrice',
            'unitPrice',
            'listPrice'
          ]);
    final cost = p == null
        ? null
        : _get<num>(
            p, const ['costPrice', 'buyPrice', 'purchasePrice', 'cost']);
    priceCtrl = TextEditingController(
        text: price == null ? '' : price.toDouble().toStringAsFixed(2));
    costCtrl = TextEditingController(
        text: cost == null ? '' : cost.toDouble().toStringAsFixed(2));
    unit = p == null
        ? 'adet'
        : (_get<String>(p, const ['unit', 'uom', 'measure', 'measureUnit']) ??
            'adet');
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    barcodeCtrl.dispose();
    priceCtrl.dispose();
    costCtrl.dispose();
    super.dispose();
  }

  Isar get _isar => ref.read(isarProvider);

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    final price = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final cost = double.tryParse(costCtrl.text.replaceAll(',', '.')) ?? 0.0;

    await _isar.writeTxn(() async {
      final p = widget.initial ?? Product();

      _set(p, 'name', nameCtrl.text.trim());
      _set(p, 'barcode', barcodeCtrl.text.trim());
      _set(p, 'unit', unit);
      _set(p, 'price', price);
      _set(p, 'costPrice', cost);
      _set(p, 'createdAt', DateTime.now());

      await _isar.products.put(p);
    });

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEdit ? 'Ürünü Düzenle' : 'Yeni Ürün',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ürün adı',
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: barcodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Barkod (opsiyonel)',
                  prefixIcon: Icon(Icons.qr_code_2),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: unit,
                decoration: const InputDecoration(
                  labelText: 'Birim',
                  prefixIcon: Icon(Icons.scale),
                ),
                items: const [
                  DropdownMenuItem(value: 'adet', child: Text('Adet')),
                  DropdownMenuItem(value: 'kg', child: Text('Kilogram')),
                  DropdownMenuItem(value: 'lt', child: Text('Litre')),
                  DropdownMenuItem(value: 'm', child: Text('Metre')),
                  DropdownMenuItem(value: 'paket', child: Text('Paket')),
                ],
                onChanged: (v) => setState(() => unit = v ?? 'adet'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: priceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Satış fiyatı',
                        prefixIcon: Icon(Icons.sell),
                        suffixText: '₺',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        final t = (v ?? '').trim().replaceAll(',', '.');
                        final d = double.tryParse(t);
                        if (d == null) return 'Geçerli sayı girin';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: costCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Maliyet (ops.)',
                        prefixIcon: Icon(Icons.production_quantity_limits),
                        suffixText: '₺',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close),
                    label: const Text('İptal'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: Text(isEdit ? 'Kaydet' : 'Ekle'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/* ----------------- Dinamik alan yardımcıları ----------------- */

T? _get<T>(Product p, List<String> names) {
  final d = p as dynamic;
  for (final n in names) {
    try {
      dynamic v;
      switch (n) {
        case 'name':
          v = d.name;
          break;
        case 'title':
          v = d.title;
          break;
        case 'productName':
          v = d.productName;
          break;
        case 'barcode':
          v = d.barcode;
          break;
        case 'barCode':
          v = d.barCode;
          break;
        case 'ean':
          v = d.ean;
          break;
        case 'sku':
          v = d.sku;
          break;
        case 'code':
          v = d.code;
          break;
        case 'unit':
          v = d.unit;
          break;
        case 'uom':
          v = d.uom;
          break;
        case 'measure':
          v = d.measure;
          break;
        case 'measureUnit':
          v = d.measureUnit;
          break;

        case 'price':
          v = d.price;
          break;
        case 'sellingPrice':
          v = d.sellingPrice;
          break;
        case 'salePrice':
          v = d.salePrice;
          break;
        case 'unitPrice':
          v = d.unitPrice;
          break;
        case 'listPrice':
          v = d.listPrice;
          break;

        case 'costPrice':
          v = d.costPrice;
          break;
        case 'buyPrice':
          v = d.buyPrice;
          break;
        case 'purchasePrice':
          v = d.purchasePrice;
          break;
        case 'cost':
          v = d.cost;
          break;

        case 'createdAt':
          v = d.createdAt;
          break;
        default:
          v = null;
      }
      if (v == null) continue;
      if (v is T) return v;
      if (T == double && v is num) return v.toDouble() as T;
      if (T == num && (v is int || v is double)) return v as T;
      if (T == String) return v.toString() as T;
      if (T == DateTime && v is String) return DateTime.tryParse(v) as T?;
    } catch (_) {
      // alan yoksa sonraki isme dene
    }
  }
  return null;
}

void _set(Product p, String name, Object? value) {
  if (value == null) return;
  final d = p as dynamic;
  try {
    switch (name) {
      case 'name':
        d.name = value;
        break;
      case 'barcode':
        d.barcode = value;
        break;
      case 'unit':
        d.unit = value;
        break;
      case 'price':
        d.price = value;
        break;
      case 'costPrice':
        d.costPrice = value;
        break;
      case 'createdAt':
        d.createdAt = value;
        break;
      default:
        break;
    }
  } catch (_) {
    // modelde alan yoksa sessiz geç
  }
}
