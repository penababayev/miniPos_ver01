import 'package:isar/isar.dart';
part 'sale_item.g.dart';

@collection
class SaleItem {
  Id id = Isar.autoIncrement;
  late int saleId; // FK to Sale
  late int productId; // FK to Product
  int qty = 1;
  double unitPrice = 0;
  double lineTotal = 0;
}
