import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:untitled/services/transaction_service.dart' as ts;
import 'package:untitled/theme/app_colors.dart';

class TransactionDetailsScreen extends StatelessWidget {
  final ts.Transaction transaction;

  const TransactionDetailsScreen({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل العملية'),
        backgroundColor: AppColors.primaryMaroon,
        foregroundColor: AppColors.textOnDark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Serial Number
            _buildDetailCard(
              title: 'الرقم التسلسلي',
              value: transaction.formattedSerialNumber,
              icon: Icons.numbers,
            ),
            const SizedBox(height: 16),

            // Reference Number (if exists)
            if (transaction.referenceNumber != null && transaction.referenceNumber!.isNotEmpty)
              _buildDetailCard(
                title: 'رقم المرجع',
                value: transaction.referenceNumber!,
                icon: Icons.tag,
              ),
            if (transaction.referenceNumber != null && transaction.referenceNumber!.isNotEmpty)
              const SizedBox(height: 16),

            // Transaction Type
            _buildDetailCard(
              title: 'نوع العملية',
              value: _getTranslatedOperationType(transaction.operationType),
              icon: _getOperationIcon(transaction.operationType),
            ),
            const SizedBox(height: 16),

            // Amount or Currency Exchange Details
            if (transaction.operationType == 'BuyCurrency' || transaction.operationType == 'SellCurrency')
              _buildCurrencyExchangeCard()
            else
              _buildDetailCard(
                title: 'المبلغ',
                value: transaction.formattedAmount,
                icon: Icons.money,
              ),
            const SizedBox(height: 16),

            // Date
            _buildDetailCard(
              title: 'التاريخ',
              value: transaction.formattedDate,
              icon: Icons.calendar_today,
            ),
            const SizedBox(height: 16),

            // Description
            _buildDetailCard(
              title: 'البيان',
              value: transaction.description,
              icon: Icons.description,
            ),
            const SizedBox(height: 16),

            // Accounts (only for non-currency exchange transactions)
            if (transaction.operationType != 'BuyCurrency' && transaction.operationType != 'SellCurrency')
              _buildAccountsCard(),
            if (transaction.operationType != 'BuyCurrency' && transaction.operationType != 'SellCurrency')
              const SizedBox(height: 16),

            // Action Buttons
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 24, color: AppColors.primaryMaroon),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

  Widget _buildAccountsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تفاصيل الحسابات',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Credit Account
            _buildAccountRow(
              title: 'الحساب الدائن',
              value: transaction.creditAccountName ?? 'غير محدد',
              icon: Icons.arrow_downward,
              color: Colors.green,
            ),

            const SizedBox(height: 8),

            // Debit Account
            _buildAccountRow(
              title: 'الحساب المدين',
              value: transaction.debitAccountName ?? 'غير محدد',
              icon: Icons.arrow_upward,
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountRow({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          '$title: ',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('سيتم إضافة الطباعة قريباً')),
            );
          },
          icon: const Icon(Icons.print),
          label: const Text('طباعة'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryMaroon,
            foregroundColor: AppColors.textOnDark,
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('سيتم إضافة التعديل قريباً')),
            );
          },
          icon: const Icon(Icons.edit),
          label: const Text('تعديل'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryMaroon,
            foregroundColor: AppColors.textOnDark,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrencyExchangeCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.currency_exchange, size: 24, color: AppColors.primaryMaroon),
                const SizedBox(width: 16),
                const Text(
                  'تفاصيل الصرف',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (transaction.fromAmount != null && transaction.fromCurrencyId != null)
              _buildExchangeRow(
                'المبلغ المدفوع',
                '${NumberFormat('#,##0.00').format(transaction.fromAmount)} ${transaction.fromCurrencyId}',
              ),
            if (transaction.exchangeRate != null) ...[
              const SizedBox(height: 8),
              _buildExchangeRow(
                'سعر الصرف',
                NumberFormat('#,##0.00').format(transaction.exchangeRate),
              ),
            ],
            if (transaction.toAmount != null && transaction.toCurrencyId != null) ...[
              const SizedBox(height: 8),
              _buildExchangeRow(
                'المبلغ المستلم',
                '${NumberFormat('#,##0.00').format(transaction.toAmount)} ${transaction.toCurrencyId}',
                isHighlight: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExchangeRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            color: isHighlight ? AppColors.primaryMaroon : Colors.black87,
          ),
        ),
      ],
    );
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