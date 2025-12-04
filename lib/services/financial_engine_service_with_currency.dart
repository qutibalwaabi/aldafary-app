import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Account balance model with per-currency balances
class AccountBalanceWithCurrency {
  final String id;
  final String name;
  final String type;
  final Map<String, double> balancesByCurrency; // Key: currencySymbol, Value: balance

  AccountBalanceWithCurrency({
    required this.id,
    required this.name,
    required this.type,
    required this.balancesByCurrency,
  });
}

class FinancialEngineServiceWithCurrency {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all accounts with their balances separated by currency
  Future<List<AccountBalanceWithCurrency>> getAllAccountsWithBalances() async {
    if (_currentUser == null) throw Exception('User not logged in');

    // Get all accounts
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

    // Process debit transactions
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

    // Process credit transactions (same as above, but reverse)
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

    // Handle currency exchange transactions (BuyCurrency/SellCurrency)
    final exchangeTransactions = await _firestore
        .collection('transactions')
        .where('userId', isEqualTo: _currentUser!.uid)
        .where('operationType', whereIn: ['BuyCurrency', 'SellCurrency'])
        .get();

    for (final doc in exchangeTransactions.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final operationType = data['operationType'] as String?;
      final fromCurrencyId = data['fromCurrencyId'] as String?;
      final toCurrencyId = data['toCurrencyId'] as String?;
      final fromAmount = (data['fromAmount'] as num?)?.toDouble() ?? 0.0;
      final toAmount = (data['toAmount'] as num?)?.toDouble() ?? 0.0;
      
      if (fromCurrencyId == null || toCurrencyId == null) continue;
      
      final fromCurrencySymbol = currencyIdToSymbol[fromCurrencyId] ?? fromCurrencyId;
      final toCurrencySymbol = currencyIdToSymbol[toCurrencyId] ?? toCurrencyId;
      
      // For BuyCurrency/SellCurrency, we need to determine which accounts are affected
      // This depends on how you structure these transactions in your system
      // For now, we'll skip currency exchange transactions in balance calculation
      // They should be handled separately or with specific account mappings
    }

    // Create result list
    final result = accounts.map((account) {
      final accountId = account['id'] as String;
      final balances = balancesByCurrency[accountId] ?? {};
      
      return AccountBalanceWithCurrency(
        id: accountId,
        name: account['name'] as String,
        type: account['type'] as String,
        balancesByCurrency: balances,
      );
    }).toList();

    return result;
  }
}

