import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../app_config.dart';

/// إعدادات تأتي من الإنترنت وتغيّر شكل وسلوك التطبيق فوراً بدون تحميل نسخة جديدة.
class RemoteConfig {
  final String appTitle;
  final Color primaryColor;
  final bool announcementEnabled;
  final String announcementText;
  final Color announcementColor;
  final String? announcementUrl;
  final bool featurePriorities;
  final bool featureDueDates;
  final bool featureCategories;
  final bool featureStats;
  final List<String> categories;
  final bool maintenanceEnabled;
  final String maintenanceMessage;
  final String emptyStateText;
  final int configVersion;

  const RemoteConfig({
    required this.appTitle,
    required this.primaryColor,
    required this.announcementEnabled,
    required this.announcementText,
    required this.announcementColor,
    required this.announcementUrl,
    required this.featurePriorities,
    required this.featureDueDates,
    required this.featureCategories,
    required this.featureStats,
    required this.categories,
    required this.maintenanceEnabled,
    required this.maintenanceMessage,
    required this.emptyStateText,
    required this.configVersion,
  });

  static const defaults = RemoteConfig(
    appTitle: 'مهامي',
    primaryColor: Color(0xFF4F46E5),
    announcementEnabled: false,
    announcementText: '',
    announcementColor: Color(0xFF0EA5E9),
    announcementUrl: null,
    featurePriorities: true,
    featureDueDates: true,
    featureCategories: true,
    featureStats: true,
    categories: ['عام', 'عمل', 'شخصي', 'تسوق'],
    maintenanceEnabled: false,
    maintenanceMessage: '',
    emptyStateText: 'لا توجد مهام بعد — اضغط + لإضافة أول مهمة',
    configVersion: 0,
  );

  static Color _color(dynamic v, Color fallback) {
    if (v is! String) return fallback;
    var hex = v.replaceAll('#', '').trim();
    if (hex.length == 6) hex = 'FF$hex';
    final n = int.tryParse(hex, radix: 16);
    return n == null ? fallback : Color(n);
  }

  factory RemoteConfig.fromJson(Map<String, dynamic> j) {
    final d = defaults;
    final ann = (j['announcement'] as Map?) ?? {};
    final f = (j['features'] as Map?) ?? {};
    final m = (j['maintenance'] as Map?) ?? {};
    final cats = (j['categories'] as List?)?.whereType<String>().toList();
    return RemoteConfig(
      appTitle: j['app_title'] as String? ?? d.appTitle,
      primaryColor: _color(j['primary_color'], d.primaryColor),
      announcementEnabled: ann['enabled'] as bool? ?? false,
      announcementText: ann['text'] as String? ?? '',
      announcementColor: _color(ann['color'], d.announcementColor),
      announcementUrl: ann['url'] as String?,
      featurePriorities: f['priorities'] as bool? ?? d.featurePriorities,
      featureDueDates: f['due_dates'] as bool? ?? d.featureDueDates,
      featureCategories: f['categories'] as bool? ?? d.featureCategories,
      featureStats: f['stats'] as bool? ?? d.featureStats,
      categories: (cats == null || cats.isEmpty) ? d.categories : cats,
      maintenanceEnabled: m['enabled'] as bool? ?? false,
      maintenanceMessage: m['message'] as String? ?? '',
      emptyStateText: j['empty_state_text'] as String? ?? d.emptyStateText,
      configVersion: (j['config_version'] as num?)?.toInt() ?? 0,
    );
  }
}

class RemoteConfigService extends ChangeNotifier {
  static const _cacheKey = 'remote_config_cache';
  RemoteConfig _config = RemoteConfig.defaults;
  DateTime? lastFetched;

  RemoteConfig get config => _config;

  /// يحمّل آخر نسخة محفوظة فوراً (يعمل بدون إنترنت)، ثم يجلب الجديد.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      try {
        _config = RemoteConfig.fromJson(jsonDecode(cached));
        notifyListeners();
      } catch (_) {}
    }
    await refresh();
  }

  Future<bool> refresh() async {
    try {
      // معامل t لتجاوز أي كاش في المتصفح
      final uri = Uri.parse(
          '${AppConfig.remoteConfigUrl}?t=${DateTime.now().millisecondsSinceEpoch}');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return false;
      final body = utf8.decode(res.bodyBytes);
      final json = jsonDecode(body) as Map<String, dynamic>;
      _config = RemoteConfig.fromJson(json);
      lastFetched = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, body);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Remote config fetch failed: $e');
      return false;
    }
  }
}
