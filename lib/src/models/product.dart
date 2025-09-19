import 'package:isar/isar.dart';
part 'product.g.dart';

@collection
class Product {
  Id id = Isar.autoIncrement;

  @Index(caseSensitive: false)
  late String name;

  @Index(unique: true, caseSensitive: false, replace: true)
  String? barcode;

  double costPrice = 0;
  double salePrice = 0;
  int stockQty = 0;
  int minStock = 5;
}
