import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled/core/services/internet_check_service.dart';
import 'package:untitled/core/services/phone_auth_service.dart';
import 'package:untitled/login_screen.dart';
import 'package:untitled/theme/app_colors.dart';
import 'package:untitled/utils/show_message_dialog.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _phoneAuthService = PhoneAuthService();
  bool _isLoading = false;

  Future<void> _signUpUser() async {
    if (!_formKey.currentState!.validate()) return;

    // Check internet connection
    final hasInternet = await InternetCheckService.hasInternetConnection();
    if (!hasInternet) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يوجد اتصال بالإنترنت. يرجى التحقق من الاتصال والمحاولة مرة أخرى.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check for duplicates
      final phoneExists = await _phoneAuthService.isPhoneExists(_phoneController.text.trim());
      if (phoneExists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('رقم الهاتف مستخدم بالفعل'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final emailExists = await _phoneAuthService.isEmailExists(_emailController.text.trim());
      if (emailExists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('البريد الإلكتروني مستخدم بالفعل'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final nameExists = await _phoneAuthService.isNameExists(_nameController.text.trim());
      if (nameExists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('اسم المستخدم مستخدم بالفعل'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Create user account (NO email verification at signup)
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        // Save user data to Firestore
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Save login credentials to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_phone', _phoneController.text.trim());
        await prefs.setString('saved_password', _passwordController.text.trim());

        // Sign out the user (they need to login and verify email)
        await _auth.signOut();

        if (mounted) {
          await showMessageDialog(
            context,
            title: 'اكتمل التسجيل',
            message: 'تم إنشاء الحساب بنجاح. يمكنك الآن تسجيل الدخول.',
            type: MessageType.success,
          );

          // Navigate to login screen with pre-filled data
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => LoginScreen(
                preFilledPhone: _phoneController.text.trim(),
                preFilledPassword: _passwordController.text.trim(),
              ),
            ),
            (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        String message = 'حدث خطأ في إنشاء الحساب';
        if (e.code == 'email-already-in-use') {
          message = 'البريد الإلكتروني مستخدم بالفعل';
        } else if (e.code == 'weak-password') {
          message = 'كلمة المرور ضعيفة. يجب أن تكون 6 أحرف على الأقل';
        } else if (e.code == 'invalid-email') {
          message = 'البريد الإلكتروني غير صحيح';
        } else if (e.code == 'network-request-failed') {
          message = 'فشل الاتصال بالإنترنت. يرجى التحقق من الاتصال والمحاولة مرة أخرى.';
        }
        showMessageDialog(
          context,
          title: 'خطأ في إنشاء الحساب',
          message: message,
          type: MessageType.error,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showMessageDialog(
          context,
          title: 'خطأ في إنشاء الحساب',
          message: 'حدث خطأ غير متوقع: ${e.toString()}',
          type: MessageType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء حساب جديد'),
        backgroundColor: AppColors.primaryMaroon,
        foregroundColor: AppColors.textOnDark,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم الحساب الكامل',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'هذا الحقل مطلوب';
                      }
                      if (v.trim().length < 3) {
                        return 'الاسم يجب أن يكون 3 أحرف على الأقل';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'هذا الحقل مطلوب';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                        return 'الرجاء إدخال بريد إلكتروني صحيح';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'هذا الحقل مطلوب';
                      }
                      if (v.trim().length < 8) {
                        return 'رقم الهاتف غير صحيح';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'هذا الحقل مطلوب';
                      }
                      if (v.length < 6) {
                        return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'تأكيد كلمة المرور',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'هذا الحقل مطلوب';
                      }
                      if (v != _passwordController.text) {
                        return 'كلمتا المرور غير متطابقتين';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 30),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _signUpUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryMaroon,
                            foregroundColor: AppColors.textOnDark,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                          ),
                          child: const Text('إنشاء الحساب'),
                        ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('لديك حساب بالفعل؟ تسجيل الدخول'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
