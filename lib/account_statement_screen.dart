import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:untitled/services/financial_engine_service.dart';
import 'package:untitled/theme/app_colors.dart';

class AccountStatementScreen extends StatefulWidget {
  final String accountId;
  final String accountName;

  const AccountStatementScreen({
    super.key,
    required this.accountId,
    required this.accountName,
  });

  @override
  State<AccountStatementScreen> createState() => _AccountStatementScreenState();
}

class _AccountStatementScreenState extends State<AccountStatementScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  final FinancialEngineService _financialEngine = FinancialEngineService();
  bool _isLoading = true;
  List<StatementRow> _statement = [];
  double _openingBalance = 0.0;
  double _closingBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadStatement();
  }

  Future<void> _loadStatement() async {
    setState(() { _isLoading = true; });

    try {
      // Get opening balance (before start date or all time if no start date)
      final openingBalance = _startDate != null
          ? await _getBalanceBeforeDate(widget.accountId, _startDate!)
          : 0.0;

      // Get statement rows
      final statement = await _financialEngine.getAccountStatement(
        accountId: widget.accountId,
        startDate: _startDate,
        endDate: _endDate,
      );

      // Calculate closing balance
      double closingBalance = openingBalance;
      for (final row in statement) {
        closingBalance += row.debit - row.credit;
      }

      setState(() {
        _openingBalance = openingBalance;
        _statement = statement;
        _closingBalance = closingBalance;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
      );
    }
  }

  Future<double> _getBalanceBeforeDate(String accountId, DateTime date) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0.0;

    // Get all transactions before the specified date
    final debitTransactions = await FirebaseFirestore.instance
        .collection('transactions')
        .where('debitAccountId', isEqualTo: accountId)
        .where('userId', isEqualTo: user.uid)
        .where('date', isLessThan: Timestamp.fromDate(date))
        .get();

    final creditTransactions = await FirebaseFirestore.instance
        .collection('transactions')
        .where('creditAccountId', isEqualTo: accountId)
        .where('userId', isEqualTo: user.uid)
        .where('date', isLessThan: Timestamp.fromDate(date))
        .get();

    double balance = 0.0;

    // Add debit amounts
    for (final doc in debitTransactions.docs) {
      balance += (doc['amount'] as num).toDouble();
    }

    // Subtract credit amounts
    for (final doc in creditTransactions.docs) {
      balance -= (doc['amount'] as num).toDouble();
    }

    return balance;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('كشف حساب ${widget.accountName}'),
        backgroundColor: AppColors.primaryMaroon,
        foregroundColor: AppColors.textOnDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('سيتم إضافة الطباعة قريباً')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Range Filter
          if (_startDate != null || _endDate != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.primaryMaroon.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.date_range, color: AppColors.primaryMaroon),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'الفترة: ${_startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : 'من البداية'} - ${_endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : 'حتى الآن'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                      });
                      _loadStatement();
                    },
                  ),
                ],
              ),
            ),

          // Balance Summary
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryMaroon.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الرصيد الافتتاحي:'),
                    Text(
                      NumberFormat('#,##0.00').format(_openingBalance),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الرصيد الختامي:'),
                    Text(
                      NumberFormat('#,##0.00').format(_closingBalance),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Statement List
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _statement.isEmpty
                  ? const Center(child: Text('لا توجد حركات في الفترة المحددة'))
                  : Expanded(
                      child: ListView.builder(
                        itemCount: _statement.length,
                        itemBuilder: (context, index) {
                          final row = _statement[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              title: Text(row.description),
                              subtitle: Text(DateFormat('yyyy-MM-dd').format(row.date)),
                              leading: CircleAvatar(
                                backgroundColor: row.debit > 0 ? Colors.green : Colors.red,
                                child: Icon(
                                  row.debit > 0 ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: Colors.white,
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (row.debit > 0)
                                    Text(
                                      NumberFormat('#,##0.00').format(row.debit),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  if (row.credit > 0)
                                    Text(
                                      NumberFormat('#,##0.00').format(row.credit),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                  Text(
                                    NumberFormat('#,##0.00').format(row.balance),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadStatement();
    }
  }
}