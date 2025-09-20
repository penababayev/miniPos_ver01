import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<void> saveXlsx(Uint8List bytes, String filename) async {
  final dir = await _preferredDir();
  final file = File('${dir.path}${Platform.pathSeparator}$filename');
  await file.writeAsBytes(bytes, flush: true);
  // Not: Masaüstü/Android'de Downloads klasörüne, iOS'ta Belgeler'e yazar.
}

Future<Directory> _preferredDir() async {
  try {
    final d = await getDownloadsDirectory(); // Windows/macOS/Linux/Android
    if (d != null) return d;
  } catch (_) {}
  // iOS veya geri dönüş: Belgeler
  return getApplicationDocumentsDirectory();
}
