
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddAccountScreen extends StatefulWidget {
  final QueryDocumentSnapshot? accountDocument;

  const AddAccountScreen({super.key, this.accountDocument});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _creditLimitController = TextEditingController(text: '0');
  String? _selectedAccountType;
  bool _isLoading = false;
  bool get _isEditing => widget.accountDocument != null;

  final List<String> _accountTypes = ['Customer', 'Vendor', 'Cash', 'Bank', 'Expense', 'Revenue'];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final data = widget.accountDocument!.data() as Map<String, dynamic>;
      _nameController.text = data['name'];
      _creditLimitController.text = (data['creditLimit'] ?? 0.0).toString();
      _selectedAccountType = data['type'];
    }
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final accountData = {
        'userId': user.uid,
        'name': _nameController.text.trim(),
        'type': _selectedAccountType,
        'creditLimit': double.tryParse(_creditLimitController.text.trim()) ?? 0.0,
        'lastModified': FieldValue.serverTimestamp(),
      };

      if (_isEditing) {
        await widget.accountDocument!.reference.update(accountData);
      } else {
        accountData['balance'] = 0;
        accountData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('accounts').add(accountData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? 'تم تحديث الحساب بنجاح' : 'تم حفظ الحساب بنجاح')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'تعديل حساب' : 'إضافة حساب جديد'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'اسم الحساب'), validator: (v) => v!.trim().isEmpty ? 'الرجاء إدخال اسم الحساب' : null),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedAccountType,
                decoration: const InputDecoration(labelText: 'نوع الحساب'),
                items: _accountTypes.map((String type) => DropdownMenuItem<String>(value: type, child: Text(type))).toList(),
                onChanged: (newValue) => setState(() => _selectedAccountType = newValue!),
                validator: (value) => value == null ? 'الرجاء اختيار نوع الحساب' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _creditLimitController,
                decoration: const InputDecoration(labelText: 'سقف الحساب'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'هذا الحقل مطلوب';
                  if (double.tryParse(value) == null) return 'الرجاء إدخال رقم صحيح';
                  return null;
                },
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(onPressed: _saveAccount, child: Text(_isEditing ? 'حفظ التعديلات' : 'حفظ')),
            ],
          ),
        ),
      ),
    );
  }
}
