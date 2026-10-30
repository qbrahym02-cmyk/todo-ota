import 'package:web/web.dart' as web;

/// على الويب: إعادة تحميل الصفحة تجلب أحدث نسخة من الكود فوراً.
void reloadWebApp() {
  final loc = web.window.location;
  // إضافة معامل لتجاوز الكاش
  final base = loc.href.split('?').first.split('#').first;
  loc.replace('$base?v=${DateTime.now().millisecondsSinceEpoch}');
}
