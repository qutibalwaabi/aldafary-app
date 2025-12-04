# 🚀 بناء نسخة iOS الآن

## ⚠️ ملاحظة مهمة
**لا يمكن بناء iOS على Windows محلياً.** يجب استخدام أحد الحلول التالية:

---

## 📱 الطريقة 1: GitHub Actions (الأسهل - موصى به)

### الخطوات:

1. **ادفع الكود إلى GitHub:**
   ```bash
   # إذا لم يكن لديك Git repository
   git init
   git add .
   git commit -m "Prepare iOS build"
   
   # أضف GitHub remote (استبدل USERNAME و REPO_NAME)
   git remote add origin https://github.com/USERNAME/REPO_NAME.git
   
   # ادفع الكود
   git branch -M main
   git push -u origin main
   ```

2. **شغّل البناء على GitHub:**
   - اذهب إلى: `https://github.com/USERNAME/REPO_NAME/actions`
   - اضغط على **"Build iOS"** من القائمة
   - اضغط **"Run workflow"** → **"Run workflow"**
   - انتظر 5-10 دقائق

3. **حمّل ملف IPA:**
   - بعد اكتمال البناء، اضغط على **"ios-app"** artifact
   - حمّل ملف `.ipa`

---

## 📱 الطريقة 2: استخدام Mac

إذا كان لديك Mac أو Mac في السحابة:

```bash
# 1. انتقل إلى مجلد المشروع
cd /path/to/project

# 2. احصل على التبعيات
flutter pub get

# 3. انتقل إلى مجلد iOS
cd ios

# 4. ثبت CocoaPods
pod install

# 5. ارجع إلى المجلد الرئيسي
cd ..

# 6. بناء IPA
flutter build ipa --release
```

الملف سيكون في: `build/ios/ipa/*.ipa`

---

## 📱 الطريقة 3: استخدام Codemagic (بديل)

1. سجّل في [Codemagic](https://codemagic.io)
2. اربط مستودع GitHub
3. اختر iOS build
4. شغّل البناء

---

## 🔧 استكشاف الأخطاء

### إذا فشل البناء على GitHub Actions:

**خطأ: Code signing**
- تحتاج Apple Developer Account
- أضف شهادات التوقيع في Xcode

**خطأ: Provisioning profile**
- أنشئ Provisioning Profile في Apple Developer Portal
- أضفه في Xcode

---

## ✅ حالة الملفات

جميع ملفات iOS جاهزة:
- ✅ `ios/Podfile` - معد
- ✅ `ios/Runner/Info.plist` - معد
- ✅ `ios/Runner.xcodeproj` - معد
- ✅ `.github/workflows/build_ios.yml` - جاهز

---

## 📞 المساعدة

إذا واجهت مشكلة:
1. تحقق من أن الكود موجود على GitHub
2. تأكد من أن `.github/workflows/build_ios.yml` موجود
3. تحقق من سجلات البناء في GitHub Actions

---

## ⚡ بناء سريع (على Mac فقط)

```bash
flutter build ipa --release
```




