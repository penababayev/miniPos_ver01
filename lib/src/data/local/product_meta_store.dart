import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:hive_flutter/hive_flutter.dart';

/// Ürünlerin görseli ve ölçü birimini burada tutuyoruz (Isar şemasını değiştirmeden).
/// Box adı: product_meta
/// Key: productId.toString()
/// Value: Map<String, dynamic> => { "unit": "kg|m|lt|adet", "img": "<base64>" }

class ProductMetaStore {
  static final ProductMetaStore _i = ProductMetaStore._();
  ProductMetaStore._();
  factory ProductMetaStore() => _i;

  Box? _box;

  Future<void> init() async {
    if (_box != null) return;
    await Hive.initFlutter();
    _box = await Hive.openBox('product_meta');
  }

  Future<void> setUnit(int productId, String unit) async {
    await init();
    final key = productId.toString();
    final m =
        Map<String, dynamic>.from(_box!.get(key, defaultValue: {}) as Map);
    m['unit'] = unit;
    await _box!.put(key, m);
  }

  Future<void> setImageBase64(int productId, String base64) async {
    await init();
    final key = productId.toString();
    final m =
        Map<String, dynamic>.from(_box!.get(key, defaultValue: {}) as Map);
    m['img'] = base64;
    await _box!.put(key, m);
  }

  Future<String?> getUnit(int productId) async {
    await init();
    final m = _box!.get(productId.toString()) as Map?;
    return m == null ? null : (m['unit'] as String?);
  }

  Future<String?> getImageBase64(int productId) async {
    await init();
    final m = _box!.get(productId.toString()) as Map?;
    return m == null ? null : (m['img'] as String?);
  }

  /// Yardımcı: Base64 -> bytes
  static Uint8List? decodeImage(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }
}
