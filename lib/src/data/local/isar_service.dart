import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

// Şemalarını kendi projendeki yerlere göre import et
import '../../models/product.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';
import '../../models/app_user.dart';

class IsarService {
  IsarService._();
  static final IsarService instance = IsarService._();

  Isar? _db;
  Isar get db => _db!;

  Future<void> init() async {
    if (_db != null) return;

    const dbName = 'minipos';

    if (kIsWeb) {
      // Web’de de directory parametresi zorunluysa sembolik bir ad veriyoruz.
      _db = await Isar.open(
        [
          ProductSchema,
          SaleSchema,
          SaleItemSchema,
          AppUserSchema,
        ],
        name: dbName,
        directory:
            'minipos_web', // <-- Zorunlu parametre (web’de path değil, sadece isim)
        inspector: kDebugMode,
      );
    } else {
      final dir = await getApplicationDocumentsDirectory();
      _db = await Isar.open(
        [
          ProductSchema,
          SaleSchema,
          SaleItemSchema,
          AppUserSchema,
        ],
        name: dbName,
        directory: dir.path, // <-- Native/desktop için gerçek dizin
        inspector: kDebugMode,
      );
    }
  }
}

final isarServiceProvider =
    Provider<IsarService>((ref) => IsarService.instance);

final isarProvider = Provider<Isar>((ref) {
  final s = ref.watch(isarServiceProvider);
  // init edilmemişse başlat (main() içinde await ile çağırman yine de en sağlıklısı)
  if (s._db == null) {
    // fire-and-forget
    s.init();
  }
  return s.db;
});
