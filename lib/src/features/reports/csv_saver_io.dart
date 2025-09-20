import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<void> saveCsv(String content, String filename) async {
  final dir = await _preferredDir();
  final file = File('${dir.path}${Platform.pathSeparator}$filename');
  // UTF-8 BOM ile kaydedelim ki Excel Türkçe karakterleri doğru açsın.
  final bom = utf8.encode('\uFEFF');
  final bytes = <int>[]
    ..addAll(bom)
    ..addAll(utf8.encode(content));
  await file.writeAsBytes(bytes, flush: true);
}

Future<Directory> _preferredDir() async {
  try {
    final d = await getDownloadsDirectory();
    if (d != null) return d;
  } catch (_) {}
  return getApplicationDocumentsDirectory();
}
