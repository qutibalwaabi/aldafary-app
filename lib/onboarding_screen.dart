import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled/core/models/account_model.dart';
import 'package:untitled/core/models/currency_model.dart';
import 'package:untitled/core/services/account_service.dart';
import 'package:untitled/core/services/currency_service.dart';
import 'package:untitled/home_screen.dart';
import 'package:untitled/theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cashBoxController = TextEditingController();
  final _currencyNameController = TextEditingController();
  final _currencySymbolController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _cashBoxController.dispose();
    _currencyNameController.dispose();
    _currencySymbolController.dispose();
    super.dispose();
  }

  Future<void> _completeSetup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل دخول');
      }

      final accountService = AccountService();
      final currencyService = CurrencyService();

      // Create default cash account (الصندوق الرئيسي)
      final cashAccount = AccountModel(
        id: '', // Will be set by service
        userId: user.uid,
        name: _cashBoxController.text.trim(),
        type: 'Cash',
        balance: 0.0,
        createdAt: DateTime.now(),
      );
      await accountService.createAccount(cashAccount);

      // Create default currency (العملة الافتراضية)
      final defaultCurrency = CurrencyModel(
        id: '', // Will be set by service
        userId: user.uid,
        name: _currencyNameController.text.trim(),
        symbol: _currencySymbolController.text.trim(),
        isPrimary: true,
        exchangeRate: 1.0,
        createdAt: DateTime.now(),
      );
      await currencyService.createCurrency(defaultCurrency);

      // Mark onboarding as completed
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);

      // Update user profile to mark onboarding as done
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'onboardingCompleted': true,
        'onboardingCompletedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعداد الأولي'),
        backgroundColor: AppColors.primaryMaroon,
        foregroundColor: AppColors.textOnDark,
        automaticallyImplyLeading: false, // Prevent going back
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Message
              const SizedBox(height: 16),
              const Text(
                'مرحباً بك في شركة الظفري',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'يرجى إكمال الإعداد الأولي لإكمال تسجيل الدخول',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Logo
              Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 120,
                  height: 120,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 120,
                      height: 120,
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
              ),
              const SizedBox(height: 32),

              // Cash Box Name
              TextFormField(
                controller: _cashBoxController,
                decoration: const InputDecoration(
                  labelText: 'اسم الصندوق الرئيسي الافتراضي',
                  hintText: 'مثال: الصندوق الرئيسي',
                  prefixIcon: Icon(Icons.account_balance_wallet),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال اسم الصندوق الرئيسي';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Currency Name
              TextFormField(
                controller: _currencyNameController,
                decoration: const InputDecoration(
                  labelText: 'اسم العملة الافتراضية',
                  hintText: 'مثال: الريال السعودي',
                  prefixIcon: Icon(Icons.monetization_on),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال اسم العملة';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Currency Symbol
              TextFormField(
                controller: _currencySymbolController,
                decoration: const InputDecoration(
                  labelText: 'رمز العملة الافتراضية',
                  hintText: 'مثال: ر.س أو SAR',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال رمز العملة';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Complete Setup Button
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _completeSetup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryMaroon,
                        foregroundColor: AppColors.textOnDark,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'إكمال الإعداد',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

