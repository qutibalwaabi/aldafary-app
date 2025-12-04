import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:untitled/core/models/user_profile_model.dart';

class UserProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Get user profile
  Stream<UserProfileModel?> streamUserProfile() {
    if (_currentUser == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return UserProfileModel.fromFirestore(doc);
    });
  }

  // Get user profile (one-time)
  Future<UserProfileModel?> getUserProfile() async {
    if (_currentUser == null) return null;

    final doc = await _firestore.collection('users').doc(_currentUser!.uid).get();
    if (!doc.exists) return null;

    return UserProfileModel.fromFirestore(doc);
  }

  // Create or update user profile
  Future<void> saveUserProfile(UserProfileModel profile) async {
    if (_currentUser == null) throw Exception('User not logged in');

    final profileData = profile.copyWith(
      userId: _currentUser!.uid,
      lastModified: DateTime.now(),
    ).toFirestore();

    // Check if profile exists
    final existingDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
    
    if (existingDoc.exists) {
      // Update existing profile
      await _firestore.collection('users').doc(_currentUser!.uid).update(profileData);
    } else {
      // Create new profile
      await _firestore.collection('users').doc(_currentUser!.uid).set({
        ...profileData,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Update profile image
  Future<void> updateProfileImage(String imageUrl) async {
    if (_currentUser == null) throw Exception('User not logged in');

    await _firestore.collection('users').doc(_currentUser!.uid).update({
      'profileImageUrl': imageUrl,
      'lastModified': FieldValue.serverTimestamp(),
    });
  }

  // Update logo
  Future<void> updateLogo(String logoUrl) async {
    if (_currentUser == null) throw Exception('User not logged in');

    await _firestore.collection('users').doc(_currentUser!.uid).update({
      'logoUrl': logoUrl,
      'lastModified': FieldValue.serverTimestamp(),
    });
  }
}

