import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:untitled/services/transaction_service.dart' as ts;
import 'package:untitled/transaction_details_screen.dart';
import 'package:untitled/theme/app_colors.dart';

class PaymentVoucherScreen extends StatefulWidget {
  const PaymentVoucherScreen({super.key});

  @override
  State<PaymentVoucherScreen> createState() => _PaymentVoucherScreenState();
}

class _PaymentVoucherScreenState extends State<PaymentVoucherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ts.TransactionService _transactionService = ts.TransactionService();

  String? _selectedDebitAccount;
  String? _selectedCreditAccount;
  String? _selectedCurrency;

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  List<DropdownMenuItem<String>> _accountItems = [];
  List<DropdownMenuItem<String>> _fundItems = [];
  List<DropdownMenuItem<String>> _currencyItems = [];

  @override
  void initState() {
    super.initState();
    _fetchDropdownData();
  }

  Future<void> _fetchDropdownData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final accountsSnapshot = await FirebaseFirestore.instance.collection('accounts').where('userId', isEqualTo: user.uid).get();
    final accounts = accountsSnapshot.docs.map((doc) => DropdownMenuItem<String>(value: doc.id, child: Text(doc['name']))).toList();
    final funds = accountsSnapshot.docs.where((doc) => doc['type'] == 'Cash' || doc['type'] == 'Bank').map((doc) => DropdownMenuItem<String>(value: doc.id, child: Text(doc['name']))).toList();

    final currenciesSnapshot = await FirebaseFirestore.instance.collection('currencies').where('userId', isEqualTo: user.uid).get();
    final currencies = currenciesSnapshot.docs.map((doc) => DropdownMenuItem<String>(value: doc.id, child: Text(doc['symbol']))).toList();

    setState(() {
      _accountItems = accounts;
      _fundItems = funds;
      _currencyItems = currencies;
    });
  }

  Future<void> _saveTransaction() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedDebitAccount == null || _selectedCreditAccount == null || _selectedCurrency == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء تعبئة جميع الحقول المنسدلة')));
        return;
      }
      setState(() { _isLoading = true; });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('User not logged in');

        await FirebaseFirestore.instance.collection('transactions').add({
          'userId': user.uid,
          'operationType': 'Payment',
          'debitAccountId': _selectedDebitAccount,
          'creditAccountId': _selectedCreditAccount,
          'amount': double.tryParse(_amountController.text) ?? 0.0,
          'currencyId': _selectedCurrency,
          'description': _descriptionController.text.trim(),
          'date': Timestamp.fromDate(_selectedDate),
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ سند الصرف بنجاح')));
          Navigator.of(context).pop();
        }
      } catch (e) {
        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: ${e.toString()}')));
      }
    }
  }

  void _showTransactionOptions(String transactionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خيارات العملية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.print),
              title: const Text('طباعة'),
              onTap: () {
                Navigator.of(context).pop();
                // TODO: Navigate to print screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('سيتم إضافة الطباعة قريباً')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('تعديل'),
              onTap: () {
                Navigator.of(context).pop();
                // TODO: Navigate to edit screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('سيتم إضافة التعديل قريباً')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('التفاصيل'),
              onTap: () async {
                Navigator.of(context).pop();
                // Navigate to details screen
                final transaction = await _transactionService.getTransactionById(transactionId);
                if (transaction != null && mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TransactionDetailsScreen(transaction: transaction),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سند صرف'), backgroundColor: Colors.red, foregroundColor: Colors.white),
      body: _accountItems.isEmpty
          ? const Center(child: Text('الرجاء إضافة حسابات وعملات أولاً'))
          : Column(
              children: [
                // Form Section
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(value: _selectedCreditAccount, items: _fundItems, onChanged: (val) => setState(() => _selectedCreditAccount = val), decoration: const InputDecoration(labelText: 'من حساب (الصندوق)', border: OutlineInputBorder())),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(value: _selectedDebitAccount, items: _accountItems, onChanged: (val) => setState(() => _selectedDebitAccount = val), decoration: const InputDecoration(labelText: 'إلى حساب (المدين)', border: OutlineInputBorder())),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: TextFormField(controller: _amountController, decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder()), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'أدخل المبلغ' : null)),
                                const SizedBox(width: 16),
                                SizedBox(width: 120, child: DropdownButtonFormField<String>(value: _selectedCurrency, items: _currencyItems, onChanged: (val) => setState(() => _selectedCurrency = val), decoration: const InputDecoration(labelText: 'العملة', border: OutlineInputBorder()))),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'البيان', border: OutlineInputBorder())),
                            const SizedBox(height: 16),
                            ListTile(title: Text('التاريخ: ${_selectedDate.toLocal().toString().split(' ')[0]}'), trailing: const Icon(Icons.calendar_today), onTap: () async {
                              DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2101));
                              if (picked != null) setState(() { _selectedDate = picked; });
                            }),
                            const SizedBox(height: 30),
                            _isLoading ? const CircularProgressIndicator() : ElevatedButton.icon(onPressed: _saveTransaction, icon: const Icon(Icons.save), label: const Text('حفظ'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Divider
                const Divider(height: 1),

                // Recent Transactions Section
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'آخر سندات الصرف',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Expanded(
                        child: StreamBuilder<List<ts.Transaction>>(
                          stream: _transactionService.streamTransactionsByType('Payment', limit: 50),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const Center(child: Text('لا توجد سندات صرف لعرضها'));
                            }

                            return ListView.builder(
                              itemCount: snapshot.data!.length,
                              itemBuilder: (context, index) {
                                final transaction = snapshot.data![index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  child: ListTile(
                                    title: Text(transaction.description),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(transaction.formattedDate),
                                        Text('من: ${transaction.creditAccountName} إلى: ${transaction.debitAccountName}'),
                                      ],
                                    ),
                                    trailing: Text(
                                      transaction.formattedCreditAmount,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    onTap: () => _showTransactionOptions(transaction.id),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}