import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';
import '../../models/product.dart';
import '../local/isar_service.dart';

final saleRepoProvider =
    Provider<SaleRepo>((ref) => SaleRepo(ref.read(isarProvider)));

class SaleRepo {
  final Isar isar;
  SaleRepo(this.isar);

  Future<int> createSale(List<SaleItem> items,
      {String paymentType = 'cash'}) async {
    return isar.writeTxn<int>(() async {
      final sale = Sale()
        ..createdAt = DateTime.now()
        ..paymentType = paymentType
        ..total = items.fold(0, (sum, e) => sum + e.lineTotal);

      final saleId = await isar.sales.put(sale);

      for (final item in items) {
        item.saleId = saleId;
        await isar.saleItems.put(item);
        final p = await isar.products.get(item.productId);
        if (p != null) {
          p.stockQty -= item.qty;
          await isar.products.put(p);
        }
      }
      return saleId;
    });
  }
}
