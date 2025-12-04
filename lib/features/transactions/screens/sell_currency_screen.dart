import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:untitled/services/transaction_service.dart' as ts;
import 'package:untitled/core/services/currency_service.dart';
import 'package:untitled/core/services/account_service.dart';
import 'package:untitled/core/services/exchange_rate_service.dart';
import 'package:untitled/core/models/account_model.dart';
import 'package:untitled/shared/widgets/loading_overlay.dart';
import 'package:untitled/utils/show_message_dialog.dart';
import 'package:untitled/shared/theme/app_theme.dart';
import 'package:untitled/shared/widgets/app_card.dart';
import 'package:untitled/shared/widgets/transaction_details_dialog.dart';
import 'package:untitled/theme/app_colors.dart';

class SellCurrencyScreen extends StatefulWidget {
  final String? transactionId; // For editing

  const SellCurrencyScreen({super.key, this.transactionId});

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
  final _searchController = TextEditingController();
  final ts.TransactionService _transactionService = ts.TransactionService();
  final CurrencyService _currencyService = CurrencyService();
  final AccountService _accountService = AccountService();
  final ExchangeRateService _exchangeRateService = ExchangeRateService();

  String? _selectedFromCurrency;
  String? _selectedToCurrency;
  String? _selectedDebitAccount; // حساب العملة المباعة (المدين)
  String? _selectedCreditAccount; // حساب العملة المستقبلة (الدائن)
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  Map<String, String> _currencySymbols = {};
  List<DropdownMenuItem<String>> _currencyItems = [];
  List<AccountModel> _accounts = [];
  double? _minRate;
  double? _maxRate;
  String? _rateInfo;
  String? _editingTransactionId;

  @override
  void initState() {
    super.initState();
    _editingTransactionId = widget.transactionId;
    _fetchDropdownData().then((_) {
      if (_editingTransactionId != null) {
        _loadTransactionForEdit().then((_) {
          if (mounted) {
            // Open bottom sheet for editing after data is loaded
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showAddTransactionBottomSheet();
            });
          }
        });
      }
    });
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
  
  Future<void> _loadTransactionForEdit() async {
    if (_editingTransactionId == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final transaction = await _transactionService.getTransactionById(_editingTransactionId!);
      
      if (transaction != null && mounted) {
        setState(() {
          _fromAmountController.text = transaction.fromAmount?.toString() ?? '0.0';
          _toAmountController.text = transaction.toAmount?.toString() ?? '0.0';
          _exchangeRateController.text = transaction.exchangeRate?.toString() ?? '0.0';
          _descriptionController.text = transaction.description;
          _referenceNumberController.text = transaction.referenceNumber ?? '';
          _selectedFromCurrency = transaction.fromCurrencyId;
          _selectedToCurrency = transaction.toCurrencyId;
          _selectedDate = transaction.date;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ في تحميل البيانات: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateToAmount() {
    final fromAmount = double.tryParse(_fromAmountController.text) ?? 0;
    final exchangeRate = double.tryParse(_exchangeRateController.text) ?? 0;
    if (exchangeRate == 0) {
      _toAmountController.text = '0.00';
      return;
    }
    _toAmountController.text = (fromAmount * exchangeRate).toStringAsFixed(2);
  }

  Future<void> _fetchDropdownData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final currencies = await _currencyService.streamCurrencies().first;
      final currenciesItems = currencies
          .map((currency) => DropdownMenuItem<String>(
                value: currency.id,
                child: Text(currency.symbol),
              ))
          .toList();

      final currencySymbolsMap = <String, String>{};
      for (var currency in currencies) {
        currencySymbolsMap[currency.id] = currency.symbol;
      }

      final accounts = await _accountService.streamAccounts().first;

      setState(() {
        _currencyItems = currenciesItems;
        _currencySymbols = currencySymbolsMap;
        _accounts = accounts;
      });
      
      // Load exchange rate if currencies are already selected
      if (_selectedFromCurrency != null && _selectedToCurrency != null) {
        _loadExchangeRate();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFromCurrency == null || _selectedToCurrency == null) {
      if (mounted) {
        showMessageDialog(
          context,
          title: 'خطأ في البيانات',
          message: 'الرجاء اختيار العملات',
          type: MessageType.error,
        );
      }
      return;
    }

    if (_selectedFromCurrency == _selectedToCurrency) {
      if (mounted) {
        showMessageDialog(
          context,
          title: 'خطأ في البيانات',
          message: 'العملتان يجب أن تكونا مختلفتين',
          type: MessageType.error,
        );
      }
      return;
    }

    // Show loading dialog
    if (mounted) {
      showLoadingDialog(context, message: 'جاري حفظ العملية...');
    }

    try {
      final fromAmount = double.tryParse(_fromAmountController.text) ?? 0.0;
      final toAmount = double.tryParse(_toAmountController.text) ?? 0.0;
      final exchangeRate = double.tryParse(_exchangeRateController.text) ?? 0.0;
      final description = _descriptionController.text.trim();
      final referenceNumber = _referenceNumberController.text.trim().isEmpty
          ? null
          : _referenceNumberController.text.trim();
      
      if (_editingTransactionId != null) {
        // Update existing transaction
        await _transactionService.updateCurrencyExchangeTransaction(
          transactionId: _editingTransactionId!,
          fromCurrencyId: _selectedFromCurrency!,
          fromAmount: fromAmount,
          toCurrencyId: _selectedToCurrency!,
          toAmount: toAmount,
          exchangeRate: exchangeRate,
          description: description,
          date: _selectedDate,
          referenceNumber: referenceNumber,
        );
        
        if (mounted) {
          hideLoadingDialog(context);
          Navigator.of(context).pop(); // Close bottom sheet
          showMessageDialog(
            context,
            title: 'نجح الحفظ',
            message: 'تم تعديل عملية البيع بنجاح',
            type: MessageType.success,
          );
        }
      } else {
        // Create new transaction
        if (_selectedDebitAccount == null || _selectedCreditAccount == null) {
          if (mounted) {
            hideLoadingDialog(context);
            showMessageDialog(
              context,
              title: 'خطأ في البيانات',
              message: 'الرجاء اختيار الحساب المدين والحساب الدائن',
              type: MessageType.error,
            );
          }
          return;
        }

        // Validate exchange rate range
        if (_minRate != null && _maxRate != null) {
          if (exchangeRate < _minRate! || exchangeRate > _maxRate!) {
            if (mounted) {
              hideLoadingDialog(context);
              showMessageDialog(
                context,
                title: 'خطأ في سعر الصرف',
                message: 'سعر الصرف يجب أن يكون بين ${_minRate!.toStringAsFixed(4)} و ${_maxRate!.toStringAsFixed(4)}',
                type: MessageType.error,
              );
            }
            return;
          }
        }

        await _transactionService.createCurrencyExchangeTransaction(
          operationType: 'SellCurrency',
          fromCurrencyId: _selectedFromCurrency!,
          fromAmount: fromAmount,
          toCurrencyId: _selectedToCurrency!,
          toAmount: toAmount,
          exchangeRate: exchangeRate,
          debitAccountId: _selectedDebitAccount!,
          creditAccountId: _selectedCreditAccount!,
          description: description,
          date: _selectedDate,
          referenceNumber: referenceNumber,
        );

        if (mounted) {
          hideLoadingDialog(context);
          Navigator.of(context).pop(); // Close bottom sheet
          showMessageDialog(
            context,
            title: 'نجح الحفظ',
            message: 'تم حفظ عملية البيع بنجاح',
            type: MessageType.success,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        hideLoadingDialog(context);
        showMessageDialog(
          context,
          title: 'خطأ',
          message: 'حدث خطأ: ${e.toString()}',
          type: MessageType.error,
        );
      }
    }
  }

  void _showAddTransactionBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: LoadingOverlay(
          isLoading: _isLoading,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _editingTransactionId != null ? 'تعديل عملية بيع عملة' : 'إضافة عملية بيع عملة',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
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
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'أدخل المبلغ';
                                  }
                                  final amount = double.tryParse(v);
                                  if (amount == null || amount <= 0) {
                                    return 'المبلغ يجب أن يكون أكبر من الصفر';
                                  }
                                  return null;
                                },
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
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'أدخل سعر الصرف';
                            }
                            final rate = double.tryParse(v);
                            if (rate == null || rate <= 0) {
                              return 'سعر الصرف يجب أن يكون أكبر من الصفر';
                            }
                            if (_minRate != null && _maxRate != null) {
                              if (rate < _minRate! || rate > _maxRate!) {
                                return 'سعر الصرف يجب أن يكون بين ${_minRate!.toStringAsFixed(4)} و ${_maxRate!.toStringAsFixed(4)}';
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
                              color: _rateInfo!.startsWith('تحذير') ? Colors.orange.shade50 : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _rateInfo!.startsWith('تحذير') ? Colors.orange.shade300 : Colors.blue.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _rateInfo!.startsWith('تحذير') ? Icons.warning : Icons.info,
                                  color: _rateInfo!.startsWith('تحذير') ? Colors.orange : Colors.blue,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _rateInfo!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _rateInfo!.startsWith('تحذير') ? Colors.orange.shade900 : Colors.blue.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          value: _selectedDebitAccount,
                          items: _accounts.map((account) => DropdownMenuItem<String>(
                            value: account.id,
                            child: Text(account.name),
                          )).toList(),
                          onChanged: (val) => setState(() => _selectedDebitAccount = val),
                          decoration: AppTheme.inputDecoration(
                            'الحساب المدين (حساب العملة المباعة)',
                            icon: Icons.account_balance,
                          ),
                          validator: (value) => value == null ? 'الرجاء اختيار الحساب المدين' : null,
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          value: _selectedCreditAccount,
                          items: _accounts.map((account) => DropdownMenuItem<String>(
                            value: account.id,
                            child: Text(account.name),
                          )).toList(),
                          onChanged: (val) => setState(() => _selectedCreditAccount = val),
                          decoration: AppTheme.inputDecoration(
                            'الحساب الدائن (حساب العملة المستقبلة)',
                            icon: Icons.account_balance_wallet,
                          ),
                          validator: (value) => value == null ? 'الرجاء اختيار الحساب الدائن' : null,
                        ),
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
                                onChanged: (val) => setState(() => _selectedToCurrency = val),
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
                          controller: _descriptionController,
                          decoration: AppTheme.inputDecoration(
                            'البيان',
                            icon: Icons.description,
                          ),
                          maxLines: 2,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'أدخل البيان';
                            }
                            return null;
                          },
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
                            'التاريخ: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
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
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<ts.Transaction> _filterTransactions(List<ts.Transaction> transactions, String searchQuery) {
    if (searchQuery.isEmpty) return transactions;

    final query = searchQuery.toLowerCase();
    return transactions.where((t) {
      return t.description.toLowerCase().contains(query) ||
          t.formattedSerialNumber.toLowerCase().contains(query) ||
          (t.referenceNumber?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بيع عملة'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'بحث في العمليات...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const Divider(height: 1),

          // Transactions List
          Expanded(
            child: StreamBuilder<List<ts.Transaction>>(
              stream: _transactionService.streamTransactionsByType('SellCurrency'),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'حدث خطأ: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.trending_up, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد عمليات بيع لعرضها',
                            style: AppTheme.bodyLarge.copyWith(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'ابدأ بإضافة عملية بيع جديدة',
                            style: AppTheme.bodyMedium.copyWith(
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final allTransactions = snapshot.data!;
                final filtered = _filterTransactions(allTransactions, _searchController.text);

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'لا توجد نتائج للبحث',
                        style: AppTheme.bodyLarge.copyWith(color: Colors.grey),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final transaction = filtered[index];
                    final fromCurrencySymbol = _currencySymbols[transaction.fromCurrencyId ?? ''] ?? transaction.fromCurrencyId ?? '';
                    final toCurrencySymbol = _currencySymbols[transaction.toCurrencyId ?? ''] ?? transaction.toCurrencyId ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200, width: 1),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            final transactionDetails = await _transactionService.getTransactionById(transaction.id);
                            if (transactionDetails != null && mounted) {
                              showTransactionDetailsDialog(context, transactionDetails);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      transaction.formattedSerialNumber.split('-').last,
                                      style: TextStyle(
                                        color: Colors.orange.shade700,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // First line: Currencies and Amount (Prominent)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${fromCurrencySymbol.isNotEmpty ? fromCurrencySymbol : transaction.fromCurrencyId ?? ''} → ${toCurrencySymbol.isNotEmpty ? toCurrencySymbol : transaction.toCurrencyId ?? ''}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                                fontFamily: 'Cairo',
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${NumberFormat('#,##0.00').format(transaction.fromAmount ?? transaction.amount)} ${fromCurrencySymbol.isNotEmpty ? fromCurrencySymbol : transaction.fromCurrencyId ?? ''}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange,
                                              fontFamily: 'Cairo',
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      // Second line: Description and Date (Less prominent)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              transaction.description,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                                fontFamily: 'Cairo',
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(Icons.calendar_today, size: 11, color: Colors.grey.shade500),
                                          const SizedBox(width: 4),
                                          Text(
                                            transaction.formattedDate,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade600,
                                              fontFamily: 'Cairo',
                                            ),
                                          ),
                                        ],
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
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTransactionBottomSheet,
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'إضافة',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
    _searchController.dispose();
    super.dispose();
  }
}

