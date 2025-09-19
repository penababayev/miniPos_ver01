import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../../models/product.dart';
import '../local/isar_service.dart';

final productRepoProvider =
    Provider<ProductRepo>((ref) => ProductRepo(ref.read(isarProvider)));

class ProductRepo {
  final Isar isar;
  ProductRepo(this.isar);

  Future<int> add(Product p, {int initialQty = 0}) async {
    return isar.writeTxn<int>(() async {
      final id = await isar.products.put(p);
      if (initialQty != 0) {
        final prod = await isar.products.get(id);
        if (prod != null) {
          prod.stockQty += initialQty;
          await isar.products.put(prod);
        }
      }
      return id;
    });
  }

  Future<void> update(Product p) => isar.writeTxn(() => isar.products.put(p));
  Future<void> delete(Id id) => isar.writeTxn(() => isar.products.delete(id));

  Future<List<Product>> all() => isar.products.where().sortByName().findAll();

  // İsim VEYA barkoda göre arama
  Future<List<Product>> search(String q) => isar.products
      .filter()
      .group((g) => g
          .nameContains(q, caseSensitive: false)
          .or()
          .barcodeContains(q, caseSensitive: false))
      .sortByName()
      .findAll();

  Future<Product?> byBarcode(String code) => isar.products
      .filter()
      .barcodeEqualTo(code, caseSensitive: false)
      .findFirst();
}
