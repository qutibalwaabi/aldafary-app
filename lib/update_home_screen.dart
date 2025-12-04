import 'dart:io';

void main() async {
  print('بدء تحديث الشاشة الرئيسية...');

  try {
    // نسخ الملف الجديد ليحل محل القديم
    final oldFile = File('lib/home_screen.dart');
    final newFile = File('lib/home_screen_new.dart');

    if (await newFile.exists()) {
      // حذف الملف القديم
      if (await oldFile.exists()) {
        await oldFile.delete();
        print('تم حذف الملف القديم: lib/home_screen.dart');
      }

      // نسخ الملف الجديد
      await newFile.copy('lib/home_screen.dart');
      print('تم نسخ الملف الجديد: lib/home_screen_new.dart -> lib/home_screen.dart');

      // حذف الملف المؤقت
      await newFile.delete();
      print('تم حذف الملف المؤقت: lib/home_screen_new.dart');

      print('اكتمل تحديث الشاشة الرئيسية بنجاح!');
    } else {
      print('الملف الجديد غير موجود: lib/home_screen_new.dart');
    }
  } catch (e) {
    print('حدث خطأ: $e');
  }
}