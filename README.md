# 📝 مهامي — تطبيق To-Do بـ Flutter مع تحديث عن بعد

تطبيق قائمة مهام (أندرويد + ويب) **يتحدث عن بعد** بثلاث طرق:

| الطريقة | ماذا تغيّر؟ | هل يحتاج المستخدم تحميل؟ | كيف؟ |
|---|---|---|---|
| ⚡ **الإعدادات عن بعد** | العنوان، الألوان، الإعلانات، تشغيل/إيقاف الميزات، التصنيفات، وضع الصيانة | ❌ **لا** — يظهر تلقائياً | عدّل `remote/config.json` على GitHub |
| 🌐 **نسخة الويب** | أي شيء في الكود | ❌ **لا** — ضغطة "تحديث" فقط | `git push` |
| 📱 **نسخة أندرويد** | أي شيء في الكود | يُحمَّل **داخل التطبيق** بضغطة واحدة، بدون متجر وبدون حذف التطبيق، والمهام تبقى محفوظة | `git push` |

---

## 1) تغيير التطبيق فوراً بدون أي تحديث (Remote Config)

افتح `remote/config.json` على GitHub ← اضغط ✏️ ← عدّل ← **Commit**.
خلال ~5 دقائق (أو فوراً عند السحب للأسفل داخل التطبيق) يتغير التطبيق عند **كل** المستخدمين:

```jsonc
{
  "config_version": 2,
  "app_title": "مهامي",
  "primary_color": "#E11D48",            // لون التطبيق كاملاً
  "announcement": {
    "enabled": true,
    "text": "🎉 عرض خاص اليوم!",          // شريط إعلان أعلى الشاشة
    "color": "#F59E0B",
    "url": "https://example.com"          // اختياري: رابط عند الضغط
  },
  "features": {
    "priorities": true,                   // إظهار/إخفاء الأولويات
    "due_dates": true,                    // المواعيد النهائية
    "categories": true,                   // التصنيفات
    "stats": true                         // بطاقة الإحصائيات
  },
  "categories": ["عام", "عمل", "دراسة"],
  "empty_state_text": "ابدأ يومك بمهمة!",
  "maintenance": { "enabled": false, "message": "صيانة..." }  // يقفل التطبيق برسالة
}
```

> تعديل هذا الملف **لا يشغّل** بناء جديد (مستثنى في الـ workflow).

## 2) تحديث الكود (ميزات جديدة)

```bash
# عدّل أي ملف في lib/ ثم:
git commit -am "إضافة ميزة كذا"
git push
```

GitHub Actions سيقوم تلقائياً بـ:
1. تشغيل الاختبارات
2. بناء APK موقّع بنفس المفتاح دائماً + بناء نسخة الويب
3. رفع رقم الإصدار تلقائياً (`1.0.<رقم البناء>`)
4. نشر كل شيء على GitHub Pages + توليد `update.json`
5. إنشاء GitHub Release

**عند المستخدم:** يظهر شريط "إصدار جديد متوفر" ← يضغط **تحميل وتثبيت** ← يتحمّل داخل التطبيق ← يضغط "تثبيت". المهام لا تُحذف.

رسالة الـ commit تظهر للمستخدم كـ "ما الجديد".

### تحديث إجباري
من تبويب **Actions** ← **Build & Publish Update** ← **Run workflow** ← فعّل `force` واكتب ملاحظات الإصدار.

---

## الروابط

- 🌐 التطبيق على الويب: https://qbrahym02-cmyk.github.io/todo-ota/
- 📱 تحميل APK (أول مرة فقط): https://qbrahym02-cmyk.github.io/todo-ota/app.apk
- 🔎 ملف التحديث: https://qbrahym02-cmyk.github.io/todo-ota/update.json

> أول تثبيت للـ APK: أندرويد سيطلب السماح بـ "تثبيت تطبيقات من مصادر غير معروفة". بعدها كل التحديثات تتم من داخل التطبيق.

---

## الأسرار (GitHub Secrets) المطلوبة

| Secret | الوصف |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | ملف مفتاح التوقيع (base64) |
| `ANDROID_STORE_PASSWORD` | كلمة سر الملف |
| `ANDROID_KEY_PASSWORD` | كلمة سر المفتاح |
| `ANDROID_KEY_ALIAS` | `upload` |

⚠️ **احتفظ بنسخة احتياطية من ملف `release.jks` وكلمة سره.** إذا ضاع المفتاح لن يقبل أندرويد تثبيت أي تحديث فوق النسخة القديمة، وسيضطر المستخدمون لحذف التطبيق وإعادة تثبيته.

---

## هيكل المشروع

```
lib/
├── app_config.dart                 # روابط التحديث
├── main.dart
├── models/todo.dart
├── screens/home_screen.dart        # الشاشة الرئيسية
├── services/
│   ├── todo_store.dart             # تخزين المهام محلياً
│   ├── remote_config_service.dart  # الإعدادات عن بعد
│   ├── update_service.dart         # فحص وتثبيت التحديثات
│   └── platform/                   # إعادة التحميل على الويب
└── widgets/
remote/config.json                  # ← عدّله لتغيير التطبيق فوراً
.github/workflows/publish.yml       # البناء والنشر التلقائي
```

## التشغيل محلياً

```bash
flutter pub get
flutter run            # أندرويد
flutter run -d chrome  # ويب
```

## ترقية اختيارية: Code Push حقيقي على أندرويد/iOS

لو تبي تحديث كود Dart على الجوال **بدون تحميل APK إطلاقاً** (حتى iOS)، استخدم [Shorebird](https://shorebird.dev):
```bash
shorebird init && shorebird release android   # مرة واحدة
shorebird patch android                       # لكل تحديث — يصل بصمت عند فتح التطبيق
```
يحتاج حساب على shorebird.dev (فيه خطة مجانية).
