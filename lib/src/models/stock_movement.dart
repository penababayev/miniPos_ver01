import 'package:isar/isar.dart';
part 'stock_movement.g.dart';

@collection
class StockMovement {
  Id id = Isar.autoIncrement;
  late int productId;
  int delta = 0; // +in, -out
  String reason = '';
  late DateTime createdAt;
}
