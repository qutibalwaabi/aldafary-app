import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:untitled/core/models/exchange_rate_model.dart';

class ExchangeRateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Get all exchange rates for current user
  Stream<List<Map<String, dynamic>>> streamExchangeRates() {
    if (_currentUser == null) return Stream.value([]);

    return _firestore
        .collection('exchange_rates')
        .where('userId', isEqualTo: _currentUser!.uid)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
              final data = doc.data();
            return <String, dynamic>{
                'id': doc.id,
                ...data,
              };
          }).toList();
        });
  }

  // Get all exchange rates as ExchangeRateModel
  Stream<List<ExchangeRateModel>> streamExchangeRatesAsModels() {
    if (_currentUser == null) return Stream.value([]);

    return _firestore
        .collection('exchange_rates')
        .where('userId', isEqualTo: _currentUser!.uid)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => ExchangeRateModel.fromFirestore(doc)).toList();
        });
  }

  // Check if exchange rate exists
  Future<bool> exchangeRateExists({
    required String fromCurrencyId,
    required String toCurrencyId,
  }) async {
    if (_currentUser == null) return false;

    if (fromCurrencyId == toCurrencyId) {
      return true; // Same currency, no need for exchange rate
    }

    final rateId = '${fromCurrencyId}_${toCurrencyId}';
    final doc = await _firestore.collection('exchange_rates').doc(rateId).get();
    
    if (!doc.exists) return false;
    
    // Check if it belongs to current user
    return doc.data()?['userId'] == _currentUser!.uid;
  }

  // Get exchange rate (returns Map with basePrice, maxPrice, minPrice)
  Future<Map<String, dynamic>?> getExchangeRate({
    required String fromCurrencyId,
    required String toCurrencyId,
  }) async {
    if (_currentUser == null) return null;

    if (fromCurrencyId == toCurrencyId) {
      return {
        'basePrice': 1.0,
        'maxPrice': 1.0,
        'minPrice': 1.0,
      };
    }

    final rateId = '${fromCurrencyId}_${toCurrencyId}';
    final doc = await _firestore.collection('exchange_rates').doc(rateId).get();

    if (!doc.exists) return null;
    if (doc.data()?['userId'] != _currentUser!.uid) return null;

    final data = doc.data()!;
    return {
      'id': doc.id,
      'basePrice': (data['basePrice'] ?? data['rate'] ?? 0.0).toDouble(),
      'maxPrice': (data['maxPrice'] ?? data['rate'] ?? 0.0).toDouble(),
      'minPrice': (data['minPrice'] ?? data['rate'] ?? 0.0).toDouble(),
    };
  }

  // Create or update exchange rate
  Future<void> createOrUpdateExchangeRate({
    required String fromCurrencyId,
    required String toCurrencyId,
    required double basePrice,
    required double maxPrice,
    required double minPrice,
  }) async {
    if (_currentUser == null) throw Exception('User not logged in');

    if (fromCurrencyId == toCurrencyId) {
      throw Exception('لا يمكن إضافة سعر تحويل للعملة نفسها');
    }

    if (basePrice <= 0 || maxPrice <= 0 || minPrice <= 0) {
      throw Exception('جميع الأسعار يجب أن تكون أكبر من الصفر');
    }

    if (minPrice > maxPrice) {
      throw Exception('أقل سعر يجب أن يكون أقل من أو يساوي أعلى سعر');
    }

    if (basePrice < minPrice || basePrice > maxPrice) {
      throw Exception('السعر الرئيسي يجب أن يكون بين أقل سعر وأعلى سعر');
    }

    final rateId = '${fromCurrencyId}_${toCurrencyId}';

    // Check if reverse rate exists (to prevent duplicates in different direction)
    final reverseRateId = '${toCurrencyId}_${fromCurrencyId}';
    final reverseDoc = await _firestore.collection('exchange_rates').doc(reverseRateId).get();
    
    if (reverseDoc.exists && reverseDoc.data()?['userId'] == _currentUser!.uid) {
      throw Exception('يوجد بالفعل سعر تحويل عكسي بين هاتين العملتين. الرجاء تعديل السعر الموجود أو حذفه أولاً.');
    }

    await _firestore.collection('exchange_rates').doc(rateId).set({
      'userId': _currentUser!.uid,
      'fromCurrencyId': fromCurrencyId,
      'toCurrencyId': toCurrencyId,
      'basePrice': basePrice,
      'maxPrice': maxPrice,
      'minPrice': minPrice,
      'rate': basePrice, // Keep for backward compatibility
      'createdAt': FieldValue.serverTimestamp(),
      'lastModified': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Update exchange rate
  Future<void> updateExchangeRate({
    required String rateId,
    required double basePrice,
    required double maxPrice,
    required double minPrice,
  }) async {
    if (_currentUser == null) throw Exception('User not logged in');

    if (basePrice <= 0 || maxPrice <= 0 || minPrice <= 0) {
      throw Exception('جميع الأسعار يجب أن تكون أكبر من الصفر');
    }

    if (minPrice > maxPrice) {
      throw Exception('أقل سعر يجب أن يكون أقل من أو يساوي أعلى سعر');
    }

    if (basePrice < minPrice || basePrice > maxPrice) {
      throw Exception('السعر الرئيسي يجب أن يكون بين أقل سعر وأعلى سعر');
    }

    final doc = await _firestore.collection('exchange_rates').doc(rateId).get();
    if (!doc.exists) {
      throw Exception('سعر التحويل غير موجود');
    }

    if (doc.data()?['userId'] != _currentUser!.uid) {
      throw Exception('غير مصرح لك بتعديل هذا السعر');
    }

    await _firestore.collection('exchange_rates').doc(rateId).update({
      'basePrice': basePrice,
      'maxPrice': maxPrice,
      'minPrice': minPrice,
      'rate': basePrice, // Keep for backward compatibility
      'lastModified': FieldValue.serverTimestamp(),
    });
  }

  // Delete exchange rate
  Future<void> deleteExchangeRate(String rateId) async {
    if (_currentUser == null) throw Exception('User not logged in');

    final doc = await _firestore.collection('exchange_rates').doc(rateId).get();
    if (!doc.exists) {
      throw Exception('سعر التحويل غير موجود');
    }

    if (doc.data()?['userId'] != _currentUser!.uid) {
      throw Exception('غير مصرح لك بحذف هذا السعر');
    }

    await _firestore.collection('exchange_rates').doc(rateId).delete();
  }
}

