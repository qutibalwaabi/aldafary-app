import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:untitled/core/models/user_profile_model.dart';
import 'package:untitled/core/services/user_profile_service.dart';
import 'package:untitled/shared/theme/app_theme.dart';
import 'package:untitled/shared/widgets/app_card.dart';
import 'package:untitled/shared/widgets/loading_overlay.dart';
import 'package:untitled/theme/app_colors.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _userProfileService = UserProfileService();
  final _imagePicker = ImagePicker();

  String? _logoUrl;
  bool _isLoading = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final profile = await _userProfileService.getUserProfile();
    if (profile != null && mounted) {
      setState(() {
        _nameController.text = profile.name;
        _phoneController.text = profile.phone ?? '';
        _emailController.text = profile.email ?? '';
        _addressController.text = profile.address ?? '';
        _logoUrl = profile.logoUrl;
      });
    }
  }

  Future<void> _pickLogo() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() => _isUploadingImage = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final file = File(image.path);
      final fileName = 'logo_${user.uid}.jpg';
      final ref = FirebaseStorage.instance.ref().child('users/$fileName');

      // Upload file with metadata
      final uploadTask = ref.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'max-age=3600',
        ),
      );
      
      // Wait for upload to complete
      await uploadTask;
      
      // Get download URL
      final downloadUrl = await ref.getDownloadURL();

      // Save logo URL to Firestore
      await _userProfileService.updateLogo(downloadUrl);
      setState(() => _logoUrl = downloadUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم رفع الشعار بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final profile = UserProfileModel(
        userId: user.uid,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        logoUrl: _logoUrl,
        createdAt: DateTime.now(),
      );

      await _userProfileService.saveUserProfile(profile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ البيانات بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        backgroundColor: AppColors.primaryMaroon,
        foregroundColor: AppColors.textOnDark,
        elevation: 0,
      ),
      body: LoadingOverlay(
        isLoading: _isLoading || _isUploadingImage,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo Section
                AppCard(
                  child: Column(
                    children: [
                      Text('الشعار', style: AppTheme.heading3),
                      const SizedBox(height: 20),
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: _logoUrl != null && _logoUrl!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  _logoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    // If network image fails, show default logo
                                    return Image.asset(
                                      'assets/images/logo.png',
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Icon(Icons.image, size: 48, color: Colors.grey.shade400);
                                      },
                                    );
                                  },
                                ),
                              )
                            : Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(Icons.image, size: 48, color: Colors.grey.shade400);
                                },
                              ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _pickLogo,
                        icon: const Icon(Icons.upload),
                        label: const Text('رفع شعار'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentGold,
                          foregroundColor: AppColors.textOnAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Personal Information
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('البيانات الشخصية', style: AppTheme.heading3),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nameController,
                        decoration: AppTheme.inputDecoration('الاسم الكامل', icon: Icons.person),
                        validator: (v) => v?.trim().isEmpty ?? true ? 'الرجاء إدخال الاسم' : null,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _phoneController,
                        decoration: AppTheme.inputDecoration('رقم الهاتف', icon: Icons.phone),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _emailController,
                        decoration: AppTheme.inputDecoration('البريد الإلكتروني', icon: Icons.email),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (!value.contains('@')) {
                              return 'الرجاء إدخال بريد إلكتروني صحيح';
                            }
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Address Section
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('العنوان', style: AppTheme.heading3),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _addressController,
                        decoration: AppTheme.inputDecoration('العنوان', icon: Icons.location_on),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Save Button
                ElevatedButton(
                  onPressed: _saveProfile,
                  style: AppTheme.primaryButtonStyle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'حفظ البيانات',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}

