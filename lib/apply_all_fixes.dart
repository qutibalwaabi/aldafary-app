import 'dart:io';

void main() async {
  print('بدء تطبيق جميع الإصلاحات...');

  // قائمة الملفات القديمة التي يجب حذفها
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

  // حذف الملفات القديمة
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

  // قائمة الملفات الجديدة التي يجب إعادة تسميتها
  final renames = {
    'lib/home_fixed.dart': 'lib/home_screen.dart',
    'lib/receipt_fixed.dart': 'lib/receipt_voucher_screen.dart',
    'lib/payment_fixed.dart': 'lib/payment_voucher_screen.dart',
    'lib/operations_fixed.dart': 'lib/operations_screen.dart',
    'lib/services/engine_fixed.dart': 'lib/services/financial_engine_service.dart',
    'lib/reports/statement_fixed.dart': 'lib/reports/account_statement_screen.dart',
    'lib/transaction_details.dart': 'lib/transaction_details_screen.dart',
    'lib/main_new.dart': 'lib/main.dart'
  };

  // إعادة تسمية الملفات الجديدة
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

  print('اكتمل تطبيق جميع الإصلاحات!');
  print('يمكنك الآن تشغيل التطبيق باستخدام: flutter run');
}
