import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<String> saveJsonBytes(Uint8List bytes, String fileName) async {
  final dir = await getApplicationDocumentsDirectory();
  final outDir = Directory('${dir.path}/MiniPOS/backups');
  if (!await outDir.exists()) await outDir.create(recursive: true);
  final file = File('${outDir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
