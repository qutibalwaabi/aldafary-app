import 'dart:io';

void main() async {
  print('بدء إصلاح الملفات المتبقية...');

  // قائمة الملفات التي يجب إعادة تسميتها يدوياً
  final renames = {
    'lib/services/transaction_service_new.dart': 'lib/services/transaction_service.dart',
    'lib/services/unified_balance_service_new.dart': 'lib/services/unified_balance_service.dart',
    'lib/services/financial_engine_service_new.dart': 'lib/services/financial_engine_service.dart',
    'lib/journal_voucher_screen_new.dart': 'lib/journal_voucher_screen.dart'
  };

  // إعادة تسمية الملفات
  for (final entry in renames.entries) {
    try {
      final oldFile = File(entry.key);
      final newFile = File(entry.value);

      if (await oldFile.exists()) {
        await oldFile.rename(entry.value);
        print('تم إعادة تسمية: ${entry.key} -> ${entry.value}');
      } else {
        print('الملف غير موجود: ${entry.key}');
      }
    } catch (e) {
      print('خطأ في إعادة تسمية ${entry.key}: $e');
    }
  }

  print('اكتمل إصلاح الملفات المتبقية!');
  print('يمكنك الآن تشغيل التطبيق باستخدام: flutter run');
}
