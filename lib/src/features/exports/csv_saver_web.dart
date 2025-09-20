import 'dart:html' as html;

Future<String> saveCsvText(String csv, String fileName) async {
  final blob = html.Blob([csv], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final a = html.AnchorElement(href: url)
    ..download = fileName
    ..click();
  html.Url.revokeObjectUrl(url);
  return fileName;
}
