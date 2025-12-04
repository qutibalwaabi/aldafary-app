import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:untitled/services/transaction_service.dart' as ts;
import 'package:untitled/core/services/account_service.dart';
import 'package:untitled/core/services/currency_service.dart';
import 'package:untitled/shared/widgets/print_preview_screen.dart';
import 'package:untitled/shared/widgets/unified_report_service.dart';
import 'package:untitled/features/transactions/screens/receipt_voucher_screen.dart';
import 'package:untitled/features/transactions/screens/payment_voucher_screen.dart';
import 'package:untitled/journal_voucher_screen.dart';
import 'package:untitled/features/transactions/screens/buy_currency_screen.dart';
import 'package:untitled/features/transactions/screens/sell_currency_screen.dart';
import 'package:untitled/theme/app_colors.dart';

// Helper function to show transaction details dialog
void showTransactionDetailsDialog(BuildContext context, ts.Transaction transaction) {
  showDialog(
    context: context,
    builder: (context) => TransactionDetailsDialog(transaction: transaction),
  );
}

class TransactionDetailsDialog extends StatelessWidget {
  final ts.Transaction transaction;

  const TransactionDetailsDialog({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryMaroon,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getOperationIcon(transaction.operationType),
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getTranslatedOperationType(transaction.operationType),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          transaction.formattedSerialNumber,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Accounts (Prominent)
                    FutureBuilder<List<dynamic>>(
                      future: Future.wait([
                        AccountService().getAccountById(transaction.debitAccountId),
                        AccountService().getAccountById(transaction.creditAccountId),
                      ]),
                      builder: (context, snapshot) {
                        final debitAccountName = snapshot.hasData && snapshot.data![0] != null
                            ? snapshot.data![0].name
                            : (transaction.debitAccountName ?? transaction.debitAccountId);
                        final creditAccountName = snapshot.hasData && snapshot.data![1] != null
                            ? snapshot.data![1].name
                            : (transaction.creditAccountName ?? transaction.creditAccountId);
                        
                        return Column(
                          children: [
                            _buildDetailRow(
                              icon: Icons.account_circle,
                              label: 'الحساب المدين',
                              value: debitAccountName,
                              color: Colors.red,
                              isProminent: true,
                            ),
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              icon: Icons.account_circle,
                              label: 'الحساب الدائن',
                              value: creditAccountName,
                              color: Colors.green,
                              isProminent: true,
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),
                    
                    // Amount and Currency (Prominent)
                    FutureBuilder(
                      future: CurrencyService().getCurrencyById(transaction.currencyId),
                      builder: (context, snapshot) {
                        final currencySymbol = snapshot.hasData && snapshot.data != null
                            ? snapshot.data!.symbol
                            : transaction.currencyId;
                        return _buildDetailRow(
                          icon: Icons.monetization_on,
                          label: 'المبلغ',
                          value: '${NumberFormat('#,##0.00').format(transaction.amount)} $currencySymbol',
                          color: AppColors.primaryMaroon,
                          isProminent: true,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Date (Less prominent)
                    _buildDetailRow(
                      icon: Icons.calendar_today,
                      label: 'التاريخ',
                      value: transaction.formattedDate,
                      color: Colors.grey,
                      isProminent: false,
                    ),
                    const SizedBox(height: 16),
                    
                    // Description (Less prominent)
                    _buildDetailRow(
                      icon: Icons.description,
                      label: 'البيان',
                      value: transaction.description,
                      color: Colors.grey,
                      isProminent: false,
                    ),
                  ],
                ),
              ),
            ),
            
            // Action Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _handlePrint(context),
                      icon: const Icon(Icons.print),
                      label: const Text('طباعة'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryMaroon,
                        side: BorderSide(color: AppColors.primaryMaroon),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleEdit(context),
                      icon: const Icon(Icons.edit),
                      label: const Text('تعديل'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryMaroon,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isProminent,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isProminent ? 12 : 11,
                  color: Colors.grey.shade600,
                  fontWeight: isProminent ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: isProminent ? 16 : 14,
                  fontWeight: isProminent ? FontWeight.bold : FontWeight.normal,
                  color: isProminent ? Colors.black87 : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handlePrint(BuildContext context) async {
    try {
      // Show loading indicator
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
      
      // Generate report data using unified service
      final accountService = AccountService();
      final currencyService = CurrencyService();
      final reportData = await UnifiedReportService.generateSingleTransactionReport(
        transaction,
        accountService,
        currencyService,
      );
      
      // Close loading dialog and transaction details dialog
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading
        Navigator.of(context).pop(); // Close transaction details dialog
      }
      
      if (!context.mounted) return;
      
      // Navigate to print preview with single transaction
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PrintPreviewScreen(
            reportType: ReportType.singleTransaction,
            title: reportData['title'] as String,
            content: Container(), // Not used for PDF/Excel generation
            metadata: {
              ...reportData['metadata'] as Map<String, dynamic>,
              'headers': reportData['headers'] as List<String>,
              'rows': reportData['rows'] as List<List<dynamic>>,
            },
          ),
        ),
      );
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading
      }
      
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تحضير التقرير: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _handleEdit(BuildContext context) {
    Navigator.of(context).pop(); // Close dialog
    
    // Navigate to appropriate edit screen based on operation type
    
    switch (transaction.operationType) {
      case 'Receipt':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReceiptVoucherScreen(transactionId: transaction.id),
          ),
        );
        break;
      case 'Payment':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PaymentVoucherScreen(transactionId: transaction.id),
          ),
        );
        break;
      case 'Journal':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => JournalVoucherScreen(transactionId: transaction.id),
          ),
        );
        break;
      case 'BuyCurrency':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BuyCurrencyScreen(transactionId: transaction.id),
          ),
        );
        break;
      case 'SellCurrency':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SellCurrencyScreen(transactionId: transaction.id),
          ),
        );
        break;
      default:
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('نوع العملية غير مدعوم للتعديل'),
              duration: Duration(seconds: 2),
            ),
          );
        }
    }
  }

  String _getTranslatedOperationType(String operationType) {
    switch (operationType) {
      case 'Receipt':
        return 'سند قبض';
      case 'Payment':
        return 'سند صرف';
      case 'Journal':
        return 'قيد يومية';
      case 'BuyCurrency':
        return 'شراء عملة';
      case 'SellCurrency':
        return 'بيع عملة';
      default:
        return operationType;
    }
  }

  IconData _getOperationIcon(String operationType) {
    switch (operationType) {
      case 'Receipt':
        return Icons.arrow_downward_rounded;
      case 'Payment':
        return Icons.arrow_upward_rounded;
      case 'Journal':
        return Icons.swap_horiz_rounded;
      case 'BuyCurrency':
        return Icons.trending_down_rounded;
      case 'SellCurrency':
        return Icons.trending_up_rounded;
      default:
        return Icons.receipt_rounded;
    }
  }
}

