/// إعدادات روابط التحديث عن بعد.
///
/// - [remoteConfigUrl]: ملف JSON يتحكم بالمظهر والإعلانات والميزات.
///   تعديله على GitHub يصل للتطبيق خلال دقائق **بدون أي تحميل أو بناء**.
/// - [updateManifestUrl]: ملف يُولَّد تلقائياً من GitHub Actions عند كل بناء،
///   يحتوي رقم آخر إصدار ورابط ملف APK.
class AppConfig {
  static const String owner = 'qbrahym02-cmyk';
  static const String repo = 'todo-ota';
  static const String branch = 'main';

  static const String pagesBase = 'https://$owner.github.io/$repo';

  static const String remoteConfigUrl =
      'https://raw.githubusercontent.com/$owner/$repo/$branch/remote/config.json';

  static const String updateManifestUrl = '$pagesBase/update.json';

  /// كم مرة يعيد التطبيق فحص التحديثات أثناء تشغيله.
  static const Duration pollInterval = Duration(minutes: 10);
}
