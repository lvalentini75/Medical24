import 'package:web/web.dart' as web;

Future<void> saveHealthCsv(String content, String filename) async {
  final web.HTMLAnchorElement anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = 'data:text/csv;charset=utf-8,%EF%BB%BF${Uri.encodeComponent(content)}';
  anchor.download = filename;
  anchor.click();
}