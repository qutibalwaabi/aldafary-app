
import 'package:flutter/material.dart';
import 'package:untitled/accounts_screen.dart';
import 'package:untitled/features/reports/screens/account_statement_report_screen.dart';
import 'package:untitled/features/reports/screens/transactions_report_screen.dart';
import 'package:untitled/theme/app_colors.dart';
import 'package:untitled/shared/theme/app_theme.dart';
import 'package:untitled/shared/widgets/app_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير'),
        backgroundColor: AppColors.primaryMaroon,
        foregroundColor: AppColors.textOnDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_accounts),
            tooltip: 'إدارة الحسابات',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AccountsScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'التقارير المتاحة',
              style: AppTheme.heading1,
            ),
            const SizedBox(height: 24),
            _buildReportCard(
              icon: Icons.description_rounded,
              title: 'كشف حساب',
              description: 'عرض كشف حساب مفصل مع جميع العمليات والرصيد',
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountStatementReportScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildReportCard(
              icon: Icons.receipt_long_rounded,
              title: 'تقرير العمليات',
              description: 'عرض جميع العمليات المالية مع إمكانية التصفية',
              color: Colors.purple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TransactionsReportScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.heading3,
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTheme.bodyMedium.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_back_ios_rounded, color: color),
        ],
      ),
    );
  }
}
