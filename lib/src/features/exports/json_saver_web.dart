import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<String> saveJsonBytes(Uint8List bytes, String fileName) async {
  final blob = html.Blob([bytes], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..click();
  html.Url.revokeObjectUrl(url);
  return fileName;
}
