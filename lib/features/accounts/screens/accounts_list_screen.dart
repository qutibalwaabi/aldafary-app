import 'package:flutter/material.dart';
import 'package:untitled/core/models/account_model.dart';
import 'package:untitled/core/services/account_service.dart';
import 'package:untitled/features/accounts/screens/add_edit_account_screen.dart';
import 'package:untitled/shared/theme/app_theme.dart';
import 'package:untitled/shared/widgets/app_card.dart';
import 'package:untitled/shared/widgets/confirm_dialog.dart';
import 'package:untitled/theme/app_colors.dart';
import 'package:intl/intl.dart';

class AccountsListScreen extends StatelessWidget {
  const AccountsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accountService = AccountService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الحسابات المالية'),
        backgroundColor: AppColors.primaryMaroon,
        foregroundColor: AppColors.textOnDark,
        elevation: 0,
      ),
      body: StreamBuilder<List<AccountModel>>(
        stream: accountService.streamAllAccounts(), // Show all including suspended for management
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
                    Icons.account_balance_wallet,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد حسابات',
                    style: AppTheme.heading3.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'انقر على زر + لإضافة حساب جديد',
                    style: AppTheme.bodyMedium.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final accounts = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return AppCard(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.accentGold.withOpacity(0.2),
                    child: Icon(
                      _getAccountIcon(account.type),
                      color: AppColors.primaryMaroon,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          account.name,
                          style: AppTheme.heading3.copyWith(fontSize: 18),
                        ),
                      ),
                      if (account.isSuspended)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'موقف',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        _getAccountTypeLabel(account.type),
                        style: AppTheme.bodyMedium.copyWith(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'الرصيد: ${NumberFormat('#,##0.00').format(account.balance)}',
                        style: AppTheme.bodyMedium.copyWith(
                          color: account.balance >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          account.isSuspended ? Icons.play_circle_outline : Icons.pause_circle_outline,
                          color: account.isSuspended ? Colors.green : Colors.orange,
                        ),
                        onPressed: () => _toggleSuspension(context, accountService, account),
                        tooltip: account.isSuspended ? 'إلغاء التوقيف' : 'توقيف',
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: AppColors.primaryMaroon),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AddEditAccountScreen(account: account),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteAccount(context, accountService, account),
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
            MaterialPageRoute(builder: (_) => const AddEditAccountScreen()),
          );
        },
        backgroundColor: AppColors.primaryMaroon,
        foregroundColor: AppColors.textOnDark,
        icon: const Icon(Icons.add),
        label: const Text('إضافة حساب'),
      ),
    );
  }

  IconData _getAccountIcon(String type) {
    switch (type) {
      case 'Cash':
        return Icons.money;
      case 'Bank':
        return Icons.account_balance;
      case 'Customer':
        return Icons.person;
      case 'Vendor':
        return Icons.store;
      case 'Expense':
        return Icons.trending_down;
      case 'Revenue':
        return Icons.trending_up;
      default:
        return Icons.account_circle;
    }
  }

  String _getAccountTypeLabel(String type) {
    switch (type) {
      case 'Cash':
        return 'صندوق';
      case 'Bank':
        return 'بنك';
      case 'Customer':
        return 'عميل';
      case 'Vendor':
        return 'مورد';
      case 'Expense':
        return 'مصروف';
      case 'Revenue':
        return 'إيراد';
      default:
        return type;
    }
  }

  Future<void> _toggleSuspension(
    BuildContext context,
    AccountService service,
    AccountModel account,
  ) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: account.isSuspended ? 'إلغاء توقيف الحساب' : 'توقيف الحساب',
      message: account.isSuspended
          ? 'هل تريد إلغاء توقيف الحساب "${account.name}"؟'
          : 'هل تريد توقيف الحساب "${account.name}"؟\n\nسيتم منع إجراء أي معاملات على هذا الحساب.',
      confirmText: account.isSuspended ? 'إلغاء التوقيف' : 'توقيف',
      cancelText: 'إلغاء',
      isDanger: !account.isSuspended,
    );

    if (confirmed != true) return;

    try {
      await service.updateAccount(
        account.id,
        account.copyWith(isSuspended: !account.isSuspended),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(account.isSuspended
                ? 'تم إلغاء توقيف الحساب بنجاح'
                : 'تم توقيف الحساب بنجاح'),
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

  Future<void> _deleteAccount(
    BuildContext context,
    AccountService service,
    AccountModel account,
  ) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'حذف الحساب',
      message: 'هل أنت متأكد من حذف الحساب "${account.name}"؟\n\nملاحظة: لا يمكن حذف الحساب إذا كان مستخدماً في معاملات مالية.',
      confirmText: 'حذف',
      cancelText: 'إلغاء',
      isDanger: true,
    );

    if (confirmed != true) return;

    try {
      await service.deleteAccount(account.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الحساب بنجاح'),
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

