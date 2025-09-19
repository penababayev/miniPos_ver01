import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/product.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';
import '../../models/stock_movement.dart';

final isarProvider = Provider<Isar>((ref) => throw UnimplementedError());

class IsarService {
  Future<Isar> open() async {
    final dir = await getApplicationDocumentsDirectory();
    return await Isar.open([
      ProductSchema,
      SaleSchema,
      SaleItemSchema,
      StockMovementSchema,
    ], directory: dir.path);
  }
}
