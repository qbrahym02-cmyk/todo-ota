import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app_config.dart';
import 'platform/reload_stub.dart'
    if (dart.library.js_interop) 'platform/reload_web.dart';

class UpdateInfo {
  final String version;
  final int build;
  final String apkUrl;
  final String? sha256;
  final String notes;
  final bool force;
  final int minSupportedBuild;

  UpdateInfo({
    required this.version,
    required this.build,
    required this.apkUrl,
    required this.sha256,
    required this.notes,
    required this.force,
    required this.minSupportedBuild,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> j) => UpdateInfo(
        version: j['version'] as String? ?? '0.0.0',
        build: (j['build'] as num?)?.toInt() ?? 0,
        apkUrl: j['apk_url'] as String? ?? '',
        sha256: (j['sha256'] as String?)?.isEmpty == true
            ? null
            : j['sha256'] as String?,
        notes: j['notes'] as String? ?? '',
        force: j['force'] as bool? ?? false,
        minSupportedBuild: (j['min_supported_build'] as num?)?.toInt() ?? 0,
      );
}

enum UpdateStatus { idle, checking, available, downloading, installing, error }

/// يفحص وجود إصدار أحدث ويثبته:
/// - ويب: إعادة تحميل الصفحة → الكود الجديد يعمل فوراً.
/// - أندرويد: يحمّل APK داخل التطبيق ويفتح شاشة التثبيت مباشرة.
class UpdateService extends ChangeNotifier {
  UpdateStatus status = UpdateStatus.idle;
  UpdateInfo? available;
  String currentVersion = '';
  int currentBuild = 0;
  double progress = 0;
  String? error;
  Timer? _timer;

  bool get isWeb => kIsWeb;
  bool get isMandatory =>
      available != null &&
      (available!.force || currentBuild < available!.minSupportedBuild);

  Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      currentVersion = info.version;
      currentBuild = int.tryParse(info.buildNumber) ?? 0;
    } catch (_) {}
    notifyListeners();
    await check();
    _timer = Timer.periodic(AppConfig.pollInterval, (_) => check());
  }

  Future<void> check() async {
    if (status == UpdateStatus.downloading ||
        status == UpdateStatus.installing) {
      return;
    }
    status = UpdateStatus.checking;
    notifyListeners();
    try {
      final uri = Uri.parse(
          '${AppConfig.updateManifestUrl}?t=${DateTime.now().millisecondsSinceEpoch}');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final info = UpdateInfo.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
        if (info.build > currentBuild) {
          available = info;
          status = UpdateStatus.available;
        } else {
          available = null;
          status = UpdateStatus.idle;
        }
      } else {
        status = UpdateStatus.idle;
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
      status = UpdateStatus.idle;
    }
    notifyListeners();
  }

  Future<void> install() async {
    final info = available;
    if (info == null) return;

    if (kIsWeb) {
      reloadWebApp();
      return;
    }

    if (defaultTargetPlatform != TargetPlatform.android) {
      error = 'التحديث التلقائي مدعوم على أندرويد والويب فقط';
      status = UpdateStatus.error;
      notifyListeners();
      return;
    }

    status = UpdateStatus.downloading;
    progress = 0;
    error = null;
    notifyListeners();

    try {
      OtaUpdate()
          .execute(
        info.apkUrl,
        destinationFilename: 'todo_ota_${info.build}.apk',
        sha256checksum: info.sha256,
      )
          .listen(
        (event) {
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              progress = (double.tryParse(event.value ?? '0') ?? 0) / 100;
              status = UpdateStatus.downloading;
            case OtaStatus.INSTALLING:
            case OtaStatus.INSTALLATION_DONE:
              status = UpdateStatus.installing;
            default:
              if (event.status.name.contains('ERROR') ||
                  event.status.name.contains('PERMISSION')) {
                status = UpdateStatus.error;
                error = 'فشل التحديث: ${event.status.name} ${event.value ?? ''}';
              }
          }
          notifyListeners();
        },
        onError: (e) {
          status = UpdateStatus.error;
          error = 'فشل التحديث: $e';
          notifyListeners();
        },
      );
    } catch (e) {
      status = UpdateStatus.error;
      error = 'فشل التحديث: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
