import 'dart:io';

void main() async {
  print('بدء تطبيق إصلاح الشاشة الرئيسية...');

  try {
    // حذف الملف القديم
    final oldFile = File('lib/home_screen.dart');
    if (await oldFile.exists()) {
      await oldFile.delete();
      print('تم حذف الملف القديم: lib/home_screen.dart');
    }

    // نسخ الملف المصحح
    final fixedFile = File('lib/home_screen_fixed.dart');
    if (await fixedFile.exists()) {
      await fixedFile.copy('lib/home_screen.dart');
      print('تم نسخ الملف المصحح: lib/home_screen_fixed.dart -> lib/home_screen.dart');

      // حذف الملف المؤقت
      await fixedFile.delete();
      print('تم حذف الملف المؤقت: lib/home_screen_fixed.dart');
    }

    print('اكتمل تطبيق الإصلاح بنجاح!');
  } catch (e) {
    print('حدث خطأ: $e');
  }
}