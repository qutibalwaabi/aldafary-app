import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FinancialEngineService {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a journal transaction
  Future<String> createJournalTransaction({
    required String debitAccountId,
    required String creditAccountId,
    required double amount,
    required String currencyId,
    required String description,
    DateTime? date,
  }) async {
    if (_currentUser == null) throw Exception('User not logged in');

    final doc = await _firestore.collection('transactions').add({
      'userId': _currentUser!.uid,
      'operationType': 'Journal',
      'debitAccountId': debitAccountId,
      'creditAccountId': creditAccountId,
      'amount': amount,
      'currencyId': currencyId,
      'description': description,
      'date': date != null ? Timestamp.fromDate(date) : Timestamp.now(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  // Get account statement for a specific account
  Future<List<StatementRow>> getAccountStatement({
    required String accountId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_currentUser == null) throw Exception('User not logged in');

    // Get all transactions for this account (both debit and credit)
    final debitTransactions = await _firestore
        .collection('transactions')
        .where('debitAccountId', isEqualTo: accountId)
        .orderBy('date')
        .get();

    final creditTransactions = await _firestore
        .collection('transactions')
        .where('creditAccountId', isEqualTo: accountId)
        .orderBy('date')
        .get();

    // Combine and sort all transactions by date
    final allTransactions = <Map<String, dynamic>>[];
    allTransactions.addAll(debitTransactions.docs.map((doc) => {
      ...doc.data(),
      'type': 'debit',
      'id': doc.id,
    }));
    allTransactions.addAll(creditTransactions.docs.map((doc) => {
      ...doc.data(),
      'type': 'credit',
      'id': doc.id,
    }));
    allTransactions.sort((a, b) => (a['date'] as Timestamp).compareTo(b['date'] as Timestamp));

    // Generate statement with running balance
    double runningBalance = 0.0;
    final statement = <StatementRow>[];

    for (final transaction in allTransactions) {
      final date = (transaction['date'] as Timestamp).toDate();
      final description = transaction['description'] as String;
      final debit = transaction['type'] == 'debit' 
          ? (transaction['amount'] as num).toDouble() 
          : 0.0;
      final credit = transaction['type'] == 'credit' 
          ? (transaction['amount'] as num).toDouble() 
          : 0.0;

      // Apply date filters if provided
      if (startDate != null && date.isBefore(startDate)) continue;
      if (endDate != null && date.isAfter(endDate)) continue;

      runningBalance = runningBalance + debit - credit;

      statement.add(StatementRow(
        date: date,
        description: description,
        debit: debit,
        credit: credit,
        balance: runningBalance,
      ));
    }

    return statement;
  }

  // Get all accounts with their balances (separated by currency)
  Future<List<AccountBalance>> getAllAccountsWithBalances() async {
    if (_currentUser == null) throw Exception('User not logged in');

    // Get all accounts for the current user
    final accountsSnapshot = await _firestore
        .collection('accounts')
        .where('userId', isEqualTo: _currentUser!.uid)
        .get();

    // Get all currencies
    final currenciesSnapshot = await _firestore
        .collection('currencies')
        .where('userId', isEqualTo: _currentUser!.uid)
        .get();

    // Create currency ID to symbol map
    final Map<String, String> currencyIdToSymbol = {};
    for (var doc in currenciesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      currencyIdToSymbol[doc.id] = data['symbol'] ?? '';
    }

    final accounts = accountsSnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'name': data['name'] ?? '',
        'type': data['type'] ?? '',
      };
    }).toList();

    // Get all transactions for these accounts
    final accountIds = accounts.map((a) => a['id'] as String).toList();
    
    if (accountIds.isEmpty) {
      return [];
    }

    // Handle Firestore limit of 10 items in whereIn
    List<QueryDocumentSnapshot> allDebitTransactions = [];
    List<QueryDocumentSnapshot> allCreditTransactions = [];
    
    for (int i = 0; i < accountIds.length; i += 10) {
      final batch = accountIds.skip(i).take(10).toList();
      
      final debitBatch = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: _currentUser!.uid)
          .where('debitAccountId', whereIn: batch)
          .get();
      
      final creditBatch = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: _currentUser!.uid)
          .where('creditAccountId', whereIn: batch)
          .get();
      
      allDebitTransactions.addAll(debitBatch.docs);
      allCreditTransactions.addAll(creditBatch.docs);
    }

    // Calculate balances for each account, separated by currency
    // Map<accountId, Map<currencySymbol, balance>>
    final balancesByCurrency = <String, Map<String, double>>{};

    // Initialize all accounts with empty balance maps
    for (final account in accounts) {
      balancesByCurrency[account['id'] as String] = {};
    }

    // Process debit transactions - add to debit account, subtract from credit account
    for (final doc in allDebitTransactions) {
      final data = doc.data() as Map<String, dynamic>;
      final debitAccountId = data['debitAccountId'] as String?;
      final creditAccountId = data['creditAccountId'] as String?;
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final currencyId = data['currencyId'] as String?;
      
      if (currencyId == null) continue;
      
      final currencySymbol = currencyIdToSymbol[currencyId] ?? currencyId;

      // Add to debit account
      if (debitAccountId != null && balancesByCurrency.containsKey(debitAccountId)) {
        balancesByCurrency[debitAccountId]!.update(
          currencySymbol,
          (value) => value + amount,
          ifAbsent: () => amount,
        );
      }

      // Subtract from credit account
      if (creditAccountId != null && balancesByCurrency.containsKey(creditAccountId)) {
        balancesByCurrency[creditAccountId]!.update(
          currencySymbol,
          (value) => value - amount,
          ifAbsent: () => -amount,
        );
      }
    }

    // Process credit transactions - same logic
    for (final doc in allCreditTransactions) {
      final data = doc.data() as Map<String, dynamic>;
      final debitAccountId = data['debitAccountId'] as String?;
      final creditAccountId = data['creditAccountId'] as String?;
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final currencyId = data['currencyId'] as String?;
      
      if (currencyId == null) continue;
      
      final currencySymbol = currencyIdToSymbol[currencyId] ?? currencyId;

      // Add to debit account
      if (debitAccountId != null && balancesByCurrency.containsKey(debitAccountId)) {
        balancesByCurrency[debitAccountId]!.update(
          currencySymbol,
          (value) => value + amount,
          ifAbsent: () => amount,
        );
      }

      // Subtract from credit account
      if (creditAccountId != null && balancesByCurrency.containsKey(creditAccountId)) {
        balancesByCurrency[creditAccountId]!.update(
          currencySymbol,
          (value) => value - amount,
          ifAbsent: () => -amount,
        );
      }
    }

    // Create result list - for backward compatibility, sum all currencies
    // TODO: Update AccountBalance model to support per-currency balances
    final result = accounts.map((account) {
      final accountId = account['id'] as String;
      final currencyBalances = balancesByCurrency[accountId] ?? {};
      
      // Calculate total balance (sum of all currencies) for backward compatibility
      final totalBalance = currencyBalances.values.fold(0.0, (sum, balance) => sum + balance);
      
      return AccountBalance(
        id: accountId,
        name: account['name'] as String,
        type: account['type'] as String,
        balance: totalBalance,
      );
    }).toList();

    return result;
  }

  // Add exchange rate
  Future<void> addExchangeRate({
    required String fromCurrencyId,
    required String toCurrencyId,
    required double rate,
  }) async {
    if (_currentUser == null) throw Exception('User not logged in');

    final rateId = '${fromCurrencyId}_${toCurrencyId}';

    await _firestore.collection('exchange_rates').doc(rateId).set({
      'fromCurrencyId': fromCurrencyId,
      'toCurrencyId': toCurrencyId,
      'rate': rate,
      'userId': _currentUser!.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Get exchange rate
  Future<double?> getExchangeRate({
    required String fromCurrencyId,
    required String toCurrencyId,
  }) async {
    if (_currentUser == null) throw Exception('User not logged in');

    final rateId = '${fromCurrencyId}_${toCurrencyId}';
    final doc = await _firestore.collection('exchange_rates').doc(rateId).get();

    if (!doc.exists) return null;
    return doc['rate'] as double?;
  }

  // Get all exchange rates
  Future<List<Map<String, dynamic>>> getAllExchangeRates() async {
    if (_currentUser == null) throw Exception('User not logged in');

    final snapshot = await _firestore
        .collection('exchange_rates')
        .where('userId', isEqualTo: _currentUser!.uid)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // Delete exchange rate
  Future<void> deleteExchangeRate({
    required String fromCurrencyId,
    required String toCurrencyId,
  }) async {
    if (_currentUser == null) throw Exception('User not logged in');

    final rateId = '${fromCurrencyId}_${toCurrencyId}';

    await _firestore.collection('exchange_rates').doc(rateId).delete();
  }
}

// Statement row model
class StatementRow {
  final DateTime date;
  final String description;
  final double debit;
  final double credit;
  final double balance;

  StatementRow({
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
  });
}

// Account balance model
class AccountBalance {
  final String id;
  final String name;
  final String type;
  final double balance;

  AccountBalance({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
  });
}