
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:untitled/services/transaction_service.dart' as ts;
import 'package:untitled/shared/widgets/loading_overlay.dart';
import 'package:untitled/shared/theme/app_theme.dart';
import 'package:untitled/shared/widgets/app_card.dart';
import 'package:untitled/core/services/account_service.dart';
import 'package:untitled/core/models/account_model.dart';
import 'package:untitled/core/services/exchange_rate_service.dart';
import 'package:untitled/core/services/currency_service.dart';

class SellCurrencyScreen extends StatefulWidget {
  const SellCurrencyScreen({super.key});

  @override
  State<SellCurrencyScreen> createState() => _SellCurrencyScreenState();
}

class _SellCurrencyScreenState extends State<SellCurrencyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fromAmountController = TextEditingController();
  final _exchangeRateController = TextEditingController();
  final _toAmountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _referenceNumberController = TextEditingController();

  String? _selectedFromCurrency;
  String? _selectedToCurrency;
  String? _selectedDebitAccount; // حساب العملة المستقبلة (المدين)
  String? _selectedCreditAccount; // حساب العملة المباعة (الدائن)

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  final ts.TransactionService _transactionService = ts.TransactionService();
  final AccountService _accountService = AccountService();
  final ExchangeRateService _exchangeRateService = ExchangeRateService();
  final CurrencyService _currencyService = CurrencyService();

  List<DropdownMenuItem<String>> _currencyItems = [];
  List<AccountModel> _accounts = [];
  
  double? _minRate;
  double? _maxRate;
  String? _rateInfo;

  @override
  void initState() {
    super.initState();
    _fetchDropdownData();
    _fromAmountController.addListener(_calculateToAmount);
    _exchangeRateController.addListener(_calculateToAmount);
    _exchangeRateController.addListener(_validateExchangeRate);
  }

  void _validateExchangeRate() {
    final rate = double.tryParse(_exchangeRateController.text);
    if (rate == null || _minRate == null || _maxRate == null) {
      setState(() => _rateInfo = null);
      return;
    }
    
    if (rate < _minRate! || rate > _maxRate!) {
      setState(() {
        _rateInfo = 'تحذير: السعر خارج النطاق المسموح (${_minRate!.toStringAsFixed(4)} - ${_maxRate!.toStringAsFixed(4)})';
      });
    } else {
      setState(() => _rateInfo = null);
    }
  }

  Future<void> _loadExchangeRate() async {
    if (_selectedFromCurrency == null || _selectedToCurrency == null) {
      setState(() {
        _minRate = null;
        _maxRate = null;
        _rateInfo = null;
      });
      return;
    }

    try {
      final exchangeRateData = await _exchangeRateService.getExchangeRate(
        fromCurrencyId: _selectedFromCurrency!,
        toCurrencyId: _selectedToCurrency!,
      );

      if (exchangeRateData != null) {
        setState(() {
          _minRate = exchangeRateData['minPrice'] as double;
          _maxRate = exchangeRateData['maxPrice'] as double;
          final basePrice = exchangeRateData['basePrice'] as double;
          _exchangeRateController.text = basePrice.toStringAsFixed(4);
          _rateInfo = 'السعر الرئيسي: ${basePrice.toStringAsFixed(4)} | النطاق المسموح: ${_minRate!.toStringAsFixed(4)} - ${_maxRate!.toStringAsFixed(4)}';
        });
        _calculateToAmount();
      } else {
        setState(() {
          _minRate = null;
          _maxRate = null;
          _rateInfo = 'لا يوجد سعر تحويل محدد. الرجاء تحديد سعر التحويل أولاً.';
        });
      }
    } catch (e) {
      setState(() {
        _minRate = null;
        _maxRate = null;
        _rateInfo = 'حدث خطأ في جلب سعر التحويل: ${e.toString()}';
      });
    }
  }

  void _calculateToAmount() {
    final fromAmount = double.tryParse(_fromAmountController.text) ?? 0;
    final exchangeRate = double.tryParse(_exchangeRateController.text) ?? 0;
    _toAmountController.text = (fromAmount * exchangeRate).toStringAsFixed(2);
  }

  Future<void> _fetchDropdownData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

      try {
      final currencies = await _currencyService.streamCurrencies().first;
      final currenciesItems = currencies.map((currency) => DropdownMenuItem<String>(
        value: currency.id,
        child: Text(currency.symbol),
      )).toList();

      final accounts = await _accountService.streamAccounts().first;

      setState(() {
        _currencyItems = currenciesItems;
        _accounts = accounts;
      });
      
      // Load exchange rate if currencies are already selected
      if (_selectedFromCurrency != null && _selectedToCurrency != null) {
        _loadExchangeRate();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ في تحميل البيانات: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _saveTransaction() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedFromCurrency == null || _selectedToCurrency == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار العملات')));
        return;
      }
      if (_selectedDebitAccount == null || _selectedCreditAccount == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار الحساب المدين والحساب الدائن')));
        return;
      }
      setState(() { _isLoading = true; });

      // Validate exchange rate range
      final exchangeRate = double.tryParse(_exchangeRateController.text) ?? 0.0;
      if (_minRate != null && _maxRate != null) {
        if (exchangeRate < _minRate! || exchangeRate > _maxRate!) {
          throw Exception('سعر الصرف يجب أن يكون بين ${_minRate!.toStringAsFixed(4)} و ${_maxRate!.toStringAsFixed(4)}');
        }
      }

      await _transactionService.createCurrencyExchangeTransaction(
        operationType: 'SellCurrency',
        fromCurrencyId: _selectedFromCurrency!,
        fromAmount: double.tryParse(_fromAmountController.text) ?? 0.0,
        toCurrencyId: _selectedToCurrency!,
        toAmount: double.tryParse(_toAmountController.text) ?? 0.0,
        exchangeRate: exchangeRate,
        debitAccountId: _selectedDebitAccount!, // حساب العملة المستقبلة (المدين)
        creditAccountId: _selectedCreditAccount!, // حساب العملة المباعة (الدائن)
        description: _descriptionController.text.trim(),
        date: _selectedDate,
        referenceNumber: _referenceNumberController.text.trim().isEmpty 
            ? null 
            : _referenceNumberController.text.trim(),
      );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حفظ عملية البيع بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بيع عملة'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: _currencyItems.isEmpty
            ? const Center(child: Text('الرجاء إضافة عملات أولاً'))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'بيانات عملية البيع',
                              style: AppTheme.heading3,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'العملة المباعة',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _fromAmountController,
                                    decoration: AppTheme.inputDecoration(
                                      'المبلغ',
                                      icon: Icons.attach_money,
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (v) => v?.isEmpty ?? true ? 'أدخل المبلغ' : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: 120,
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedFromCurrency,
                                    items: _currencyItems,
                                    onChanged: (val) {
                                      setState(() => _selectedFromCurrency = val);
                                      _loadExchangeRate();
                                    },
                                    decoration: AppTheme.inputDecoration(
                                      'العملة',
                                      icon: Icons.currency_exchange,
                                    ),
                                    validator: (value) => value == null ? 'اختر العملة' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _exchangeRateController,
                              decoration: AppTheme.inputDecoration(
                                'سعر الصرف',
                                icon: Icons.trending_up,
                              ),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'أدخل السعر';
                                final rate = double.tryParse(v);
                                if (rate == null || rate <= 0) {
                                  return 'سعر الصرف يجب أن يكون أكبر من الصفر';
                                }
                                if (_minRate != null && _maxRate != null) {
                                  if (rate < _minRate! || rate > _maxRate!) {
                                    return 'السعر يجب أن يكون بين ${_minRate!.toStringAsFixed(4)} و ${_maxRate!.toStringAsFixed(4)}';
                                  }
                                }
                                return null;
                              },
                            ),
                            if (_rateInfo != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _rateInfo!.contains('تحذير') || _rateInfo!.contains('خطأ')
                                      ? Colors.orange.shade50
                                      : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _rateInfo!.contains('تحذير') || _rateInfo!.contains('خطأ')
                                        ? Colors.orange
                                        : Colors.blue,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _rateInfo!.contains('تحذير') || _rateInfo!.contains('خطأ')
                                          ? Icons.warning
                                          : Icons.info,
                                      color: _rateInfo!.contains('تحذير') || _rateInfo!.contains('خطأ')
                                          ? Colors.orange
                                          : Colors.blue,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _rateInfo!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _rateInfo!.contains('تحذير') || _rateInfo!.contains('خطأ')
                                              ? Colors.orange.shade900
                                              : Colors.blue.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            const Text(
                              'العملة المشتراة',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _toAmountController,
                                    readOnly: true,
                                    decoration: AppTheme.inputDecoration(
                                      'المبلغ الناتج',
                                      icon: Icons.calculate,
                                    ).copyWith(fillColor: Colors.grey.shade200),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: 120,
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedToCurrency,
                                    items: _currencyItems,
                                    onChanged: (val) {
                                      setState(() => _selectedToCurrency = val);
                                      _loadExchangeRate();
                                    },
                                    decoration: AppTheme.inputDecoration(
                                      'العملة',
                                      icon: Icons.currency_exchange,
                                    ),
                                    validator: (value) => value == null ? 'اختر العملة' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 12),
                            const Text(
                              'الحسابات المحاسبية',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _selectedDebitAccount,
                              items: _accounts.map((account) => DropdownMenuItem<String>(
                                value: account.id,
                                child: Text('${account.name} (${account.type})'),
                              )).toList(),
                              onChanged: (val) => setState(() => _selectedDebitAccount = val),
                              decoration: AppTheme.inputDecoration(
                                'حساب العملة المستقبلة (مدين)',
                                icon: Icons.account_circle,
                              ),
                              validator: (value) => value == null ? 'اختر الحساب المدين' : null,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _selectedCreditAccount,
                              items: _accounts.map((account) => DropdownMenuItem<String>(
                                value: account.id,
                                child: Text('${account.name} (${account.type})'),
                              )).toList(),
                              onChanged: (val) => setState(() => _selectedCreditAccount = val),
                              decoration: AppTheme.inputDecoration(
                                'حساب العملة المباعة (دائن)',
                                icon: Icons.account_balance_wallet,
                              ),
                              validator: (value) => value == null ? 'اختر الحساب الدائن' : null,
                            ),
                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _descriptionController,
                              decoration: AppTheme.inputDecoration(
                                'البيان',
                                icon: Icons.description,
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _referenceNumberController,
                              decoration: AppTheme.inputDecoration(
                                'رقم المرجع (اختياري)',
                                icon: Icons.numbers,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ListTile(
                              title: Text(
                                'التاريخ: ${_selectedDate.toLocal().toString().split(' ')[0]}',
                                style: AppTheme.bodyLarge,
                              ),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: () async {
                                DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2101),
                                  locale: const Locale('ar', 'SA'),
                                );
                                if (picked != null) {
                                  setState(() => _selectedDate = picked);
                                }
                              },
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _saveTransaction,
                              icon: const Icon(Icons.save),
                              label: const Text('حفظ'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                              ),
                            ),
                          ],
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
    _fromAmountController.dispose();
    _exchangeRateController.dispose();
    _toAmountController.dispose();
    _descriptionController.dispose();
    _referenceNumberController.dispose();
    super.dispose();
  }
}
