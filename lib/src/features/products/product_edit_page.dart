import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/local/product_meta_store.dart';
import '../../data/repos/product_repo.dart';
import '../../models/product.dart';

class ProductEditPage extends ConsumerStatefulWidget {
  final Product? product;
  const ProductEditPage({super.key, this.product});

  @override
  ConsumerState<ProductEditPage> createState() => _ProductEditPageState();
}

class _ProductEditPageState extends ConsumerState<ProductEditPage> {
  final _form = GlobalKey<FormState>();

  late TextEditingController name;
  late TextEditingController barcode;
  late TextEditingController cost;
  late TextEditingController price;
  late TextEditingController stock;
  late TextEditingController minStock;

  String unit = 'adet'; // adet | kg | m | lt
  String? imgB64;

  final meta = ProductMetaStore();

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    name = TextEditingController(text: p?.name ?? '');
    barcode = TextEditingController(text: p?.barcode ?? '');
    cost = TextEditingController(text: (p?.costPrice ?? 0).toString());
    price = TextEditingController(text: (p?.salePrice ?? 0).toString());
    stock = TextEditingController(text: (p?.stockQty ?? 0).toString());
    minStock = TextEditingController(text: (p?.minStock ?? 5).toString());

    () async {
      await meta.init();
      if (p != null) {
        unit = await meta.getUnit(p.id) ?? 'adet';
        imgB64 = await meta.getImageBase64(p.id);
        if (mounted) setState(() {});
      }
    }();
  }

  @override
  void dispose() {
    name.dispose();
    barcode.dispose();
    cost.dispose();
    price.dispose();
    stock.dispose();
    minStock.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 900, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    imgB64 = base64Encode(bytes);
    setState(() {});
  }

  Uint8List? get _imgBytes {
    if (imgB64 == null) return null;
    try {
      return base64Decode(imgB64!);
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    final repo = ref.read(productRepoProvider);
    final p = widget.product ?? Product()
      ..name = name.text.trim()
      ..barcode = barcode.text.trim().isEmpty ? null : barcode.text.trim()
      ..costPrice = double.tryParse(cost.text.replaceAll(',', '.')) ?? 0
      ..salePrice = double.tryParse(price.text.replaceAll(',', '.')) ?? 0
      ..stockQty = int.tryParse(stock.text) ?? 0
      ..minStock = int.tryParse(minStock.text) ?? 5;

    if (widget.product != null) {
      // update
      p.name = name.text.trim();
      p.barcode = barcode.text.trim().isEmpty ? null : barcode.text.trim();
      p.costPrice = double.tryParse(cost.text.replaceAll(',', '.')) ?? 0;
      p.salePrice = double.tryParse(price.text.replaceAll(',', '.')) ?? 0;
      p.stockQty = int.tryParse(stock.text) ?? 0;
      p.minStock = int.tryParse(minStock.text) ?? 5;
      await repo.update(p);
    } else {
      await repo.add(p);
    }

    // meta: unit + image
    await meta.setUnit(p.id, unit);
    if (imgB64 != null && imgB64!.isNotEmpty) {
      await meta.setImageBase64(p.id, imgB64!);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.product == null ? 'Yeni Ürün' : 'Ürün Düzenle';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Görsel
          Center(
            child: InkWell(
              onTap: _pickImage,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: _imgBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.memory(_imgBytes!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_a_photo, size: 32),
                          SizedBox(height: 8),
                          Text('Fotoğraf ekle'),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Form
          Form(
            key: _form,
            child: Column(
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Ürün Adı'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: barcode,
                  decoration:
                      const InputDecoration(labelText: 'Barkod (opsiyonel)'),
                ),
                const SizedBox(height: 8),

                // Ölçü birimi
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: unit,
                        decoration:
                            const InputDecoration(labelText: 'Ölçü birimi'),
                        items: const [
                          DropdownMenuItem(
                              value: 'adet', child: Text('Adet (sayı)')),
                          DropdownMenuItem(
                              value: 'kg', child: Text('Kilogram (kg)')),
                          DropdownMenuItem(
                              value: 'm', child: Text('Metre (m)')),
                          DropdownMenuItem(
                              value: 'lt', child: Text('Litre (lt)')),
                        ],
                        onChanged: (v) => setState(() => unit = v ?? 'adet'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: price,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: 'Satış Fiyatı (${unit})'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: cost,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Alış Fiyatı'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: stock,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText:
                                'Stok (${unit == 'adet' ? 'adet' : unit})'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: minStock,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Kritik Stok (min)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                label: const Text('Vazgeç'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Kaydet'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
