import 'package:flutter/material.dart';
import 'package:untitled/services/transaction_service.dart';
import 'package:untitled/transaction_details_screen.dart';
import 'package:untitled/theme/app_colors.dart';

class OperationsScreen extends StatefulWidget {
  const OperationsScreen({super.key});

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  final TransactionService _transactionService = TransactionService();
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Receipt', 'Payment', 'Journal'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('جميع العمليات'),
        backgroundColor: AppColors.primaryMaroon,
        foregroundColor: AppColors.textOnDark,
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Text(
                  'تصفية حسب النوع:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    onChanged: (value) {
                      setState(() {
                        _selectedFilter = value!;
                      });
                    },
                    items: _filterOptions.map((filter) {
                      return DropdownMenuItem<String>(
                        value: filter,
                        child: Text(_getTranslatedFilter(filter)),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Transactions List
          Expanded(
            child: StreamBuilder<List<Transaction>>(
              stream: _selectedFilter == 'All'
                  ? _transactionService.streamAllTransactions()
                  : _transactionService.streamTransactionsByType(_selectedFilter),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'حدث خطأ: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text('لا توجد عمليات لعرضها'),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final transaction = snapshot.data![index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getOperationColor(transaction.operationType),
                          child: Icon(
                            _getOperationIcon(transaction.operationType),
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          _getTranslatedOperationType(transaction.operationType),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(transaction.description),
                        trailing: Text(
                          transaction.formattedAmount,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        onTap: () => _showTransactionOptions(transaction.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getOperationColor(String operationType) {
    switch (operationType) {
      case 'Receipt':
        return Colors.green;
      case 'Payment':
        return Colors.red;
      case 'Journal':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getOperationIcon(String operationType) {
    switch (operationType) {
      case 'Receipt':
        return Icons.arrow_downward;
      case 'Payment':
        return Icons.arrow_upward;
      case 'Journal':
        return Icons.swap_horiz;
      default:
        return Icons.receipt;
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
      default:
        return operationType;
    }
  }

  String _getTranslatedFilter(String filter) {
    switch (filter) {
      case 'All':
        return 'الكل';
      case 'Receipt':
        return 'سندات القبض';
      case 'Payment':
        return 'سندات الصرف';
      case 'Journal':
        return 'قيود اليومية';
      default:
        return filter;
    }
  }

  void _showTransactionOptions(String transactionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خيارات العملية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.print),
              title: const Text('طباعة'),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('سيتم إضافة الطباعة قريباً')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('تعديل'),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('سيتم إضافة التعديل قريباً')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('التفاصيل'),
              onTap: () async {
                Navigator.of(context).pop();
                final transaction = await _transactionService.getTransactionById(transactionId);
                if (transaction != null && mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TransactionDetailsScreen(transaction: transaction),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}