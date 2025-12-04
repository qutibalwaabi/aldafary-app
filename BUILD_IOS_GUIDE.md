# دليل بناء تطبيق iOS

## متطلبات البناء

**ملاحظة مهمة:** بناء تطبيق iOS يتطلب:
- **جهاز Mac** مع macOS مثبت
- **Xcode** من App Store
- **Apple Developer Account** (مجاني للتطوير، مدفوع للنشر)

## خطوات البناء

### 1. التحضير على Mac

```bash
# انتقل إلى مجلد المشروع
cd /path/to/untitled

# تأكد من تحديث Flutter
flutter upgrade

# احصل على التبعيات
flutter pub get

# انتقل إلى مجلد iOS
cd ios

# ثبت Pods (CocoaPods dependencies)
pod install

# ارجع إلى المجلد الرئيسي
cd ..
```

### 2. بناء التطبيق

#### للاختبار (Development):
```bash
flutter build ios --debug
```

#### للإنتاج (Release - حجم أصغر):
```bash
flutter build ios --release
```

#### لإنشاء IPA (للنشر):
```bash
flutter build ipa --release
```

الملف سيكون في: `build/ios/ipa/`

## تحسينات الحجم المطبقة ✅

تم تطبيق التحسينات التالية لتقليل حجم التطبيق:

1. ✅ **تحسين Compiler Settings:**
   - `SWIFT_OPTIMIZATION_LEVEL = "-Osize"` (تحسين الحجم بدلاً من السرعة)
   - `GCC_OPTIMIZATION_LEVEL = s` (تحسين الحجم)
   - `SWIFT_COMPILATION_MODE = wholemodule` (تحسين شامل)

2. ✅ **إزالة Bitcode:**
   - `ENABLE_BITCODE = NO` (موصى به لـ Flutter، يقلل الحجم)

3. ✅ **تقليل الخطوط:**
   - استخدام فقط Cairo-Regular و Cairo-Bold (بدلاً من جميع الأوزان)

4. ✅ **Podfile Optimization:**
   - إعدادات تحسين في post_install script

## حجم التطبيق المتوقع

مع التحسينات المطبقة:
- **Debug build:** ~80-120 MB
- **Release build:** ~25-40 MB  
- **IPA (compressed):** ~15-30 MB

**ملاحظة:** الحجم الفعلي يعتمد على:
- حجم الصور والأيقونات
- المكتبات المستخدمة
- الخطوط المضافة

## ملاحظات مهمة

1. **Code Signing:** يجب تكوين Code Signing في Xcode قبل البناء
2. **Bundle Identifier:** يجب تغيير `com.example.untitled` إلى معرف فريد
3. **App Icon:** تم إعداد الأيقونات في `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
4. **Info.plist:** تم تحديث `Info.plist` بإعدادات التطبيق

## حل المشاكل

### إذا واجهت مشكلة في pod install:
```bash
cd ios
pod deintegrate
pod install
```

### لتنظيف البناء:
```bash
flutter clean
flutter pub get
cd ios
pod install
cd ..
flutter build ios --release
```

## النشر على App Store

بعد البناء، يمكنك:
1. فتح `ios/Runner.xcworkspace` في Xcode (⚠️ ليس .xcodeproj)
2. اختر **Product > Archive** من القائمة
3. في **Organizer**، اختر **Distribute App**
4. اتبع الخطوات لرفع التطبيق إلى App Store Connect

## 🚀 بناء سريع (على Mac)

```bash
# خطوات سريعة
cd ios
pod install
cd ..
flutter build ipa --release

# الملف سيكون في:
# build/ios/ipa/*.ipa
```

## 📱 تثبيت على جهاز iPhone (للاختبار)

### طريقة 1: عبر Xcode
1. افتح `ios/Runner.xcworkspace` في Xcode
2. اختر جهاز iPhone من القائمة
3. اضغط ▶️ Run (أو Cmd+R)

### طريقة 2: عبر IPA
1. قم ببناء IPA: `flutter build ipa --release`
2. استخدم **Xcode > Window > Devices and Simulators**
3. اسحب ملف IPA إلى التطبيقات المثبتة

## 🔧 حل المشاكل الشائعة

### خطأ: "No Podfile found"
```bash
cd ios
pod init
pod install
```

### خطأ: "Code signing is required"
1. افتح `ios/Runner.xcworkspace` في Xcode
2. اذهب إلى **Signing & Capabilities**
3. اختر Team الخاص بك (أو أنشئ Apple ID مجاني)

### خطأ: "Swift version mismatch"
```bash
cd ios
pod deintegrate
pod install
```

## 🌐 بدائل للبناء بدون Mac

### 1. GitHub Actions (مجاني)
إنشاء ملف `.github/workflows/build_ios.yml`:
```yaml
name: Build iOS
on: [push]
jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: cd ios && pod install
      - run: flutter build ipa --release
      - uses: actions/upload-artifact@v2
        with:
          name: app
          path: build/ios/ipa/*.ipa
```

### 2. Codemagic (مجاني للبداية)
- سجل في codemagic.io
- اربط مستودع GitHub
- سيتم البناء تلقائياً

### 3. MacStadium / AWS Mac
- استأجر Mac في السحابة
- اربط عن بُعد
- قم بالبناء

## 📦 تحسينات إضافية لتقليل الحجم

إذا أردت تقليل الحجم أكثر:

1. **إزالة الخطوط غير المستخدمة:**
   - احذف الخطوط التي لا تستخدمها من `assets/fonts/`

2. **ضغط الصور:**
   - استخدم أدوات ضغط للصور قبل وضعها في `assets/images/`

3. **تقليل الأيقونات:**
   - تأكد من أن جميع الأيقونات في `AppIcon.appiconset` بحجم مناسب

