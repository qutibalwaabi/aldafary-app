import 'package:untitled/core/services/account_service.dart';
import 'package:untitled/core/services/currency_service.dart';
import 'package:untitled/core/services/exchange_rate_service.dart';
import 'package:untitled/services/balance_service.dart';
import 'package:intl/intl.dart';

/// Service to check account balance and credit limit before transactions
class BalanceCheckService {
  final AccountService _accountService = AccountService();
  final CurrencyService _currencyService = CurrencyService();
  final BalanceService _balanceService = BalanceService();
  final ExchangeRateService _exchangeRateService = ExchangeRateService();

  /// Check if account can have negative balance based on credit limit
  /// Returns true if transaction is allowed, throws exception if not
  Future<void> checkAccountBalance({
    required String accountId,
    required String currencyId,
    required double amount, // Positive amount (debit or credit)
    required bool isDebitTransaction, // true for debit, false for credit
  }) async {
    // Get account details
    final account = await _accountService.getAccountById(accountId);
    if (account == null) {
      throw Exception('الحساب غير موجود');
    }

    // Check if account is suspended
    if (account.isSuspended) {
      throw Exception('الحساب موقف ولا يمكن إجراء معاملات عليه');
    }

    // IMPORTANT: Credit limit check ONLY applies to Customer and Vendor accounts
    // Other account types (Cash, Bank, Expense, Revenue) don't have credit limit restrictions
    final isCustomerOrVendor = account.type == 'Customer' || account.type == 'Vendor';
    
    if (!isCustomerOrVendor) {
      // For non-customer/vendor accounts (Cash, Bank, Expense, Revenue), skip credit limit check
      // Only check if balance is sufficient for credit transactions when limit is 0
      if (!isDebitTransaction) {
        final currentBalance = await _getAccountBalanceInCurrency(accountId, currencyId);
        if (currentBalance - amount < 0 && account.creditLimit == 0) {
          throw Exception('الرصيد غير كافٍ. الرصيد الحالي: ${_formatBalance(currentBalance)}');
        }
      }
      return; // Allow transaction for non-customer/vendor accounts
    }

    // For Customer/Vendor accounts only: Check credit limit
    // If credit limit is 0, no credit allowed (only positive balance)
    if (account.creditLimit == 0) {
      // For debit transactions, we add to balance (positive)
      // For credit transactions, we subtract from balance (negative)
      if (isDebitTransaction) {
        // Debit is always allowed (increasing balance)
        return;
      } else {
        // Credit transaction: check current balance
        final currentBalance = await _getAccountBalanceInCurrency(accountId, currencyId);
        if (currentBalance - amount < 0) {
          throw Exception('الرصيد غير كافٍ. الرصيد الحالي: ${_formatBalance(currentBalance)}');
        }
      }
      return;
    }

    // Get current balance for this currency
    final currentBalance = await _getAccountBalanceInCurrency(accountId, currencyId);

    // Get primary currency for credit limit calculation
    final primaryCurrency = await _currencyService.getPrimaryCurrency();
    if (primaryCurrency == null) {
      throw Exception('لا توجد عملة رئيسية محددة');
    }

    // Convert credit limit to current currency if needed
    double creditLimitInCurrency = account.creditLimit;
    if (currencyId != primaryCurrency.id) {
      // Get exchange rate to convert credit limit
      final exchangeRateData = await _exchangeRateService.getExchangeRate(
        fromCurrencyId: primaryCurrency.id,
        toCurrencyId: currencyId,
      );
      
      if (exchangeRateData != null) {
        final basePrice = exchangeRateData['basePrice'] as double;
        // Credit limit in primary currency / exchange rate = credit limit in target currency
        creditLimitInCurrency = account.creditLimit / basePrice;
      } else {
        // If no exchange rate found, cannot convert - use a conservative approach
        throw Exception('لا يوجد سعر تحويل محدد بين العملة الرئيسية والعملة المطلوبة. الرجاء تحديد سعر التحويل أولاً.');
      }
    }

    // Calculate new balance after transaction
    final newBalance = isDebitTransaction 
        ? currentBalance + amount 
        : currentBalance - amount;

    // Check if new balance exceeds credit limit
    // Credit limit applies to negative balance (debit balance)
    // If balance becomes more negative than credit limit, reject
    if (newBalance < -creditLimitInCurrency) {
      final availableCredit = creditLimitInCurrency + (currentBalance < 0 ? -currentBalance : 0);
      throw Exception(
        'تجاوز السقف الائتماني. السقف المصرح: ${_formatBalance(creditLimitInCurrency)}, '
        'الرصيد الحالي: ${_formatBalance(currentBalance)}, '
        'الرصيد المتاح: ${_formatBalance(availableCredit)}'
      );
    }
  }

  /// Get account balance for a specific currency
  Future<double> _getAccountBalanceInCurrency(String accountId, String currencyId) async {
    final accountBalances = await _balanceService.getAllAccountsWithBalances();
    final accountBalance = accountBalances.firstWhere(
      (ab) => ab.accountId == accountId,
      orElse: () => throw Exception('الحساب غير موجود'),
    );

    // Get currency symbol
    final currency = await _currencyService.getCurrencyById(currencyId);
    if (currency == null) {
      throw Exception('العملة غير موجودة');
    }

    return accountBalance.balances[currency.symbol] ?? 0.0;
  }

  String _formatBalance(double balance) {
    return NumberFormat('#,##0.00').format(balance);
  }
}

