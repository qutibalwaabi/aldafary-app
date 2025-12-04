import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class StatementRow {
  final DateTime date;
  final String description;
  final double debit;
  final double credit;
  final double balance;
  final String? transactionId;
  final String operationType;

  StatementRow({
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
    this.transactionId,
    required this.operationType,
  });
}

class AccountStatementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Get account statement for a specific account
  Future<List<StatementRow>> getAccountStatement({
    required String accountId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_currentUser == null) throw Exception('User not logged in');

    // Get all transactions for this account (both debit and credit)
    // Note: Firestore requires an index for multiple where clauses with orderBy
    // We'll fetch all and filter in memory for date ranges
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
      ...doc.data(),
      'type': 'debit',
      'id': doc.id,
    }));
    allTransactions.addAll(creditSnapshot.docs.map((doc) => {
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
      
      // Apply date filters if provided
      if (startDate != null && date.isBefore(startDate)) continue;
      if (endDate != null) {
        final endDateWithTime = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        if (date.isAfter(endDateWithTime)) continue;
      }
      
      final description = transaction['description'] as String? ?? '';
      final operationType = transaction['operationType'] as String? ?? 'Unknown';
      final amount = transaction['amount'];
      final debit = transaction['type'] == 'debit' 
          ? (amount != null ? (amount as num).toDouble() : 0.0)
          : 0.0;
      final credit = transaction['type'] == 'credit' 
          ? (amount != null ? (amount as num).toDouble() : 0.0)
          : 0.0;

      runningBalance = runningBalance + debit - credit;

      statement.add(StatementRow(
        date: date,
        description: description,
        debit: debit,
        credit: credit,
        balance: runningBalance,
        transactionId: transaction['id'] as String?,
        operationType: operationType,
      ));
    }

    return statement;
  }
}

