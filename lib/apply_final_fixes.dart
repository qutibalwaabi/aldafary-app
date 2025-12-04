import 'dart:io';

void main() async {
  print('بدء تطبيق الإصلاحات النهائية...');

  // قائمة الملفات القديمة التي يجب حذفها
  final oldFiles = [
    'lib/services/transaction_service.dart',
    'lib/services/unified_balance_service.dart',
    'lib/services/financial_engine_service.dart',
    'lib/journal_voucher_screen.dart',
    'lib/transaction_details_screen.dart'
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
    'lib/services/transaction_service_new.dart': 'lib/services/transaction_service.dart',
    'lib/services/unified_balance_service_new.dart': 'lib/services/unified_balance_service.dart',
    'lib/services/financial_engine_service_new.dart': 'lib/services/financial_engine_service.dart',
    'lib/journal_voucher_screen_new.dart': 'lib/journal_voucher_screen.dart',
    'lib/transaction_details_screen_new.dart': 'lib/transaction_details_screen.dart'
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

  print('اكتمل تطبيق جميع الإصلاحات النهائية!');
  print('يمكنك الآن تشغيل التطبيق باستخدام: flutter run');
}
