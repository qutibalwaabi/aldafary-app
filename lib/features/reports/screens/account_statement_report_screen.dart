import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:untitled/core/services/account_statement_service_currency_separated.dart';
import 'package:untitled/core/services/account_service.dart';
import 'package:untitled/core/services/currency_service.dart';
import 'package:untitled/core/models/account_model.dart';
import 'package:untitled/core/models/currency_model.dart';
import 'package:untitled/shared/widgets/loading_overlay.dart';
import 'package:untitled/shared/widgets/print_preview_screen.dart';
import 'package:untitled/shared/widgets/unified_report_service.dart';
import 'package:untitled/theme/app_colors.dart';
import 'package:untitled/utils/show_message_dialog.dart';
import 'package:untitled/core/services/account_statement_service.dart' as old_service;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AccountStatementReportScreen extends StatefulWidget {
  const AccountStatementReportScreen({super.key});

  @override
  State<AccountStatementReportScreen> createState() => _AccountStatementReportScreenState();
}

class _AccountStatementReportScreenState extends State<AccountStatementReportScreen> {
  final _statementService = AccountStatementServiceCurrencySeparated();
  final _accountService = AccountService();
  final _currencyService = CurrencyService();
  final _searchController = TextEditingController();
  
  AccountModel? _selectedAccount;
  CurrencyModel? _selectedCurrency;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  Map<String, AccountStatementByCurrency> _statementsByCurrency = {};
  
  List<AccountModel> _accounts = [];
  List<CurrencyModel> _currencies = [];
  List<AccountModel> _filteredAccounts = [];
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _endDate = DateTime.now();
    _startDate = DateTime.now().subtract(const Duration(days: 30));
    _searchController.addListener(_filterAccounts);
  }

  void _filterAccounts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredAccounts = _accounts;
      } else {
        _filteredAccounts = _accounts.where((account) {
          return account.name.toLowerCase().contains(query) ||
              account.type.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadData() async {
    try {
      final accounts = await _accountService.streamAccounts().first;
      final currencies = await _currencyService.streamCurrencies().first;
      setState(() {
        _accounts = accounts;
        _currencies = currencies;
        _filteredAccounts = accounts;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ في تحميل البيانات: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _generateStatement() async {
    if (_selectedAccount == null) {
      if (mounted) {
        showMessageDialog(
          context,
          title: 'خطأ في البيانات',
          message: 'الرجاء اختيار حساب',
          type: MessageType.error,
        );
      }
      return;
    }

    // Show loading dialog
    if (mounted) {
      showLoadingDialog(context, message: 'جاري إنشاء كشف الحساب...');
    }
    
    setState(() {
      _showFilters = false; // Hide filters after generating
    });

    try {
      final statements = await _statementService.getAccountStatementByCurrency(
        accountId: _selectedAccount!.id,
        startDate: _startDate,
        endDate: _endDate,
        selectedCurrencyId: _selectedCurrency?.id,
      );
      
      setState(() {
        _statementsByCurrency = statements;
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
          message: 'حدث خطأ في إنشاء الكشف: ${e.toString()}',
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

  Future<void> _handlePrint() async {
    await _exportToPrintPreview();
  }

  Future<void> _handleShare() async {
    if (_statementsByCurrency.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات لعرضها')),
      );
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/account_statement_${DateTime.now().millisecondsSinceEpoch}.txt');
      await file.writeAsString(_generateTextReport());
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'كشف حساب: ${_selectedAccount?.name ?? ""}',
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
    if (_statementsByCurrency.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات لعرضها')),
      );
      return;
    }

    // Convert to old format for unified report service
    final allStatementRows = <old_service.StatementRow>[];
    for (var statementByCurrency in _statementsByCurrency.values) {
      for (var row in statementByCurrency.rows) {
        allStatementRows.add(old_service.StatementRow(
          date: row.date,
          description: row.description,
          debit: row.debit,
          credit: row.credit,
          balance: row.balance,
          transactionId: row.transactionId,
          operationType: row.operationType,
        ));
      }
    }
    allStatementRows.sort((a, b) => a.date.compareTo(b.date));

    // Generate report data
    final reportData = UnifiedReportService.generateAccountStatementReport(
      statements: allStatementRows,
      accountName: _selectedAccount?.name ?? '',
      startDate: _startDate,
      endDate: _endDate,
      currencySymbol: _selectedCurrency?.symbol,
    );

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PrintPreviewScreen(
          reportType: ReportType.accountStatement,
          title: reportData['title'] as String,
          content: Container(),
          metadata: {
            ...reportData['metadata'] as Map<String, dynamic>,
            'headers': reportData['headers'] as List<String>,
            'rows': reportData['rows'] as List<List<dynamic>>,
            'statementsByCurrency': _statementsByCurrency,
            'initialAction': action?.name,
          },
        ),
      ),
    ).then((_) {
      // Execute action if specified
      if (action == ExportAction.pdf) {
        // PDF export will be handled by PrintPreviewScreen
      } else if (action == ExportAction.excel) {
        // Excel export will be handled by PrintPreviewScreen
      }
    });
  }

  String _generateTextReport() {
    final buffer = StringBuffer();
    buffer.writeln('كشف حساب: ${_selectedAccount?.name ?? ""}');
    if (_startDate != null && _endDate != null) {
      buffer.writeln('من ${DateFormat('yyyy-MM-dd').format(_startDate!)} إلى ${DateFormat('yyyy-MM-dd').format(_endDate!)}');
    }
    buffer.writeln('');
    
    for (var statement in _statementsByCurrency.values) {
      buffer.writeln('العملة: ${statement.currencySymbol}');
      buffer.writeln('الرصيد الافتتاحي: ${NumberFormat('#,##0.00').format(statement.openingBalance)}');
      buffer.writeln('─────────────────────');
      
      for (var row in statement.rows) {
        buffer.writeln('${DateFormat('yyyy-MM-dd').format(row.date)} | ${row.description} | مدين: ${row.debit > 0 ? NumberFormat('#,##0.00').format(row.debit) : "-"} | دائن: ${row.credit > 0 ? NumberFormat('#,##0.00').format(row.credit) : "-"} | الرصيد: ${NumberFormat('#,##0.00').format(row.balance)}');
      }
      
      buffer.writeln('─────────────────────');
      buffer.writeln('الرصيد النهائي: ${NumberFormat('#,##0.00').format(statement.closingBalance)} ${statement.currencySymbol}');
      buffer.writeln('');
    }
    
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('كشف حساب'),
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
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'بحث عن حساب...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 140,
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
                            items: _filteredAccounts.map((account) => DropdownMenuItem<AccountModel>(
                              value: account,
                              child: Text(
                                account.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            )).toList(),
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
                              labelText: 'العملة (اختياري)',
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
                                child: Text('الكل', style: TextStyle(fontSize: 12)),
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
                          onPressed: _generateStatement,
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
            ] else if (_selectedAccount != null) ...[
              // Compact summary bar when filters are hidden
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
                        _selectedAccount!.name,
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
            
            // Statement Display - Priority to Data
            if (_statementsByCurrency.isEmpty && !_isLoading) ...[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد بيانات لعرضها',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'اختر الحساب والفترة ثم اضغط "عرض"',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_statementsByCurrency.isNotEmpty) ...[
              Expanded(
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedAccount?.name ?? '',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_startDate != null && _endDate != null)
                                  Text(
                                    'من ${DateFormat('yyyy-MM-dd').format(_startDate!)} إلى ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryMaroon.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_statementsByCurrency.length} عملة',
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
                    
                    // Statements by Currency - Elegant Tables
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _statementsByCurrency.length,
                        itemBuilder: (context, index) {
                          final currencyId = _statementsByCurrency.keys.elementAt(index);
                          final statement = _statementsByCurrency[currencyId]!;
                          return _buildCurrencyStatement(statement);
                        },
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

  Widget _buildCurrencyStatement(AccountStatementByCurrency statement) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Currency Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryMaroon.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.currency_exchange, color: AppColors.primaryMaroon, size: 20),
                const SizedBox(width: 8),
                Text(
                  statement.currencySymbol,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryMaroon,
                  ),
                ),
                const Spacer(),
                Text(
                  '${statement.rows.length} عملية',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          
          // Elegant Compact Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 35,
              dataRowMaxHeight: 50,
              columnSpacing: 12,
              headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
              columns: const [
                DataColumn(
                  label: Text('التاريخ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  numeric: false,
                ),
                DataColumn(
                  label: Text('نوع العملية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  numeric: false,
                ),
                DataColumn(
                  label: Text('مدين', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  numeric: true,
                ),
                DataColumn(
                  label: Text('دائن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  numeric: true,
                ),
                DataColumn(
                  label: Text('الرصيد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  numeric: true,
                ),
                DataColumn(
                  label: Text('النوع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  numeric: false,
                ),
              ],
              rows: statement.rows.map((row) {
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        DateFormat('yyyy-MM-dd').format(row.date),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 150,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getOperationTypeColor(row.operationType).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _getTranslatedOperationType(row.operationType),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getOperationTypeColor(row.operationType),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        row.debit > 0 ? NumberFormat('#,##0.00').format(row.debit) : '-',
                        style: TextStyle(
                          fontSize: 10,
                          color: row.debit > 0 ? Colors.green.shade700 : Colors.grey,
                          fontWeight: row.debit > 0 ? FontWeight.w500 : FontWeight.normal,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                    DataCell(
                      Text(
                        row.credit > 0 ? NumberFormat('#,##0.00').format(row.credit) : '-',
                        style: TextStyle(
                          fontSize: 10,
                          color: row.credit > 0 ? Colors.red.shade700 : Colors.grey,
                          fontWeight: row.credit > 0 ? FontWeight.w500 : FontWeight.normal,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            NumberFormat('#,##0.00').format(row.balance.abs()),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: row.balance >= 0 ? Colors.red.shade700 : Colors.green.shade700,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (row.balance >= 0 ? Colors.red : Colors.green).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          row.balance >= 0 ? 'مدين' : 'دائن',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: row.balance >= 0 ? Colors.red.shade700 : Colors.green.shade700,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          
          // Final Balance Summary - Prominent
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'الرصيد الافتتاحي:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${NumberFormat('#,##0.00').format(statement.openingBalance.abs())} ${statement.currencySymbol}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statement.openingBalance >= 0 ? Colors.red.shade700 : Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statement.openingBalance >= 0 ? 'مدين' : 'دائن',
                          style: TextStyle(
                            fontSize: 10,
                            color: statement.openingBalance >= 0 ? Colors.red.shade700 : Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'إجمالي المدين:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      '${NumberFormat('#,##0.00').format(statement.totalDebit)} ${statement.currencySymbol}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'إجمالي الدائن:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      '${NumberFormat('#,##0.00').format(statement.totalCredit)} ${statement.currencySymbol}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMaroon.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الرصيد النهائي:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryMaroon,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${NumberFormat('#,##0.00').format(statement.closingBalance.abs())} ${statement.currencySymbol}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: statement.closingBalance >= 0 
                                  ? Colors.red.shade700 
                                  : Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (statement.closingBalance >= 0 ? Colors.red : Colors.green).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statement.closingBalance >= 0 ? 'مدين' : 'دائن',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: statement.closingBalance >= 0 
                                    ? Colors.red.shade700 
                                    : Colors.green.shade700,
                              ),
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
        ],
      ),
    );
  }


  String _getTranslatedOperationType(String operationType) {
    switch (operationType) {
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
        return operationType;
    }
  }

  Color _getOperationTypeColor(String operationType) {
    switch (operationType) {
      case 'Receipt':
        return Colors.green;
      case 'Payment':
        return Colors.red;
      case 'Journal':
        return Colors.blue;
      case 'BuyCurrency':
        return Colors.orange;
      case 'SellCurrency':
        return Colors.purple;
      default:
        return Colors.grey;
    }
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
