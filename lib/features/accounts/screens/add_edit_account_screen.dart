import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:untitled/core/models/account_model.dart';
import 'package:untitled/core/services/account_service.dart';
import 'package:untitled/shared/theme/app_theme.dart';
import 'package:untitled/shared/widgets/app_card.dart';
import 'package:untitled/shared/widgets/loading_overlay.dart';
import 'package:untitled/theme/app_colors.dart';

class AddEditAccountScreen extends StatefulWidget {
  final AccountModel? account;

  const AddEditAccountScreen({super.key, this.account});

  @override
  State<AddEditAccountScreen> createState() => _AddEditAccountScreenState();
}

class _AddEditAccountScreenState extends State<AddEditAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _creditLimitController = TextEditingController(text: '0');
  final _accountService = AccountService();
  
  String? _selectedAccountType;
  bool _isLoading = false;
  bool _isSuspended = false;
  
  bool get _isEditing => widget.account != null;

  final List<Map<String, String>> _accountTypes = [
    {'value': 'Customer', 'label': 'عميل'},
    {'value': 'Vendor', 'label': 'مورد'},
    {'value': 'Cash', 'label': 'صندوق'},
    {'value': 'Bank', 'label': 'بنك'},
    {'value': 'Expense', 'label': 'مصروف'},
    {'value': 'Revenue', 'label': 'إيراد'},
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing && widget.account != null) {
      final account = widget.account!;
      _nameController.text = account.name;
      _creditLimitController.text = account.creditLimit.toString();
      _selectedAccountType = account.type;
      _isSuspended = account.isSuspended;
    }
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل دخول');
      }

      final account = AccountModel(
        id: widget.account?.id ?? '',
        userId: widget.account?.userId ?? user.uid, // Use existing userId or current user's uid
        name: _nameController.text.trim(),
        type: _selectedAccountType!,
        creditLimit: double.tryParse(_creditLimitController.text.trim()) ?? 0.0,
        isSuspended: _isSuspended, // Always use current value
        createdAt: widget.account?.createdAt ?? DateTime.now(),
      );

      if (_isEditing) {
        await _accountService.updateAccount(widget.account!.id, account);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث الحساب بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        await _accountService.createAccount(account);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حفظ الحساب بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
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
        title: Text(_isEditing ? 'تعديل حساب' : 'إضافة حساب جديد'),
        backgroundColor: AppColors.primaryMaroon,
        foregroundColor: AppColors.textOnDark,
        elevation: 0,
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isEditing ? 'تعديل بيانات الحساب' : 'بيانات الحساب الجديد',
                        style: AppTheme.heading3,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nameController,
                        decoration: AppTheme.inputDecoration('اسم الحساب', icon: Icons.account_circle),
                        validator: (v) => v?.trim().isEmpty ?? true ? 'الرجاء إدخال اسم الحساب' : null,
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _selectedAccountType,
                        decoration: AppTheme.inputDecoration('نوع الحساب', icon: Icons.category),
                        items: _accountTypes.map((type) {
                          return DropdownMenuItem<String>(
                            value: type['value'],
                            child: Text(type['label']!),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedAccountType = value),
                        validator: (value) => value == null ? 'الرجاء اختيار نوع الحساب' : null,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _creditLimitController,
                        decoration: AppTheme.inputDecoration('سقف الحساب', icon: Icons.credit_card),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'هذا الحقل مطلوب';
                          if (double.tryParse(value) == null) return 'الرجاء إدخال رقم صحيح';
                          return null;
                        },
                      ),
                      if (_isEditing) ...[
                        const SizedBox(height: 20),
                        SwitchListTile(
                          title: const Text('حساب موقف'),
                          subtitle: Text(
                            _isSuspended
                                ? 'الحساب موقف ولا يمكن إجراء معاملات عليه'
                                : 'الحساب نشط ويمكن إجراء المعاملات',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          value: _isSuspended,
                          onChanged: (value) => setState(() => _isSuspended = value),
                          activeColor: Colors.red,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saveAccount,
                  style: AppTheme.primaryButtonStyle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      _isEditing ? 'حفظ التعديلات' : 'حفظ الحساب',
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
    _creditLimitController.dispose();
    super.dispose();
  }
}

