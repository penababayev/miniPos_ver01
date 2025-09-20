import 'dart:convert';
import 'dart:html' as html;

Future<void> saveCsv(String content, String filename) async {
  // UTF-8 BOM ekleyelim (Excel uyumluluğu için)
  final data = '\uFEFF$content';
  final bytes = utf8.encode(data);
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
