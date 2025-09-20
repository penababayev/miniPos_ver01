// dart run bin/license_gen.dart --secret "CHANGE_THIS_SECRET_FOR_YOUR_APP_MINIPOS_2025" --days 30 --edition basic --uid demo1
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

void main(List<String> args) {
  final opts = _parseArgs(args);

  final secret = opts['secret'] ?? '';
  if (secret.isEmpty) {
    _e('HATA: --secret vermelisiniz (uygulamadaki SECRET ile aynı olmalı).');
    exit(1);
  }
  final days = int.tryParse(opts['days'] ?? '30') ?? 30;
  final edition = opts['edition'] ?? 'basic';
  final uid = opts['uid'] ?? 'user1';

  final now = DateTime.now();
  final expiry = now.add(Duration(days: days));
  final expEpoch = expiry.millisecondsSinceEpoch;

  final payload = '$expEpoch|$edition|$uid';
  final payloadB64 = base64Url.encode(utf8.encode(payload)).replaceAll('=', '');

  final mac = Hmac(sha256, utf8.encode(secret));
  final digest = mac.convert(utf8.encode(payload)).bytes;
  final sigFirst8 = digest.sublist(0, 8);
  final sigB64 = base64Url.encode(sigFirst8).replaceAll('=', '');

  final key = '$payloadB64-$sigB64';

  stdout.writeln('---------------------------');
  stdout.writeln('MiniPOS Lisans Anahtarı');
  stdout.writeln('Sona erme : ${_fmt(expiry)}  (epoch: $expEpoch)');
  stdout.writeln('Sürüm     : $edition');
  stdout.writeln('UID       : $uid');
  stdout.writeln('---------------------------');
  stdout.writeln('KEY       : $key');
  stdout.writeln('---------------------------');
  stdout.writeln(
      'Not: Bu anahtar uygulamada "Anahtar Gir" ekranına kopyalanıp yapıştırılmalıdır.');
}

Map<String, String> _parseArgs(List<String> args) {
  final map = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a.startsWith('--')) {
      final k = a.substring(2);
      final v = (i + 1 < args.length && !args[i + 1].startsWith('--'))
          ? args[++i]
          : 'true';
      map[k] = v;
    }
  }
  return map;
}

void _e(String m) => stderr.writeln(m);

String _fmt(DateTime d) {
  String two(int x) => x.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}
