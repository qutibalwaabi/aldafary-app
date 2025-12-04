import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:untitled/core/models/currency_model.dart';

class CurrencyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Get all currencies for current user (excluding suspended)
  Stream<List<CurrencyModel>> streamCurrencies({bool includeSuspended = false}) {
    if (_currentUser == null) return Stream.value([]);

    // Get all currencies and filter in memory to avoid composite index issues
    return _firestore
        .collection('currencies')
        .where('userId', isEqualTo: _currentUser!.uid)
        .snapshots()
        .map((snapshot) {
          var currencies = snapshot.docs
              .map((doc) => CurrencyModel.fromFirestore(doc))
              .toList();
          
          // Filter suspended currencies in memory
          if (!includeSuspended) {
            currencies = currencies.where((c) => !c.isSuspended).toList();
          }
          
          // Sort: primary currency first, then by name
          currencies.sort((a, b) {
            if (a.isPrimary && !b.isPrimary) return -1;
            if (!a.isPrimary && b.isPrimary) return 1;
            return a.name.compareTo(b.name);
          });
          
          return currencies;
        });
  }

  // Get all currencies including suspended (for admin screens)
  Stream<List<CurrencyModel>> streamAllCurrencies() {
    return streamCurrencies(includeSuspended: true);
  }

  // Get currency by ID
  Future<CurrencyModel?> getCurrencyById(String currencyId) async {
    if (_currentUser == null) return null;

    final doc = await _firestore.collection('currencies').doc(currencyId).get();
    if (!doc.exists) return null;

    final currency = CurrencyModel.fromFirestore(doc);
    if (currency.userId != _currentUser!.uid) return null;

    return currency;
  }

  // Get primary currency
  Future<CurrencyModel?> getPrimaryCurrency() async {
    if (_currentUser == null) return null;

    // Try isPrimary first, fallback to isBase for backward compatibility
    var snapshot = await _firestore
        .collection('currencies')
        .where('userId', isEqualTo: _currentUser!.uid)
        .where('isPrimary', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      snapshot = await _firestore
          .collection('currencies')
          .where('userId', isEqualTo: _currentUser!.uid)
          .where('isBase', isEqualTo: true)
          .limit(1)
          .get();
    }

    if (snapshot.docs.isEmpty) return null;

    return CurrencyModel.fromFirestore(snapshot.docs.first);
  }

  // Keep for backward compatibility
  Future<CurrencyModel?> getBaseCurrency() async {
    return getPrimaryCurrency();
  }

  // Create currency
  Future<String> createCurrency(CurrencyModel currency) async {
    if (_currentUser == null) throw Exception('User not logged in');

    // If setting as primary currency, ensure no other primary currency exists
    if (currency.isPrimary) {
      final existingPrimary = await getPrimaryCurrency();
      if (existingPrimary != null) {
        throw Exception('يمكن أن تكون هناك عملة أساسية واحدة فقط. الرجاء تعديل العملة الحالية أولاً.');
      }
    }

    // Prevent suspending primary currency
    if (currency.isPrimary && currency.isSuspended) {
      throw Exception('لا يمكن إيقاف العملة الرئيسية');
    }

    final currencyData = currency.copyWith(
      userId: _currentUser!.uid,
      createdAt: DateTime.now(),
      exchangeRate: currency.isPrimary ? 1.0 : currency.exchangeRate,
    ).toFirestore();

    final docRef = await _firestore.collection('currencies').add(currencyData);
    return docRef.id;
  }

  // Update currency
  Future<void> updateCurrency(String currencyId, CurrencyModel currency) async {
    if (_currentUser == null) throw Exception('User not logged in');

    // Verify ownership
    final existingCurrency = await getCurrencyById(currencyId);
    if (existingCurrency == null) {
      throw Exception('Currency not found or access denied');
    }

    // Prevent suspending primary currency
    if (existingCurrency.isPrimary && currency.isSuspended) {
      throw Exception('لا يمكن إيقاف العملة الرئيسية');
    }

    // Prevent changing primary currency if it's used in transactions
    if (existingCurrency.isPrimary && !currency.isPrimary) {
      final isUsed = await isCurrencyUsed(currencyId);
      if (isUsed) {
        throw Exception('لا يمكن تغيير حالة العملة الأساسية لأنها مستخدمة في معاملات مالية. الرجاء تعيين عملة أساسية أخرى أولاً.');
      }
    }

    // Prevent changing primary currency status if it's used
    if (existingCurrency.isPrimary && currency.isPrimary) {
      // If it's already primary and staying primary, check if we can modify other fields
      final isUsed = await isCurrencyUsed(currencyId);
      if (isUsed && (existingCurrency.name != currency.name || existingCurrency.symbol != currency.symbol)) {
        throw Exception('لا يمكن تعديل اسم أو رمز العملة الأساسية لأنها مستخدمة في معاملات مالية.');
      }
    }

    // If setting as primary currency, ensure no other primary currency exists
    if (currency.isPrimary && !existingCurrency.isPrimary) {
      final otherPrimary = await getPrimaryCurrency();
      if (otherPrimary != null && otherPrimary.id != currencyId) {
        throw Exception('يمكن أن تكون هناك عملة أساسية واحدة فقط. الرجاء تعديل العملة الحالية أولاً.');
      }
    }

    final updateData = currency.copyWith(
      lastModified: DateTime.now(),
      exchangeRate: currency.isPrimary ? 1.0 : currency.exchangeRate,
    ).toFirestore();

    await _firestore.collection('currencies').doc(currencyId).update(updateData);
  }

  // Check if currency is used in transactions
  Future<bool> isCurrencyUsed(String currencyId) async {
    if (_currentUser == null) return false;

    final query = await _firestore
        .collection('transactions')
        .where('userId', isEqualTo: _currentUser!.uid)
        .where('currencyId', isEqualTo: currencyId)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  // Delete currency (only if not used)
  Future<void> deleteCurrency(String currencyId) async {
    if (_currentUser == null) throw Exception('User not logged in');

    // Verify ownership
    final currency = await getCurrencyById(currencyId);
    if (currency == null) {
      throw Exception('Currency not found or access denied');
    }

    // Prevent deletion of primary currency
    if (currency.isPrimary) {
      throw Exception('لا يمكن حذف العملة الأساسية. الرجاء تعيين عملة أساسية أخرى أولاً.');
    }

    // Check if currency is used
    final isUsed = await isCurrencyUsed(currencyId);
    if (isUsed) {
      throw Exception('لا يمكن حذف العملة لأنها مستخدمة في معاملات مالية');
    }

    await _firestore.collection('currencies').doc(currencyId).delete();
  }
}

