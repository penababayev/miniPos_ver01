import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<void> savePdf(Uint8List bytes, String filename) async {
  Directory? dir;
  try {
    dir = await getDownloadsDirectory();
  } catch (_) {}
  dir ??= await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
}
