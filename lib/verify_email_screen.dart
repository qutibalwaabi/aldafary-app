
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled/utils/show_message_dialog.dart';
import 'package:untitled/onboarding_screen.dart';
import 'package:untitled/home_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    sendVerificationEmail(); 
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => checkEmailVerified(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> checkEmailVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _timer?.cancel();
      return;
    }
    
    // Reload user to get latest email verification status
    await user.reload();
    final updatedUser = FirebaseAuth.instance.currentUser;
    
    if (updatedUser?.emailVerified ?? false) {
      _timer?.cancel();
      
      if (mounted && updatedUser != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم التحقق من البريد الإلكتروني بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Check if onboarding is completed
        final prefs = await SharedPreferences.getInstance();
        final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
        
        // Also check in Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(updatedUser.uid)
            .get();
        
        final firestoreOnboardingCompleted = userDoc.exists 
            ? (userDoc.data()?['onboardingCompleted'] ?? false)
            : false;
        
        if (!onboardingCompleted && !firestoreOnboardingCompleted) {
          // Navigate to onboarding screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          );
        } else {
          // Navigate to home screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    }
  }

  Future<void> sendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          showMessageDialog(
            context,
            title: 'خطأ',
            message: 'لا يوجد مستخدم مسجل الدخول',
            type: MessageType.error,
          );
        }
        return;
      }

      // Reload user first to get latest status
      await user.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;
      
      if (updatedUser == null) return;
      
      // Check if already verified
      if (updatedUser.emailVerified) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم التحقق من البريد الإلكتروني مسبقاً'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      // Send verification email without ActionCodeSettings (simpler and more reliable)
      await updatedUser.sendEmailVerification();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال رابط التحقق إلى بريدك الإلكتروني. يرجى التحقق من مجلد البريد المزعج (Spam) إذا لم تجده في الوارد.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'حدث خطأ أثناء إرسال بريد التحقق';
      if (e.code == 'too-many-requests') {
        errorMessage = 'تم إرسال طلبات كثيرة. يرجى المحاولة لاحقاً.';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'فشل الاتصال بالإنترنت. يرجى التحقق من اتصالك.';
      }
      
      if (mounted) {
        showMessageDialog(
          context,
          title: 'خطأ',
          message: '$errorMessage\n\n${e.message ?? ''}',
          type: MessageType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        showMessageDialog(
          context,
          title: 'خطأ',
          message: 'فشل إرسال بريد التحقق: ${e.toString()}\n\nملاحظة: تأكد من تفعيل Email/Password في Firebase Console',
          type: MessageType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("التحقق من البريد الإلكتروني"),
         actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.email_outlined, size: 100),
              const SizedBox(height: 20),
              const Text('تم إرسال رابط التحقق إلى:', style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(FirebaseAuth.instance.currentUser?.email ?? 'بريدك الإلكتروني', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              const Text('الرجاء الضغط على الرابط في الرسالة لتفعيل حسابك. (قد تجد الرسالة في مجلد Spam)', textAlign: TextAlign.center,),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: sendVerificationEmail,
                icon: const Icon(Icons.send),
                label: const Text('إعادة إرسال البريد'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
