import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:untitled/services/transaction_service.dart' as ts;
import 'package:untitled/core/services/account_service.dart';
import 'package:untitled/core/services/currency_service.dart';
import 'package:untitled/core/models/account_model.dart';
import 'package:untitled/shared/widgets/app_card.dart';
import 'package:untitled/shared/theme/app_theme.dart';
import 'package:untitled/theme/app_colors.dart';
import 'package:untitled/shared/widgets/transaction_details_dialog.dart';

class OperationsScreen extends StatefulWidget {
  const OperationsScreen({super.key});

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  final ts.TransactionService _transactionService = ts.TransactionService();
  final AccountService _accountService = AccountService();
  final CurrencyService _currencyService = CurrencyService();
  final _searchController = TextEditingController();
  
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Receipt', 'Payment', 'Journal', 'BuyCurrency', 'SellCurrency'];
  // Removed state variables - will use StreamBuilder instead

  List<ts.Transaction> _filterTransactions(
    List<ts.Transaction> transactions,
    String searchQuery,
    Map<String, String> accountNames,
  ) {
    if (searchQuery.isEmpty) return transactions;
    
    final query = searchQuery.toLowerCase();
    return transactions.where((t) {
      return t.description.toLowerCase().contains(query) ||
          t.formattedSerialNumber.toLowerCase().contains(query) ||
          (t.referenceNumber?.toLowerCase().contains(query) ?? false) ||
          (accountNames[t.debitAccountId]?.toLowerCase().contains(query) ?? false) ||
          (accountNames[t.creditAccountId]?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

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
          // Filter and Search Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
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
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'بحث في العمليات...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Transactions List
          Expanded(
            child: StreamBuilder<List<ts.Transaction>>(
              stream: _selectedFilter == 'All'
                  ? _transactionService.streamAllTransactions()
                  : _transactionService.streamTransactionsByType(_selectedFilter),
              builder: (context, transactionsSnapshot) {
                if (transactionsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (transactionsSnapshot.hasError) {
                  return Center(
                    child: Text(
                      'حدث خطأ: ${transactionsSnapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (!transactionsSnapshot.hasData || transactionsSnapshot.data!.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد عمليات لعرضها',
                            style: AppTheme.bodyLarge.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final allTransactions = transactionsSnapshot.data!;

                // Load accounts and currencies using StreamBuilder
                return StreamBuilder<List<AccountModel>>(
                  stream: _accountService.streamAccounts(),
                  builder: (context, accountsSnapshot) {
                    final accounts = accountsSnapshot.data ?? [];
                    final accountNamesMap = <String, String>{};
                    for (var account in accounts) {
                      accountNamesMap[account.id] = account.name;
                    }
                    
                    debugPrint('Operations Screen: Loaded ${accounts.length} accounts');

                    return StreamBuilder<List<dynamic>>(
                      stream: _currencyService.streamCurrencies(),
                      builder: (context, currenciesSnapshot) {
                        final currencies = currenciesSnapshot.data ?? [];
                        final currencySymbolsMap = <String, String>{};
                        for (var currency in currencies) {
                          currencySymbolsMap[currency.id] = currency.symbol;
                        }
                        
                        debugPrint('Operations Screen: Loaded ${currencies.length} currencies');
                        debugPrint('Operations Screen: Processing ${allTransactions.length} transactions');

                        final filteredTransactions = _filterTransactions(
                          allTransactions,
                          _searchController.text,
                          accountNamesMap,
                        );

                        if (filteredTransactions.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                'لا توجد نتائج للبحث',
                                style: AppTheme.bodyLarge.copyWith(color: Colors.grey),
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredTransactions.length,
                          itemBuilder: (context, index) {
                            final transaction = filteredTransactions[index];
                            final debitAccountId = transaction.debitAccountId;
                            final creditAccountId = transaction.creditAccountId;
                            final currencyId = transaction.currencyId;
                            
                            debugPrint('Building transaction ${transaction.id}:');
                            debugPrint('  debitAccountId: $debitAccountId');
                            debugPrint('  creditAccountId: $creditAccountId');
                            debugPrint('  currencyId: $currencyId');
                            debugPrint('  accountNamesMap keys: ${accountNamesMap.keys.toList()}');
                            debugPrint('  currencySymbolsMap keys: ${currencySymbolsMap.keys.toList()}');
                            
                            final debitName = accountNamesMap[debitAccountId] ?? debitAccountId ?? 'غير محدد';
                            final creditName = accountNamesMap[creditAccountId] ?? creditAccountId ?? 'غير محدد';
                            final currencySymbol = currencySymbolsMap[currencyId] ?? currencyId ?? 'غير محدد';
                            
                            debugPrint('  Final debitName: $debitName');
                            debugPrint('  Final creditName: $creditName');
                            debugPrint('  Final currencySymbol: $currencySymbol');
                            final operationColor = _getOperationColor(transaction.operationType);
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200, width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () async {
                                    final transactionDetails = await _transactionService.getTransactionById(transaction.id);
                                    if (transactionDetails != null && mounted) {
                                      showTransactionDetailsDialog(context, transactionDetails);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: operationColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                _getOperationIcon(transaction.operationType),
                                                color: operationColor,
                                                size: 22,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                transaction.formattedSerialNumber.split('-').last,
                                                style: TextStyle(
                                                  color: operationColor,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // First line: Operation Type (Prominent and Elegant)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: operationColor.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: operationColor.withOpacity(0.3),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      _getOperationIcon(transaction.operationType),
                                                      size: 14,
                                                      color: operationColor,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      _getTranslatedOperationType(transaction.operationType),
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                        color: operationColor,
                                                        fontFamily: 'Cairo',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              // Second line: Accounts (Prominent)
                                              Row(
                                                children: [
                                                  Icon(Icons.account_circle, size: 14, color: Colors.grey.shade700),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      '$creditName → $debitName',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.black87,
                                                        fontFamily: 'Cairo',
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              // Third line: Amount and Currency (Prominent)
                                              Row(
                                                children: [
                                                  Text(
                                                    '${NumberFormat('#,##0.00').format(transaction.amount)} $currencySymbol',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.bold,
                                                      color: operationColor,
                                                      fontFamily: 'Cairo',
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  // Description (Less prominent)
                                                  Expanded(
                                                    child: Text(
                                                      transaction.description,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey.shade600,
                                                        fontFamily: 'Cairo',
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      textAlign: TextAlign.end,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              // Fourth line: Date (Less prominent)
                                              Row(
                                                children: [
                                                  Icon(Icons.calendar_today, size: 11, color: Colors.grey.shade500),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    transaction.formattedDate,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey.shade600,
                                                      fontFamily: 'Cairo',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
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
      case 'BuyCurrency':
      case 'SellCurrency':
        return Colors.purple;
      default:
        return Colors.grey;
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
      case 'BuyCurrency':
        return 'شراء عملة';
      case 'SellCurrency':
        return 'بيع عملة';
      default:
        return filter;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

