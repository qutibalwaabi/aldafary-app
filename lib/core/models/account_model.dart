import 'package:cloud_firestore/cloud_firestore.dart';

class AccountModel {
  final String id;
  final String userId;
  final String name;
  final String type;
  final double creditLimit;
  final double balance;
  final bool isSuspended;
  final DateTime createdAt;
  final DateTime? lastModified;

  AccountModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.creditLimit = 0.0,
    this.balance = 0.0,
    this.isSuspended = false,
    required this.createdAt,
    this.lastModified,
  });

  factory AccountModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AccountModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      type: data['type'] ?? '',
      creditLimit: (data['creditLimit'] ?? 0.0).toDouble(),
      balance: (data['balance'] ?? 0.0).toDouble(),
      isSuspended: data['isSuspended'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastModified: (data['lastModified'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'type': type,
      'creditLimit': creditLimit,
      'balance': balance,
      'isSuspended': isSuspended,
      'createdAt': Timestamp.fromDate(createdAt),
      if (lastModified != null) 'lastModified': Timestamp.fromDate(lastModified!),
    };
  }

  AccountModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? type,
    double? creditLimit,
    double? balance,
    bool? isSuspended,
    DateTime? createdAt,
    DateTime? lastModified,
  }) {
    return AccountModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      creditLimit: creditLimit ?? this.creditLimit,
      balance: balance ?? this.balance,
      isSuspended: isSuspended ?? this.isSuspended,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}

