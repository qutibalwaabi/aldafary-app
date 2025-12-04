import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:untitled/core/services/transaction_serial_service.dart';
import 'package:untitled/core/services/balance_check_service.dart';
import 'package:untitled/core/services/currency_service.dart';

class TransactionService {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BalanceCheckService _balanceCheckService = BalanceCheckService();
  final CurrencyService _currencyService = CurrencyService();

  // Stream all transactions
  Stream<List<Transaction>> streamAllTransactions() {
    if (_currentUser == null) return Stream.value([]);

    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: _currentUser!.uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Transaction.fromFirestore(doc))
            .toList());
  }

  // Stream transactions by type
  Stream<List<Transaction>> streamTransactionsByType(String type, {int limit = 50}) {
    if (_currentUser == null) return Stream.value([]);

    var query = _firestore
        .collection('transactions')
        .where('userId', isEqualTo: _currentUser!.uid)
        .where('operationType', isEqualTo: type)
        .orderBy('date', descending: true);

    if (limit > 0) {
      query = query.limit(limit);
    }

    return query.snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Transaction.fromFirestore(doc))
            .toList());
  }

  // Stream recent transactions
  Stream<List<Transaction>> streamRecentTransactions({int limit = 10}) {
    if (_currentUser == null) return Stream.value([]);

    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: _currentUser!.uid)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Transaction.fromFirestore(doc))
            .toList());
  }

  // Get transaction by ID
  Future<Transaction?> getTransactionById(String transactionId) async {
    if (_currentUser == null) return null;

    final doc = await _firestore
        .collection('transactions')
        .doc(transactionId)
        .get();

    if (!doc.exists) return null;

    return Transaction.fromFirestore(doc);
  }

  // Create a new transaction
  Future<String> createTransaction({
    required String operationType,
    required String debitAccountId,
    required String creditAccountId,
    required double amount,
    required String currencyId,
    required String description,
    DateTime? date,
    String? referenceNumber,
  }) async {
    if (_currentUser == null) throw Exception('User not logged in');

    // Validate accounting rules
    if (debitAccountId == creditAccountId) {
      throw Exception('الحساب المدين والدائن يجب أن يكونا مختلفين');
    }
    
    if (amount <= 0) {
      throw Exception('المبلغ يجب أن يكون أكبر من الصفر');
    }
    
    if (description.trim().isEmpty) {
      throw Exception('البيان مطلوب');
    }

    // Check currency is not suspended
    final currency = await _currencyService.getCurrencyById(currencyId);
    if (currency == null) {
      throw Exception('العملة غير موجودة');
    }
    if (currency.isSuspended) {
      throw Exception('العملة موقفة ولا يمكن إجراء معاملات بها');
    }

    // Check balance and credit limit for debit account
    await _balanceCheckService.checkAccountBalance(
      accountId: debitAccountId,
      currencyId: currencyId,
      amount: amount,
      isDebitTransaction: true, // Debit transaction adds to account
    );

    // Check balance and credit limit for credit account
    await _balanceCheckService.checkAccountBalance(
      accountId: creditAccountId,
      currencyId: currencyId,
      amount: amount,
      isDebitTransaction: false, // Credit transaction subtracts from account
    );

    // Get serial number for this operation type
    final serialService = TransactionSerialService();
    final serialNumber = await serialService.getNextSerialNumber(operationType);
    final formattedSerial = TransactionSerialService.formatSerialNumber(operationType, serialNumber);

    final transactionData = {
      'userId': _currentUser!.uid,
      'operationType': operationType,
      'debitAccountId': debitAccountId,
      'creditAccountId': creditAccountId,
      'amount': amount,
      'currencyId': currencyId,
      'description': description,
      'date': date != null ? Timestamp.fromDate(date) : Timestamp.now(),
      'serialNumber': serialNumber,
      'formattedSerialNumber': formattedSerial,
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Add reference number if provided
    if (referenceNumber != null && referenceNumber.trim().isNotEmpty) {
      transactionData['referenceNumber'] = referenceNumber.trim();
    }

    final doc = await _firestore.collection('transactions').add(transactionData);

    return doc.id;
  }

  // Update transaction
  Future<void> updateTransaction({
    required String transactionId,
    String? operationType,
    String? debitAccountId,
    String? creditAccountId,
    double? amount,
    String? currencyId,
    String? description,
    DateTime? date,
    String? referenceNumber,
  }) async {
    if (_currentUser == null) throw Exception('User not logged in');

    final updateData = <String, dynamic>{};

    // Note: serialNumber and formattedSerialNumber cannot be updated
    if (operationType != null) updateData['operationType'] = operationType;
    if (debitAccountId != null) updateData['debitAccountId'] = debitAccountId;
    if (creditAccountId != null) updateData['creditAccountId'] = creditAccountId;
    if (amount != null) updateData['amount'] = amount;
    if (currencyId != null) updateData['currencyId'] = currencyId;
    if (description != null) updateData['description'] = description;
    if (date != null) updateData['date'] = Timestamp.fromDate(date);
    
    // Handle reference number - can be set to empty string to clear it
    if (referenceNumber != null) {
      if (referenceNumber.trim().isEmpty) {
        updateData['referenceNumber'] = FieldValue.delete();
      } else {
        updateData['referenceNumber'] = referenceNumber.trim();
      }
    }

    updateData['updatedAt'] = FieldValue.serverTimestamp();

    await _firestore
        .collection('transactions')
        .doc(transactionId)
        .update(updateData);
  }

  // Create currency exchange transaction (Buy/Sell)
  Future<String> createCurrencyExchangeTransaction({
    required String operationType, // 'BuyCurrency' or 'SellCurrency'
    required String fromCurrencyId,
    required double fromAmount,
    required String toCurrencyId,
    required double toAmount,
    required double exchangeRate,
    required String debitAccountId, // حساب العملة المشتراة (المدين)
    required String creditAccountId, // حساب العملة المدفوعة (الدائن)
    required String description,
    DateTime? date,
    String? referenceNumber,
  }) async {
    if (_currentUser == null) throw Exception('User not logged in');

    // Validate accounting rules
    if (debitAccountId == creditAccountId) {
      throw Exception('الحساب المدين والدائن يجب أن يكونا مختلفين');
    }

    // Check currencies are not suspended
    final fromCurrency = await _currencyService.getCurrencyById(fromCurrencyId);
    final toCurrency = await _currencyService.getCurrencyById(toCurrencyId);
    if (fromCurrency == null || toCurrency == null) {
      throw Exception('إحدى العملات غير موجودة');
    }
    if (fromCurrency.isSuspended || toCurrency.isSuspended) {
      throw Exception('إحدى العملات موقفة ولا يمكن إجراء معاملات بها');
    }

    // Check balance for debit account (receives toCurrency)
    await _balanceCheckService.checkAccountBalance(
      accountId: debitAccountId,
      currencyId: toCurrencyId,
      amount: toAmount,
      isDebitTransaction: true, // Receiving currency (debit)
    );

    // Check balance for credit account (pays fromCurrency)
    await _balanceCheckService.checkAccountBalance(
      accountId: creditAccountId,
      currencyId: fromCurrencyId,
      amount: fromAmount,
      isDebitTransaction: false, // Paying currency (credit)
    );

    // Get serial number for this operation type
    final serialService = TransactionSerialService();
    final serialNumber = await serialService.getNextSerialNumber(operationType);
    final formattedSerial = TransactionSerialService.formatSerialNumber(operationType, serialNumber);

    // For BuyCurrency: debit the account that receives the new currency, credit the account that pays fromCurrency
    // For SellCurrency: debit the account that receives the new currency, credit the account that pays fromCurrency
    // The transaction needs to be split into two entries:
    // 1. Debit transaction: debitAccountId (receives toCurrency) with toAmount in toCurrency
    // 2. Credit transaction: creditAccountId (pays fromCurrency) with fromAmount in fromCurrency

    // First transaction: Debit entry (المدين)
    final debitTransactionData = {
      'userId': _currentUser!.uid,
      'operationType': operationType,
      'debitAccountId': debitAccountId,
      'creditAccountId': creditAccountId,
      'amount': toAmount, // Amount in the currency received (المشتراة)
      'currencyId': toCurrencyId,
      'description': description,
      'date': date != null ? Timestamp.fromDate(date) : Timestamp.now(),
      'serialNumber': serialNumber,
      'formattedSerialNumber': formattedSerial,
      'createdAt': FieldValue.serverTimestamp(),
      // Currency exchange specific fields
      'fromCurrencyId': fromCurrencyId,
      'fromAmount': fromAmount,
      'toCurrencyId': toCurrencyId,
      'toAmount': toAmount,
      'exchangeRate': exchangeRate,
    };

    // Add reference number if provided
    if (referenceNumber != null && referenceNumber.trim().isNotEmpty) {
      debitTransactionData['referenceNumber'] = referenceNumber.trim();
    }

    final debitDoc = await _firestore.collection('transactions').add(debitTransactionData);

    // Second transaction: Credit entry (الدائن)
    final creditTransactionData = {
      'userId': _currentUser!.uid,
      'operationType': operationType,
      'debitAccountId': debitAccountId,
      'creditAccountId': creditAccountId,
      'amount': fromAmount, // Amount in the currency paid (المدفوعة)
      'currencyId': fromCurrencyId,
      'description': description,
      'date': date != null ? Timestamp.fromDate(date) : Timestamp.now(),
      'serialNumber': serialNumber,
      'formattedSerialNumber': formattedSerial,
      'createdAt': FieldValue.serverTimestamp(),
      // Currency exchange specific fields
      'fromCurrencyId': fromCurrencyId,
      'fromAmount': fromAmount,
      'toCurrencyId': toCurrencyId,
      'toAmount': toAmount,
      'exchangeRate': exchangeRate,
      'relatedTransactionId': debitDoc.id, // Link to the debit transaction
    };

    if (referenceNumber != null && referenceNumber.trim().isNotEmpty) {
      creditTransactionData['referenceNumber'] = referenceNumber.trim();
    }

    final creditDoc = await _firestore.collection('transactions').add(creditTransactionData);

    // Update the debit transaction with the credit transaction ID
    await debitDoc.update({'relatedTransactionId': creditDoc.id});

    return debitDoc.id; // Return the debit transaction ID as primary
  }

  // Update currency exchange transaction
  Future<void> updateCurrencyExchangeTransaction({
    required String transactionId,
    String? fromCurrencyId,
    double? fromAmount,
    String? toCurrencyId,
    double? toAmount,
    double? exchangeRate,
    String? description,
    DateTime? date,
    String? referenceNumber,
  }) async {
    if (_currentUser == null) throw Exception('User not logged in');

    final updateData = <String, dynamic>{};

    if (fromCurrencyId != null) updateData['fromCurrencyId'] = fromCurrencyId;
    if (fromAmount != null) updateData['fromAmount'] = fromAmount;
    if (toCurrencyId != null) updateData['toCurrencyId'] = toCurrencyId;
    if (toAmount != null) updateData['toAmount'] = toAmount;
    if (exchangeRate != null) updateData['exchangeRate'] = exchangeRate;
    if (description != null) updateData['description'] = description;
    if (date != null) updateData['date'] = Timestamp.fromDate(date);
    
    // Handle reference number
    if (referenceNumber != null) {
      if (referenceNumber.trim().isEmpty) {
        updateData['referenceNumber'] = FieldValue.delete();
      } else {
        updateData['referenceNumber'] = referenceNumber.trim();
      }
    }

    updateData['updatedAt'] = FieldValue.serverTimestamp();

    await _firestore
        .collection('transactions')
        .doc(transactionId)
        .update(updateData);
  }

  // Delete transaction
  Future<void> deleteTransaction(String transactionId) async {
    if (_currentUser == null) throw Exception('User not logged in');

    await _firestore
        .collection('transactions')
        .doc(transactionId)
        .delete();
  }
}

class Transaction {
  final String id;
  final String operationType;
  final String debitAccountId;
  final String creditAccountId;
  final double amount;
  final String currencyId;
  final String description;
  final DateTime date;
  final DateTime createdAt;
  final String? debitAccountName;
  final String? creditAccountName;
  final int serialNumber;
  final String formattedSerialNumber;
  final String? referenceNumber;
  
  // Currency exchange specific fields
  final String? fromCurrencyId;
  final double? fromAmount;
  final String? toCurrencyId;
  final double? toAmount;
  final double? exchangeRate;

  Transaction({
    required this.id,
    required this.operationType,
    required this.debitAccountId,
    required this.creditAccountId,
    required this.amount,
    required this.currencyId,
    required this.description,
    required this.date,
    required this.createdAt,
    this.debitAccountName,
    this.creditAccountName,
    required this.serialNumber,
    required this.formattedSerialNumber,
    this.referenceNumber,
    this.fromCurrencyId,
    this.fromAmount,
    this.toCurrencyId,
    this.toAmount,
    this.exchangeRate,
  });

  // Create a Transaction from a Firestore document
  factory Transaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle createdAt which might be null for old records
    DateTime createdAt;
    if (data['createdAt'] != null) {
      createdAt = (data['createdAt'] as Timestamp).toDate();
    } else {
      createdAt = DateTime.now();
    }

    // Get serial number (default to 0 for old records)
    final serialNumber = (data['serialNumber'] ?? 0) as int;
    
    // Generate formatted serial if missing
    String formattedSerial = data['formattedSerialNumber'] ?? '';
    if (formattedSerial.isEmpty && serialNumber > 0) {
      formattedSerial = TransactionSerialService.formatSerialNumber(
        data['operationType'] ?? '',
        serialNumber,
      );
    }

    return Transaction(
      id: doc.id,
      operationType: data['operationType'] ?? '',
      debitAccountId: data['debitAccountId'] ?? '',
      creditAccountId: data['creditAccountId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      currencyId: data['currencyId'] ?? '',
      description: data['description'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      createdAt: createdAt,
      debitAccountName: data['debitAccountName'],
      creditAccountName: data['creditAccountName'],
      serialNumber: serialNumber,
      formattedSerialNumber: formattedSerial,
      referenceNumber: data['referenceNumber'],
      // Currency exchange fields
      fromCurrencyId: data['fromCurrencyId'],
      fromAmount: data['fromAmount'] != null ? (data['fromAmount'] as num).toDouble() : null,
      toCurrencyId: data['toCurrencyId'],
      toAmount: data['toAmount'] != null ? (data['toAmount'] as num).toDouble() : null,
      exchangeRate: data['exchangeRate'] != null ? (data['exchangeRate'] as num).toDouble() : null,
    );
  }

  // Getters for formatted values
  String get formattedAmount {
    return NumberFormat('#,##0.00').format(amount);
  }

  String get formattedDate {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String get formattedDebitAmount {
    return NumberFormat('#,##0.00').format(amount);
  }

  String get formattedCreditAmount {
    return NumberFormat('#,##0.00').format(amount);
  }
}