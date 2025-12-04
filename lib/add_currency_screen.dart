
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddCurrencyScreen extends StatefulWidget {
  const AddCurrencyScreen({super.key});

  @override
  State<AddCurrencyScreen> createState() => _AddCurrencyScreenState();
}

class _AddCurrencyScreenState extends State<AddCurrencyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _symbolController = TextEditingController();
  bool _isBaseCurrency = false;
  bool _isLoading = false;

  Future<void> _saveCurrency() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('User not logged in');

        final collection = FirebaseFirestore.instance.collection('currencies');

        // If setting a new base currency, ensure no other base currency exists for this user
        if (_isBaseCurrency) {
          final existingBase = await collection
              .where('userId', isEqualTo: user.uid)
              .where('isBase', isEqualTo: true)
              .limit(1)
              .get();
          if (existingBase.docs.isNotEmpty) {
            throw Exception('يمكن أن تكون هناك عملة أساسية واحدة فقط. الرجاء تعديل العملة الحالية أولاً.');
          }
        }

        await collection.add({
          'userId': user.uid,
          'name': _nameController.text.trim(),
          'symbol': _symbolController.text.trim(),
          'isBase': _isBaseCurrency,
          // Exchange rate for base currency is always 1
          'exchangeRate': _isBaseCurrency ? 1 : 0,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حفظ العملة بنجاح')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة عملة جديدة'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'اسم العملة (مثال: ريال يمني)', border: OutlineInputBorder()),
                validator: (value) => value!.trim().isEmpty ? 'الرجاء إدخال اسم العملة' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _symbolController,
                decoration: const InputDecoration(labelText: 'رمز العملة (مثال: ر.ي)', border: OutlineInputBorder()),
                validator: (value) => value!.trim().isEmpty ? 'الرجاء إدخال رمز العملة' : null,
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('تعيين كعملة أساسية'),
                value: _isBaseCurrency,
                onChanged: (bool value) {
                  setState(() {
                    _isBaseCurrency = value;
                  });
                },
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _saveCurrency,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                      ),
                      child: const Text('حفظ'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
