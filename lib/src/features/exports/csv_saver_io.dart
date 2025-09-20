import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String> saveCsvText(String csv, String fileName) async {
  final dir = await getApplicationDocumentsDirectory();
  final outDir = Directory('${dir.path}/MiniPOS/exports');
  if (!await outDir.exists()) await outDir.create(recursive: true);
  final file = File('${outDir.path}/$fileName');
  await file.writeAsString(csv, flush: true);
  return file.path;
}
