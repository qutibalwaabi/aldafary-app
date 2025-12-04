# المهام المتبقية

## ✅ ما تم إنجازه (في آخر تعديل)

1. ✅ تعديل شاشة تسجيل الدخول:
   - الدخول برقم الهاتف وكلمة المرور
   - فحص الإنترنت قبل الدخول
   - التحقق من البريد فقط عند تسجيل الدخول

2. ✅ تعديل شاشة إنشاء الحساب:
   - حفظ بيانات الدخول في SharedPreferences
   - منع تكرار الهاتف/الاسم/البريد
   - إغلاق شاشة الإنشاء وفتح شاشة الدخول مع ملء البيانات تلقائياً
   - إزالة التحقق من البريد عند الإنشاء

3. ✅ منع الدخول التلقائي في AuthWrapper

4. ✅ التحقق من حفظ الشعار في Firebase Storage

---

## ❌ المهام المتبقية

### 1. إضافة دعم التعديل الكامل (الأهم) 🔴
**الموقع:** `lib/shared/widgets/transaction_details_dialog.dart`
- **السطر 297:** يوجد TODO: "Implement edit functionality when screens support transactionId parameter"
- **المطلوب:**
  - إضافة دعم `transactionId` في جميع شاشات التعديل:
    - `ReceiptVoucherScreen` - إضافة constructor parameter `transactionId`
    - `PaymentVoucherScreen` - إضافة constructor parameter `transactionId`
    - `JournalVoucherScreen` - إضافة constructor parameter `transactionId`
    - `BuyCurrencyScreen` - إضافة constructor parameter `transactionId`
    - `SellCurrencyScreen` - إضافة constructor parameter `transactionId`
  - تحديث `_handleEdit` في `transaction_details_dialog.dart` للانتقال للشاشة الصحيحة مع `transactionId`
  - تحديث كل شاشة لتحميل بيانات العملية عند وجود `transactionId` وتمكين التعديل

### 2. إصلاح Excel Export في شاشة كشف الحساب 🟡
**الموقع:** `lib/features/reports/screens/account_statement_report_screen.dart`
- **السطر 380:** يوجد TODO: "Implement Excel export"
- **المطلوب:** إضافة وظيفة تصدير Excel مثلما تم في `transactions_report_screen.dart`

### 3. إصلاح Share في شاشة كشف الحساب 🟡
**الموقع:** `lib/features/reports/screens/account_statement_report_screen.dart`
- **السطر 366:** يوجد TODO: "Implement share"
- **المطلوب:** إضافة وظيفة المشاركة باستخدام `share_plus` package

### 4. إضافة أزرار طباعة لكل عملية 🟢
**المواقع:**
- `lib/home_screen.dart` - عند النقر على عملية
- `lib/features/transactions/screens/operations_screen.dart` - عند النقر على عملية
- `lib/features/reports/screens/account_statement_report_screen.dart` - لكل بند في الكشف

**المطلوب:**
- إضافة زر طباعة صغير بجانب كل عملية
- عند النقر، فتح `transaction_details_dialog` الذي يحتوي على زر طباعة
- أو فتح `PrintPreviewScreen` مباشرة للعملية المحددة

---

## 📋 ملاحظات

### أولويات التنفيذ:
1. **الأولوية العالية:** إضافة دعم التعديل الكامل (رقم 1)
2. **الأولوية المتوسطة:** إصلاح Excel Export و Share (رقم 2 و 3)
3. **الأولوية المنخفضة:** إضافة أزرار طباعة (رقم 4) - يمكن استخدام dialog التفاصيل الموجود

### الملفات التي تحتاج تعديل:
- `lib/shared/widgets/transaction_details_dialog.dart` - إضافة التعديل
- `lib/features/transactions/screens/receipt_voucher_screen.dart` - دعم transactionId
- `lib/features/transactions/screens/payment_voucher_screen.dart` - دعم transactionId
- `lib/journal_voucher_screen.dart` - دعم transactionId
- `lib/features/transactions/screens/buy_currency_screen.dart` - دعم transactionId
- `lib/features/transactions/screens/sell_currency_screen.dart` - دعم transactionId
- `lib/features/reports/screens/account_statement_report_screen.dart` - Excel و Share
- `lib/services/transaction_service.dart` - قد تحتاج إضافة `updateTransaction` method

---

## ✅ الحالة الحالية

- ✅ طباعة التقارير تعمل (PDF/Excel)
- ✅ عرض تفاصيل العملية (Dialog)
- ✅ طباعة عملية واحدة من Dialog التفاصيل
- ❌ تعديل العملية (يحتاج transactionId support)
- ❌ Excel export في كشف الحساب
- ❌ Share في كشف الحساب

