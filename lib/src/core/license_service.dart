import 'dart:convert';
import 'package:flutter/foundation.dart'; // ValueNotifier
import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Anahtar formatı: BASE64URL(payload) + "-" + BASE64URL(sigFirst8)
/// payload: "expEpoch|edition|uid"
class LicenseInfo {
  final String? key;
  final DateTime? expiry;
  const LicenseInfo({this.key, this.expiry});

  bool get isActive => expiry != null && expiry!.isAfter(DateTime.now());

  int get remainingDays => expiry == null
      ? 0
      : expiry!.difference(DateTime.now()).inDays.clamp(0, 9999);
}

class LicenseService {
  static final LicenseService _i = LicenseService._();
  LicenseService._();
  factory LicenseService() => _i;

  static const _boxName = 'license_box';
  static const _keyField = 'key';
  static const _expField = 'expiry';

  // !!! Uygulama ve anahtar üreticide aynı olmalı
  static const _SECRET = 'CHANGE_THIS_SECRET_FOR_YOUR_APP_MINIPOS_2025';

  Box? _box;

  /// Tüm app’in izleyebileceği **reaktif** durum.
  /// LicenseBanner ve diğer ekranlar bunu dinleyerek otomatik güncellenir.
  final ValueNotifier<bool> active = ValueNotifier<bool>(false);

  Future<void> init() async {
    if (_box != null) return;
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);

    // Açılışta mevcut durumu yükleyip bildir
    final info = await current();
    active.value = info.isActive;
  }

  Future<LicenseInfo> current() async {
    await init();
    final k = _box!.get(_keyField) as String?;
    final expIso = _box!.get(_expField) as String?;
    final exp = expIso != null ? DateTime.tryParse(expIso) : null;
    return LicenseInfo(key: k, expiry: exp);
  }

  Future<void> clear() async {
    await init();
    await _box!.delete(_keyField);
    await _box!.delete(_expField);
    active.value = false; // 🔔 herkese haber ver
  }

  String _normalize(String input) {
    // sadece base64url karakterleri ve '-' kalsın
    return input.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '');
  }

  /// Lisans anahtarını doğrular ve **kaydeder**.
  /// null => geçerli, aksi halde hata mesajı
  Future<String?> verifyAndSave(String inputKey) async {
    await init();
    final normalized = _normalize(inputKey);
    if (normalized.length < 20) return 'Anahtar formatı hatalı';

    final idx = normalized.lastIndexOf('-');
    if (idx <= 0 || idx >= normalized.length - 1) {
      return 'Anahtar formatı hatalı';
    }
    final payloadB64 = normalized.substring(0, idx);
    final sigB64 = normalized.substring(idx + 1);

    List<int>? _b64urlDecode(String s) {
      try {
        var t = s;
        final mod = t.length % 4;
        if (mod != 0) t += '=' * (4 - mod);
        return base64Url.decode(t);
      } catch (_) {
        return null;
      }
    }

    final payloadBytes = _b64urlDecode(payloadB64);
    final sigBytes = _b64urlDecode(sigB64);
    if (payloadBytes == null || sigBytes == null) {
      return 'Anahtar çözümlenemedi';
    }

    final payload = utf8.decode(payloadBytes);
    final parts = payload.split('|'); // expEpoch|edition|uid
    if (parts.isEmpty) return 'Anahtar içeriği hatalı';

    final expEpoch = int.tryParse(parts[0]);
    if (expEpoch == null) return 'Son kullanma tarihi okunamadı';
    final expiry = DateTime.fromMillisecondsSinceEpoch(expEpoch);

    final mac = Hmac(sha256, utf8.encode(_SECRET));
    final digest = mac.convert(utf8.encode(payload)).bytes;
    final expected = digest.sublist(0, 8);
    if (!_bytesEqual(expected, sigBytes)) return 'Anahtar geçersiz';
    if (!expiry.isAfter(DateTime.now())) return 'Abonelik süresi dolmuş';

    await _box!.put(_keyField, normalized);
    await _box!.put(_expField, expiry.toIso8601String());

    active.value = true; // 🔔 herkese haber ver
    return null;
  }

  /// Kurtarma akışı için: girilen anahtar, kayıtlı olanla **eşleşiyor mu?**
  /// (Sadece eşitlik kontrolü — yeniden imza doğrulaması gerekmez.)
  Future<bool> keyMatches(String inputKey) async {
    await init();
    final stored = (_box!.get(_keyField) as String?) ?? '';
    if (stored.isEmpty) return false;

    final normStored = _normalize(stored);
    final normInput = _normalize(inputKey);

    // Süre dolmuş olsa bile "eşleşme" var mı diye döner; akışta ayrıca isActive kontrolü yap.
    return _bytesEqual(utf8.encode(normStored), utf8.encode(normInput));
  }

  /// UI için yardımcı: anahtarı maskele (XXXX-…-YYYY).
  String maskKey(String? k) {
    if (k == null || k.isEmpty) return '';
    final s = _normalize(k);
    if (s.length <= 8) return s;
    return '${s.substring(0, 4)}…${s.substring(s.length - 4)}';
  }

  bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var r = 0;
    for (var i = 0; i < a.length; i++) {
      r |= a[i] ^ b[i];
    }
    return r == 0;
  }
}
