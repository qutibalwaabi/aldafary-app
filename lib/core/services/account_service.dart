import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:untitled/core/models/account_model.dart';

class AccountService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Get all accounts for current user (excluding suspended)
  Stream<List<AccountModel>> streamAccounts({bool includeSuspended = false}) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('AccountService: No current user');
      return Stream.value([]);
    }

    debugPrint('AccountService: Querying accounts for userId: ${currentUser.uid}');

    // First, try to get all accounts without filter to check if any exist
    return _firestore
        .collection('accounts')
        .where('userId', isEqualTo: currentUser.uid)
        .snapshots()
        .asyncMap((snapshot) async {
          debugPrint('AccountService: Firestore returned ${snapshot.docs.length} documents');
          
          // If no accounts found, check if accounts exist with empty/null userId (fix old data)
          if (snapshot.docs.isEmpty) {
            debugPrint('AccountService: No accounts found with userId=${currentUser.uid}, checking for accounts with empty userId...');
            final allAccountsSnapshot = await _firestore
                .collection('accounts')
                .where('userId', isEqualTo: '')
                .limit(10)
                .get();
            
            if (allAccountsSnapshot.docs.isNotEmpty) {
              debugPrint('AccountService: Found ${allAccountsSnapshot.docs.length} accounts with empty userId - these need to be fixed!');
              // Fix accounts with empty userId
              final batch = _firestore.batch();
              for (var doc in allAccountsSnapshot.docs) {
                batch.update(doc.reference, {'userId': currentUser.uid});
              }
              await batch.commit();
              debugPrint('AccountService: Fixed ${allAccountsSnapshot.docs.length} accounts with empty userId');
              
              // Get accounts again after fix
              final fixedSnapshot = await _firestore
                  .collection('accounts')
                  .where('userId', isEqualTo: currentUser.uid)
                  .get();
              
              final fixedAccounts = fixedSnapshot.docs.map((doc) {
                try {
                  return AccountModel.fromFirestore(doc);
                } catch (e) {
                  debugPrint('AccountService: Error parsing account ${doc.id}: $e');
                  return null;
                }
              }).whereType<AccountModel>().toList();
              
              // Apply filters
              var filteredAccounts = fixedAccounts;
              if (!includeSuspended) {
                filteredAccounts = filteredAccounts.where((a) => !a.isSuspended).toList();
              }
              filteredAccounts.sort((a, b) => a.name.compareTo(b.name));
              
              return filteredAccounts;
            }
          }
          
          var accounts = snapshot.docs.map((doc) {
            try {
              final data = doc.data();
              debugPrint('AccountService: Account ${doc.id}: name=${data['name']}, isSuspended=${data['isSuspended'] ?? false}, userId=${data['userId']}');
              return AccountModel.fromFirestore(doc);
            } catch (e) {
              debugPrint('AccountService: Error parsing account ${doc.id}: $e');
              return null;
            }
          }).whereType<AccountModel>().toList();
          
          debugPrint('AccountService: Loaded ${accounts.length} accounts (before filter)');
          
          // Filter suspended accounts in memory
          if (!includeSuspended) {
            final beforeCount = accounts.length;
            accounts = accounts.where((a) => !a.isSuspended).toList();
            debugPrint('AccountService: Filtered ${beforeCount - accounts.length} suspended accounts');
          }
          
          // Sort by name in memory
          accounts.sort((a, b) => a.name.compareTo(b.name));
          
          debugPrint('AccountService: Returning ${accounts.length} accounts');
          if (accounts.isEmpty) {
            debugPrint('AccountService: WARNING - No accounts found! Check Firestore for userId: ${currentUser.uid}');
          }
          return accounts;
        });
  }

  // Get all accounts including suspended (for admin screens)
  Stream<List<AccountModel>> streamAllAccounts() {
    return streamAccounts(includeSuspended: true);
  }

  // Get account by ID
  Future<AccountModel?> getAccountById(String accountId) async {
    if (_currentUser == null) return null;

    final doc = await _firestore.collection('accounts').doc(accountId).get();
    if (!doc.exists) return null;

    final account = AccountModel.fromFirestore(doc);
    if (account.userId != _currentUser!.uid) return null;

    return account;
  }

  // Create account
  Future<String> createAccount(AccountModel account) async {
    if (_currentUser == null) throw Exception('User not logged in');

    final accountData = account.copyWith(
      userId: _currentUser!.uid,
      createdAt: DateTime.now(),
    ).toFirestore();

    final docRef = await _firestore.collection('accounts').add(accountData);
    return docRef.id;
  }

  // Update account
  Future<void> updateAccount(String accountId, AccountModel account) async {
    if (_currentUser == null) throw Exception('User not logged in');

    // Verify ownership
    final existingAccount = await getAccountById(accountId);
    if (existingAccount == null) {
      throw Exception('Account not found or access denied');
    }

    final updateData = account.copyWith(
      userId: _currentUser!.uid, // Ensure userId is set correctly
      lastModified: DateTime.now(),
    ).toFirestore();

    await _firestore.collection('accounts').doc(accountId).update(updateData);
  }

  // Check if account is used in transactions
  Future<bool> isAccountUsed(String accountId) async {
    if (_currentUser == null) return false;

    // Check debit transactions
    final debitQuery = await _firestore
        .collection('transactions')
        .where('userId', isEqualTo: _currentUser!.uid)
        .where('debitAccountId', isEqualTo: accountId)
        .limit(1)
        .get();

    if (debitQuery.docs.isNotEmpty) return true;

    // Check credit transactions
    final creditQuery = await _firestore
        .collection('transactions')
        .where('userId', isEqualTo: _currentUser!.uid)
        .where('creditAccountId', isEqualTo: accountId)
        .limit(1)
        .get();

    return creditQuery.docs.isNotEmpty;
  }

  // Delete account (only if not used)
  Future<void> deleteAccount(String accountId) async {
    if (_currentUser == null) throw Exception('User not logged in');

    // Verify ownership
    final account = await getAccountById(accountId);
    if (account == null) {
      throw Exception('Account not found or access denied');
    }

    // Check if account is used
    final isUsed = await isAccountUsed(accountId);
    if (isUsed) {
      throw Exception('لا يمكن حذف الحساب لأنه مستخدم في معاملات مالية');
    }

    await _firestore.collection('accounts').doc(accountId).delete();
  }

  // Get account balance
  Future<double> getAccountBalance(String accountId) async {
    if (_currentUser == null) return 0.0;

    // Get all transactions for this account
    final debitTransactions = await _firestore
        .collection('transactions')
        .where('userId', isEqualTo: _currentUser!.uid)
        .where('debitAccountId', isEqualTo: accountId)
        .get();

    final creditTransactions = await _firestore
        .collection('transactions')
        .where('userId', isEqualTo: _currentUser!.uid)
        .where('creditAccountId', isEqualTo: accountId)
        .get();

    double balance = 0.0;

    // Add debit amounts
    for (var doc in debitTransactions.docs) {
      balance += (doc.data()['amount'] ?? 0.0).toDouble();
    }

    // Subtract credit amounts
    for (var doc in creditTransactions.docs) {
      balance -= (doc.data()['amount'] ?? 0.0).toDouble();
    }

    return balance;
  }
}

