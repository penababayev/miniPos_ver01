import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Modeller
import '../models/product.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/app_user.dart';

// Kaydetme (koşullu import)
import '../features/exports/json_saver_io.dart'
    if (dart.library.html) '../features/exports/json_saver_web.dart';

class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const _kAutoEnabled = 'backup.auto.enabled';
  static const _kLastBackup = 'backup.last.iso';
  static const _kWebCache =
      'backup.web.latest'; // web: son otomatik yedek içeriği (JSON)

  // --------- Public API ---------

  Future<bool> getAutoEnabled() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kAutoEnabled) ?? false;
  }

  Future<void> setAutoEnabled(bool enabled) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kAutoEnabled, enabled);
  }

  Future<DateTime?> lastBackupAt() async {
    final sp = await SharedPreferences.getInstance();
    final iso = sp.getString(_kLastBackup);
    return (iso == null) ? null : DateTime.tryParse(iso);
  }

  /// Manuel tetikleme veya günlük otomatik yedek.
  /// [force] true ise bugün de olsa yedek alır.
  Future<String?> runDailyBackupIfNeeded(Isar isar,
      {bool force = false}) async {
    final sp = await SharedPreferences.getInstance();
    final enabled = sp.getBool(_kAutoEnabled) ?? false;
    if (!enabled && !force) return null;

    final lastIso = sp.getString(_kLastBackup);
    final last = lastIso == null ? null : DateTime.tryParse(lastIso);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isSameDay = last != null &&
        DateTime(last.year, last.month, last.day).isAtSameMomentAs(today);

    if (isSameDay && !force) return null;

    final bytes = await exportFullJsonBytes(isar);
    final fileName = 'minipos_backup_${_ts(now)}.json';

    if (kIsWeb) {
      // Web: otomatik indirme yerine local storage’da sakla
      await sp.setString(_kWebCache, utf8.decode(bytes));
      await sp.setString(_kLastBackup, now.toIso8601String());
      return 'web-cache';
    } else {
      final path = await saveJsonBytes(bytes, fileName);
      await sp.setString(_kLastBackup, now.toIso8601String());
      return path;
    }
  }

  /// Web’de son otomatik yedeği indirilebilir dosya olarak ver.
  Future<String?> downloadLastWebBackup() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kWebCache);
    if (raw == null || raw.isEmpty) return null;
    final bytes = Uint8List.fromList(utf8.encode(raw));
    final fileName = 'minipos_backup_${_ts(DateTime.now())}.json';
    return await saveJsonBytes(bytes, fileName);
  }

  // --------- Exporters ---------

  Future<Uint8List> exportFullJsonBytes(Isar isar) async {
    final products = await isar.products.where().findAll();
    final sales = await isar.sales.where().findAll();
    final items = await isar.saleItems.where().findAll();
    final users = await isar.appUsers.where().findAll();

    final data = <String, dynamic>{
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'products': products.map(_productToMap).toList(),
      'sales': sales.map(_saleToMap).toList(),
      'saleItems': items.map(_saleItemToMap).toList(),
      'users': users.map(_userToMap).toList(),
    };
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    return Uint8List.fromList(utf8.encode(jsonStr));
  }

  /// CSV — Ürünler
  Future<String> exportProductsCsv(Isar isar) async {
    final list = await isar.products.where().findAll();
    final sb = StringBuffer();
    sb.writeln('id;name;barcode;unit;price;costPrice;createdAt');
    for (final p in list) {
      sb.writeln([
        p.id,
        _csv(_safeString(_tryGet<String>(p, ['name', 'title', 'productName']))),
        _csv(_safeString(_tryGet<String>(
            p, ['barcode', 'barCode', 'ean', 'ean13', 'sku', 'code']))),
        _csv(_safeString(_tryGet<String>(p, ['unit']))),
        _safeNum(_tryGet<num>(p,
            ['price', 'sellingPrice', 'salePrice', 'unitPrice', 'listPrice'])),
        _safeNum(_tryGet<num>(
            p, ['costPrice', 'buyPrice', 'purchasePrice', 'cost'])),
        _safeString(_tryGet<DateTime>(p, ['createdAt'])?.toIso8601String()),
      ].join(';'));
    }
    return sb.toString();
  }

  /// CSV — Satışlar
  Future<String> exportSalesCsv(Isar isar) async {
    final list = await isar.sales.where().findAll();
    final sb = StringBuffer();
    sb.writeln('id;createdAt;total;paymentType');
    for (final s in list) {
      sb.writeln([
        s.id,
        s.createdAt.toIso8601String(),
        s.total.toStringAsFixed(2),
        (s.paymentType ?? ''),
      ].join(';'));
    }
    return sb.toString();
  }

  /// CSV — Satır kalemleri
  Future<String> exportSaleItemsCsv(Isar isar) async {
    final list = await isar.saleItems.where().findAll();
    final sb = StringBuffer();
    sb.writeln('id;saleId;productId;qty;unitPrice;lineTotal');
    for (final it in list) {
      sb.writeln([
        it.id,
        it.saleId,
        it.productId,
        it.qty,
        it.unitPrice.toStringAsFixed(2),
        it.lineTotal.toStringAsFixed(2),
      ].join(';'));
    }
    return sb.toString();
  }

  // --------- Importer (tam geri yükleme) ---------

  /// JSON yedeğini içeri alır.
  /// [replaceAll] true → mevcut veriyi SİLER ve yedeği yükler.
  Future<void> importFullJson(Isar isar, Map<String, dynamic> json,
      {bool replaceAll = true}) async {
    final products = (json['products'] as List? ?? []).cast<Map>();
    final sales = (json['sales'] as List? ?? []).cast<Map>();
    final items = (json['saleItems'] as List? ?? []).cast<Map>();
    final users = (json['users'] as List? ?? []).cast<Map>();

    await isar.writeTxn(() async {
      if (replaceAll) {
        await isar.saleItems.clear();
        await isar.sales.clear();
        await isar.products.clear();
        await isar.appUsers.clear();
      }

      // Users
      for (final m in users) {
        final u = AppUser()
          ..id = (m['id'] ?? 0) as int
          ..name = (m['name'] ?? '') as String
          ..role = ((m['role'] ?? 'cashier') == 'manager')
              ? UserRole.manager
              : UserRole.cashier
          ..pinSalt = (m['pinSalt'] ?? '') as String
          ..pinHash = (m['pinHash'] ?? '') as String
          ..active = (m['active'] ?? true) as bool
          ..createdAt =
              DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now();
        await isar.appUsers.put(u);
      }

      // Products
      for (final m in products) {
        final p = Product()..id = (m['id'] ?? 0) as int;
        _trySet(p, 'name', m['name']);
        _trySet(p, 'barcode', m['barcode']);
        _trySet(p, 'unit', m['unit']);
        _trySet(p, 'price', (m['price'] as num?)?.toDouble());
        _trySet(p, 'costPrice', (m['costPrice'] as num?)?.toDouble());
        _trySet(p, 'createdAt', DateTime.tryParse(m['createdAt'] ?? ''));
        await isar.products.put(p);
      }

      // Sales
      for (final m in sales) {
        final s = Sale()
          ..id = (m['id'] ?? 0) as int
          ..createdAt =
              DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now()
          ..total = (m['total'] as num?)?.toDouble() ?? 0.0
          ..paymentType = (m['paymentType'] as String?) ?? 'cash';
        await isar.sales.put(s);
      }

      // Items
      for (final m in items) {
        final qtyD = ((m['qty'] ?? 0) as num).toDouble();
        final upD = (m['unitPrice'] as num?)?.toDouble() ?? 0.0;
        final fallbackLine = (qtyD * upD); // double * double -> double

        final it = SaleItem()
          ..id = (m['id'] ?? 0) as int
          ..saleId = (m['saleId'] ?? 0) as int
          ..productId = (m['productId'] ?? 0) as int
          ..qty = (m['qty'] ?? 0) as int
          ..unitPrice = upD
          // 🔧 FIX: fallback'ı double yaptık
          ..lineTotal = (m['lineTotal'] as num?)?.toDouble() ?? fallbackLine;
        await isar.saleItems.put(it);
      }
    });
  }

  // --------- Private helpers ---------

  String _csv(String s) => '"${s.replaceAll('"', '""')}"';
  String _safeString(Object? v) => v == null ? '' : v.toString();

  /// CSV’de sayıları güvenli stringe çevirir (null → boş, int → int, double → 2 hane).
  String _safeNum(num? v, {int fractionDigits = 2}) {
    if (v == null) return '';
    if (v is int) return v.toString();
    final d = v.toDouble();
    return d.toStringAsFixed(fractionDigits);
  }

  String _ts(DateTime d) =>
      '${d.year}-${_2(d.month)}-${_2(d.day)}_${_2(d.hour)}-${_2(d.minute)}-${_2(d.second)}';
  String _2(int x) => x.toString().padLeft(2, '0');

  /// Belirli alan adları için güvenli okuma (alan yoksa sıradaki isme dener).
  T? _tryGet<T>(Object obj, List<String> names) {
    final d = obj as dynamic;
    for (final n in names) {
      try {
        dynamic v;
        switch (n) {
          // strings
          case 'name':
            v = d.name;
            break;
          case 'title':
            v = d.title;
            break;
          case 'productName':
            v = d.productName;
            break;
          case 'barcode':
            v = d.barcode;
            break;
          case 'barCode':
            v = d.barCode;
            break;
          case 'ean':
            v = d.ean;
            break;
          case 'ean13':
            v = d.ean13;
            break;
          case 'sku':
            v = d.sku;
            break;
          case 'code':
            v = d.code;
            break;
          case 'unit':
            v = d.unit;
            break;

          // nums
          case 'price':
            v = d.price;
            break;
          case 'sellingPrice':
            v = d.sellingPrice;
            break;
          case 'salePrice':
            v = d.salePrice;
            break;
          case 'unitPrice':
            v = d.unitPrice;
            break;
          case 'listPrice':
            v = d.listPrice;
            break;
          case 'costPrice':
            v = d.costPrice;
            break;
          case 'buyPrice':
            v = d.buyPrice;
            break;
          case 'purchasePrice':
            v = d.purchasePrice;
            break;
          case 'cost':
            v = d.cost;
            break;

          // dates
          case 'createdAt':
            v = d.createdAt;
            break;

          default:
            v = null;
        }
        if (v == null) continue;
        if (v is T) return v;
        if (T == double && v is num) return v.toDouble() as T;
        if (T == num && (v is int || v is double)) return v as T;
        if (T == String) return v.toString() as T;
      } catch (_) {
        // alan yoksa sıradaki isme dene
      }
    }
    return null;
  }

  /// Bilinen alan adları için güvenli atama
  void _trySet(Object obj, String name, Object? value) {
    if (value == null) return;
    final d = obj as dynamic;
    try {
      switch (name) {
        case 'name':
          d.name = value;
          break;
        case 'barcode':
          d.barcode = value;
          break;
        case 'unit':
          d.unit = value;
          break;
        case 'price':
          d.price = value;
          break;
        case 'costPrice':
          d.costPrice = value;
          break;
        case 'createdAt':
          d.createdAt = value;
          break;
        default:
          break;
      }
    } catch (_) {/* alan yoksa geç */}
  }

  Map<String, dynamic> _productToMap(Product p) => {
        'id': p.id,
        'name': _tryGet<String>(p, ['name', 'title', 'productName']) ?? '',
        'barcode': _tryGet<String>(
            p, ['barcode', 'barCode', 'ean', 'ean13', 'sku', 'code']),
        'unit': _tryGet<String>(p, ['unit']),
        'price': (_tryGet<num>(p, [
                  'price',
                  'sellingPrice',
                  'salePrice',
                  'unitPrice',
                  'listPrice'
                ]) ??
                0)
            .toDouble(),
        'costPrice': (_tryGet<num>(
                    p, ['costPrice', 'buyPrice', 'purchasePrice', 'cost']) ??
                0)
            .toDouble(),
        'createdAt': (_tryGet<DateTime>(p, ['createdAt']) ?? DateTime.now())
            .toIso8601String(),
      };

  Map<String, dynamic> _saleToMap(Sale s) => {
        'id': s.id,
        'createdAt': s.createdAt.toIso8601String(),
        'total': s.total,
        'paymentType': s.paymentType,
      };

  Map<String, dynamic> _saleItemToMap(SaleItem it) => {
        'id': it.id,
        'saleId': it.saleId,
        'productId': it.productId,
        'qty': it.qty,
        'unitPrice': it.unitPrice,
        'lineTotal': it.lineTotal,
      };

  Map<String, dynamic> _userToMap(AppUser u) => {
        'id': u.id,
        'name': u.name,
        'role': u.role == UserRole.manager ? 'manager' : 'cashier',
        'pinSalt': u.pinSalt,
        'pinHash': u.pinHash,
        'active': u.active,
        'createdAt': u.createdAt.toIso8601String(),
      };
}
