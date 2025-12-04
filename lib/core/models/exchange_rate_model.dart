import 'package:cloud_firestore/cloud_firestore.dart';

class ExchangeRateModel {
  final String id;
  final String userId;
  final String fromCurrencyId;
  final String toCurrencyId;
  final double basePrice; // السعر الرئيسي
  final double maxPrice; // أعلى سعر مسموح
  final double minPrice; // أقل سعر مسموح
  final DateTime createdAt;
  final DateTime? lastModified;

  ExchangeRateModel({
    required this.id,
    required this.userId,
    required this.fromCurrencyId,
    required this.toCurrencyId,
    required this.basePrice,
    required this.maxPrice,
    required this.minPrice,
    required this.createdAt,
    this.lastModified,
  });

  factory ExchangeRateModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExchangeRateModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      fromCurrencyId: data['fromCurrencyId'] ?? '',
      toCurrencyId: data['toCurrencyId'] ?? '',
      basePrice: (data['basePrice'] ?? 0.0).toDouble(),
      maxPrice: (data['maxPrice'] ?? 0.0).toDouble(),
      minPrice: (data['minPrice'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastModified: (data['lastModified'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'fromCurrencyId': fromCurrencyId,
      'toCurrencyId': toCurrencyId,
      'basePrice': basePrice,
      'maxPrice': maxPrice,
      'minPrice': minPrice,
      'createdAt': Timestamp.fromDate(createdAt),
      if (lastModified != null) 'lastModified': Timestamp.fromDate(lastModified!),
    };
  }

  ExchangeRateModel copyWith({
    String? id,
    String? userId,
    String? fromCurrencyId,
    String? toCurrencyId,
    double? basePrice,
    double? maxPrice,
    double? minPrice,
    DateTime? createdAt,
    DateTime? lastModified,
  }) {
    return ExchangeRateModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fromCurrencyId: fromCurrencyId ?? this.fromCurrencyId,
      toCurrencyId: toCurrencyId ?? this.toCurrencyId,
      basePrice: basePrice ?? this.basePrice,
      maxPrice: maxPrice ?? this.maxPrice,
      minPrice: minPrice ?? this.minPrice,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}


