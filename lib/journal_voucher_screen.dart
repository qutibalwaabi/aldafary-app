import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:untitled/services/transaction_service.dart' as ts;
import 'package:untitled/core/services/account_service.dart';
import 'package:untitled/core/services/currency_service.dart';
import 'package:untitled/shared/theme/app_theme.dart';
import 'package:untitled/shared/widgets/app_card.dart';
import 'package:untitled/shared/widgets/loading_overlay.dart';
import 'package:untitled/utils/show_message_dialog.dart';
import 'package:untitled/theme/app_colors.dart';
import 'package:untitled/shared/widgets/transaction_details_dialog.dart';

class JournalVoucherScreen extends StatefulWidget {
  final String? transactionId; // For editing existing transaction
  
  const JournalVoucherScreen({super.key, this.transactionId});

  @override
  State<JournalVoucherScreen> createState() => _JournalVoucherScreenState();
}

class _JournalVoucherScreenState extends State<JournalVoucherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _referenceNumberController = TextEditingController();
  final _searchController = TextEditingController();
  final ts.TransactionService _transactionService = ts.TransactionService();
  final AccountService _accountService = AccountService();
  final CurrencyService _currencyService = CurrencyService();

  String? _selectedDebitAccount;
  String? _selectedCreditAccount;
  String? _selectedCurrency;

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  Map<String, String> _accountNames = {};
  Map<String, String> _currencySymbols = {}; // Map: currencyId -> symbol

  List<DropdownMenuItem<String>> _accountItems = [];
  List<DropdownMenuItem<String>> _currencyItems = [];
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
              _showAddJournalBottomSheet();
            });
          }
        });
      }
    });
  }
  
  Future<void> _loadTransactionForEdit() async {
    if (_editingTransactionId == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final transaction = await _transactionService.getTransactionById(_editingTransactionId!);
      
      if (transaction != null && mounted) {
        setState(() {
          _amountController.text = transaction.amount.toString();
          _descriptionController.text = transaction.description;
          _referenceNumberController.text = transaction.referenceNumber ?? '';
          _selectedDebitAccount = transaction.debitAccountId;
          _selectedCreditAccount = transaction.creditAccountId;
          _selectedCurrency = transaction.currencyId;
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

  Future<void> _fetchDropdownData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final accounts = await _accountService.streamAccounts().first;
      
      // Build account names map
      final accountNamesMap = <String, String>{};
      for (var account in accounts) {
        accountNamesMap[account.id] = account.name;
      }

      final accountsItems = accounts
          .map((account) => DropdownMenuItem<String>(
                value: account.id,
                child: Text('${account.name} (${account.type})'),
              ))
          .toList();

      final currencies = await _currencyService.streamCurrencies().first;
      final currenciesItems = currencies
          .map((currency) => DropdownMenuItem<String>(
                value: currency.id,
                child: Text(currency.symbol),
              ))
          .toList();
      
      // Build currency symbols map
      final currencySymbolsMap = <String, String>{};
      for (var currency in currencies) {
        currencySymbolsMap[currency.id] = currency.symbol;
      }

      setState(() {
        _accountItems = accountsItems;
        _currencyItems = currenciesItems;
        _accountNames = accountNamesMap;
        _currencySymbols = currencySymbolsMap;
      });
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

    if (_selectedDebitAccount == null ||
        _selectedCreditAccount == null ||
        _selectedCurrency == null) {
      if (mounted) {
        showMessageDialog(
          context,
          title: 'خطأ في البيانات',
          message: 'الرجاء تعبئة جميع الحقول المنسدلة',
          type: MessageType.error,
        );
      }
      return;
    }

    // Validate that debit account != credit account
    if (_selectedDebitAccount == _selectedCreditAccount) {
      if (mounted) {
        showMessageDialog(
          context,
          title: 'خطأ في البيانات',
          message: 'الحساب المدين والدائن يجب أن يكونا مختلفين',
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
      final amount = double.tryParse(_amountController.text) ?? 0.0;
      final description = _descriptionController.text.trim();
      final referenceNumber = _referenceNumberController.text.trim().isEmpty 
          ? null 
          : _referenceNumberController.text.trim();
      
      if (_editingTransactionId != null) {
        // Update existing transaction
        await _transactionService.updateTransaction(
          transactionId: _editingTransactionId!,
          debitAccountId: _selectedDebitAccount!,
          creditAccountId: _selectedCreditAccount!,
          amount: amount,
          currencyId: _selectedCurrency!,
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
            message: 'تم تعديل قيد اليومية بنجاح',
            type: MessageType.success,
          );
        }
      } else {
        // Create new transaction
        await _transactionService.createTransaction(
          operationType: 'Journal',
          debitAccountId: _selectedDebitAccount!,
          creditAccountId: _selectedCreditAccount!,
          amount: amount,
          currencyId: _selectedCurrency!,
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
            message: 'تم حفظ قيد اليومية بنجاح',
            type: MessageType.success,
          );
          // Clear form
          _amountController.clear();
          _descriptionController.clear();
          _referenceNumberController.clear();
          _selectedDebitAccount = null;
          _selectedCreditAccount = null;
          _selectedCurrency = null;
          _selectedDate = DateTime.now();
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

  void _showAddJournalBottomSheet() {
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
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryMaroon,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Text(
                    _editingTransactionId != null ? 'تعديل قيد يومية' : 'إضافة قيد يومية',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedDebitAccount,
                        items: _accountItems,
                        onChanged: (val) =>
                            setState(() => _selectedDebitAccount = val),
                        decoration: AppTheme.inputDecoration(
                          'من حساب (مدين)',
                          icon: Icons.account_circle,
                        ),
                        validator: (value) =>
                            value == null ? 'الرجاء اختيار الحساب المدين' : null,
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _selectedCreditAccount,
                        items: _accountItems,
                        onChanged: (val) =>
                            setState(() => _selectedCreditAccount = val),
                        decoration: AppTheme.inputDecoration(
                          'إلى حساب (دائن)',
                          icon: Icons.account_circle,
                        ),
                        validator: (value) =>
                            value == null ? 'الرجاء اختيار الحساب الدائن' : null,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _amountController,
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
                              value: _selectedCurrency,
                              items: _currencyItems,
                              onChanged: (val) =>
                                  setState(() => _selectedCurrency = val),
                              decoration: AppTheme.inputDecoration(
                                'العملة',
                                icon: Icons.currency_exchange,
                              ),
                              validator: (value) =>
                                  value == null ? 'اختر العملة' : null,
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
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          await _saveTransaction();
                          // Don't close if editing, let _saveTransaction handle it
                          if (mounted && !_isLoading && _editingTransactionId == null) {
                            Navigator.pop(context);
                          }
                        },
                        style: AppTheme.primaryButtonStyle.copyWith(
                          minimumSize: const MaterialStatePropertyAll(Size(double.infinity, 50)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            _editingTransactionId != null ? 'حفظ التعديلات' : 'حفظ قيد اليومية',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('قيد يومية'),
        backgroundColor: AppColors.primaryMaroon,
        foregroundColor: AppColors.textOnDark,
        elevation: 0,
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: _accountItems.isEmpty
          ? const Center(child: Text('الرجاء إضافة حسابات وعملات أولاً'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'بحث...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (value) {
                          // Will be handled in StreamBuilder
                        },
                      ),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'قيود اليومية',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<ts.Transaction>>(
                    stream: _transactionService.streamTransactionsByType('Journal', limit: 50),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                'لا توجد قيود يومية',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'انقر على زر + لإضافة قيد يومية جديد',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                              ),
                            ],
                          ),
                        );
                      }

                      final transactions = snapshot.data!;
                      final searchQuery = _searchController.text;
                      
                      // Filter transactions
                      final filtered = searchQuery.isEmpty
                          ? transactions
                          : transactions.where((t) {
                              final query = searchQuery.toLowerCase();
                              return t.description.toLowerCase().contains(query) ||
                                  t.formattedSerialNumber.toLowerCase().contains(query) ||
                                  (t.referenceNumber?.toLowerCase().contains(query) ?? false) ||
                                  (_accountNames[t.debitAccountId]?.toLowerCase().contains(query) ?? false) ||
                                  (_accountNames[t.creditAccountId]?.toLowerCase().contains(query) ?? false);
                            }).toList();

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final transaction = filtered[index];
                          final debitName = _accountNames[transaction.debitAccountId] ?? transaction.debitAccountId;
                          final creditName = _accountNames[transaction.creditAccountId] ?? transaction.creditAccountId;
                          
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
                                          color: AppColors.primaryMaroon.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: Text(
                                            transaction.formattedSerialNumber.split('-').last,
                                            style: TextStyle(
                                              color: AppColors.primaryMaroon,
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
                                            // First line: Description and Amount
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    transaction.description,
                                                    style: const TextStyle(
                                                      fontSize: 14,
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
                                                  '${NumberFormat('#,##0.00').format(transaction.amount)} ${_currencySymbols[transaction.currencyId] ?? transaction.currencyId}',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primaryMaroon,
                                                    fontFamily: 'Cairo',
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            // Second line: Accounts and Date
                                            Row(
                                              children: [
                                                Icon(Icons.account_circle, size: 12, color: Colors.grey.shade600),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    '$debitName → $creditName',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade700,
                                                      fontFamily: 'Cairo',
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                                                const SizedBox(width: 4),
                                                Text(
                                                  transaction.formattedDate,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade700,
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddJournalBottomSheet,
        backgroundColor: AppColors.primaryMaroon,
        icon: const Icon(Icons.add),
        label: const Text('إضافة قيد يومية'),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _referenceNumberController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
