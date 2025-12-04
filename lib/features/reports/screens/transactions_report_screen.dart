import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:untitled/services/transaction_service.dart' as ts;
import 'package:untitled/core/services/account_service.dart';
import 'package:untitled/core/services/currency_service.dart';
import 'package:untitled/core/models/account_model.dart';
import 'package:untitled/core/models/currency_model.dart';
import 'package:untitled/shared/widgets/loading_overlay.dart';
import 'package:untitled/shared/widgets/print_preview_screen.dart';
import 'package:untitled/shared/widgets/unified_report_service.dart';
import 'package:untitled/theme/app_colors.dart';
import 'package:untitled/utils/show_message_dialog.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class TransactionsReportScreen extends StatefulWidget {
  const TransactionsReportScreen({super.key});

  @override
  State<TransactionsReportScreen> createState() => _TransactionsReportScreenState();
}

class _TransactionsReportScreenState extends State<TransactionsReportScreen> {
  final _transactionService = ts.TransactionService();
  final _accountService = AccountService();
  final _currencyService = CurrencyService();
  
  final _searchController = TextEditingController();
  
  String? _selectedOperationType;
  AccountModel? _selectedAccount;
  CurrencyModel? _selectedCurrency;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  List<ts.Transaction> _transactions = [];
  List<ts.Transaction> _filteredTransactions = [];
  Map<String, String> _accountNames = {};
  Map<String, String> _currencySymbols = {};
  
  List<AccountModel> _accounts = [];
  List<CurrencyModel> _currencies = [];
  bool _showFilters = false;

  final List<String> _operationTypes = [
    'Receipt',
    'Payment',
    'Journal',
    'BuyCurrency',
    'SellCurrency',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _endDate = DateTime.now();
    _startDate = DateTime.now().subtract(const Duration(days: 30));
    _searchController.addListener(_applySearchFilter);
  }

  void _applySearchFilter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredTransactions = _transactions;
      } else {
        _filteredTransactions = _transactions.where((t) {
          return t.description.toLowerCase().contains(query) ||
              t.formattedSerialNumber.toLowerCase().contains(query) ||
              (t.referenceNumber?.toLowerCase().contains(query) ?? false) ||
              (_accountNames[t.debitAccountId]?.toLowerCase().contains(query) ?? false) ||
              (_accountNames[t.creditAccountId]?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
    });
  }

  Future<void> _loadData() async {
    try {
      final accounts = await _accountService.streamAccounts().first;
      final currencies = await _currencyService.streamCurrencies().first;
      
      // Build account names map
      final accountNamesMap = <String, String>{};
      for (var account in accounts) {
        accountNamesMap[account.id] = account.name;
      }
      
      // Build currency symbols map
      final currencySymbolsMap = <String, String>{};
      for (var currency in currencies) {
        currencySymbolsMap[currency.id] = currency.symbol;
      }
      
      setState(() {
        _accounts = accounts;
        _currencies = currencies;
        _accountNames = accountNamesMap;
        _currencySymbols = currencySymbolsMap;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ في تحميل البيانات: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _generateReport() async {
    // Show loading dialog
    if (mounted) {
      showLoadingDialog(context, message: 'جاري إنشاء التقرير...');
    }
    
    setState(() {
      _showFilters = false; // Hide filters after generating
    });

    try {
      final allTransactions = await _transactionService.streamAllTransactions().first;
      
      List<ts.Transaction> filtered = allTransactions;

      // Filter by operation type
      if (_selectedOperationType != null) {
        filtered = filtered.where((t) => t.operationType == _selectedOperationType).toList();
      }

      // Filter by account
      if (_selectedAccount != null) {
        filtered = filtered.where((t) => 
          t.debitAccountId == _selectedAccount!.id || 
          t.creditAccountId == _selectedAccount!.id
        ).toList();
      }

      // Filter by currency
      if (_selectedCurrency != null) {
        filtered = filtered.where((t) => t.currencyId == _selectedCurrency!.id).toList();
      }

      // Filter by date range
      if (_startDate != null || _endDate != null) {
        filtered = filtered.where((t) {
          if (_startDate != null && t.date.isBefore(_startDate!)) return false;
          if (_endDate != null) {
            final endDateWithTime = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
            if (t.date.isAfter(endDateWithTime)) return false;
          }
          return true;
        }).toList();
      }

      setState(() {
        _transactions = filtered;
        _filteredTransactions = filtered;
      });
      
      if (mounted) {
        hideLoadingDialog(context);
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

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryMaroon,
              onPrimary: AppColors.textOnDark,
              onSurface: AppColors.textOnLight,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryMaroon,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  String _getOperationTypeName(String type) {
    switch (type) {
      case 'Receipt':
        return 'سند قبض';
      case 'Payment':
        return 'سند صرف';
      case 'Journal':
        return 'قيد يومية';
      case 'BuyCurrency':
        return 'شراء عملة';
      case 'SellCurrency':
        return 'بيع عملة';
      default:
        return type;
    }
  }

  Color _getOperationTypeColor(String type) {
    switch (type) {
      case 'Receipt':
        return Colors.green;
      case 'Payment':
        return Colors.red;
      case 'Journal':
        return Colors.blue;
      case 'BuyCurrency':
      case 'SellCurrency':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Future<void> _handlePrint() async {
    await _exportToPrintPreview();
  }

  Future<void> _handleShare() async {
    if (_filteredTransactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات لعرضها')),
      );
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/transactions_report_${DateTime.now().millisecondsSinceEpoch}.txt');
      await file.writeAsString(_generateTextReport());
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'تقرير العمليات',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _handlePDF() async {
    await _exportToPrintPreview(action: ExportAction.pdf);
  }

  Future<void> _handleExcel() async {
    await _exportToPrintPreview(action: ExportAction.excel);
  }

  Future<void> _exportToPrintPreview({ExportAction? action}) async {
    if (_filteredTransactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات لعرضها')),
      );
      return;
    }
    
    // Generate report data
    final reportData = UnifiedReportService.generateTransactionsReport(
      transactions: _filteredTransactions,
      accountNames: _accountNames,
      currencySymbols: _currencySymbols,
      accountName: _selectedAccount?.name,
      startDate: _startDate,
      endDate: _endDate,
      operationType: _selectedOperationType,
    );

    if (!mounted) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PrintPreviewScreen(
          reportType: ReportType.transactionsReport,
          title: reportData['title'] as String,
          content: Container(),
          metadata: {
            ...reportData['metadata'] as Map<String, dynamic>,
            'headers': reportData['headers'] as List<String>,
            'rows': reportData['rows'] as List<List<dynamic>>,
            'initialAction': action?.name,
          },
        ),
      ),
    );
  }

  String _generateTextReport() {
    final buffer = StringBuffer();
    buffer.writeln('تقرير العمليات');
    if (_startDate != null && _endDate != null) {
      buffer.writeln('من ${DateFormat('yyyy-MM-dd').format(_startDate!)} إلى ${DateFormat('yyyy-MM-dd').format(_endDate!)}');
    }
    buffer.writeln('عدد العمليات: ${_filteredTransactions.length}');
    buffer.writeln('');
    buffer.writeln('─────────────────────');
    
    for (var transaction in _filteredTransactions) {
      buffer.writeln('${transaction.formattedSerialNumber} | ${_getOperationTypeName(transaction.operationType)}');
      buffer.writeln('${_accountNames[transaction.creditAccountId] ?? transaction.creditAccountId} → ${_accountNames[transaction.debitAccountId] ?? transaction.debitAccountId}');
      buffer.writeln('${NumberFormat('#,##0.00').format(transaction.amount)} ${_currencySymbols[transaction.currencyId] ?? transaction.currencyId}');
      buffer.writeln('${DateFormat('yyyy-MM-dd').format(transaction.date)} | ${transaction.description}');
      buffer.writeln('─────────────────────');
    }
    
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير العمليات'),
        backgroundColor: AppColors.primaryMaroon,
        foregroundColor: AppColors.textOnDark,
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_alt : Icons.filter_alt_outlined),
            onPressed: () {
              setState(() => _showFilters = !_showFilters);
            },
            tooltip: 'إظهار/إخفاء الفلاتر',
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Column(
          children: [
            // Compact Filters Section (Collapsible)
            if (_showFilters) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryMaroon.withOpacity(0.05),
                  border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedOperationType,
                            decoration: InputDecoration(
                              labelText: 'نوع العملية',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('جميع الأنواع', style: TextStyle(fontSize: 12)),
                              ),
                              ..._operationTypes.map((type) => DropdownMenuItem<String>(
                                value: type,
                                child: Text(_getOperationTypeName(type), style: const TextStyle(fontSize: 12)),
                              )),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedOperationType = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<AccountModel>(
                            value: _selectedAccount,
                            decoration: InputDecoration(
                              labelText: 'الحساب',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: [
                              const DropdownMenuItem<AccountModel>(
                                value: null,
                                child: Text('جميع الحسابات', style: TextStyle(fontSize: 12)),
                              ),
                              ..._accounts.map((account) => DropdownMenuItem<AccountModel>(
                                value: account,
                                child: Text(
                                  account.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              )),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedAccount = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<CurrencyModel>(
                            value: _selectedCurrency,
                            decoration: InputDecoration(
                              labelText: 'العملة',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: [
                              const DropdownMenuItem<CurrencyModel>(
                                value: null,
                                child: Text('جميع العملات', style: TextStyle(fontSize: 12)),
                              ),
                              ..._currencies.map((currency) => DropdownMenuItem<CurrencyModel>(
                                value: currency,
                                child: Text(
                                  '${currency.name} (${currency.symbol})',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              )),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedCurrency = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, true),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'الفترة',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              child: Text(
                                _startDate != null && _endDate != null
                                    ? '${DateFormat('yyyy-MM-dd').format(_startDate!)} - ${DateFormat('yyyy-MM-dd').format(_endDate!)}'
                                    : 'اختر الفترة',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _generateReport,
                          icon: const Icon(Icons.visibility, size: 18),
                          label: const Text('عرض', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryMaroon,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else if (_transactions.isNotEmpty) ...[
              // Compact summary bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryMaroon.withOpacity(0.05),
                  border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'عدد العمليات: ${_filteredTransactions.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    if (_startDate != null && _endDate != null)
                      Text(
                        '${DateFormat('yyyy-MM-dd').format(_startDate!)} - ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                  ],
                ),
              ),
            ],
            
            // Transactions Display - Priority to Data
            if (_filteredTransactions.isEmpty && !_isLoading) ...[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد عمليات لعرضها',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'اختر الفلاتر ثم اضغط "عرض"',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_filteredTransactions.isNotEmpty) ...[
              // Search Bar (Compact)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'بحث في العمليات...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ),
              
              // Elegant Compact Table
              Expanded(
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'تقرير العمليات',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryMaroon.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_filteredTransactions.length} عملية',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryMaroon,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Transactions Table
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 40,
                          dataRowMinHeight: 45,
                          dataRowMaxHeight: 70,
                          columnSpacing: 12,
                          headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
                          columns: const [
                            DataColumn(
                              label: Text('نوع العملية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              numeric: false,
                            ),
                            DataColumn(
                              label: Text('الحسابات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              numeric: false,
                            ),
                            DataColumn(
                              label: Text('المبلغ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              numeric: true,
                            ),
                            DataColumn(
                              label: Text('العملة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              numeric: false,
                            ),
                            DataColumn(
                              label: Text('التاريخ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              numeric: false,
                            ),
                            DataColumn(
                              label: Text('البيان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              numeric: false,
                            ),
                          ],
                          rows: _filteredTransactions.map((transaction) {
                            final operationColor = _getOperationTypeColor(transaction.operationType);
                            final debitName = _accountNames[transaction.debitAccountId] ?? transaction.debitAccountId;
                            final creditName = _accountNames[transaction.creditAccountId] ?? transaction.creditAccountId;
                            final currencySymbol = _currencySymbols[transaction.currencyId] ?? transaction.currencyId;
                            
                            return DataRow(
                              cells: [
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: operationColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _getOperationTypeName(transaction.operationType),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: operationColor,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 180,
                                    child: Text(
                                      '$creditName → $debitName',
                                      style: const TextStyle(fontSize: 10),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    NumberFormat('#,##0.00').format(transaction.amount),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: operationColor,
                                    ),
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    currencySymbol,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    DateFormat('yyyy-MM-dd').format(transaction.date),
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 150,
                                    child: Text(
                                      transaction.description,
                                      style: const TextStyle(fontSize: 10),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Action Button - Print Only (opens preview screen)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _handlePrint,
                      icon: const Icon(Icons.print, size: 24),
                      label: const Text(
                        'طباعة',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryMaroon,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }


  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

enum ExportAction {
  print,
  pdf,
  excel,
}
