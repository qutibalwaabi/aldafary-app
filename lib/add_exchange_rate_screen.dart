
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddExchangeRateScreen extends StatefulWidget {
  const AddExchangeRateScreen({super.key});

  @override
  State<AddExchangeRateScreen> createState() => _AddExchangeRateScreenState();
}

class _AddExchangeRateScreenState extends State<AddExchangeRateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _rateController = TextEditingController();
  String? _fromCurrencyId;
  String? _toCurrencyId;
  bool _isLoading = false;

  List<DropdownMenuItem<String>> _currencyItems = [];

  @override
  void initState() {
    super.initState();
    _fetchCurrencies();
  }

  Future<void> _fetchCurrencies() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance.collection('currencies').where('userId', isEqualTo: user.uid).get();
    final items = snapshot.docs.map((doc) {
      return DropdownMenuItem<String>(
        value: doc.id,
        child: Text(doc['name']),
      );
    }).toList();
    setState(() => _currencyItems = items);
  }

  Future<void> _saveRate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromCurrencyId == null || _toCurrencyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار العملات')));
      return;
    }
    setState(() { _isLoading = true; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');
      
      // Create a unique ID for the currency pair to prevent duplicates
      final rateId = '${_fromCurrencyId}_${_toCurrencyId}';

      await FirebaseFirestore.instance.collection('exchange_rates').doc(rateId).set({
        'userId': user.uid,
        'fromCurrencyId': _fromCurrencyId,
        'toCurrencyId': _toCurrencyId,
        'rate': double.tryParse(_rateController.text) ?? 0.0,
        'lastModified': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ سعر التحويل')));
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
      appBar: AppBar(title: const Text('إضافة/تعديل سعر التحويل')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _fromCurrencyId,
                items: _currencyItems,
                onChanged: (val) => setState(() => _fromCurrencyId = val),
                decoration: const InputDecoration(labelText: 'من عملة', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _toCurrencyId,
                items: _currencyItems,
                onChanged: (val) => setState(() => _toCurrencyId = val),
                decoration: const InputDecoration(labelText: 'إلى عملة', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rateController,
                decoration: const InputDecoration(labelText: 'سعر التحويل', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.isEmpty) ? 'الرجاء إدخال السعر' : null,
              ),
              const SizedBox(height: 30),
              _isLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _saveRate, child: const Text('حفظ')),
            ],
          ),
        ),
      ),
    );
  }
}
