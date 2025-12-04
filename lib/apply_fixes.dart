// هذا الملف يحتوي على جميع التعليمات اللازمة لتطبيق الإصلاحات
// يرجى اتباع هذه الخطوات بالترتيب

import 'dart:io';

void main() async {
  print('بدء تطبيق الإصلاحات...');

  // 1. حذف الملفات القديمة
  final oldFiles = [
    'lib/home_screen.dart',
    'lib/receipt_voucher_screen.dart',
    'lib/payment_voucher_screen.dart',
    'lib/operations_screen.dart',
    'lib/financial_engine_service.dart',
    'lib/account_statement_screen.dart',
    'lib/login_screen.dart',
    'lib/main.dart'
  ];

  for (final file in oldFiles) {
    try {
      final fileObj = File(file);
      if (await fileObj.exists()) {
        await fileObj.delete();
        print('تم حذف: $file');
      }
    } catch (e) {
      print('خطأ في حذف $file: $e');
    }
  }

  // 2. إعادة تسمية الملفات الجديدة
  final renames = {
    'lib/home.dart': 'lib/home_screen.dart',
    'lib/receipt.dart': 'lib/receipt_voucher_screen.dart',
    'lib/payment.dart': 'lib/payment_voucher_screen.dart',
    'lib/operations.dart': 'lib/operations_screen.dart',
    'lib/services/engine.dart': 'lib/services/financial_engine_service.dart',
    'lib/reports/statement.dart': 'lib/reports/account_statement_screen.dart',
    'lib/login.dart': 'lib/login_screen.dart',
    'lib/main_new.dart': 'lib/main.dart'
  };

  for (final entry in renames.entries) {
    try {
      final oldFile = File(entry.key);
      final newFile = File(entry.value);

      if (await oldFile.exists()) {
        await oldFile.rename(entry.value);
        print('تم إعادة تسمية: ${entry.key} -> ${entry.value}');
      }
    } catch (e) {
      print('خطأ في إعادة تسمية ${entry.key}: $e');
    }
  }

  print('اكتمل تطبيق الإصلاحات!');
  print('يمكنك الآن تشغيل التطبيق باستخدام: flutter run');
}
