import 'package:isar/isar.dart';
part 'sale.g.dart';

@collection
class Sale {
  Id id = Isar.autoIncrement;
  late DateTime createdAt;
  double total = 0;
  String paymentType = 'cash';
}
