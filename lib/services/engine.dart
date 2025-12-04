import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FinancialEngineService {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  // Get all accounts with their balances
  Future<List<AccountBalance>> getAllAccountsWithBalances() async {
    if (_currentUser == null) throw Exception('User not logged in');

    // Get all accounts for the current user
    final accountsSnapshot = await _firestore
        .collection('accounts')
        .where('userId', isEqualTo: _currentUser!.uid)
        .get();

    final accounts = accountsSnapshot.docs.map((doc) {
      return {
        'id': doc.id,
        'name': doc['name'],
        'type': doc['type'],
      };
    }).toList();

    // Get all transactions for these accounts
    final accountIds = accounts.map((a) => a['id'] as String).toList();

    final debitTransactionsFuture = _firestore.collection('transactions')
        .where('debitAccountId', whereIn: accountIds)
        .get();

    final creditTransactionsFuture = _firestore.collection('transactions')
        .where('creditAccountId', whereIn: accountIds)
        .get();

    final results = await Future.wait([debitTransactionsFuture, creditTransactionsFuture]);
    final debitTransactions = results[0].docs;
    final creditTransactions = results[1].docs;

    // Calculate balances for each account
    final balances = <String, double>{};

    // Initialize all accounts with zero balance
    for (final account in accounts) {
      balances[account['id'] as String] = 0.0;
    }

    // Add debit amounts
    for (final doc in debitTransactions) {
      final accountId = doc['debitAccountId'] as String;
      final amount = (doc['amount'] as num).toDouble();
      balances[accountId] = (balances[accountId] ?? 0.0) + amount;
    }

    // Subtract credit amounts
    for (final doc in creditTransactions) {
      final accountId = doc['creditAccountId'] as String;
      final amount = (doc['amount'] as num).toDouble();
      balances[accountId] = (balances[accountId] ?? 0.0) - amount;
    }

    // Create result list
    final result = accounts.map((account) {
      final accountId = account['id'] as String;
      return AccountBalance(
        id: accountId,
        name: account['name'] as String,
        type: account['type'] as String,
        balance: balances[accountId] ?? 0.0,
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