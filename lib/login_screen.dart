import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled/core/services/internet_check_service.dart';
import 'package:untitled/core/services/phone_auth_service.dart';
import 'package:untitled/signup_screen.dart';
import 'package:untitled/theme/app_colors.dart';
import 'package:untitled/verify_email_screen.dart';
import 'package:untitled/onboarding_screen.dart';
import 'package:untitled/home_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? preFilledPhone;
  final String? preFilledPassword;
  
  const LoginScreen({super.key, this.preFilledPhone, this.preFilledPassword});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  final _phoneAuthService = PhoneAuthService();

  @override
  void initState() {
    super.initState();
    // Fill pre-filled data if provided
    if (widget.preFilledPhone != null) {
      _phoneController.text = widget.preFilledPhone!;
    }
    if (widget.preFilledPassword != null) {
      _passwordController.text = widget.preFilledPassword!;
    }
    
    // Load saved credentials from SharedPreferences
    _loadSavedCredentials();
  }
  
  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPhone = prefs.getString('saved_phone');
      final savedPassword = prefs.getString('saved_password');
      
      if (savedPhone != null && savedPhone.isNotEmpty) {
        _phoneController.text = savedPhone;
      }
      if (savedPassword != null && savedPassword.isNotEmpty) {
        _passwordController.text = savedPassword;
      }
    } catch (e) {
      // Ignore errors when loading saved credentials
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    // Check internet connection
    final hasInternet = await InternetCheckService.hasInternetConnection();
    if (!hasInternet) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لا يوجد اتصال بالإنترنت. يرجى التحقق من الاتصال والمحاولة مرة أخرى.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Sign in with phone and password
      final userCredential = await _phoneAuthService.signInWithPhoneAndPassword(
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
      );

      if (userCredential == null || userCredential.user == null) {
        setState(() => _isLoading = false);
        if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'فشل تسجيل الدخول. يرجى التحقق من البيانات والمحاولة مرة أخرى.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
        }
        return;
      }

      // Reload user to get latest email verification status
      await userCredential.user!.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;

      if (mounted && updatedUser != null) {
        // Save login credentials for future auto-fill
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_phone', _phoneController.text.trim());
        await prefs.setString('saved_password', _passwordController.text);
        
        // Check if email is verified (check at login)
        if (!updatedUser.emailVerified) {
          setState(() => _isLoading = false);
          // Navigate to email verification screen
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
          );
        } else {
          // Email verified, check if onboarding is completed
          setState(() => _isLoading = false);
          
          // Check if user has completed onboarding
          final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
          
          // Also check in Firestore
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(updatedUser.uid)
              .get();
          
          final firestoreOnboardingCompleted = userDoc.exists 
              ? (userDoc.data()?['onboardingCompleted'] ?? false)
              : false;
          
          if (!mounted) return;
          
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
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);

      String message = 'حدث خطأ ما';
      if (e.code == 'user-not-found') {
        message = 'لا يوجد مستخدم بهذا رقم الهاتف';
      } else if (e.code == 'wrong-password') {
        message = 'كلمة المرور غير صحيحة';
      } else if (e.code == 'user-disabled') {
        message = 'تم تعطيل حساب هذا المستخدم';
      } else if (e.code == 'too-many-requests') {
        message = 'تم تجاوز عدد محاولات تسجيل الدخول. يرجى المحاولة لاحقاً';
      } else if (e.code == 'network-request-failed') {
        message = 'فشل الاتصال بالإنترنت. يرجى التحقق من الاتصال والمحاولة مرة أخرى.';
      } else if (e.code == 'invalid-email') {
        message = 'البريد الإلكتروني غير صحيح';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ: ${e.toString()}',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF800000), // Maroon color
      appBar: AppBar(
        title: const Text('تسجيل الدخول'),
        backgroundColor: AppColors.primaryMaroon,
        foregroundColor: AppColors.textOnDark,
      ),
      body: Container(
        color: const Color(0xFF800000), // Maroon color background
        child: Center(
          child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: InputDecorationTheme(
                labelStyle: const TextStyle(color: Colors.white70),
                errorStyle: const TextStyle(color: Colors.white, fontSize: 12),
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIconColor: Colors.white,
                suffixIconColor: Colors.white,
              ),
              textSelectionTheme: const TextSelectionThemeData(
                cursorColor: Colors.white,
                selectionColor: Colors.white54,
                selectionHandleColor: Colors.white,
              ),
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: Colors.white,
              ),
            ),
            child: Form(
              key: _formKey,
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'assets/images/logo.png',
                  width: 120,
                  height: 120,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: AppColors.primaryMaroon,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance,
                        size: 64,
                        color: AppColors.textOnDark,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Title
                const Text(
                  'شركة الظفري',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white, // White text on maroon background
                  ),
                ),
                const SizedBox(height: 32),

                // Phone Field
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف',
                    labelStyle: const TextStyle(color: Colors.white70),
                    errorStyle: const TextStyle(color: Colors.white, fontSize: 12),
                    prefixIcon: const Icon(Icons.phone, color: Colors.white),
                    border: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white, width: 2),
                    ),
                    errorBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red),
                    ),
                    focusedErrorBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال رقم الهاتف';
                    }
                    // Basic phone validation
                    if (value.trim().length < 8) {
                      return 'رقم الهاتف غير صحيح';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    labelStyle: const TextStyle(color: Colors.white70),
                    errorStyle: const TextStyle(color: Colors.white, fontSize: 12),
                    prefixIcon: const Icon(Icons.lock, color: Colors.white),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white, width: 2),
                    ),
                    errorBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red),
                    ),
                    focusedErrorBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال كلمة المرور';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Login Button
                _isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : ElevatedButton(
                        onPressed: _signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryMaroon,
                          foregroundColor: AppColors.textOnDark,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('تسجيل الدخول'),
                      ),
                const SizedBox(height: 16),

                // Register Button
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SignUpScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'ليس لديك حساب؟ قم بإنشاء حساب جديد',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}
