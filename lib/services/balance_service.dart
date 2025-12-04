
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountBalance {
  final String accountId;
  final String accountName;
  final String accountType;
  final Map<String, double> balances; // Key: currencySymbol, Value: balance

  AccountBalance({
    required this.accountId,
    required this.accountName,
    required this.accountType,
    required this.balances,
  });
}

class BalanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // This is the NEW, correct engine for calculating balances.
  Future<List<AccountBalance>> getAllAccountsWithBalances() async {
    if (_currentUser == null) throw Exception('User not logged in');

    // 1. Fetch all necessary data in parallel.
    final accountsFuture = _firestore.collection('accounts').where('userId', isEqualTo: _currentUser!.uid).get();
    final currenciesFuture = _firestore.collection('currencies').where('userId', isEqualTo: _currentUser!.uid).get();
    
    final accountIds = (await accountsFuture).docs.map((d) => d.id).toList();
    
    if (accountIds.isEmpty) {
      return [];
    }

    // Fetch transactions where the user is either on the debit or credit side.
    // Firestore does not support OR queries, so we do two separate queries.
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
    
    final debitTransactionsFuture = Future.value(allDebitTransactions);
    final creditTransactionsFuture = Future.value(allCreditTransactions);

    final results = await Future.wait([accountsFuture, currenciesFuture, debitTransactionsFuture, creditTransactionsFuture]);

    final accountsSnapshot = results[0] as QuerySnapshot;
    final currenciesSnapshot = results[1] as QuerySnapshot;
    final debitTransactions = results[2] as List<QueryDocumentSnapshot>;
    final creditTransactions = results[3] as List<QueryDocumentSnapshot>;

    // 2. Prepare data for easy lookup.
    final Map<String, String> currencyIdToSymbol = {
      for (var doc in currenciesSnapshot.docs) doc.id: (doc.data() as Map<String, dynamic>)['symbol'] ?? ''
    };
    
    final Map<String, AccountBalance> accountsBalances = {
      for (var doc in accountsSnapshot.docs) 
        doc.id: AccountBalance(
          accountId: doc.id,
          accountName: (doc.data() as Map<String, dynamic>)['name'] ?? '',
          accountType: (doc.data() as Map<String, dynamic>)['type'] ?? '',
          balances: {},
        )
    };

    // 3. Process all debit transactions.
    for (var txDoc in debitTransactions) {
      final tx = txDoc.data() as Map<String, dynamic>;
      final debitAccountId = tx['debitAccountId'];
      final creditAccountId = tx['creditAccountId'];
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      final currencyId = tx['currencyId'];
      final currencySymbol = currencyId != null ? (currencyIdToSymbol[currencyId] ?? currencyId) : 'UNK';

      // Add to debit account
      if (debitAccountId != null && accountsBalances.containsKey(debitAccountId)) {
        accountsBalances[debitAccountId]!.balances.update(currencySymbol, (value) => value + amount, ifAbsent: () => amount);
      }

      // Subtract from credit account
      if (creditAccountId != null && accountsBalances.containsKey(creditAccountId)) {
        accountsBalances[creditAccountId]!.balances.update(currencySymbol, (value) => value - amount, ifAbsent: () => -amount);
      }
    }

    // 4. Process all credit transactions (same logic as debit)
    for (var txDoc in creditTransactions) {
      final tx = txDoc.data() as Map<String, dynamic>;
      final debitAccountId = tx['debitAccountId'];
      final creditAccountId = tx['creditAccountId'];
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      final currencyId = tx['currencyId'];
      final currencySymbol = currencyId != null ? (currencyIdToSymbol[currencyId] ?? currencyId) : 'UNK';

      // Add to debit account
      if (debitAccountId != null && accountsBalances.containsKey(debitAccountId)) {
        accountsBalances[debitAccountId]!.balances.update(currencySymbol, (value) => value + amount, ifAbsent: () => amount);
      }

      // Subtract from credit account
      if (creditAccountId != null && accountsBalances.containsKey(creditAccountId)) {
        accountsBalances[creditAccountId]!.balances.update(currencySymbol, (value) => value - amount, ifAbsent: () => -amount);
      }
    }

    return accountsBalances.values.toList();
  }
}
