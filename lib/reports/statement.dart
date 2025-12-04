import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:untitled/services/engine.dart';
import 'package:untitled/theme/app_colors.dart';

class AccountStatementScreen extends StatefulWidget {
  const AccountStatementScreen({super.key});

  @override
  State<AccountStatementScreen> createState() => _AccountStatementScreenState();
}

class _AccountStatementScreenState extends State<AccountStatementScreen> {
  final FinancialEngineService _financialEngine = FinancialEngineService();
  String? _selectedAccountId;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  List<StatementRow> _statement = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('كشف حساب'),
        backgroundColor: AppColors.primaryMaroon,
        foregroundColor: AppColors.textOnDark,
      ),
      body: Column(
        children: [
          // Filters Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Account Selection
                FutureBuilder<List<AccountBalance>>(
                  future: _financialEngine.getAllAccountsWithBalances(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final accounts = snapshot.data!;
                    if (accounts.isEmpty) {
                      return const Center(
                        child: Text('لا توجد حسابات متاحة'),
                      );
                    }

                    return DropdownButtonFormField<String>(
                      value: _selectedAccountId,
                      decoration: const InputDecoration(
                        labelText: 'اختر الحساب',
                        border: OutlineInputBorder(),
                      ),
                      items: accounts.map((account) {
                        return DropdownMenuItem<String>(
                          value: account.id,
                          child: Text(account.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedAccountId = value;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Date Range
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              _startDate = date;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'من تاريخ',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            _startDate != null
                                ? DateFormat('yyyy-MM-dd').format(_startDate!)
                                : 'اختر التاريخ',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _endDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              _endDate = date;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'إلى تاريخ',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            _endDate != null
                                ? DateFormat('yyyy-MM-dd').format(_endDate!)
                                : 'اختر التاريخ',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Generate Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selectedAccountId != null ? _generateStatement : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryMaroon,
                      foregroundColor: AppColors.textOnDark,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: AppColors.textOnDark)
                        : const Text('إنشاء الكشف'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Statement Table
          Expanded(
            child: _statement.isEmpty
                ? const Center(
                    child: Text('اختر حساباً وقم بإنشاء الكشف'),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(
                            label: Text('التاريخ'),
                          ),
                          DataColumn(
                            label: Text('البيان'),
                          ),
                          DataColumn(
                            label: Text('مدين'),
                          ),
                          DataColumn(
                            label: Text('دائن'),
                          ),
                          DataColumn(
                            label: Text('الرصيد'),
                          ),
                        ],
                        rows: _statement.map((row) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(DateFormat('yyyy-MM-dd').format(row.date)),
                              ),
                              DataCell(
                                Text(row.description),
                              ),
                              DataCell(
                                Text(
                                  row.debit > 0
                                      ? NumberFormat('#,##0.00').format(row.debit)
                                      : '',
                                ),
                              ),
                              DataCell(
                                Text(
                                  row.credit > 0
                                      ? NumberFormat('#,##0.00').format(row.credit)
                                      : '',
                                ),
                              ),
                              DataCell(
                                Text(
                                  NumberFormat('#,##0.00').format(row.balance),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateStatement() async {
    if (_selectedAccountId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _financialEngine.getAccountStatement(
        accountId: _selectedAccountId!,
        startDate: _startDate,
        endDate: _endDate,
      );

      setState(() {
        _statement = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
        );
      }
    }
  }
}