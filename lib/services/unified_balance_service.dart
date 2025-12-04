import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UnifiedBalanceService {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream all account balances
  Stream<Map<String, double>> streamAllAccountBalances() {
    if (_currentUser == null) return Stream.value({});

    return _firestore
        .collection('account_balances')
        .where('userId', isEqualTo: _currentUser!.uid)
        .snapshots()
        .map((snapshot) {
          final balances = <String, double>{};
          for (final doc in snapshot.docs) {
            balances[doc.id] = (doc.data()['balance'] ?? 0).toDouble();
          }
          return balances;
        });
  }

  // Get balance for a specific account
  Future<double> getAccountBalance(String accountId) async {
    if (_currentUser == null) return 0.0;

    final doc = await _firestore
        .collection('account_balances')
        .doc(accountId)
        .get();

    if (!doc.exists) return 0.0;

    return (doc.data()?['balance'] ?? 0).toDouble();
  }

  // Update account balance
  Future<void> updateAccountBalance({
    required String accountId,
    required double newBalance,
  }) async {
    if (_currentUser == null) throw Exception('User not logged in');

    await _firestore
        .collection('account_balances')
        .doc(accountId)
        .set({
          'userId': _currentUser!.uid,
          'balance': newBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  // Add to account balance
  Future<void> addToAccountBalance({
    required String accountId,
    required double amount,
  }) async {
    final currentBalance = await getAccountBalance(accountId);
    await updateAccountBalance(
      accountId: accountId,
      newBalance: currentBalance + amount,
    );
  }

  // Subtract from account balance
  Future<void> subtractFromAccountBalance({
    required String accountId,
    required double amount,
  }) async {
    final currentBalance = await getAccountBalance(accountId);
    await updateAccountBalance(
      accountId: accountId,
      newBalance: currentBalance - amount,
    );
  }
}