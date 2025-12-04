import 'package:cloud_firestore/cloud_firestore.dart';

class CurrencyModel {
  final String id;
  final String userId;
  final String name;
  final String symbol;
  final bool isPrimary; // Renamed from isBase for consistency
  final bool isSuspended;
  final double exchangeRate; // Keep for backward compatibility, but will use ExchangeRate service
  final DateTime createdAt;
  final DateTime? lastModified;

  CurrencyModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.symbol,
    this.isPrimary = false,
    this.isSuspended = false,
    this.exchangeRate = 1.0,
    required this.createdAt,
    this.lastModified,
  });

  factory CurrencyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // Support both isBase (old) and isPrimary (new) for backward compatibility
    final isPrimary = data['isPrimary'] ?? data['isBase'] ?? false;
    return CurrencyModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      symbol: data['symbol'] ?? '',
      isPrimary: isPrimary,
      isSuspended: data['isSuspended'] ?? false,
      exchangeRate: (data['exchangeRate'] ?? 1.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastModified: (data['lastModified'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'symbol': symbol,
      'isPrimary': isPrimary,
      'isBase': isPrimary, // Keep for backward compatibility
      'isSuspended': isSuspended,
      'exchangeRate': exchangeRate,
      'createdAt': Timestamp.fromDate(createdAt),
      if (lastModified != null) 'lastModified': Timestamp.fromDate(lastModified!),
    };
  }

  CurrencyModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? symbol,
    bool? isPrimary,
    bool? isSuspended,
    double? exchangeRate,
    DateTime? createdAt,
    DateTime? lastModified,
  }) {
    return CurrencyModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
      isPrimary: isPrimary ?? this.isPrimary,
      isSuspended: isSuspended ?? this.isSuspended,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}

