import 'dart:math' as math;
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

  /// items içinde qty (int), unitPrice ve lineTotal dolu olmalı.
  /// paymentType: 'cash' | 'card' | 'credit'
  /// discount: sepet indirimi (TL). Toplam = sum(lineTotal) - discount
  Future<int> createSale(
    List<SaleItem> items, {
    String paymentType = 'cash',
    double discount = 0.0,
  }) async {
    final now = DateTime.now();

    final subtotal = items.fold<double>(0.0, (s, e) => s + e.lineTotal);
    final safeDiscount = discount < 0 ? 0.0 : discount;
    // clamp yerine double dönen max kullanıyoruz
    final total = math.max(0.0, subtotal - safeDiscount);

    return isar.writeTxn<int>(() async {
      final sale = Sale()
        ..createdAt = now
        ..total = total
        ..paymentType = paymentType;

      final saleId = await isar.sales.put(sale);

      for (final it in items) {
        it.saleId = saleId;
        await isar.saleItems.put(it);

        // stok düş: int bekliyor → clamp sonrası .toInt()
        final p = await isar.products.get(it.productId);
        if (p != null) {
          p.stockQty = (p.stockQty - it.qty).clamp(0, 1 << 31).toInt();
          await isar.products.put(p);
        }
      }
      return saleId;
    });
  }
}
