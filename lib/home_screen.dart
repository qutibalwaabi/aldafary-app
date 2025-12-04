import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:untitled/services/transaction_service.dart' as ts;
import 'package:untitled/core/services/account_service.dart';
import 'package:untitled/core/services/currency_service.dart';
import 'package:untitled/core/models/account_model.dart';
import 'package:untitled/features/transactions/screens/receipt_voucher_screen.dart';
import 'package:untitled/features/transactions/screens/payment_voucher_screen.dart';
import 'package:untitled/journal_voucher_screen.dart';
import 'package:untitled/features/transactions/screens/operations_screen.dart';
import 'package:untitled/accounts_screen.dart';
import 'package:untitled/currencies_screen.dart';
import 'package:untitled/exchange_rates_screen.dart';
import 'package:untitled/account_balances_screen.dart';
import 'package:untitled/features/transactions/screens/buy_currency_screen.dart';
import 'package:untitled/features/transactions/screens/sell_currency_screen.dart';
import 'package:untitled/reports_screen.dart';
import 'package:untitled/user_profile_screen.dart';
import 'package:untitled/theme/app_colors.dart';
import 'package:untitled/shared/theme/app_theme.dart';
import 'package:untitled/shared/widgets/app_card.dart';
import 'package:untitled/shared/widgets/transaction_details_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final ts.TransactionService _transactionService = ts.TransactionService();
  final AccountService _accountService = AccountService();
  final CurrencyService _currencyService = CurrencyService();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ar_SA', null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'الرئيسية',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.primaryMaroon,
        foregroundColor: AppColors.textOnDark,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_rounded, size: 22),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const UserProfileScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        color: AppColors.primaryMaroon,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fund Balance Card - Replacing Welcome Section
              _buildFundBalanceCard(),
              const SizedBox(height: 20),

              // Quick Actions Section - Compact Grid
              _buildQuickActionsSection(),
              const SizedBox(height: 20),

              // Recent Transactions Section
              _buildRecentTransactionsSection(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      drawer: _buildDrawer(),
    );
  }

  Widget _buildFundBalanceCard() {
    return StreamBuilder<List<AccountModel>>(
      stream: _accountService.streamAccounts(),
      builder: (context, accountsSnapshot) {
        double fundBalance = 0.0;
        String currencySymbol = 'ر.س';

        if (accountsSnapshot.hasData) {
          final cashAccounts = accountsSnapshot.data!
              .where((a) => a.type.toLowerCase() == 'cash' || a.type.toLowerCase() == 'صندوق')
              .toList();
          
          for (var account in cashAccounts) {
            fundBalance += account.balance;
          }

          // Get currency symbol from transactions or default
          // For now, use default - currency will be shown per transaction
          currencySymbol = 'ر.س';
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.green.shade600,
                Colors.green.shade700,
              ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'رصيد الصندوق',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${NumberFormat('#,##0.00').format(fundBalance)} $currencySymbol',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(Icons.dashboard_rounded, color: AppColors.primaryMaroon, size: 20),
              const SizedBox(width: 8),
              Text(
                'الإجراءات السريعة',
                style: AppTheme.heading2.copyWith(
                  color: AppColors.textOnLight,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 12.0,
          crossAxisSpacing: 12.0,
          childAspectRatio: 1.0,
          children: [
            _buildCompactActionCard(
              title: 'سند قبض',
              icon: Icons.arrow_downward_rounded,
              color: Colors.green,
              onTap: () => _navigateToScreen(const ReceiptVoucherScreen()),
            ),
            _buildCompactActionCard(
              title: 'سند صرف',
              icon: Icons.arrow_upward_rounded,
              color: Colors.red,
              onTap: () => _navigateToScreen(const PaymentVoucherScreen()),
            ),
            _buildCompactActionCard(
              title: 'قيد يومية',
              icon: Icons.swap_horiz_rounded,
              color: Colors.blue,
              onTap: () => _navigateToScreen(const JournalVoucherScreen()),
            ),
            _buildCompactActionCard(
              title: 'شراء عملة',
              icon: Icons.trending_down_rounded,
              color: Colors.purple,
              onTap: () => _navigateToScreen(const BuyCurrencyScreen()),
            ),
            _buildCompactActionCard(
              title: 'بيع عملة',
              icon: Icons.trending_up_rounded,
              color: Colors.orange,
              onTap: () => _navigateToScreen(const SellCurrencyScreen()),
            ),
            _buildCompactActionCard(
              title: 'العمليات',
              icon: Icons.receipt_long_rounded,
              color: AppColors.primaryMaroon,
              onTap: () => _navigateToScreen(const OperationsScreen()),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textOnLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Cairo',
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceSummarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.account_balance_rounded, color: Colors.blue.shade700, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'ملخص الأرصدة',
                style: AppTheme.heading2.copyWith(
                  color: AppColors.textOnLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        StreamBuilder<List<AccountModel>>(
          stream: _accountService.streamAccounts(),
          builder: (context, accountsSnapshot) {
            if (accountsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (!accountsSnapshot.hasData || accountsSnapshot.data!.isEmpty) {
              return AppCard(
                padding: const EdgeInsets.all(40.0),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'لا توجد حسابات لعرضها',
                        style: AppTheme.bodyLarge.copyWith(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ابدأ بإضافة حساب جديد',
                        style: AppTheme.bodyMedium.copyWith(
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final accounts = accountsSnapshot.data!;
            
            // Calculate balances by account type
            double totalCash = 0.0;
            double totalBank = 0.0;
            double totalCustomer = 0.0;
            double totalVendor = 0.0;

            // Calculate balances for each account
            for (var account in accounts) {
              final balance = account.balance;
              switch (account.type.toLowerCase()) {
                case 'cash':
                  totalCash += balance;
                  break;
                case 'bank':
                  totalBank += balance;
                  break;
                case 'customer':
                  totalCustomer += balance;
                  break;
                case 'vendor':
                  totalVendor += balance;
                  break;
              }
            }

            final total = totalCash + totalBank + totalCustomer + totalVendor;

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildProfessionalBalanceCard(
                        title: 'الصندوق',
                        amount: totalCash,
                        icon: Icons.money_rounded,
                        gradient: [Colors.green.shade400, Colors.green.shade600],
                        iconBg: Colors.green.shade50,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildProfessionalBalanceCard(
                        title: 'البنوك',
                        amount: totalBank,
                        icon: Icons.account_balance_rounded,
                        gradient: [Colors.blue.shade400, Colors.blue.shade600],
                        iconBg: Colors.blue.shade50,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildProfessionalBalanceCard(
                  title: 'الإجمالي',
                  amount: total,
                  icon: Icons.summarize_rounded,
                  gradient: [AppColors.primaryMaroon, AppColors.primaryMaroon.withOpacity(0.8)],
                  iconBg: AppColors.primaryMaroon.withOpacity(0.1),
                  isTotal: true,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildProfessionalBalanceCard({
    required String title,
    required double amount,
    required IconData icon,
    required List<Color> gradient,
    required Color iconBg,
    bool isTotal = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const Spacer(),
              if (isTotal)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'إجمالي',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            NumberFormat('#,##0.00').format(amount),
            style: TextStyle(
              color: Colors.white,
              fontSize: isTotal ? 26 : 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.history_rounded, color: Colors.purple.shade700, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'آخر العمليات',
                        style: AppTheme.heading2.copyWith(
                          color: AppColors.textOnLight,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _navigateToScreen(const OperationsScreen()),
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 14),
                label: const Text(
                  'عرض الكل',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryMaroon,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: StreamBuilder<List<ts.Transaction>>(
            stream: _transactionService.streamRecentTransactions(limit: 5),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'لا توجد عمليات لعرضها',
                          style: AppTheme.bodyLarge.copyWith(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ابدأ بإضافة عملية مالية جديدة',
                          style: AppTheme.bodyMedium.copyWith(
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final transactions = snapshot.data!;
              return StreamBuilder<List<AccountModel>>(
                stream: _accountService.streamAccounts(),
                builder: (context, accountsSnapshot) {
                  if (accountsSnapshot.connectionState == ConnectionState.waiting && !accountsSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final accounts = accountsSnapshot.data ?? [];
                  final accountNamesMap = <String, String>{};
                  for (var account in accounts) {
                    accountNamesMap[account.id] = account.name;
                  }
                  
                  debugPrint('Home Screen: Loaded ${accounts.length} accounts');
                  debugPrint('Home Screen: Account names map has ${accountNamesMap.length} entries');

                  final fundAccounts = accounts.where((a) => 
                    a.type.toLowerCase() == 'cash' || a.type.toLowerCase() == 'صندوق'
                  ).toList();

                  // Load currencies using StreamBuilder
                  return StreamBuilder<List<dynamic>>(
                    stream: _currencyService.streamCurrencies(),
                    builder: (context, currenciesSnapshot) {
                      final currencySymbolsMap = <String, String>{};
                      if (currenciesSnapshot.hasData) {
                        for (var currency in currenciesSnapshot.data!) {
                          currencySymbolsMap[currency.id] = currency.symbol;
                        }
                      }
                      
                      debugPrint('Home Screen: Loaded ${currenciesSnapshot.data?.length ?? 0} currencies');
                      debugPrint('Home Screen: Currency symbols map has ${currencySymbolsMap.length} entries');

                      // Debug transaction data
                      for (var transaction in transactions) {
                        debugPrint('Transaction ${transaction.id}: debitAccountId=${transaction.debitAccountId}, creditAccountId=${transaction.creditAccountId}, currencyId=${transaction.currencyId}');
                        debugPrint('  Debit name: ${accountNamesMap[transaction.debitAccountId]}');
                        debugPrint('  Credit name: ${accountNamesMap[transaction.creditAccountId]}');
                        debugPrint('  Currency symbol: ${currencySymbolsMap[transaction.currencyId]}');
                      }

                      return Column(
                        children: [
                          ...transactions.map((transaction) {
                            return _buildTransactionTile(
                              transaction,
                              accountNamesMap,
                              fundAccounts,
                              currencySymbolsMap,
                            );
                          }),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionTile(
    ts.Transaction transaction,
    Map<String, String> accountNamesMap,
    List<AccountModel> fundAccounts,
    Map<String, String> currencySymbolsMap,
  ) {
    final color = _getOperationTypeColor(transaction.operationType);
    
    final debitName = accountNamesMap[transaction.debitAccountId] ?? transaction.debitAccountId ?? 'غير محدد';
    final creditName = accountNamesMap[transaction.creditAccountId] ?? transaction.creditAccountId ?? 'غير محدد';
    
    // Determine fund account (usually cash type)
    final isDebitFund = fundAccounts.any((a) => a.id == transaction.debitAccountId);
    final isCreditFund = fundAccounts.any((a) => a.id == transaction.creditAccountId);
    final fundAccount = isDebitFund ? debitName : (isCreditFund ? creditName : '');
    final otherAccount = isDebitFund ? creditName : debitName;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToTransactionDetails(transaction),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getOperationTypeIcon(transaction.operationType),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Operation Name - Prominent and Elegant
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getOperationTypeIcon(transaction.operationType),
                            size: 14,
                            color: color,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getTranslatedOperationType(transaction.operationType),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: color,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // First line: Accounts and Amount
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.account_circle, size: 14, color: Colors.grey.shade700),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '$creditName → $debitName',
                                  style: const TextStyle(
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
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${NumberFormat('#,##0.00').format(transaction.amount)} ${currencySymbolsMap[transaction.currencyId] ?? transaction.currencyId ?? 'غير محدد'}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: color,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Second line: Date
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('yyyy-MM-dd', 'ar').format(transaction.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
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
    );
  }

  Color _getOperationTypeColor(String operationType) {
    switch (operationType) {
      case 'Receipt':
        return Colors.green;
      case 'Payment':
        return Colors.red;
      case 'Journal':
        return Colors.blue;
      case 'Currency Exchange':
      case 'BuyCurrency':
      case 'SellCurrency':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getOperationTypeIcon(String operationType) {
    switch (operationType) {
      case 'Receipt':
        return Icons.arrow_downward_rounded;
      case 'Payment':
        return Icons.arrow_upward_rounded;
      case 'Journal':
        return Icons.swap_horiz_rounded;
      case 'Currency Exchange':
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

  void _navigateToScreen(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _navigateToTransactionDetails(ts.Transaction transaction) {
    showTransactionDetailsDialog(context, transaction);
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryMaroon,
                  AppColors.primaryMaroon.withOpacity(0.8),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 30,
                  child: Icon(
                    Icons.person,
                    size: 40,
                    color: AppColors.primaryMaroon,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _currentUser?.displayName ?? 'مستخدم',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentUser?.email ?? '',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
          _buildDrawerItem(
            icon: Icons.dashboard_rounded,
            title: 'الرئيسية',
            onTap: () => Navigator.of(context).pop(),
          ),
          _buildDrawerItem(
            icon: Icons.receipt_long_rounded,
            title: 'العمليات',
            onTap: () {
              Navigator.of(context).pop();
              _navigateToScreen(const OperationsScreen());
            },
          ),
          _buildDrawerItem(
            icon: Icons.account_balance_wallet_rounded,
            title: 'الحسابات',
            onTap: () {
              Navigator.of(context).pop();
              _navigateToScreen(const AccountsScreen());
            },
          ),
          _buildDrawerItem(
            icon: Icons.currency_exchange_rounded,
            title: 'العملات',
            onTap: () {
              Navigator.of(context).pop();
              _navigateToScreen(const CurrenciesScreen());
            },
          ),
          _buildDrawerItem(
            icon: Icons.money_rounded,
            title: 'أسعار التحويل',
            onTap: () {
              Navigator.of(context).pop();
              _navigateToScreen(const ExchangeRatesScreen());
            },
          ),
          _buildDrawerItem(
            icon: Icons.account_balance_rounded,
            title: 'الأرصدة',
            onTap: () {
              Navigator.of(context).pop();
              _navigateToScreen(const AccountBalancesScreen());
            },
          ),
          const Divider(),
          _buildDrawerItem(
            icon: Icons.trending_down_rounded,
            title: 'شراء عملة',
            color: Colors.purple,
            onTap: () {
              Navigator.of(context).pop();
              _navigateToScreen(const BuyCurrencyScreen());
            },
          ),
          _buildDrawerItem(
            icon: Icons.trending_up_rounded,
            title: 'بيع عملة',
            color: Colors.orange,
            onTap: () {
              Navigator.of(context).pop();
              _navigateToScreen(const SellCurrencyScreen());
            },
          ),
          _buildDrawerItem(
            icon: Icons.bar_chart_rounded,
            title: 'التقارير',
            onTap: () {
              Navigator.of(context).pop();
              _navigateToScreen(const ReportsScreen());
            },
          ),
          const Divider(),
          _buildDrawerItem(
            icon: Icons.person_rounded,
            title: 'الملف الشخصي',
            onTap: () {
              Navigator.of(context).pop();
              _navigateToScreen(const UserProfileScreen());
            },
          ),
          _buildDrawerItem(
            icon: Icons.logout_rounded,
            title: 'تسجيل الخروج',
            color: Colors.red,
            onTap: () async {
              Navigator.of(context).pop();
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.primaryMaroon),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? Colors.black87,
          fontFamily: 'Cairo',
        ),
      ),
      onTap: onTap,
    );
  }
}

