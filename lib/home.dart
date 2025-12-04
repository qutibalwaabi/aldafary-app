import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:untitled/accounts_screen.dart';
import 'package:untitled/currencies_screen.dart';
import 'package:untitled/journal_voucher_screen.dart';
import 'package:untitled/operations.dart';
import 'package:untitled/payment.dart';
import 'package:untitled/receipt.dart';
import 'package:untitled/reports_screen.dart';
import 'package:untitled/services/unified_balance_service.dart';
import 'package:untitled/services/transaction_service.dart' as ts;
import 'package:untitled/theme/app_colors.dart';
import 'package:untitled/transaction_details.dart';
import 'package:untitled/user_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ts.TransactionService _transactionService = ts.TransactionService();
  final UnifiedBalanceService _balanceService = UnifiedBalanceService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('شركة الظفري المالي'),
        backgroundColor: AppColors.primaryMaroon,
        foregroundColor: AppColors.textOnDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UserProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance Card Section
            _buildBalanceCard(),
            const SizedBox(height: 24),

            // Quick Actions Section
            _buildQuickActions(),
            const SizedBox(height: 24),

            // Recent Transactions Section
            _buildSectionHeader('آخر العمليات'),
            const SizedBox(height: 8),
            _buildRecentTransactions(),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return StreamBuilder<Map<String, double>>(
      stream: _balanceService.streamAllAccountBalances(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final balances = snapshot.data!;
        double totalBalance = 0.0;

        // Calculate total balance across all accounts
        balances.forEach((accountId, balance) {
          totalBalance += balance;
        });

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'رصيد الصندوق',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  NumberFormat('#,##0.00').format(totalBalance),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textOnLight,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('العمليات السريعة'),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: [
            _buildQuickActionCard(
              icon: Icons.arrow_downward,
              label: 'سند قبض',
              color: Colors.green,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ReceiptScreen()),
                );
              },
            ),
            _buildQuickActionCard(
              icon: Icons.arrow_upward,
              label: 'سند صرف',
              color: Colors.red,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PaymentScreen()),
                );
              },
            ),
            _buildQuickActionCard(
              icon: Icons.swap_horiz,
              label: 'قيد يومية',
              color: Colors.blue,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const JournalVoucherScreen()),
                );
              },
            ),
            _buildQuickActionCard(
              icon: Icons.list_alt,
              label: 'كل العمليات',
              color: AppColors.primaryMaroon,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OperationsScreen()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(){
     return StreamBuilder<List<ts.Transaction>>(
       stream: _transactionService.streamRecentTransactions(limit: 10),
       builder: (context, snapshot) {
         if (snapshot.hasError) return Padding(padding: const EdgeInsets.all(16.0), child: Text('فشل تحميل العمليات. الرجاء إنشاء الفهارس المطلوبة في Firestore.', style: const TextStyle(color: Colors.red)));
         if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
         if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('لا توجد عمليات لعرضها.')));

         return ListView.builder(
           padding: EdgeInsets.zero,
           shrinkWrap: true,
           physics: const NeverScrollableScrollPhysics(),
           itemCount: snapshot.data!.length,
           itemBuilder: (context, index) {
              final transaction = snapshot.data![index];
             return Card(
               child: ListTile(
                 title: Text(_getTranslatedOperationType(transaction.operationType), style: const TextStyle(fontWeight: FontWeight.bold)),
                 subtitle: Text(transaction.description),
                 trailing: Text(transaction.formattedAmount),
                 onTap: () => _showTransactionOptions(transaction.id),
               ),
             );
           },
         );
       },
   );
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

  String _getTranslatedOperationType(String operationType) {
    switch (operationType) {
      case 'Receipt':
        return 'سند قبض';
      case 'Payment':
        return 'سند صرف';
      case 'Journal':
        return 'قيد يومية';
      default:
        return operationType;
    }
  }
}