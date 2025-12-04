import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TransactionSerialService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Get next serial number for a specific operation type
  Future<int> getNextSerialNumber(String operationType) async {
    if (_currentUser == null) throw Exception('User not logged in');

    final counterRef = _firestore
        .collection('transaction_counters')
        .doc('${_currentUser!.uid}_$operationType');

    // Use transaction to ensure atomic increment
    return await _firestore.runTransaction((transaction) async {
      final counterDoc = await transaction.get(counterRef);
      
      int currentCount = 0;
      if (counterDoc.exists) {
        currentCount = (counterDoc.data()?['count'] ?? 0) as int;
      }
      
      final newCount = currentCount + 1;
      transaction.set(counterRef, {
        'userId': _currentUser!.uid,
        'operationType': operationType,
        'count': newCount,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      return newCount;
    });
  }

  // Get current serial number (without incrementing)
  Future<int> getCurrentSerialNumber(String operationType) async {
    if (_currentUser == null) return 0;

    final counterDoc = await _firestore
        .collection('transaction_counters')
        .doc('${_currentUser!.uid}_$operationType')
        .get();

    if (!counterDoc.exists) return 0;
    return (counterDoc.data()?['count'] ?? 0) as int;
  }

  // Format serial number based on operation type
  static String formatSerialNumber(String operationType, int serialNumber) {
    String prefix;
    switch (operationType) {
      case 'Receipt':
        prefix = 'RCV';
        break;
      case 'Payment':
        prefix = 'PAY';
        break;
      case 'Journal':
        prefix = 'JRN';
        break;
      case 'BuyCurrency':
        prefix = 'BCY';
        break;
      case 'SellCurrency':
        prefix = 'SCY';
        break;
      default:
        prefix = 'TXN';
    }
    
    // Format: PREFIX-YYYY-000001
    final year = DateTime.now().year;
    return '$prefix-$year-${serialNumber.toString().padLeft(6, '0')}';
  }
}

