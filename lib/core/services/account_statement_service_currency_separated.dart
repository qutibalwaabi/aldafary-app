import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class StatementRowWithCurrency {
  final DateTime date;
  final String description;
  final double debit;
  final double credit;
  final double balance;
  final String? transactionId;
  final String operationType;
  final String currencyId;
  final String currencySymbol;

  StatementRowWithCurrency({
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
    this.transactionId,
    required this.operationType,
    required this.currencyId,
    required this.currencySymbol,
  });
}

class AccountStatementByCurrency {
  final String currencyId;
  final String currencySymbol;
  final List<StatementRowWithCurrency> rows;
  final double openingBalance;
  final double closingBalance;
  final double totalDebit;
  final double totalCredit;

  AccountStatementByCurrency({
    required this.currencyId,
    required this.currencySymbol,
    required this.rows,
    required this.openingBalance,
    required this.closingBalance,
    required this.totalDebit,
    required this.totalCredit,
  });
}

class AccountStatementServiceCurrencySeparated {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Get account statement separated by currency
  Future<Map<String, AccountStatementByCurrency>> getAccountStatementByCurrency({
    required String accountId,
    DateTime? startDate,
    DateTime? endDate,
    String? selectedCurrencyId, // If provided, only return this currency
  }) async {
    if (_currentUser == null) throw Exception('User not logged in');

    // Get all currencies
    final currenciesSnapshot = await _firestore
        .collection('currencies')
        .where('userId', isEqualTo: _currentUser!.uid)
        .get();

    final currencyIdToSymbol = <String, String>{};
    for (var doc in currenciesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      currencyIdToSymbol[doc.id] = data['symbol'] ?? '';
    }

    // Get all transactions for this account
    final debitQuery = _firestore
        .collection('transactions')
        .where('userId', isEqualTo: _currentUser!.uid)
        .where('debitAccountId', isEqualTo: accountId)
        .orderBy('date');

    final creditQuery = _firestore
        .collection('transactions')
        .where('userId', isEqualTo: _currentUser!.uid)
        .where('creditAccountId', isEqualTo: accountId)
        .orderBy('date');

    final debitSnapshot = await debitQuery.get();
    final creditSnapshot = await creditQuery.get();

    // Combine and sort all transactions by date
    final allTransactions = <Map<String, dynamic>>[];
    allTransactions.addAll(debitSnapshot.docs.map((doc) => {
      ...doc.data() as Map<String, dynamic>,
      'type': 'debit',
      'id': doc.id,
    }));
    allTransactions.addAll(creditSnapshot.docs.map((doc) => {
      ...doc.data() as Map<String, dynamic>,
      'type': 'credit',
      'id': doc.id,
    }));
    allTransactions.sort((a, b) => (a['date'] as Timestamp).compareTo(b['date'] as Timestamp));

    // Group transactions by currency and calculate balances
    final statementsByCurrency = <String, List<StatementRowWithCurrency>>{};
    final openingBalancesByCurrency = <String, double>{};
    final closingBalancesByCurrency = <String, double>{};
    final totalDebitByCurrency = <String, double>{};
    final totalCreditByCurrency = <String, double>{};

    // Calculate opening balances (before start date)
    if (startDate != null) {
      for (var transaction in allTransactions) {
        final date = (transaction['date'] as Timestamp).toDate();
        if (date.isBefore(startDate)) {
          final currencyId = transaction['currencyId'] as String?;
          if (currencyId == null) continue;
          
          final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
          final isDebit = transaction['type'] == 'debit';
          
          if (selectedCurrencyId == null || currencyId == selectedCurrencyId) {
            openingBalancesByCurrency[currencyId] = 
                (openingBalancesByCurrency[currencyId] ?? 0.0) + 
                (isDebit ? amount : -amount);
          }
        }
      }
    }

    // Process transactions and group by currency
    for (var transaction in allTransactions) {
      final date = (transaction['date'] as Timestamp).toDate();
      final currencyId = transaction['currencyId'] as String?;
      
      if (currencyId == null) continue;
      
      // Filter by selected currency if provided
      if (selectedCurrencyId != null && currencyId != selectedCurrencyId) continue;
      
      // Apply date filters
      if (startDate != null && date.isBefore(startDate)) continue;
      if (endDate != null) {
        final endDateWithTime = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        if (date.isAfter(endDateWithTime)) continue;
      }

      if (!statementsByCurrency.containsKey(currencyId)) {
        statementsByCurrency[currencyId] = [];
      }

      final description = transaction['description'] as String? ?? '';
      final operationType = transaction['operationType'] as String? ?? 'Unknown';
      final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
      final isDebit = transaction['type'] == 'debit';
      
      final debit = isDebit ? amount : 0.0;
      final credit = !isDebit ? amount : 0.0;

      // Calculate running balance for this currency
      final existingRows = statementsByCurrency[currencyId]!;
      final previousBalance = existingRows.isEmpty 
          ? (openingBalancesByCurrency[currencyId] ?? 0.0)
          : existingRows.last.balance;
      final newBalance = previousBalance + debit - credit;

      // Update totals
      totalDebitByCurrency[currencyId] = (totalDebitByCurrency[currencyId] ?? 0.0) + debit;
      totalCreditByCurrency[currencyId] = (totalCreditByCurrency[currencyId] ?? 0.0) + credit;

      statementsByCurrency[currencyId]!.add(StatementRowWithCurrency(
        date: date,
        description: description,
        debit: debit,
        credit: credit,
        balance: newBalance,
        transactionId: transaction['id'] as String?,
        operationType: operationType,
        currencyId: currencyId,
        currencySymbol: currencyIdToSymbol[currencyId] ?? currencyId,
      ));

      // Update closing balance
      closingBalancesByCurrency[currencyId] = newBalance;
    }

    // Build result map
    final result = <String, AccountStatementByCurrency>{};
    for (var currencyId in statementsByCurrency.keys) {
      result[currencyId] = AccountStatementByCurrency(
        currencyId: currencyId,
        currencySymbol: currencyIdToSymbol[currencyId] ?? currencyId,
        rows: statementsByCurrency[currencyId]!,
        openingBalance: openingBalancesByCurrency[currencyId] ?? 0.0,
        closingBalance: closingBalancesByCurrency[currencyId] ?? 0.0,
        totalDebit: totalDebitByCurrency[currencyId] ?? 0.0,
        totalCredit: totalCreditByCurrency[currencyId] ?? 0.0,
      );
    }

    return result;
  }
}

