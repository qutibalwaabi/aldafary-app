import 'package:flutter/material.dart';
import 'package:untitled/core/models/currency_model.dart';
import 'package:untitled/core/services/currency_service.dart';
import 'package:untitled/features/currencies/screens/add_edit_currency_screen.dart';
import 'package:untitled/shared/theme/app_theme.dart';
import 'package:untitled/shared/widgets/app_card.dart';
import 'package:untitled/shared/widgets/confirm_dialog.dart';
import 'package:untitled/theme/app_colors.dart';

class CurrenciesListScreen extends StatelessWidget {
  const CurrenciesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyService = CurrencyService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة العملات'),
        backgroundColor: AppColors.primaryMaroon,
        foregroundColor: AppColors.textOnDark,
        elevation: 0,
      ),
      body: StreamBuilder<List<CurrencyModel>>(
        stream: currencyService.streamAllCurrencies(), // Show all including suspended for management
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('حدث خطأ: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.currency_exchange,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد عملات',
                    style: AppTheme.heading3.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'انقر على زر + لإضافة عملة جديدة',
                    style: AppTheme.bodyMedium.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final currencies = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: currencies.length,
            itemBuilder: (context, index) {
              final currency = currencies[index];
              return AppCard(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: currency.isPrimary
                        ? AppColors.accentGold.withOpacity(0.3)
                        : AppColors.primaryMaroon.withOpacity(0.1),
                    radius: 28,
                    child: Text(
                      currency.symbol,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: currency.isPrimary ? AppColors.accentGold : AppColors.primaryMaroon,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          currency.name,
                          style: AppTheme.heading3.copyWith(fontSize: 18),
                        ),
                      ),
                      if (currency.isPrimary) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentGold.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'أساسية',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppColors.accentGold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (currency.isSuspended && !currency.isPrimary) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'موقفة',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'سعر الصرف: ${currency.exchangeRate}',
                        style: AppTheme.bodyMedium.copyWith(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!currency.isPrimary)
                        IconButton(
                          icon: Icon(
                            currency.isSuspended ? Icons.play_circle_outline : Icons.pause_circle_outline,
                            color: currency.isSuspended ? Colors.green : Colors.orange,
                          ),
                          onPressed: () => _toggleSuspension(context, currencyService, currency),
                          tooltip: currency.isSuspended ? 'إلغاء التوقيف' : 'توقيف',
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: AppColors.primaryMaroon),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AddEditCurrencyScreen(currency: currency),
                            ),
                          );
                        },
                      ),
                      if (!currency.isPrimary)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteCurrency(context, currencyService, currency),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddEditCurrencyScreen()),
          );
        },
        backgroundColor: AppColors.primaryMaroon,
        foregroundColor: AppColors.textOnDark,
        icon: const Icon(Icons.add),
        label: const Text('إضافة عملة'),
      ),
    );
  }

  Future<void> _toggleSuspension(
    BuildContext context,
    CurrencyService service,
    CurrencyModel currency,
  ) async {
    if (currency.isPrimary) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن توقيف العملة الرئيسية'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showConfirmDialog(
      context: context,
      title: currency.isSuspended ? 'إلغاء توقيف العملة' : 'توقيف العملة',
      message: currency.isSuspended
          ? 'هل تريد إلغاء توقيف العملة "${currency.name}"؟'
          : 'هل تريد توقيف العملة "${currency.name}"؟\n\nسيتم منع إجراء أي معاملات بهذه العملة.',
      confirmText: currency.isSuspended ? 'إلغاء التوقيف' : 'توقيف',
      cancelText: 'إلغاء',
      isDanger: !currency.isSuspended,
    );

    if (confirmed != true) return;

    try {
      await service.updateCurrency(
        currency.id,
        currency.copyWith(isSuspended: !currency.isSuspended),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currency.isSuspended
                ? 'تم إلغاء توقيف العملة بنجاح'
                : 'تم توقيف العملة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteCurrency(
    BuildContext context,
    CurrencyService service,
    CurrencyModel currency,
  ) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'حذف العملة',
      message: 'هل أنت متأكد من حذف العملة "${currency.name}"؟\n\nملاحظة: لا يمكن حذف العملة إذا كانت مستخدمة في معاملات مالية.',
      confirmText: 'حذف',
      cancelText: 'إلغاء',
      isDanger: true,
    );

    if (confirmed != true) return;

    try {
      await service.deleteCurrency(currency.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف العملة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

