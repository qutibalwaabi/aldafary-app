import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:untitled/services/transaction_service.dart' as ts;
import 'package:untitled/core/models/account_model.dart';
import 'package:untitled/core/services/account_service.dart';
import 'package:untitled/core/services/currency_service.dart';
import 'package:untitled/core/services/account_statement_service.dart';
import 'package:untitled/core/services/account_statement_service.dart' show StatementRow;

/// Unified Report Service to generate report data for any type of report
class UnifiedReportService {
  final AccountService _accountService = AccountService();
  final CurrencyService _currencyService = CurrencyService();
  
  /// Generate report data for a single transaction
  static Future<Map<String, dynamic>> generateSingleTransactionReport(
    ts.Transaction transaction,
    AccountService accountService,
    CurrencyService currencyService,
  ) async {
    final debitAccount = await accountService.getAccountById(transaction.debitAccountId);
    final creditAccount = await accountService.getAccountById(transaction.creditAccountId);
    final currency = await currencyService.getCurrencyById(transaction.currencyId);
    
    final headers = [
      'الرقم التسلسلي',
      'نوع العملية',
      'الحساب المدين',
      'الحساب الدائن',
      'المبلغ',
      'العملة',
      'التاريخ',
      'البيان',
    ];
    
    String operationTypeName;
    switch (transaction.operationType) {
      case 'Receipt':
        operationTypeName = 'سند قبض';
        break;
      case 'Payment':
        operationTypeName = 'سند صرف';
        break;
      case 'Journal':
        operationTypeName = 'قيد يومية';
        break;
      case 'BuyCurrency':
        operationTypeName = 'شراء عملة';
        break;
      case 'SellCurrency':
        operationTypeName = 'بيع عملة';
        break;
      default:
        operationTypeName = transaction.operationType;
    }
    
    final rows = [
      [
        transaction.formattedSerialNumber,
        operationTypeName,
        debitAccount?.name ?? transaction.debitAccountId,
        creditAccount?.name ?? transaction.creditAccountId,
        NumberFormat('#,##0.00').format(transaction.amount),
        currency?.symbol ?? transaction.currencyId,
        DateFormat('yyyy-MM-dd').format(transaction.date),
        transaction.description,
      ],
    ];
    
    // Determine which account name to show prominently (for Payment show debit, for Receipt show credit)
    String prominentAccountName;
    if (transaction.operationType == 'Payment') {
      prominentAccountName = debitAccount?.name ?? transaction.debitAccountId;
    } else {
      prominentAccountName = creditAccount?.name ?? transaction.creditAccountId;
    }
    
    return {
      'headers': headers,
      'rows': rows,
      'title': 'تفاصيل العملية: $prominentAccountName', // Show account name instead of serial number
      'metadata': {
        'serialNumber': transaction.formattedSerialNumber,
        'operationType': operationTypeName,
        'date': DateFormat('yyyy-MM-dd').format(transaction.date),
        'amount': transaction.amount,
        'currency': currency?.symbol ?? transaction.currencyId,
        'accountName': prominentAccountName, // Add account name to metadata
        'debitAccount': debitAccount?.name ?? transaction.debitAccountId,
        'creditAccount': creditAccount?.name ?? transaction.creditAccountId,
      },
    };
  }
  
  /// Generate report data for transactions list
  static Map<String, dynamic> generateTransactionsReport({
    required List<ts.Transaction> transactions,
    required Map<String, String> accountNames,
    required Map<String, String> currencySymbols,
    String? accountName,
    DateTime? startDate,
    DateTime? endDate,
    String? operationType,
  }) {
    final headers = [
      'الرقم التسلسلي',
      'نوع العملية',
      'الحساب المدين',
      'الحساب الدائن',
      'المبلغ',
      'العملة',
      'التاريخ',
      'البيان',
    ];
    
    String operationTypeName(String type) {
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
    
    final rows = transactions.map((transaction) {
      return [
        transaction.formattedSerialNumber,
        operationTypeName(transaction.operationType),
        accountNames[transaction.debitAccountId] ?? transaction.debitAccountId,
        accountNames[transaction.creditAccountId] ?? transaction.creditAccountId,
        NumberFormat('#,##0.00').format(transaction.amount),
        currencySymbols[transaction.currencyId] ?? transaction.currencyId,
        DateFormat('yyyy-MM-dd').format(transaction.date),
        transaction.description,
      ];
    }).toList();
    
    final totalAmount = transactions.fold<double>(
      0.0,
      (sum, t) => sum + t.amount,
    );
    
    String title = 'تقرير العمليات';
    if (operationType != null) {
      title = '${operationTypeName(operationType)} - $title';
    }
    if (accountName != null) {
      title = '$title - $accountName';
    }
    
    return {
      'headers': headers,
      'rows': rows,
      'title': title,
      'metadata': {
        'count': transactions.length.toString(),
        'totalAmount': totalAmount,
        'dateRange': startDate != null && endDate != null
            ? 'من ${DateFormat('yyyy-MM-dd').format(startDate)} إلى ${DateFormat('yyyy-MM-dd').format(endDate)}'
            : null,
        'accountName': accountName,
        'operationType': operationType != null ? operationTypeName(operationType) : 'الكل',
      },
    };
  }
  
  /// Generate report data for account statement
  static Map<String, dynamic> generateAccountStatementReport({
    required List<StatementRow> statements,
    required String accountName,
    DateTime? startDate,
    DateTime? endDate,
    String? currencySymbol,
  }) {
    final headers = [
      'التاريخ',
      'البيان',
      'مدين',
      'دائن',
      'الرصيد',
    ];
    
    double openingBalance = 0.0;
    if (statements.isNotEmpty) {
      openingBalance = statements.first.balance - statements.first.debit + statements.first.credit;
    }
    final closingBalance = statements.isNotEmpty ? statements.last.balance : 0.0;
    
    final rows = statements.map((row) {
      return [
        DateFormat('yyyy-MM-dd').format(row.date),
        row.description,
        row.debit > 0 ? NumberFormat('#,##0.00').format(row.debit) : '-',
        row.credit > 0 ? NumberFormat('#,##0.00').format(row.credit) : '-',
        NumberFormat('#,##0.00').format(row.balance),
      ];
    }).toList();
    
    return {
      'headers': headers,
      'rows': rows,
      'title': 'كشف حساب: $accountName',
      'metadata': {
        'accountName': accountName,
        'dateRange': startDate != null && endDate != null
            ? 'من ${DateFormat('yyyy-MM-dd').format(startDate)} إلى ${DateFormat('yyyy-MM-dd').format(endDate)}'
            : null,
        'count': statements.length.toString(),
        'openingBalance': openingBalance,
        'closingBalance': closingBalance,
        'currency': currencySymbol,
      },
    };
  }
}

