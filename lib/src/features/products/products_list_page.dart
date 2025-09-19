import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repos/product_repo.dart';
import '../../models/product.dart';
import 'product_edit_page.dart';

class ProductsListPage extends ConsumerStatefulWidget {
  const ProductsListPage({super.key});
  @override
  ConsumerState<ProductsListPage> createState() => _ProductsListPageState();
}

class _ProductsListPageState extends ConsumerState<ProductsListPage> {
  String query = '';

  Future<void> _goNewProduct() async {
    await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ProductEditPage(),
        ));
    if (mounted) setState(() {}); // listeyi yenile
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Product>>(
        future: query.isEmpty
            ? ref.read(productRepoProvider).all()
            : ref.read(productRepoProvider).search(query),
        builder: (context, snap) {
          final items = snap.data ?? [];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search), hintText: 'Ürün ara...'),
                  onChanged: (v) => setState(() => query = v),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (c, i) {
                    final p = items[i];
                    return ListTile(
                      title: Text(p.name),
                      subtitle: Text(
                          'Stok: ${p.stockQty}  |  Fiyat: ${p.salePrice.toStringAsFixed(2)}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductEditPage(product: p),
                              ));
                          if (mounted) setState(() {});
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goNewProduct,
        icon: const Icon(Icons.add),
        label: const Text('Yeni Ürün'),
      ),
    );
  }
}
