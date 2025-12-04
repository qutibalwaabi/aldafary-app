import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:untitled/services/balance_service.dart';
import 'package:untitled/theme/app_colors.dart';
import 'package:untitled/account_statement_screen.dart';

class AccountBalancesScreen extends StatefulWidget {
  const AccountBalancesScreen({super.key});

  @override
  State<AccountBalancesScreen> createState() => _AccountBalancesScreenState();
}

class _AccountBalancesScreenState extends State<AccountBalancesScreen> {
  final BalanceService _balanceService = BalanceService();
  bool _isLoading = true;
  List<AccountBalance> _accountBalances = [];
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadBalances();
  }

  Future<void> _loadBalances() async {
    setState(() { _isLoading = true; });

    try {
      final balances = await _balanceService.getAllAccountsWithBalances();

      // Filter balances based on selected filter
      List<AccountBalance> filteredBalances = balances;
      if (_selectedFilter != 'All') {
        filteredBalances = balances.where((balance) => balance.accountType == _selectedFilter).toList();
      }

      setState(() {
        _accountBalances = filteredBalances;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
      if (mounted) {
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
        title: const Text('الأرصدة'),
        backgroundColor: AppColors.primaryMaroon,
        foregroundColor: AppColors.textOnDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBalances,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.all(16.0),
            color: AppColors.primaryMaroon.withOpacity(0.1),
            child: Row(
              children: [
                const Text(
                  'تصفية حسب النوع:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    onChanged: (value) {
                      setState(() {
                        _selectedFilter = value!;
                      });
                      _loadBalances();
                    },
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('الكل')),
                      DropdownMenuItem(value: 'Cash', child: Text('صندوق')),
                      DropdownMenuItem(value: 'Bank', child: Text('بنك')),
                      DropdownMenuItem(value: 'Customer', child: Text('عميل')),
                      DropdownMenuItem(value: 'Supplier', child: Text('مورد')),
                      DropdownMenuItem(value: 'Expense', child: Text('مصروفات')),
                      DropdownMenuItem(value: 'Revenue', child: Text('إيرادات')),
                    ],
                    isExpanded: true,
                  ),
                ),
              ],
            ),
          ),

          // Balances List
          _isLoading
              ? const Expanded(child: Center(child: CircularProgressIndicator()))
              : _accountBalances.isEmpty
                  ? const Expanded(child: Center(child: Text('لا توجد أرصدة لعرضها')))
                  : Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _accountBalances.length,
                        itemBuilder: (context, index) {
                          final balance = _accountBalances[index];
                          return _buildAccountBalanceCard(balance);
                        },
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildAccountBalanceCard(AccountBalance balance) {
    final currencies = balance.balances.keys.toList();
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToAccountStatement(balance.accountId, balance.accountName),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: _getAccountTypeColor(balance.accountType),
            child: Icon(
              _getAccountTypeIcon(balance.accountType),
              color: Colors.white,
            ),
          ),
          title: Text(
            balance.accountName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(_getAccountTypeLabel(balance.accountType)),
          children: currencies.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('لا توجد أرصدة لهذا الحساب'),
                  ),
                ]
              : currencies.map((currencySymbol) {
                  final currencyBalance = balance.balances[currencySymbol] ?? 0.0;
                  return ListTile(
                    dense: true,
                    leading: const SizedBox(width: 40),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          currencySymbol,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          NumberFormat('#,##0.00').format(currencyBalance.abs()),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: currencyBalance >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      currencyBalance >= 0 ? 'دائن' : 'مدين',
                      style: TextStyle(
                        fontSize: 12,
                        color: currencyBalance >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  );
                }).toList(),
        ),
      ),
    );
  }

  Color _getAccountTypeColor(String type) {
    switch (type) {
      case 'Cash':
        return Colors.green;
      case 'Bank':
        return Colors.blue;
      case 'Customer':
        return Colors.purple;
      case 'Supplier':
        return Colors.orange;
      case 'Expense':
        return Colors.red;
      case 'Revenue':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getAccountTypeIcon(String type) {
    switch (type) {
      case 'Cash':
        return Icons.money;
      case 'Bank':
        return Icons.account_balance;
      case 'Customer':
        return Icons.person;
      case 'Supplier':
        return Icons.business;
      case 'Expense':
        return Icons.trending_down;
      case 'Revenue':
        return Icons.trending_up;
      default:
        return Icons.account_balance_wallet;
    }
  }

  String _getAccountTypeLabel(String type) {
    switch (type) {
      case 'Cash':
        return 'صندوق';
      case 'Bank':
        return 'بنك';
      case 'Customer':
        return 'عميل';
      case 'Supplier':
        return 'مورد';
      case 'Expense':
        return 'مصروفات';
      case 'Revenue':
        return 'إيرادات';
      default:
        return type;
    }
  }

  void _navigateToAccountStatement(String accountId, String accountName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccountStatementScreen(
          accountId: accountId,
          accountName: accountName,
        ),
      ),
    );
  }
}

class AccountBalancesScreenFixed extends StatefulWidget {
  const AccountBalancesScreenFixed({super.key});

  @override
  State<AccountBalancesScreenFixed> createState() => _AccountBalancesScreenFixedState();
}

class _AccountBalancesScreenFixedState extends State<AccountBalancesScreenFixed> {
  final BalanceService _balanceService = BalanceService();
  bool _isLoading = true;
  List<AccountBalance> _accountBalances = [];
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadBalances();
  }

  Future<void> _loadBalances() async {
    setState(() { _isLoading = true; });

    try {
      final balances = await _balanceService.getAllAccountsWithBalances();

      // Filter balances based on selected filter
      List<AccountBalance> filteredBalances = balances;
      if (_selectedFilter != 'All') {
        filteredBalances = balances.where((balance) => balance.accountType == _selectedFilter).toList();
      }

      setState(() {
        _accountBalances = filteredBalances;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
      if (mounted) {
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
        title: const Text('الأرصدة'),
        backgroundColor: AppColors.primaryMaroon,
        foregroundColor: AppColors.textOnDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBalances,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.all(16.0),
            color: AppColors.primaryMaroon.withOpacity(0.1),
            child: Row(
              children: [
                const Text(
                  'تصفية حسب النوع:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    onChanged: (value) {
                      setState(() {
                        _selectedFilter = value!;
                      });
                      _loadBalances();
                    },
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('الكل')),
                      DropdownMenuItem(value: 'Cash', child: Text('صندوق')),
                      DropdownMenuItem(value: 'Bank', child: Text('بنك')),
                      DropdownMenuItem(value: 'Customer', child: Text('عميل')),
                      DropdownMenuItem(value: 'Supplier', child: Text('مورد')),
                      DropdownMenuItem(value: 'Expense', child: Text('مصروفات')),
                      DropdownMenuItem(value: 'Revenue', child: Text('إيرادات')),
                    ],
                    isExpanded: true,
                  ),
                ),
              ],
            ),
          ),

          // Balances List
          _isLoading
              ? const Expanded(child: Center(child: CircularProgressIndicator()))
              : _accountBalances.isEmpty
                  ? const Expanded(child: Center(child: Text('لا توجد أرصدة لعرضها')))
                  : Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _accountBalances.length,
                        itemBuilder: (context, index) {
                          final balance = _accountBalances[index];
                          return _buildAccountBalanceCard(balance);
                        },
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildAccountBalanceCard(AccountBalance balance) {
    final currencies = balance.balances.keys.toList();
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToAccountStatement(balance.accountId, balance.accountName),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: _getAccountTypeColor(balance.accountType),
            child: Icon(
              _getAccountTypeIcon(balance.accountType),
              color: Colors.white,
            ),
          ),
          title: Text(
            balance.accountName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(_getAccountTypeLabel(balance.accountType)),
          children: currencies.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('لا توجد أرصدة لهذا الحساب'),
                  ),
                ]
              : currencies.map((currencySymbol) {
                  final currencyBalance = balance.balances[currencySymbol] ?? 0.0;
                  return ListTile(
                    dense: true,
                    leading: const SizedBox(width: 40),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          currencySymbol,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          NumberFormat('#,##0.00').format(currencyBalance.abs()),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: currencyBalance >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      currencyBalance >= 0 ? 'دائن' : 'مدين',
                      style: TextStyle(
                        fontSize: 12,
                        color: currencyBalance >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  );
                }).toList(),
        ),
      ),
    );
  }

  Color _getAccountTypeColor(String type) {
    switch (type) {
      case 'Cash':
        return Colors.green;
      case 'Bank':
        return Colors.blue;
      case 'Customer':
        return Colors.purple;
      case 'Supplier':
        return Colors.orange;
      case 'Expense':
        return Colors.red;
      case 'Revenue':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getAccountTypeIcon(String type) {
    switch (type) {
      case 'Cash':
        return Icons.money;
      case 'Bank':
        return Icons.account_balance;
      case 'Customer':
        return Icons.person;
      case 'Supplier':
        return Icons.business;
      case 'Expense':
        return Icons.trending_down;
      case 'Revenue':
        return Icons.trending_up;
      default:
        return Icons.account_balance_wallet;
    }
  }

  String _getAccountTypeLabel(String type) {
    switch (type) {
      case 'Cash':
        return 'صندوق';
      case 'Bank':
        return 'بنك';
      case 'Customer':
        return 'عميل';
      case 'Supplier':
        return 'مورد';
      case 'Expense':
        return 'مصروفات';
      case 'Revenue':
        return 'إيرادات';
      default:
        return type;
    }
  }

  void _navigateToAccountStatement(String accountId, String accountName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccountStatementScreen(
          accountId: accountId,
          accountName: accountName,
        ),
      ),
    );
  }
}

