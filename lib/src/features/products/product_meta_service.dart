import 'dart:convert';
import 'dart:io' show File, Directory; // IO hedefleri için
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Ürün meta bilgileri (kategori + resim) için küçük bir servis.
/// Isar şemasına dokunmadan, Hive kutularında saklarız:
///   - product_meta: key = productId.toString()
///       { 'category': String?, 'image': String?, 'kind': 'path'|'b64' }
///   - categories_box: { 'names': <String>[] }
class ProductMetaService {
  ProductMetaService._();
  static final ProductMetaService instance = ProductMetaService._();

  static const _metaBox = 'product_meta';
  static const _catBox = 'categories_box';

  static bool _ready = false;
  late Box _box; // tip verilmedi -> platform/type sorunlarına takılmaz
  late Box _cat;

  Future<void> init() async {
    if (_ready) return;
    await Hive.initFlutter();
    _box = await Hive.openBox(_metaBox);
    _cat = await Hive.openBox(_catBox);
    _ready = true;
  }

  Future<Map<String, dynamic>?> metaOf(int productId) async {
    await init();
    final raw = _box.get(productId.toString());
    if (raw is Map) return Map<String, dynamic>.from(raw.cast());
    return null;
  }

  Future<Map<int, Map<String, dynamic>>> allMeta() async {
    await init();
    final out = <int, Map<String, dynamic>>{};
    for (final k in _box.keys) {
      final id = int.tryParse(k.toString());
      if (id == null) continue;
      final raw = _box.get(k);
      if (raw is Map) out[id] = Map<String, dynamic>.from(raw.cast());
    }
    return out;
  }

  Future<List<String>> categories() async {
    await init();
    final list = (_cat.get('names') as List?)?.cast<String>() ?? <String>[];
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  Future<void> _addCategory(String name) async {
    final list = await categories();
    if (!list.contains(name)) {
      list.add(name);
      await _cat.put('names', list);
    }
  }

  Future<void> setCategory(int productId, String? category) async {
    await init();
    final key = productId.toString();
    final cur = await metaOf(productId) ?? <String, dynamic>{};
    cur['category'] = (category ?? '').trim().isEmpty ? null : category!.trim();
    await _box.put(key, cur);
    if (cur['category'] != null) await _addCategory(cur['category'] as String);
  }

  /// Resim seç + kaydet.
  /// Web: bytes → base64 ('kind'='b64')
  /// IO : Documents/MiniPOS/images/p_<id>.<ext> ('kind'='path')
  Future<void> pickAndSaveImage(BuildContext context, int productId) async {
    await init();

    if (kIsWeb) {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (res == null || res.files.single.bytes == null) return;
      final b64 = base64Encode(res.files.single.bytes!);
      final m = (await metaOf(productId)) ?? <String, dynamic>{};
      m['image'] = b64;
      m['kind'] = 'b64';
      await _box.put(productId.toString(), m);
      return;
    }

    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final imgDir = Directory('${dir.path}/MiniPOS/images');
    if (!await imgDir.exists()) await imgDir.create(recursive: true);

    final ext = x.path.split('.').last.toLowerCase();
    final savePath = '${imgDir.path}/p_$productId.$ext';
    final file = File(savePath);
    await file.writeAsBytes(await x.readAsBytes());

    final m = (await metaOf(productId)) ?? <String, dynamic>{};
    m['image'] = savePath;
    m['kind'] = 'path';
    await _box.put(productId.toString(), m);
  }

  Future<void> clearImage(int productId) async {
    await init();
    final m = (await metaOf(productId)) ?? <String, dynamic>{};
    m.remove('image');
    m.remove('kind');
    await _box.put(productId.toString(), m);
  }

  /// Meta’daki resimden ImageProvider üret.
  Future<ImageProvider?> imageProviderOf(int productId) async {
    final m = await metaOf(productId);
    if (m == null || m['image'] == null) return null;

    if (m['kind'] == 'b64') {
      final bytes = base64Decode(m['image'] as String);
      return MemoryImage(bytes);
    }
    // path
    return FileImage(File(m['image'] as String));
  }
}
