import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  late final TextEditingController nameCtrl;
  late final TextEditingController barcodeCtrl;
  late final TextEditingController costCtrl;
  late final TextEditingController saleCtrl;
  late final TextEditingController stockCtrl;
  late final TextEditingController minStockCtrl;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    nameCtrl = TextEditingController(text: p?.name ?? '');
    barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    costCtrl = TextEditingController(text: (p?.costPrice ?? 0).toString());
    saleCtrl = TextEditingController(text: (p?.salePrice ?? 0).toString());
    stockCtrl = TextEditingController(text: (p?.stockQty ?? 0).toString());
    minStockCtrl = TextEditingController(text: (p?.minStock ?? 5).toString());
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    barcodeCtrl.dispose();
    costCtrl.dispose();
    saleCtrl.dispose();
    stockCtrl.dispose();
    minStockCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.product == null ? 'Yeni Ürün' : 'Ürün Düzenle')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Ürün adı'),
                validator: (v) => v == null || v.isEmpty ? 'Gerekli' : null),
            TextFormField(
                controller: barcodeCtrl,
                decoration:
                    const InputDecoration(labelText: 'Barkod (opsiyonel)')),
            Row(children: [
              Expanded(
                  child: TextFormField(
                      controller: costCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Alış fiyatı'))),
              const SizedBox(width: 12),
              Expanded(
                  child: TextFormField(
                      controller: saleCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Satış fiyatı'))),
            ]),
            Row(children: [
              Expanded(
                  child: TextFormField(
                      controller: stockCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Stok adedi'))),
              const SizedBox(width: 12),
              Expanded(
                  child: TextFormField(
                      controller: minStockCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Kritik stok'))),
            ]),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                if (!_form.currentState!.validate()) return;
                final repo = ref.read(productRepoProvider);
                final p = (widget.product ?? Product())
                  ..name = nameCtrl.text
                  ..barcode = barcodeCtrl.text.isEmpty ? null : barcodeCtrl.text
                  ..costPrice = double.tryParse(costCtrl.text) ?? 0
                  ..salePrice = double.tryParse(saleCtrl.text) ?? 0
                  ..stockQty = int.tryParse(stockCtrl.text) ?? 0
                  ..minStock = int.tryParse(minStockCtrl.text) ?? 5;
                if (widget.product == null) {
                  await repo.add(p);
                } else {
                  await repo.update(p);
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Kaydet'),
            )
          ],
        ),
      ),
      floatingActionButton: widget.product == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                await ref.read(productRepoProvider).delete(widget.product!.id);
                if (mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Sil'),
            ),
    );
  }
}
