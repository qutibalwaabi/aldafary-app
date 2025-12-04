# قائمة الملفات المكررة التي يجب حذفها

## 📁 ملفات يجب حذفها (ملفات مؤقتة وإصلاحات)

### ملفات الإصلاح (Fix Scripts)
هذه الملفات كانت تستخدم لإصلاح المشاكل لكن لم تعد ضرورية:

```
lib/apply_all_fixes.dart
lib/apply_final_fixes.dart
lib/apply_final_home_fix.dart
lib/apply_fixes.dart
lib/apply_home_fix.dart
lib/fix_home.dart
lib/fix_remaining_files.dart
lib/update_home_screen.dart
lib/fix_instructions.txt
```

### ملفات النسخ المؤقتة
هذه نسخ مؤقتة من الملفات الأصلية:

```
lib/home_screen_temp.dart
lib/home_screen_updated.dart
lib/home_screen_final.dart (إن وجد)
lib/new_page.dart (إن كان مؤقت)
```

### ملفات النسخ المكررة
هذه نسخ من الملفات الأصلية مع أسماء مختلفة:

```
lib/services/financial_engine_service_fixed.dart
lib/services/financial_engine_service_final.dart
lib/payment_voucher_screen_fixed.dart
lib/payment_voucher_screen_final.dart
lib/receipt_voucher_screen_fixed.dart
lib/receipt_voucher_screen_final.dart
lib/operations_screen_fixed.dart
lib/operations_screen_final.dart
lib/login_screen_fixed.dart
lib/reports/account_statement_screen_fixed.dart
lib/reports/account_statement_screen_final.dart
```

## ✅ الملفات التي يجب الاحتفاظ بها

### الملفات الأساسية (الأصلية)
```
lib/main.dart
lib/home_screen.dart
lib/login_screen.dart
lib/receipt_voucher_screen.dart
lib/payment_voucher_screen.dart
lib/journal_voucher_screen.dart
lib/operations_screen.dart
lib/accounts_screen.dart
lib/currencies_screen.dart
lib/buy_currency_screen.dart
lib/sell_currency_screen.dart
lib/reports_screen.dart
lib/user_profile_screen.dart
lib/transaction_details_screen.dart
lib/account_balances_screen.dart
lib/account_statement_screen.dart
lib/add_account_screen.dart
lib/add_currency_screen.dart
lib/add_exchange_rate_screen.dart
lib/exchange_rates_screen.dart
lib/splash_screen.dart
lib/signup_screen.dart
lib/otp_screen.dart
lib/verify_email_screen.dart
```

### الخدمات (يجب توحيدها لاحقاً)
```
lib/services/transaction_service.dart
lib/services/unified_balance_service.dart
lib/services/financial_engine_service.dart
lib/services/balance_service.dart (قد يحتاج دمج)
lib/services/engine.dart (قد يحتاج دمج)
```

### المكونات المشتركة
```
lib/theme/app_colors.dart
lib/utils/show_message_dialog.dart
lib/firebase_options.dart
```

## 🔧 خطوات التنظيف

### 1. نسخ احتياطي
قبل الحذف، تأكد من أن الملفات الأصلية تعمل بشكل صحيح.

### 2. حذف الملفات المؤقتة
```bash
# حذف ملفات الإصلاح
rm lib/apply_*.dart
rm lib/fix_*.dart
rm lib/update_*.dart
rm lib/fix_instructions.txt

# حذف الملفات المؤقتة
rm lib/home_screen_temp.dart
rm lib/home_screen_updated.dart
rm lib/new_page.dart  # إذا كان مؤقت

# حذف النسخ المكررة
rm lib/**/*_fixed.dart
rm lib/**/*_final.dart
```

### 3. التحقق
بعد الحذف، تأكد من أن التطبيق يعمل:
```bash
flutter clean
flutter pub get
flutter run
```

## 📝 ملاحظات

- **احذر**: تأكد من أن الملفات الأصلية تعمل قبل حذف النسخ المكررة
- **النسخ الاحتياطي**: احتفظ بنسخة احتياطية قبل البدء
- **الاختبار**: اختبر التطبيق بعد كل خطوة تنظيف

---

**تاريخ الإنشاء**: $(date)
**الحالة**: جاهز للتنفيذ

