import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PhoneAuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Find user email by phone number
  Future<String?> getUserEmailByPhone(String phone) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('phone', isEqualTo: phone.trim())
          .limit(1)
          .get();
      
      if (query.docs.isEmpty) {
        return null;
      }
      
      final userData = query.docs.first.data();
      return userData['email'] as String?;
    } catch (e) {
      return null;
    }
  }
  
  /// Sign in with phone number and password
  Future<UserCredential?> signInWithPhoneAndPassword({
    required String phone,
    required String password,
  }) async {
    try {
      // Find user email by phone number
      final email = await getUserEmailByPhone(phone);
      
      if (email == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'لا يوجد مستخدم بهذا رقم الهاتف',
        );
      }
      
      // Sign in with email and password
      return await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      if (e is FirebaseAuthException) {
        rethrow;
      }
      throw FirebaseAuthException(
        code: 'unknown-error',
        message: e.toString(),
      );
    }
  }
  
  /// Check if phone number already exists
  Future<bool> isPhoneExists(String phone) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('phone', isEqualTo: phone.trim())
          .limit(1)
          .get();
      
      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Check if email already exists
  Future<bool> isEmailExists(String email) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();
      
      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Check if name already exists
  Future<bool> isNameExists(String name) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('name', isEqualTo: name.trim())
          .limit(1)
          .get();
      
      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

