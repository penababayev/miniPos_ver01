import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../data/local/isar_service.dart';
import '../../core/auth_controller.dart';
import '../../models/app_user.dart';
import '../../models/product.dart';
import 'product_meta_service.dart';

class ProductsListPage extends ConsumerStatefulWidget {
  const ProductsListPage({super.key});

  @override
  ConsumerState<ProductsListPage> createState() => _ProductsListPageState();
}

class _ProductsListPageState extends ConsumerState<ProductsListPage> {
  final _q = TextEditingController();
  bool _loading = true;
  List<Product> _all = [];
  Map<int, Map<String, dynamic>> _meta = {};
  List<String> _cats = [];
  String _cat = 'Hepsi';

  @override
  void initState() {
    super.initState();
    _reload();
    _q.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Isar get _isar => ref.read(isarProvider);

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final prods = await _isar.products.where().findAll();
      final meta = await ProductMetaService.instance.allMeta();
      final cats = await ProductMetaService.instance.categories();

      prods.sort((a, b) => _name(a).compareTo(_name(b)));

      if (!mounted) return;
      setState(() {
        _all = prods;
        _meta = meta;
        _cats = cats;
        if (!_cats.contains(_cat) && _cat != 'Hepsi') _cat = 'Hepsi';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ürünler yüklenemedi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _name(Product p) =>
      _get<String>(p, const ['name', 'title', 'productName']) ?? '';

  String? _barcode(Product p) =>
      _get<String>(p, const ['barcode', 'barCode', 'ean', 'sku', 'code']);

  String _unit(Product p) =>
      _get<String>(p, const ['unit', 'uom', 'measure', 'measureUnit']) ?? '';

  double _price(Product p) =>
      (_get<num>(p, const [
        'price',
        'sellingPrice',
        'salePrice',
        'unitPrice',
        'listPrice'
      ])?.toDouble()) ??
      0.0;

  Iterable<Product> _filtered() {
    final q = _q.text.trim().toLowerCase();
    return _all.where((p) {
      final n = _name(p).toLowerCase();
      final b = (_barcode(p) ?? '').toLowerCase();
      final cat = (_meta[p.id]?['category'] as String?)?.toLowerCase() ?? '';
      final okQ = q.isEmpty || n.contains(q) || b.contains(q);
      final okC = _cat == 'Hepsi' || cat == _cat.toLowerCase();
      return okQ && okC;
    });
  }

  Future<void> _addOrEdit({Product? product}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ProductEditorSheet(
        initial: product,
        meta: _meta[product?.id ?? 0],
        knownCategories: _cats,
      ),
    );
    if (ok == true) {
      await _reload();
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
        content: Text('"${_name(p)}" ürünü silinecek.'),
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
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).user;
    final canEdit = me?.role == UserRole.manager;

    final items = _filtered().toList();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık + Ekle
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
            // Arama
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
            // Kategori çipleri
            if (_cats.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: const Text('Hepsi'),
                        selected: _cat == 'Hepsi',
                        onSelected: (_) => setState(() => _cat = 'Hepsi'),
                      ),
                    ),
                    ..._cats.map((c) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(c),
                            selected: _cat.toLowerCase() == c.toLowerCase(),
                            onSelected: (_) => setState(() => _cat = c),
                          ),
                        )),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
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
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final p = items[i];
                            final m = _meta[p.id];
                            final cat = (m?['category'] as String?) ?? '';
                            final avatar = FutureBuilder(
                              future: ProductMetaService.instance
                                  .imageProviderOf(p.id),
                              builder: (_, snap) {
                                final prov = snap.data as ImageProvider?;
                                if (prov == null) {
                                  return const CircleAvatar(
                                      child: Icon(Icons.image_not_supported));
                                }
                                return CircleAvatar(backgroundImage: prov);
                              },
                            );

                            // stok göstermek istersen (modelinde varsa) oku:
                            final onHand = _get<num>(
                                p, const ['currentStock', 'stock', 'onHand']);

                            return ListTile(
                              leading: SizedBox(
                                  width: 48, height: 48, child: avatar),
                              title:
                                  Text(_name(p).isEmpty ? '(adsız)' : _name(p)),
                              subtitle: Text([
                                if ((_barcode(p) ?? '').isNotEmpty)
                                  'Barkod: ${_barcode(p)}',
                                if (cat.isNotEmpty) 'Kategori: $cat',
                                if (_unit(p).isNotEmpty) 'Birim: ${_unit(p)}',
                                if (onHand != null)
                                  'Stok: ${onHand.toString()}',
                              ].join(' • ')),
                              trailing: Text(_price(p).toStringAsFixed(2)),
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

/// Ürün ekleme/düzenleme (kategori + resim + stok)
class ProductEditorSheet extends ConsumerStatefulWidget {
  const ProductEditorSheet({
    super.key,
    this.initial,
    this.meta,
    required this.knownCategories,
  });

  final Product? initial;
  final Map<String, dynamic>? meta;
  final List<String> knownCategories;

  @override
  ConsumerState<ProductEditorSheet> createState() => _ProductEditorSheetState();
}

class _ProductEditorSheetState extends ConsumerState<ProductEditorSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController nameCtrl;
  late final TextEditingController barcodeCtrl;
  late final TextEditingController priceCtrl;
  late final TextEditingController costCtrl;
  late final TextEditingController categoryCtrl;
  late final TextEditingController stockCtrl;
  late final TextEditingController minStockCtrl;

  String unit = 'adet';
  ImageProvider? _preview;

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
    categoryCtrl = TextEditingController(
        text: (widget.meta?['category'] as String?) ?? '');

    final onHand = p == null
        ? null
        : _get<num>(p, const ['currentStock', 'stock', 'onHand']);
    final minSt = p == null
        ? null
        : _get<num>(p, const ['minStock', 'reorderLevel', 'minQty']);
    stockCtrl =
        TextEditingController(text: onHand == null ? '' : onHand.toString());
    minStockCtrl =
        TextEditingController(text: minSt == null ? '' : minSt.toString());

    _loadPreview();
  }

  Future<void> _loadPreview() async {
    if (widget.initial == null) return;
    final prov =
        await ProductMetaService.instance.imageProviderOf(widget.initial!.id);
    if (mounted) setState(() => _preview = prov);
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    barcodeCtrl.dispose();
    priceCtrl.dispose();
    costCtrl.dispose();
    categoryCtrl.dispose();
    stockCtrl.dispose();
    minStockCtrl.dispose();
    super.dispose();
  }

  Isar get _isar => ref.read(isarProvider);

  Future<void> _save({bool closeSheet = true}) async {
    if (!_form.currentState!.validate()) return;

    final price = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final cost = double.tryParse(costCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final initStock =
        double.tryParse(stockCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final minStock =
        double.tryParse(minStockCtrl.text.replaceAll(',', '.')) ?? 0.0;

    int id = widget.initial?.id ?? 0;

    await _isar.writeTxn(() async {
      final p = widget.initial ?? Product();
      _set(p, 'name', nameCtrl.text.trim());
      _set(p, 'barcode', barcodeCtrl.text.trim());
      _set(p, 'unit', unit);
      _set(p, 'price', price);
      _set(p, 'costPrice', cost);
      _set(p, 'currentStock', initStock); // varsa yaz
      _set(p, 'stock', initStock);
      _set(p, 'onHand', initStock);
      _set(p, 'minStock', minStock);
      if (widget.initial == null) _set(p, 'createdAt', DateTime.now());
      id = await _isar.products.put(p);
    });

    await ProductMetaService.instance.setCategory(id, categoryCtrl.text.trim());

    if (!mounted) return;
    if (closeSheet) {
      Navigator.pop(context, true);
    } else {
      // Yeni eklemeye devam: alanları sıfırla
      setState(() {
        nameCtrl.clear();
        barcodeCtrl.clear();
        priceCtrl.clear();
        costCtrl.clear();
        categoryCtrl.clear();
        stockCtrl.clear();
        minStockCtrl.clear();
        unit = 'adet';
        _preview = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ürün eklendi')),
      );
    }
  }

  Future<void> _pickImage() async {
    if (widget.initial == null) return; // yeni üründe önce kaydet
    final id = widget.initial!.id;
    await ProductMetaService.instance.pickAndSaveImage(context, id);
    final prov = await ProductMetaService.instance.imageProviderOf(id);
    if (mounted) setState(() => _preview = prov);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final cats = widget.knownCategories;

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
              const SizedBox(height: 10),

              // Resim
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundImage: _preview,
                    child: _preview == null
                        ? const Icon(Icons.image, size: 32)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: isEdit ? _pickImage : null,
                    icon: const Icon(Icons.photo),
                    label: const Text('Resim seç'),
                  ),
                  const SizedBox(width: 8),
                  if (_preview != null)
                    OutlinedButton.icon(
                      onPressed: () async {
                        if (widget.initial == null) return;
                        await ProductMetaService.instance
                            .clearImage(widget.initial!.id);
                        setState(() => _preview = null);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Kaldır'),
                    ),
                ],
              ),
              if (!isEdit)
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 6),
                  child: Text(
                    'Önce ürünü kaydedin, sonra resim ekleyin.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
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

              // Kategori (yaz + öneri)
              Autocomplete<String>(
                initialValue: TextEditingValue(text: categoryCtrl.text),
                optionsBuilder: (TextEditingValue t) {
                  final q = t.text.toLowerCase();
                  return cats.where((e) => e.toLowerCase().contains(q));
                },
                onSelected: (v) => categoryCtrl.text = v,
                fieldViewBuilder: (ctx, textCtrl, focus, onSubmit) {
                  textCtrl.text = categoryCtrl.text;
                  textCtrl.addListener(() => categoryCtrl.text = textCtrl.text);
                  return TextField(
                    controller: textCtrl,
                    focusNode: focus,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      prefixIcon: Icon(Icons.category),
                    ),
                  );
                },
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

              // Fiyat & Maliyet
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
              const SizedBox(height: 8),

              // Stok alanları
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: stockCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Başlangıç Stoğu',
                        prefixIcon: Icon(Icons.inventory_2),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: minStockCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Minimum Stok',
                        prefixIcon: Icon(Icons.warning_amber),
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
                  // Kaydet + Yeni (yalnızca yeni oluştururken)
                  if (widget.initial == null) ...[
                    OutlinedButton(
                      onPressed: () => _save(closeSheet: false),
                      child: const Text('Kaydet + Yeni'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  FilledButton.icon(
                    onPressed: () => _save(),
                    icon: const Icon(Icons.save),
                    label: Text(widget.initial != null ? 'Kaydet' : 'Ekle'),
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

        case 'currentStock':
          v = d.currentStock;
          break;
        case 'stock':
          v = d.stock;
          break;
        case 'onHand':
          v = d.onHand;
          break;
        case 'minStock':
          v = d.minStock;
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
    } catch (_) {}
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

      case 'currentStock':
        d.currentStock = value;
        break;
      case 'stock':
        d.stock = value;
        break;
      case 'onHand':
        d.onHand = value;
        break;
      case 'minStock':
        d.minStock = value;
        break;

      case 'createdAt':
        d.createdAt = value;
        break;
      default:
        break;
    }
  } catch (_) {/* model alanı yoksa sessizce geç */}
}
