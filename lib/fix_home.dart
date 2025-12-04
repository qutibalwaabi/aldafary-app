import 'dart:io';

void main() async {
  print('بدء إصلاح الشاشة الرئيسية...');

  try {
    final homeScreen = File('lib/home_screen.dart');
    if (await homeScreen.exists()) {
      await homeScreen.delete();
      print('تم حذف الملف القديم');
    }

    final content = File('lib/home_screen_fixed.dart');
    if (await content.exists()) {
      await content.copy('lib/home_screen.dart');
      print('تم نسخ الملف المصحح');
      await content.delete();
      print('تم حذف الملف المؤقت');
    }

    print('اكتمل الإصلاح بنجاح!');
  } catch (e) {
    print('حدث خطأ: $e');
  }
}