import 'dart:io';

void main() async {
  print('بدء تطبيق الإصلاح النهائي للشاشة الرئيسية...');

  try {
    // حذف الملف القديم
    final oldFile = File('lib/home_screen.dart');
    if (await oldFile.exists()) {
      await oldFile.delete();
      print('تم حذف الملف القديم: lib/home_screen.dart');
    }

    // نسخ الملف المصحح
    final fixedFile = File('lib/home_screen_final.dart');
    if (await fixedFile.exists()) {
      await fixedFile.copy('lib/home_screen.dart');
      print('تم نسخ الملف المصحح: lib/home_screen_final.dart -> lib/home_screen.dart');

      // حذف الملف المؤقت
      await fixedFile.delete();
      print('تم حذف الملف المؤقت: lib/home_screen_final.dart');
    }

    print('اكتمل تطبيق الإصلاح النهائي بنجاح!');
    print('يمكنك الآن تشغيل التطبيق باستخدام: flutter run');
  } catch (e) {
    print('حدث خطأ: $e');
  }
}