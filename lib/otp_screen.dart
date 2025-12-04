
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:untitled/home_screen.dart';

class OtpScreen extends StatefulWidget {
  final String verificationId;
  // User data, only available during sign-up
  final String? name;
  final String? phone;
  final String? company;

  // Constructor for sign-up flow
  const OtpScreen({
    super.key,
    required this.verificationId,
    this.name,
    this.phone,
    this.company,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  void _verifyOtp() async {
    if (_otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال الرمز المكون من 6 أرقام')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: _otpController.text.trim(),
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);

      // If it's a sign-up flow (name is not null), save user data
      if (widget.name != null && userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'name': widget.name,
          'phone': widget.phone,
          'companyName': widget.company,
          'logoUrl': '', // Added logoUrl field, initially empty
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Navigate to home screen on successful sign-in
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (Route<dynamic> route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('رمز التحقق غير صحيح أو حدث خطأ: ${e.code}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    const Color whiteColor = Colors.white;
    const Color goldColor = Color(0xFFFFD700);

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back, color: whiteColor), onPressed: () => Navigator.of(context).pop()), title: const Text('التحقق من الرمز', style: TextStyle(color: whiteColor, fontWeight: FontWeight.bold)), centerTitle: true),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text('الرجاء إدخال الرمز المكون من 6 أرقام الذي تم إرساله إلى هاتفك', textAlign: TextAlign.center, style: TextStyle(color: whiteColor, fontSize: 16)),
                const SizedBox(height: 40),
                TextField(controller: _otpController, keyboardType: TextInputType.number, textAlign: TextAlign.center, maxLength: 6, style: const TextStyle(color: whiteColor, fontSize: 24, letterSpacing: 10), decoration: InputDecoration(counterText: '', labelText: 'رمز التحقق (OTP)', labelStyle: const TextStyle(color: whiteColor, letterSpacing: 0), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: const BorderSide(color: whiteColor, width: 1.0)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: const BorderSide(color: goldColor, width: 2.0)))),
                const SizedBox(height: 30),
                _isLoading
                    ? const CircularProgressIndicator(color: whiteColor)
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: whiteColor, foregroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 15)),
                        onPressed: _verifyOtp,
                        child: const Text('تحقق', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
