import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileModel {
  final String userId;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? logoUrl;
  final String? profileImageUrl;
  final String? defaultCashAccountId;
  final DateTime createdAt;
  final DateTime? lastModified;

  UserProfileModel({
    required this.userId,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.logoUrl,
    this.profileImageUrl,
    this.defaultCashAccountId,
    required this.createdAt,
    this.lastModified,
  });

  factory UserProfileModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfileModel(
      userId: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'],
      email: data['email'],
      address: data['address'],
      logoUrl: data['logoUrl'],
      profileImageUrl: data['profileImageUrl'],
      defaultCashAccountId: data['defaultCashAccountId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastModified: (data['lastModified'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (address != null) 'address': address,
      if (logoUrl != null) 'logoUrl': logoUrl,
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
      if (defaultCashAccountId != null) 'defaultCashAccountId': defaultCashAccountId,
      'createdAt': Timestamp.fromDate(createdAt),
      if (lastModified != null) 'lastModified': Timestamp.fromDate(lastModified!),
    };
  }

  UserProfileModel copyWith({
    String? userId,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? logoUrl,
    String? profileImageUrl,
    String? defaultCashAccountId,
    DateTime? createdAt,
    DateTime? lastModified,
  }) {
    return UserProfileModel(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      logoUrl: logoUrl ?? this.logoUrl,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      defaultCashAccountId: defaultCashAccountId ?? this.defaultCashAccountId,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}

