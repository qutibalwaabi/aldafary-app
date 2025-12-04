# تعليمات بناء التطبيق لجميع المنصات

## 📱 Android (جاهز ✅)
تم بناء التطبيق مسبقاً. الملفات موجودة في:
```
build/app/outputs/flutter-apk/
  - app-arm64-v8a-release.apk (25.7 MB) - للأجهزة الحديثة
  - app-armeabi-v7a-release.apk (23.8 MB) - للأجهزة القديمة
  - app-release.apk (62.8 MB) - موحد لجميع الأجهزة
```

---

## 🍎 iOS (iPhone/iPad)

### المتطلبات:
1. جهاز Mac مع Xcode مثبت
2. حساب Apple Developer (للتوزيع)
3. CocoaPods مثبت (`sudo gem install cocoapods`)

### خطوات البناء:

#### 1. تهيئة iOS للمرة الأولى:
```bash
cd ios
pod install
cd ..
```

#### 2. بناء التطبيق:

**للاختبار (Development):**
```bash
flutter build ios --debug
```

**للإطلاق (Release - للتوزيع):**
```bash
flutter build ios --release
```

#### 3. موقع الملفات المبنية:
```
build/ios/iphoneos/
  - Runner.app (تطبيق iOS)
```

#### 4. للتحضير للتوزيع عبر App Store:
```bash
# بناء IPA للتوزيع
flutter build ipa
```
الملف سيكون في:
```
build/ios/ipa/
  - Runner.ipa
```

#### ملاحظات iOS:
- **لا يمكن بناء iOS على Windows**: يحتاج Mac و Xcode
- للتوزيع عبر App Store، تحتاج Apple Developer Account ($99/سنة)
- للتوزيع عبر TestFlight (للاختبار)، تحتاج Apple Developer Account

---

## 🖥️ macOS (سطح المكتب - Mac)

### المتطلبات:
1. جهاز Mac
2. Xcode مثبت
3. CocoaPods مثبت

### خطوات البناء:

#### 1. تهيئة macOS للمرة الأولى:
```bash
cd macos
pod install
cd ..
```

#### 2. بناء التطبيق:

**للاختبار:**
```bash
flutter build macos --debug
```

**للإطلاق:**
```bash
flutter build macos --release
```

#### 3. موقع الملفات المبنية:
```
build/macos/Build/Products/Release/
  - Runner.app (تطبيق macOS - يمكن فتحه مباشرة)
```

#### 4. إنشاء DMG للتوزيع (اختياري):
```bash
# بعد البناء، يمكن استخدام أدوات لإنشاء DMG
# الملف .app جاهز للاستخدام مباشرة
```

---

## 🪟 Windows (سطح المكتب - Windows)

### المتطلبات:
1. Windows 10/11
2. Visual Studio 2022 مع:
   - Desktop development with C++
   - Windows 10/11 SDK

### خطوات البناء:

#### 1. بناء التطبيق:

**للاختبار:**
```bash
flutter build windows --debug
```

**للإطلاق:**
```bash
flutter build windows --release
```

#### 2. موقع الملفات المبنية:
```
build/windows/x64/runner/Release/
  - untitled.exe (التطبيق القابل للتنفيذ)
  - flutter_windows.dll
  - data/ (الملفات المطلوبة)
```

#### 3. للتوزيع:
- يمكن نسخ المجلد `Release` بالكامل
- أو إنشاء installer باستخدام أدوات مثل Inno Setup أو NSIS

---

## 🌐 Web (اختياري)

```bash
flutter build web
```

الملفات ستكون في:
```
build/web/
```

---

## 📋 ملخص المواقع:

| المنصة | مسار الملف المبنية |
|--------|-------------------|
| **Android** | `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` |
| **iOS** | `build/ios/iphoneos/Runner.app` أو `build/ios/ipa/Runner.ipa` |
| **macOS** | `build/macos/Build/Products/Release/Runner.app` |
| **Windows** | `build/windows/x64/runner/Release/untitled.exe` |

---

## ⚠️ ملاحظات مهمة:

1. **iOS و macOS يحتاجان Mac** - لا يمكن بناؤهما على Windows
2. **Android جاهز الآن** - الملف موجود في مجلد `build/app/outputs/flutter-apk/`
3. **Windows يمكن بناؤه على Windows** - جاهز للبناء
4. **للتوزيع الرسمي**، تحتاج:
   - Android: حساب Google Play Developer ($25 لمرة واحدة)
   - iOS: حساب Apple Developer ($99/سنة)
   - macOS: حساب Apple Developer ($99/سنة)
   - Windows: حساب Microsoft Store Developer ($19 لمرة واحدة)

---

## 🚀 أوامر سريعة:

```bash
# Android (جاهز)
flutter build apk --release

# iOS (يحتاج Mac)
flutter build ios --release
flutter build ipa

# macOS (يحتاج Mac)
flutter build macos --release

# Windows (يمكن على Windows)
flutter build windows --release

# Web
flutter build web
```

---

## 📞 للمساعدة:
- تأكد من تشغيل `flutter doctor` لفحص البيئة
- تأكد من تثبيت جميع المتطلبات قبل البناء
