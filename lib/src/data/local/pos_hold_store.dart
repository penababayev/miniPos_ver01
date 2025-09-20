import 'package:hive_flutter/hive_flutter.dart';

class HeldCartItem {
  final int productId;
  final int qty;
  final double unitPrice;
  HeldCartItem(
      {required this.productId, required this.qty, required this.unitPrice});

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'qty': qty,
        'unitPrice': unitPrice,
      };

  factory HeldCartItem.fromMap(Map m) => HeldCartItem(
        productId: (m['productId'] as num).toInt(),
        qty: (m['qty'] as num).toInt(),
        unitPrice: (m['unitPrice'] as num).toDouble(),
      );
}

class HeldCart {
  final String id;
  String title;
  final DateTime createdAt;
  final List<HeldCartItem> items;

  HeldCart(
      {required this.id,
      required this.title,
      required this.createdAt,
      required this.items});

  double get total => items.fold(0.0, (s, e) => s + (e.unitPrice * e.qty));

  int get lines => items.length;
  int get qtyTotal => items.fold(0, (s, e) => s + e.qty);

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'items': items.map((e) => e.toMap()).toList(),
      };

  factory HeldCart.fromMap(Map m) => HeldCart(
        id: m['id'] as String,
        title: m['title'] as String,
        createdAt: DateTime.parse(m['createdAt'] as String),
        items: (m['items'] as List)
            .map((e) => HeldCartItem.fromMap(e as Map))
            .toList(),
      );
}

class PosHoldStore {
  static final PosHoldStore _i = PosHoldStore._();
  PosHoldStore._();
  factory PosHoldStore() => _i;

  Box? _box;

  Future<void> init() async {
    if (_box != null) return;
    await Hive.initFlutter();
    _box = await Hive.openBox('pos_holds');
  }

  String newId() => DateTime.now().millisecondsSinceEpoch.toString();

  Future<List<HeldCart>> list() async {
    await init();
    final all = _box!.toMap().values.toList();
    final holds = <HeldCart>[];
    for (final v in all) {
      if (v is Map) {
        holds.add(HeldCart.fromMap(v));
      }
    }
    // en yeni üstte
    holds.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return holds;
  }

  Future<void> save(HeldCart c) async {
    await init();
    await _box!.put(c.id, c.toMap());
  }

  Future<void> remove(String id) async {
    await init();
    await _box!.delete(id);
  }

  Future<void> rename(String id, String title) async {
    await init();
    final raw = _box!.get(id);
    if (raw is Map) {
      final c = HeldCart.fromMap(raw);
      c.title = title;
      await _box!.put(id, c.toMap());
    }
  }
}
