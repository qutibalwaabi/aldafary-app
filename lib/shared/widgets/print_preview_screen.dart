import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:untitled/theme/app_colors.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/painting.dart' show Border;
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:untitled/core/services/user_profile_service.dart';
import 'package:http/http.dart' as http;
import 'package:untitled/core/utils/arabic_number_to_words.dart';
import 'package:untitled/core/services/account_statement_service_currency_separated.dart';

enum ReportType {
  accountStatement,
  transactionsReport,
  balanceReport,
  singleTransaction,
}

class PrintPreviewScreen extends StatefulWidget {
  final ReportType reportType;
  final String title;
  final Widget content;
  final Map<String, dynamic>? metadata;

  const PrintPreviewScreen({
    super.key,
    required this.reportType,
    required this.title,
    required this.content,
    this.metadata,
  });

  @override
  State<PrintPreviewScreen> createState() => _PrintPreviewScreenState();
}

class _PrintPreviewScreenState extends State<PrintPreviewScreen> with SingleTickerProviderStateMixin {
  int _selectedTabIndex = 1; // 0 = HTML Preview, 1 = PDF Preview
  Uint8List? _pdfBytes;
  bool _isGeneratingPDF = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: _selectedTabIndex);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });
    // Generate PDF immediately for preview
    _generatePDFBytes();
    
    // Execute initial action if specified
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialAction = widget.metadata?['initialAction'] as String?;
      if (initialAction != null && mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          switch (initialAction) {
            case 'print':
              _printReport(context);
              break;
            case 'pdf':
              _exportToPDF(context);
              break;
            case 'excel':
              _exportToExcel(context);
              break;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _generatePDFBytes() async {
    setState(() => _isGeneratingPDF = true);
    try {
      debugPrint('PrintPreviewScreen: Starting PDF generation...');
      debugPrint('PrintPreviewScreen: Metadata: ${widget.metadata?.keys.toList()}');
      
      final pdf = await _generatePDF();
      debugPrint('PrintPreviewScreen: PDF document created successfully');
      
      final bytes = await pdf.save();
      debugPrint('PrintPreviewScreen: PDF bytes generated: ${bytes.length} bytes');
      
      if (mounted) {
        setState(() {
          _pdfBytes = bytes;
          _isGeneratingPDF = false;
        });
        debugPrint('PrintPreviewScreen: PDF generation completed successfully');
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() => _isGeneratingPDF = false);
      }
      debugPrint('Error generating PDF: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في إنشاء PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Load Arabic font for PDF
  // Cache fonts to avoid reloading
  pw.Font? _cachedArabicFont;
  pw.Font? _cachedArabicBoldFont;

  Future<pw.Font> _loadArabicFont() async {
    if (_cachedArabicFont != null) {
      return _cachedArabicFont!;
    }
    
    try {
      // Try loading Cairo-Regular first
      final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      _cachedArabicFont = pw.Font.ttf(fontData);
      debugPrint('PrintPreviewScreen: Arabic font (Cairo-Regular) loaded successfully (${fontData.lengthInBytes} bytes)');
      
      // Verify font is valid
      if (_cachedArabicFont != null) {
        return _cachedArabicFont!;
      }
    } catch (e) {
      debugPrint('PrintPreviewScreen: Error loading Cairo-Regular font: $e');
    }
    
    // Try Cairo-Bold as fallback
    try {
      final fontData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
      _cachedArabicFont = pw.Font.ttf(fontData);
      debugPrint('PrintPreviewScreen: Using Cairo-Bold as fallback (${fontData.lengthInBytes} bytes)');
      return _cachedArabicFont!;
    } catch (e2) {
      debugPrint('PrintPreviewScreen: Error loading Cairo-Bold font: $e2');
    }
    
    // Last resort: use default font (may not support Arabic well)
    debugPrint('PrintPreviewScreen: WARNING - Using default font (Arabic may not render correctly)');
    _cachedArabicFont = pw.Font.courier();
    return _cachedArabicFont!;
  }

  Future<pw.Font> _loadArabicBoldFont() async {
    if (_cachedArabicBoldFont != null) {
      return _cachedArabicBoldFont!;
    }
    
    try {
      // Try loading Cairo-Bold first
      final fontData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
      _cachedArabicBoldFont = pw.Font.ttf(fontData);
      debugPrint('PrintPreviewScreen: Arabic bold font (Cairo-Bold) loaded successfully (${fontData.lengthInBytes} bytes)');
      
      // Verify font is valid
      if (_cachedArabicBoldFont != null) {
        return _cachedArabicBoldFont!;
      }
    } catch (e) {
      debugPrint('PrintPreviewScreen: Error loading Cairo-Bold font: $e');
    }
    
    // Try Cairo-Regular as fallback
    try {
      final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      _cachedArabicBoldFont = pw.Font.ttf(fontData);
      debugPrint('PrintPreviewScreen: Using Cairo-Regular as fallback for bold (${fontData.lengthInBytes} bytes)');
      return _cachedArabicBoldFont!;
    } catch (e2) {
      debugPrint('PrintPreviewScreen: Error loading Cairo-Regular font: $e2');
    }
    
    // Last resort: use default font
    debugPrint('PrintPreviewScreen: WARNING - Using default font for bold (Arabic may not render correctly)');
    _cachedArabicBoldFont = pw.Font.courier();
    return _cachedArabicBoldFont!;
  }

  /// Helper function to detect if text contains Arabic characters
  /// Comprehensive regex covering all Arabic character ranges
  /// Improved detection logic
  bool _isArabicText(String text) {
    if (text.isEmpty) return false;
    
    // Check for Arabic characters in all Unicode ranges
    // Includes: Arabic, Arabic Supplement, Arabic Extended-A, Arabic Presentation Forms-A/B, Hebrew
    final arabicRegex = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    
    // Count Arabic characters vs total non-space characters
    final arabicChars = text.split('').where((char) => arabicRegex.hasMatch(char)).length;
    final nonSpaceChars = text.replaceAll(RegExp(r'\s'), '').length;
    
    if (nonSpaceChars == 0) return false;
    
    // Consider text Arabic if it contains Arabic characters and they represent a significant portion
    // Lowered threshold to 20% to catch more Arabic content
    return arabicChars > 0 && (arabicChars / nonSpaceChars) > 0.2;
  }

  /// Helper function to normalize and clean Arabic text
  /// IMPORTANT: Only remove problematic characters, DO NOT change Arabic letter shapes
  /// The font will handle proper Arabic character shaping automatically
  String _normalizeArabicText(String text) {
    if (text.isEmpty) return text;
    
    // ONLY remove zero-width and directional control characters
    // DO NOT normalize Arabic letters - let the font handle proper shaping
    String normalized = text
        .replaceAll('\u200B', '') // Zero-width space
        .replaceAll('\u200C', '') // Zero-width non-joiner
        .replaceAll('\u200D', '') // Zero-width joiner
        .replaceAll('\uFEFF', '') // Zero-width no-break space
        .replaceAll('\u200E', '') // Left-to-right mark
        .replaceAll('\u200F', '') // Right-to-left mark
        .replaceAll('\u202A', '') // Left-to-right embedding
        .replaceAll('\u202B', '') // Right-to-left embedding
        .replaceAll('\u202C', '') // Pop directional formatting
        .replaceAll('\u202D', '') // Left-to-right override
        .replaceAll('\u202E', '') // Right-to-left override
        .replaceAll('\u2066', '') // Left-to-right isolate
        .replaceAll('\u2067', '') // Right-to-left isolate
        .replaceAll('\u2068', '') // First strong isolate
        .replaceAll('\u2069', ''); // Pop directional isolate
    
    // Remove any remaining problematic control characters
    normalized = normalized.replaceAll(RegExp(r'[\u2000-\u200F\u2028-\u202F\u2060-\u206F]'), '');
    
    // CRITICAL: Do NOT change Arabic letter shapes (أ, إ, آ, ى, ة)
    // The Cairo font will handle proper Arabic character shaping and ligatures
    
    // DO NOT add RTL embedding marks - they may cause issues with pdf package
    // The textDirection parameter in pw.Text should handle RTL correctly
    
    return normalized.trim();
  }

  /// Helper function to create properly formatted Arabic text widget
  /// This ensures Arabic text is rendered correctly with proper font and direction
  pw.Widget _buildArabicText(
    String text,
    pw.Font font, {
    double fontSize = 10,
    pw.FontWeight fontWeight = pw.FontWeight.normal,
    PdfColor? color,
    pw.TextAlign textAlign = pw.TextAlign.right,
    int maxLines = 3,
  }) {
    // Normalize text
    final normalizedText = _normalizeArabicText(text);
    final isArabic = _isArabicText(text);
    
    // For Arabic text, ALWAYS use RTL and right alignment
    final finalDirection = isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    final finalAlign = isArabic ? pw.TextAlign.right : textAlign;
    
    return pw.Text(
      normalizedText,
      style: pw.TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? PdfColors.black,
        font: font, // CRITICAL: Always use Arabic font
      ),
      textAlign: finalAlign,
      textDirection: finalDirection, // CRITICAL: RTL for Arabic
      maxLines: maxLines,
    );
  }

  /// Helper function to determine text alignment and direction
  /// Returns a map with 'align' and 'direction' keys
  /// Improved logic to handle mixed content (Arabic + English + Numbers)
  Map<String, dynamic> _getTextProperties(String text) {
    if (text.isEmpty) {
      return {
        'align': pw.TextAlign.right,
        'direction': pw.TextDirection.rtl,
      };
    }
    
    final normalizedText = _normalizeArabicText(text);
    final trimmedText = normalizedText.trim();
    
    // Check if it's a pure number (including dates and formatted numbers)
    final isPureNumber = RegExp(r'^\s*-?\d+([\.,]\d+)?\s*$|^\d{4}-\d{2}-\d{2}|^#.*#\s*$').hasMatch(trimmedText);
    
    // Check if text contains Arabic characters
    final isArabic = _isArabicText(normalizedText);
    
    // Check if text contains English letters
    final hasEnglish = RegExp(r'[a-zA-Z]').hasMatch(normalizedText);
    
    // Determine alignment and direction
    pw.TextAlign align;
    pw.TextDirection direction;
    
    if (isPureNumber) {
      // Pure numbers: center aligned, LTR
      align = pw.TextAlign.center;
      direction = pw.TextDirection.ltr;
    } else if (isArabic && !hasEnglish) {
      // Pure Arabic: right aligned, RTL
      align = pw.TextAlign.right;
      direction = pw.TextDirection.rtl;
    } else if (hasEnglish && !isArabic) {
      // Pure English: left aligned, LTR
      align = pw.TextAlign.left;
      direction = pw.TextDirection.ltr;
    } else {
      // Mixed content: prioritize Arabic if it's the majority
      final arabicChars = normalizedText.split('').where((char) => 
        RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]').hasMatch(char)
      ).length;
      final totalChars = normalizedText.length;
      
      if (arabicChars / totalChars > 0.5) {
        // Arabic is majority: right aligned, RTL
        align = pw.TextAlign.right;
        direction = pw.TextDirection.rtl;
      } else {
        // English/Numbers are majority: left aligned, LTR
        align = pw.TextAlign.left;
        direction = pw.TextDirection.ltr;
      }
    }
    
    return {
      'align': align,
      'direction': direction,
    };
  }

  Widget _buildPreviewContent() {
    // Always try to build from metadata first if available
    final metadata = widget.metadata;
    
    // Debug: Print metadata to console
    if (metadata != null) {
      debugPrint('PrintPreviewScreen metadata keys: ${metadata.keys.toList()}');
      debugPrint('PrintPreviewScreen has headers: ${metadata.containsKey('headers')}');
      debugPrint('PrintPreviewScreen has rows: ${metadata.containsKey('rows')}');
      if (metadata.containsKey('headers')) {
        debugPrint('Headers: ${metadata['headers']}');
      }
      if (metadata.containsKey('rows')) {
        debugPrint('Rows count: ${(metadata['rows'] as List?)?.length ?? 0}');
      }
    }
    
    // If no metadata, check if custom content is provided
    if (metadata == null || metadata.isEmpty) {
      debugPrint('PrintPreviewScreen: No metadata provided');
      // Check if it's an empty Container
      if (widget.content is Container) {
        final container = widget.content as Container;
        if (container.child == null) {
          debugPrint('PrintPreviewScreen: Empty Container detected');
          return _buildEmptyState();
        }
      }
      return widget.content;
    }

    // Check for statementsByCurrency (account statement with multiple currencies)
    if (metadata['statementsByCurrency'] != null) {
      return _buildAccountStatementPreview(metadata);
    }

    // Check for headers and rows (standard report)
    if (metadata['headers'] == null || metadata['rows'] == null) {
      return _buildEmptyState();
    }

    final headers = metadata['headers'] as List<String>?;
    final rows = metadata['rows'] as List?;

    if (headers == null || rows == null || headers.isEmpty || rows.isEmpty) {
      return _buildEmptyState();
    }

    // Build preview table from headers and rows
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Metadata info if available
        if (metadata['accountName'] != null || metadata['dateRange'] != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (metadata['accountName'] != null)
                  _buildPreviewMetadataRow('الحساب:', metadata['accountName'].toString()),
                if (metadata['dateRange'] != null)
                  _buildPreviewMetadataRow('الفترة:', metadata['dateRange'].toString()),
                if (metadata['count'] != null)
                  _buildPreviewMetadataRow('عدد السجلات:', metadata['count'].toString()),
              ],
            ),
          ),
        // Table
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              headingRowHeight: 50,
              dataRowMinHeight: 40,
              columnSpacing: 20,
              columns: headers.map((header) => DataColumn(
                label: Text(
                  header,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              )).toList(),
              rows: rows.map((row) {
                final rowData = row is List ? row : [];
                if (rowData.length != headers.length) {
                  // Pad with empty cells if needed
                  final paddedRow = List<String>.from(rowData.map((e) => e.toString()));
                  while (paddedRow.length < headers.length) {
                    paddedRow.add('');
                  }
                  return DataRow(
                    cells: paddedRow.map((cell) => DataCell(
                      Text(
                        cell,
                        style: const TextStyle(fontSize: 12),
                      ),
                    )).toList(),
                  );
                }
                return DataRow(
                  cells: rowData.map((cell) => DataCell(
                    Text(
                      cell.toString(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  )).toList(),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'لا توجد بيانات لعرضها',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountStatementPreview(Map<String, dynamic> metadata) {
    final statementsByCurrency = metadata['statementsByCurrency'] as Map<String, AccountStatementByCurrency>?;
    if (statementsByCurrency == null || statementsByCurrency.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Metadata info
        if (metadata['accountName'] != null || metadata['dateRange'] != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (metadata['accountName'] != null)
                  _buildPreviewMetadataRow('الحساب:', metadata['accountName'].toString()),
                if (metadata['dateRange'] != null)
                  _buildPreviewMetadataRow('الفترة:', metadata['dateRange'].toString()),
              ],
            ),
          ),
        // Statements by currency
        ...statementsByCurrency.values.map((statement) {
          return Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Currency header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMaroon.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'العملة: ${statement.currencySymbol}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryMaroon,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Table
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 40,
                    dataRowMinHeight: 35,
                    columnSpacing: 16,
                    columns: const [
                      DataColumn(label: Text('التاريخ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      DataColumn(label: Text('العملية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      DataColumn(label: Text('مدين', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      DataColumn(label: Text('دائن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      DataColumn(label: Text('الرصيد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    ],
                    rows: statement.rows.map((row) {
                      return DataRow(
                        cells: [
                          DataCell(Text(DateFormat('yyyy-MM-dd').format(row.date), style: const TextStyle(fontSize: 11))),
                          DataCell(Text(_getTranslatedOperationType(row.operationType), style: const TextStyle(fontSize: 11))),
                          DataCell(Text(row.debit > 0 ? NumberFormat('#,##0.00').format(row.debit) : '-', style: const TextStyle(fontSize: 11))),
                          DataCell(Text(row.credit > 0 ? NumberFormat('#,##0.00').format(row.credit) : '-', style: const TextStyle(fontSize: 11))),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(NumberFormat('#,##0.00').format(row.balance.abs()), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: row.balance >= 0 ? Colors.red.shade700 : Colors.green.shade700)),
                              const SizedBox(width: 4),
                              Text(row.balance >= 0 ? 'مدين' : 'دائن', style: TextStyle(fontSize: 10, color: row.balance >= 0 ? Colors.red.shade700 : Colors.green.shade700)),
                            ],
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                // Balance summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('الرصيد الافتتاحي:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                          Row(
                            children: [
                              Text('${NumberFormat('#,##0.00').format(statement.openingBalance.abs())} ${statement.currencySymbol}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statement.openingBalance >= 0 ? Colors.red.shade700 : Colors.green.shade700)),
                              const SizedBox(width: 4),
                              Text(statement.openingBalance >= 0 ? 'مدين' : 'دائن', style: TextStyle(fontSize: 10, color: statement.openingBalance >= 0 ? Colors.red.shade700 : Colors.green.shade700)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('إجمالي المدين:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                          Text('${NumberFormat('#,##0.00').format(statement.totalDebit)} ${statement.currencySymbol}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('إجمالي الدائن:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                          Text('${NumberFormat('#,##0.00').format(statement.totalCredit)} ${statement.currencySymbol}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
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
                            Text('الرصيد النهائي:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryMaroon)),
                            Row(
                              children: [
                                Text('${NumberFormat('#,##0.00').format(statement.closingBalance.abs())} ${statement.currencySymbol}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: statement.closingBalance >= 0 ? Colors.red.shade700 : Colors.green.shade700)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (statement.closingBalance >= 0 ? Colors.red : Colors.green).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(statement.closingBalance >= 0 ? 'مدين' : 'دائن', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statement.closingBalance >= 0 ? Colors.red.shade700 : Colors.green.shade700)),
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
        }).toList(),
      ],
    );
  }

  String _getTranslatedOperationType(String operationType) {
    switch (operationType) {
      case 'Receipt':
        return 'سند قبض';
      case 'Payment':
        return 'سند دفع';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppColors.primaryMaroon,
        foregroundColor: AppColors.textOnDark,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primaryMaroon,
              labelColor: AppColors.primaryMaroon,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: 'معاينة HTML', icon: Icon(Icons.view_list, size: 20)),
                Tab(text: 'معاينة PDF', icon: Icon(Icons.picture_as_pdf, size: 20)),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _selectedTabIndex == 0
                ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
                    child: _buildPreviewContent(),
                  )
                : _buildPDFPreview(),
          ),
          Container(
            padding: const EdgeInsets.all(16),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    context,
                    icon: Icons.print,
                    label: 'طباعة',
                    color: AppColors.primaryMaroon,
                    onPressed: () => _printReport(context),
                  ),
                  _buildActionButton(
                    context,
                    icon: Icons.share,
                    label: 'مشاركة',
                    color: Colors.blue,
                    onPressed: () => _shareReport(context),
                  ),
                  _buildActionButton(
                    context,
                    icon: Icons.file_download,
                    label: 'PDF',
                    color: Colors.red,
                    onPressed: () => _exportToPDF(context),
                  ),
                  _buildActionButton(
                    context,
                    icon: Icons.table_chart,
                    label: 'Excel',
                    color: Colors.green,
                    onPressed: () => _exportToExcel(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPDFPreview() {
    if (_isGeneratingPDF) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'جارٍ إنشاء PDF...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    if (_pdfBytes == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'فشل في إنشاء PDF',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _generatePDFBytes,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    return PdfPreview(
      build: (PdfPageFormat format) => _pdfBytes!,
      allowPrinting: true,
      allowSharing: true,
      canChangeOrientation: false,
      canChangePageFormat: false,
      canDebug: false,
      pdfFileName: '${widget.title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: color),
          onPressed: onPressed,
          iconSize: 28,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _printReport(BuildContext context) async {
    try {
      final pdf = await _generatePDF();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
      
      if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
            content: Text('تم فتح نافذة الطباعة'),
            backgroundColor: Colors.green,
      ),
    );
  }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<pw.Document> _generatePDF() async {
    try {
      debugPrint('PrintPreviewScreen: Starting _generatePDF...');

      final pdf = pw.Document();
      final userProfileService = UserProfileService();
      
      debugPrint('PrintPreviewScreen: Getting user profile...');
      final userProfile = await userProfileService.getUserProfile();
      debugPrint('PrintPreviewScreen: User profile loaded: ${userProfile?.name}');
      
      final currentUser = FirebaseAuth.instance.currentUser;
      debugPrint('PrintPreviewScreen: Current user: ${currentUser?.email}');

      // Load Arabic fonts
      debugPrint('PrintPreviewScreen: Loading Arabic fonts...');
      final arabicFont = await _loadArabicFont();
      final arabicBoldFont = await _loadArabicBoldFont();
      debugPrint('PrintPreviewScreen: Fonts loaded successfully');

    // Get logo image if available, otherwise use default logo
    pw.ImageProvider? logoImage;
    
    // Try to load user's logo first
    if (userProfile?.logoUrl != null && userProfile!.logoUrl!.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(userProfile.logoUrl!));
        if (response.statusCode == 200) {
          logoImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        // User logo loading failed, try default logo
      }
    }
    
    // If no user logo, load default logo from assets
    if (logoImage == null) {
      try {
        final logoBytes = await rootBundle.load('assets/images/logo.png');
        logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (e) {
        // Default logo loading failed, continue without it
      }
    }
      
      // Use half A4 page for single transaction vouchers
      final pageFormat = widget.reportType == ReportType.singleTransaction
          ? PdfPageFormat(210 * PdfPageFormat.mm, 148.5 * PdfPageFormat.mm) // Half A4 (A5 - width x height)
          : PdfPageFormat.a4;
      final margin = widget.reportType == ReportType.singleTransaction
          ? const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10) // Very small margins for maximum space
          : const pw.EdgeInsets.all(40);
      
      pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: margin,
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicBoldFont,
        ),
        // CRITICAL: Set default text direction to RTL for Arabic support
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return [
            // Header with Logo and Company Info
            _buildPDFHeader(logoImage, userProfile, currentUser, arabicFont, arabicBoldFont),
            pw.SizedBox(height: 20),
            
            // Report Title - For single transaction, extract account name from metadata
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF800000), // Maroon color
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Center(
                child: _buildArabicText(
                  // For single transaction, show account name prominently
                  widget.reportType == ReportType.singleTransaction && widget.metadata?['accountName'] != null
                      ? '${widget.metadata!['accountName']}'
                      : widget.title,
                  arabicBoldFont,
                  fontSize: 20, // Reduced from 24 to 20
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  textAlign: pw.TextAlign.center,
                  maxLines: 2,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            // Report Date/Time
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildArabicText(
                  'تاريخ الطباعة: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                  arabicFont,
                  fontSize: 9,
                  color: PdfColors.grey600,
                  textAlign: pw.TextAlign.right,
                ),
                _buildArabicText(
                  'Print Date: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                  arabicFont,
                  fontSize: 9,
                  color: PdfColors.grey600,
                  textAlign: pw.TextAlign.left,
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            
            // Report Metadata
            if (widget.metadata != null) ...[
              _buildPDFMetadata(arabicFont, arabicBoldFont),
              pw.SizedBox(height: 20),
            ],
            
            // Report Content
            if (widget.metadata?['statementsByCurrency'] != null)
              _buildPDFAccountStatement(arabicFont, arabicBoldFont)
            else if (widget.reportType == ReportType.singleTransaction && widget.metadata?['rows'] != null && (widget.metadata!['rows'] as List).isNotEmpty)
              _buildSingleTransactionVoucher(arabicFont, arabicBoldFont, logoImage, userProfile, currentUser)
            else if (widget.metadata?['rows'] != null && widget.metadata!['rows'] is List)
              _buildPDFTable(arabicFont, arabicBoldFont)
            else
              _buildArabicText(
                'لا توجد بيانات لعرضها',
                arabicFont,
                fontSize: 12,
                color: PdfColors.grey600,
                textAlign: pw.TextAlign.center,
              ),
            
            pw.Spacer(),
            
            // Footer
            pw.Divider(),
            pw.SizedBox(height: 10),
            _buildPDFFooter(arabicFont),
          ];
        },
      ),
    );
    
    debugPrint('PrintPreviewScreen: PDF document created successfully');
    return pdf;
    } catch (e, stackTrace) {
      debugPrint('PrintPreviewScreen: Error in _generatePDF: $e');
      debugPrint('PrintPreviewScreen: Stack trace: $stackTrace');
      rethrow; // Re-throw to be caught by caller
    }
  }

  pw.Widget _buildPDFHeader(pw.ImageProvider? logoImage, dynamic userProfile, dynamic currentUser, pw.Font arabicFont, pw.Font arabicBoldFont) {
    // Maroon color for logo background (0xFF800000 = #800000)
    final maroonColor = PdfColor.fromInt(0xFF800000);
    
    // Company name in Arabic and English - Normalize to remove problematic characters
    final companyNameArabic = _normalizeArabicText(userProfile?.name ?? 'شركة الظفري للصرافة والتحويلات');
    final companyNameEnglish = userProfile?.name ?? 'Al-Dafary Co. Exchange & Transfers';
    final address = _normalizeArabicText(userProfile?.address ?? '');
    final phone = userProfile?.phone ?? '';
    
    // Get text properties for Arabic text
    final arabicNameProps = _getTextProperties(companyNameArabic);
    final addressProps = _getTextProperties(address);
    
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 15),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey400, width: 2),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // English Company Info (Left side)
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                _buildArabicText(
                  companyNameEnglish,
                  arabicBoldFont,
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                  textAlign: pw.TextAlign.left,
                ),
                if (address.isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  _buildArabicText(
                    address,
                    arabicFont,
                    fontSize: 10,
                    color: PdfColors.grey700,
                    textAlign: pw.TextAlign.left,
                  ),
                ],
                if (phone.isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  _buildArabicText(
                    'Tel: $phone',
                    arabicFont,
                    fontSize: 10,
                    color: PdfColors.grey700,
                    textAlign: pw.TextAlign.left,
                  ),
                ],
              ],
            ),
          ),
          
          pw.SizedBox(width: 10),
          
          // Logo with maroon background in center
          if (logoImage != null)
            pw.Container(
              width: 80,
              height: 80,
              decoration: pw.BoxDecoration(
                color: maroonColor,
                shape: pw.BoxShape.circle,
              ),
              padding: const pw.EdgeInsets.all(8),
              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
            ),
          
          pw.SizedBox(width: 10),
          
          // Arabic Company Info (Right side)
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                _buildArabicText(
                  companyNameArabic, // Already normalized
                  arabicBoldFont,
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                  textAlign: arabicNameProps['align'] as pw.TextAlign,
                  maxLines: 2,
                ),
                if (address.isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  _buildArabicText(
                    address, // Already normalized
                    arabicFont,
                    fontSize: 10,
                    color: PdfColors.grey700,
                    textAlign: pw.TextAlign.right,
                    maxLines: 2,
                  ),
                ],
                if (phone.isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  _buildArabicText(
                    'هاتف: $phone',
                    arabicFont,
                    fontSize: 10,
                    color: PdfColors.grey700,
                    textAlign: pw.TextAlign.right,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFMetadata(pw.Font arabicFont, pw.Font arabicBoldFont) {
    final metadata = widget.metadata;
    if (metadata == null) return pw.SizedBox.shrink();
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (metadata['accountName'] != null)
            _buildPDFMetadataRow('الحساب:', metadata['accountName'].toString(), arabicFont, arabicBoldFont),
          if (metadata['dateRange'] != null)
            _buildPDFMetadataRow('الفترة:', metadata['dateRange'].toString(), arabicFont, arabicBoldFont),
          if (metadata['count'] != null)
            _buildPDFMetadataRow('عدد السجلات:', metadata['count'].toString(), arabicFont, arabicBoldFont),
          if (metadata['operationType'] != null)
            _buildPDFMetadataRow('نوع العملية:', metadata['operationType'].toString(), arabicFont, arabicBoldFont),
          if (metadata['totalAmount'] != null)
            _buildPDFMetadataRow(
              'الإجمالي:',
              (() {
                final totalAmount = metadata['totalAmount'];
                return totalAmount is num
                    ? NumberFormat('#,##0.00').format(totalAmount)
                    : totalAmount.toString();
              })(),
              arabicFont,
              arabicBoldFont,
            ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFMetadataRow(String label, String value, pw.Font arabicFont, pw.Font arabicBoldFont) {
    // Normalize Arabic text
    final normalizedLabel = _normalizeArabicText(label);
    final normalizedValue = _normalizeArabicText(value);
    
    // Get text properties
    final labelProps = _getTextProperties(normalizedLabel);
    final valueProps = _getTextProperties(normalizedValue);
    
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Expanded(
            child: _buildArabicText(
              normalizedValue,
              arabicFont,
              fontSize: 11,
              textAlign: valueProps['align'] as pw.TextAlign,
            ),
          ),
          pw.SizedBox(width: 10),
          _buildArabicText(
            normalizedLabel,
            arabicBoldFont,
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            textAlign: labelProps['align'] as pw.TextAlign,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFTable(pw.Font arabicFont, pw.Font arabicBoldFont) {
    final metadata = widget.metadata;
    if (metadata == null || metadata['rows'] == null || metadata['rows'] is! List) {
      return pw.SizedBox.shrink();
    }

    final rows = metadata['rows'] as List;
    final headers = metadata['headers'] as List<String>? ?? [];

    if (rows.isEmpty) {
      return _buildArabicText(
        'لا توجد بيانات لعرضها',
        arabicFont,
        fontSize: 12,
        color: PdfColors.grey600,
        textAlign: pw.TextAlign.center,
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey600, width: 1),
      columnWidths: {
        for (int i = 0; i < headers.length; i++)
          i: pw.FlexColumnWidth(1),
      },
      children: [
        // Header Row
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFF800000), // Maroon header
          ),
          children: headers.map((header) {
            // Normalize header text
            final normalizedHeader = _normalizeArabicText(header);
            final headerProps = _getTextProperties(normalizedHeader);
            
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: _buildArabicText(
                normalizedHeader,
                arabicBoldFont,
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                textAlign: headerProps['align'] as pw.TextAlign,
                maxLines: 2,
              ),
            );
          }).toList(),
        ),
        
        // Data Rows
        ...rows.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          final rowData = row is List ? row : row.toString().split('\t');
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: index % 2 == 0 ? PdfColors.grey50 : PdfColors.white,
            ),
            children: rowData.map((cell) {
              final cellValue = cell.toString().trim();
              // Normalize Arabic text
              final normalizedText = _normalizeArabicText(cellValue);
              
              // Get text properties (alignment and direction)
              final textProps = _getTextProperties(normalizedText);
              
              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: _buildArabicText(
                  normalizedText,
                  arabicFont,
                  fontSize: 10,
                  color: PdfColors.black,
                  textAlign: textProps['align'] as pw.TextAlign,
                  maxLines: 3,
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  pw.Widget _buildPDFAccountStatement(pw.Font arabicFont, pw.Font arabicBoldFont) {
    final metadata = widget.metadata;
    if (metadata == null || metadata['statementsByCurrency'] == null) {
      return pw.SizedBox.shrink();
    }

    final statementsByCurrency = metadata['statementsByCurrency'] as Map<String, AccountStatementByCurrency>?;
    if (statementsByCurrency == null || statementsByCurrency.isEmpty) {
      return _buildArabicText(
        'لا توجد بيانات لعرضها',
        arabicFont,
        fontSize: 12,
        color: PdfColors.grey600,
        textAlign: pw.TextAlign.center,
      );
    }

            return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: statementsByCurrency.values.map((statement) {
        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 20),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Currency Header
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF800000), // Maroon
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildArabicText(
                  'Currency: ${statement.currencySymbol}',
                  arabicBoldFont,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  textAlign: pw.TextAlign.left,
                ),
                _buildArabicText(
                  'العملة: ${statement.currencySymbol}',
                  arabicBoldFont,
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  textAlign: pw.TextAlign.right,
                ),
                  ],
                ),
              ),
                  pw.SizedBox(height: 10),
              
              // Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey600, width: 1),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.2),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                  4: const pw.FlexColumnWidth(1.2),
                  5: const pw.FlexColumnWidth(0.8),
                },
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFF800000), // Maroon header
                    ),
                    children: [
                      _buildPDFCell(_normalizeArabicText('التاريخ'), arabicBoldFont, true),
                      _buildPDFCell(_normalizeArabicText('العملية'), arabicBoldFont, true),
                      _buildPDFCell(_normalizeArabicText('مدين'), arabicBoldFont, true),
                      _buildPDFCell(_normalizeArabicText('دائن'), arabicBoldFont, true),
                      _buildPDFCell(_normalizeArabicText('الرصيد'), arabicBoldFont, true),
                      _buildPDFCell(_normalizeArabicText('النوع'), arabicBoldFont, true),
                    ],
                  ),
                  
                  // Data Rows
                  ...statement.rows.asMap().entries.map((entry) {
                    final index = entry.key;
                    final row = entry.value;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: index % 2 == 0 ? PdfColors.grey50 : PdfColors.white,
                      ),
                      children: [
                        _buildPDFCell(DateFormat('yyyy-MM-dd').format(row.date), arabicFont, false),
                        _buildPDFCell(_normalizeArabicText(_getTranslatedOperationType(row.operationType)), arabicFont, false),
                        _buildPDFCell(row.debit > 0 ? NumberFormat('#,##0.00').format(row.debit) : '-', arabicFont, false),
                        _buildPDFCell(row.credit > 0 ? NumberFormat('#,##0.00').format(row.credit) : '-', arabicFont, false),
                        _buildPDFCell(NumberFormat('#,##0.00').format(row.balance.abs()), arabicFont, false),
                        _buildPDFCell(_normalizeArabicText(row.balance >= 0 ? 'مدين' : 'دائن'), arabicFont, false),
                      ],
                    );
                  }),
                ],
              ),
              
              pw.SizedBox(height: 10),
              
              // Balance Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildPDFBalanceRow(_normalizeArabicText('الرصيد الافتتاحي:'), '${NumberFormat('#,##0.00').format(statement.openingBalance.abs())} ${statement.currencySymbol} ${_normalizeArabicText(statement.openingBalance >= 0 ? 'مدين' : 'دائن')}', arabicFont, arabicBoldFont),
                    pw.SizedBox(height: 4),
                    _buildPDFBalanceRow(_normalizeArabicText('إجمالي المدين:'), '${NumberFormat('#,##0.00').format(statement.totalDebit)} ${statement.currencySymbol}', arabicFont, arabicBoldFont),
                    pw.SizedBox(height: 4),
                    _buildPDFBalanceRow(_normalizeArabicText('إجمالي الدائن:'), '${NumberFormat('#,##0.00').format(statement.totalCredit)} ${statement.currencySymbol}', arabicFont, arabicBoldFont),
                    pw.SizedBox(height: 8),
                pw.Divider(),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFFF2E6E6), // Light maroon tint (maroon with opacity 0.1 on white)
                        border: pw.Border.all(
                          color: PdfColor.fromInt(0xFF800000),
                          width: 2,
                        ),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: _buildPDFBalanceRow(_normalizeArabicText('الرصيد النهائي:'), '${NumberFormat('#,##0.00').format(statement.closingBalance.abs())} ${statement.currencySymbol} ${_normalizeArabicText(statement.closingBalance >= 0 ? 'مدين' : 'دائن')}', arabicBoldFont, arabicBoldFont, isBold: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  pw.Widget _buildPDFCell(String text, pw.Font font, bool isHeader) {
    // Normalize Arabic text - CRITICAL for proper rendering
    final normalizedText = _normalizeArabicText(text);
    
    // Check if text is Arabic
    final isArabic = _isArabicText(normalizedText);
    
    // Get text properties (alignment and direction)
    final textProps = _getTextProperties(normalizedText);
    
    // For Arabic text, ALWAYS use RTL and right alignment
    final finalDirection = isArabic ? pw.TextDirection.rtl : (textProps['direction'] as pw.TextDirection);
    final finalAlign = isArabic ? pw.TextAlign.right : (textProps['align'] as pw.TextAlign);
    
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: isHeader
          ? pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF800000), // Maroon header
            )
          : null,
      child: _buildArabicText(
        normalizedText,
        font,
        fontSize: isHeader ? 11 : 10,
        fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: isHeader ? PdfColors.white : PdfColors.black,
        textAlign: finalAlign,
        maxLines: 3,
      ),
    );
  }

  pw.Widget _buildPDFBalanceRow(String label, String value, pw.Font labelFont, pw.Font valueFont, {bool isBold = false}) {
    // Normalize Arabic text
    final normalizedLabel = _normalizeArabicText(label);
    final normalizedValue = _normalizeArabicText(value);
    
    // Get text properties
    final labelProps = _getTextProperties(normalizedLabel);
    final valueProps = _getTextProperties(normalizedValue);
    
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _buildArabicText(
          normalizedValue,
          valueFont,
          fontSize: isBold ? 12 : 10,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          textAlign: valueProps['align'] as pw.TextAlign,
        ),
        _buildArabicText(
          normalizedLabel,
          labelFont,
          fontSize: isBold ? 11 : 10,
          fontWeight: pw.FontWeight.bold,
          textAlign: labelProps['align'] as pw.TextAlign,
        ),
      ],
    );
  }

  pw.Widget _buildPDFFooter(pw.Font arabicFont) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey400, width: 1),
        ),
      ),
      child: pw.Center(
        child: _buildArabicText(
          'تم إنشاء هذا التقرير بواسطة النظام المحاسبي الإلكتروني | ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
          arabicFont,
          fontSize: 8,
          color: PdfColors.grey600,
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }

  // Ultra-compact header for voucher (minimal header)
  pw.Widget _buildCompactVoucherHeader(
    pw.ImageProvider? logoImage,
    String companyNameArabic,
    String companyNameEnglish,
    String address,
    String phone,
    pw.Font arabicFont,
    pw.Font arabicBoldFont,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Company Info (Left - English) - Ultra Compact
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              _buildArabicText(
                companyNameEnglish,
                arabicBoldFont,
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
                textAlign: pw.TextAlign.left,
              ),
              if (address.isNotEmpty) ...[
                pw.SizedBox(height: 0.5),
                _buildArabicText(
                  address,
                  arabicFont,
                  fontSize: 6,
                  color: PdfColors.grey700,
                  textAlign: pw.TextAlign.left,
                ),
              ],
              if (phone.isNotEmpty) ...[
                pw.SizedBox(height: 0.5),
                _buildArabicText(
                  'Tel: $phone',
                  arabicFont,
                  fontSize: 6,
                  color: PdfColors.grey700,
                  textAlign: pw.TextAlign.left,
                ),
              ],
            ],
          ),
        ),
        
        pw.SizedBox(width: 4),
        
        // Logo (Center) - Very Small
        if (logoImage != null)
          pw.Container(
            width: 20,
            height: 20,
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF800000), // Maroon background
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Center(
              child: pw.Image(logoImage, width: 18, height: 18, fit: pw.BoxFit.contain),
            ),
          )
        else
          pw.SizedBox(width: 20),
        
        pw.SizedBox(width: 4),
        
        // Company Info (Right - Arabic) - Ultra Compact
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              _buildArabicText(
                companyNameArabic,
                arabicBoldFont,
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
                textAlign: pw.TextAlign.right,
              ),
              if (address.isNotEmpty) ...[
                pw.SizedBox(height: 0.5),
                _buildArabicText(
                  address,
                  arabicFont,
                  fontSize: 6,
                  color: PdfColors.grey700,
                  textAlign: pw.TextAlign.right,
                ),
              ],
              if (phone.isNotEmpty) ...[
                pw.SizedBox(height: 0.5),
                _buildArabicText(
                  'هاتف: $phone',
                  arabicFont,
                  fontSize: 6,
                  color: PdfColors.grey700,
                  textAlign: pw.TextAlign.right,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Ultra-compact Footer for voucher
  pw.Widget _buildVoucherFooter(pw.Font arabicFont, pw.Font arabicBoldFont, String date) {
    final now = DateTime.now();
    final formattedDateTime = DateFormat('dd/MM/yyyy hh:mm:ss a').format(now);
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Divider(height: 0.5, color: PdfColors.grey400),
        pw.SizedBox(height: 2),
        
        // Client Name and Signature Row (compact)
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildArabicText(
              'التوقيع',
              arabicBoldFont,
              fontSize: 6,
              fontWeight: pw.FontWeight.bold,
              textAlign: pw.TextAlign.right,
            ),
            pw.SizedBox(width: 10),
            _buildArabicText(
              'اسم العميل: ....................',
              arabicFont,
              fontSize: 6,
              textAlign: pw.TextAlign.right,
            ),
          ],
        ),
        
        pw.SizedBox(height: 1.5),
        
        // Branch and Employee (compact)
        _buildArabicText(
          'الفرع: المركز الرئيسي  |  الموظف: [اسم الموظف]',
          arabicFont,
          fontSize: 6,
          textAlign: pw.TextAlign.right,
        ),
        
        pw.SizedBox(height: 2),
        
        // Note and Timestamp in one row
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildArabicText(
              formattedDateTime,
              arabicFont,
              fontSize: 5,
              color: PdfColors.grey600,
              textAlign: pw.TextAlign.left,
            ),
            _buildArabicText(
              'هذا الإشعار لي ولا يحتاج ختم أو توقيع',
              arabicFont,
              fontSize: 5,
              color: PdfColors.grey600,
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildSingleTransactionVoucher(
    pw.Font arabicFont,
    pw.Font arabicBoldFont,
    pw.ImageProvider? logoImage,
    dynamic userProfile,
    dynamic currentUser,
  ) {
    final metadata = widget.metadata;
    if (metadata == null || metadata['rows'] == null || (metadata['rows'] as List).isEmpty) {
      return pw.SizedBox.shrink();
    }

    final rows = metadata['rows'] as List;
    final headers = metadata['headers'] as List<String>? ?? [];
    final rowData = rows[0] as List<dynamic>;
    
    // Extract and normalize data
    final serialNumber = rowData.length > 0 ? _normalizeArabicText(rowData[0].toString()) : '';
    final operationTypeRaw = rowData.length > 1 ? rowData[1].toString() : '';
    final operationType = rowData.length > 1 ? _normalizeArabicText(_getTranslatedOperationType(operationTypeRaw)) : '';
    final debitAccount = rowData.length > 2 ? _normalizeArabicText(rowData[2].toString()) : '';
    final creditAccount = rowData.length > 3 ? _normalizeArabicText(rowData[3].toString()) : '';
    final amount = rowData.length > 4 ? (double.tryParse(rowData[4].toString().replaceAll(',', '')) ?? 0.0) : 0.0;
    final currency = rowData.length > 5 ? _normalizeArabicText(rowData[5].toString()) : '';
    final date = rowData.length > 6 ? _normalizeArabicText(rowData[6].toString()) : DateFormat('yyyy-MM-dd').format(DateTime.now());
    final description = rowData.length > 7 ? _normalizeArabicText(rowData[7].toString()) : '';
    
    // Determine relevant account name based on operation type
    String relevantAccount;
    String notificationText;
    if (operationTypeRaw == 'Payment' || operationTypeRaw == 'SellCurrency') {
      // Payment or Sell Currency - show debit account (the account paying)
      relevantAccount = debitAccount;
      notificationText = 'نود إشعاركم أننا قيدنا على حسابكم لدينا حسب التفاصيل التالية';
    } else if (operationTypeRaw == 'Receipt' || operationTypeRaw == 'BuyCurrency') {
      // Receipt or Buy Currency - show credit account (the account receiving)
      relevantAccount = creditAccount;
      notificationText = 'نود إشعاركم أننا أضفنا إلى حسابكم لدينا حسب التفاصيل التالية';
    } else {
      // Journal entry - show both accounts or credit account
      relevantAccount = creditAccount;
      notificationText = 'نود إشعاركم أننا قيدنا العملية التالية';
    }
    
    // Get currency name for Arabic number conversion
    String currencyName = 'ريال يمني';
    if (currency.contains('سعودي') || currency.contains('SAR')) {
      currencyName = 'ريال سعودي';
    } else if (currency.contains('دولار') || currency.contains('USD')) {
      currencyName = 'دولار أمريكي';
    }
    
    final amountInWords = ArabicNumberToWords.convert(amount, currencyName);
    final formattedAmount = NumberFormat('#,##0.00').format(amount);

    // Get company info
    final companyNameArabic = userProfile?.name ?? 'الشركة';
    final companyNameEnglish = userProfile?.name ?? 'Company';
    final address = userProfile?.address ?? '';
    final phone = userProfile?.phone ?? '';

    // Format date for display (convert yyyy-MM-dd to yyyy/MM/dd if needed)
    String formattedDate = date;
    if (date.contains('-')) {
      formattedDate = date.replaceAll('-', '/');
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Ultra-compact Header (minimal)
        _buildCompactVoucherHeader(logoImage, companyNameArabic, companyNameEnglish, address, phone, arabicFont, arabicBoldFont),
        
        pw.SizedBox(height: 3),
        
        // Main Title - Operation Type (e.g., إشعار مدين، سند قبض، قيد يومية)
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1.5),
            borderRadius: pw.BorderRadius.circular(2),
          ),
          child: pw.Center(
            child: _buildArabicText(
              operationType.isEmpty ? 'نوع العملية' : operationType,
              arabicBoldFont,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
              textAlign: pw.TextAlign.center,
            ),
          ),
        ),
        
        pw.SizedBox(height: 3),
        
        // Voucher Number and Date Row (very compact)
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            // Serial Number Box (left)
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1),
                  borderRadius: pw.BorderRadius.circular(2),
                ),
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    _buildArabicText(
                      serialNumber,
                      arabicBoldFont,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 1),
                    _buildArabicText(
                      'رقم الإشعار',
                      arabicFont,
                      fontSize: 6,
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            
            pw.SizedBox(width: 4),
            
            // Date Box (right)
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1),
                  borderRadius: pw.BorderRadius.circular(2),
                ),
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    _buildArabicText(
                      formattedDate,
                      arabicBoldFont,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 1),
                    _buildArabicText(
                      'التاريخ',
                      arabicFont,
                      fontSize: 6,
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        
        pw.SizedBox(height: 3),
        
        // Recipient Name and Account Number - Combined in one row
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            // Account Number Box (left)
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1),
                  borderRadius: pw.BorderRadius.circular(2),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: _buildArabicText(
                        relevantAccount.isEmpty ? '---' : relevantAccount,
                        arabicFont,
                        fontSize: 7,
                        textAlign: pw.TextAlign.right,
                        maxLines: 1,
                      ),
                    ),
                    pw.SizedBox(width: 3),
                    _buildArabicText(
                      'رقم الحساب:',
                      arabicBoldFont,
                      fontSize: 6,
                      fontWeight: pw.FontWeight.bold,
                      textAlign: pw.TextAlign.right,
                    ),
                  ],
                ),
              ),
            ),
            
            pw.SizedBox(width: 4),
            
            // Recipient Name Box (right)
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1),
                  borderRadius: pw.BorderRadius.circular(2),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: _buildArabicText(
                        relevantAccount.isEmpty ? '---' : relevantAccount,
                        arabicFont,
                        fontSize: 7,
                        textAlign: pw.TextAlign.right,
                        maxLines: 1,
                      ),
                    ),
                    pw.SizedBox(width: 3),
                    _buildArabicText(
                      'السيد / السادة:',
                      arabicBoldFont,
                      fontSize: 6,
                      fontWeight: pw.FontWeight.bold,
                      textAlign: pw.TextAlign.right,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        
        pw.SizedBox(height: 3),
        
        // Notification Text (very compact)
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1),
            borderRadius: pw.BorderRadius.circular(2),
          ),
          child: _buildArabicText(
            notificationText,
            arabicFont,
            fontSize: 7,
            textAlign: pw.TextAlign.center,
            maxLines: 1,
          ),
        ),
        
        pw.SizedBox(height: 3),
        
        // Amount and Currency Row (combined)
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            // Amount Box
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1),
                  borderRadius: pw.BorderRadius.circular(2),
                ),
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    _buildArabicText(
                      '#$formattedAmount#',
                      arabicBoldFont,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 1),
                    _buildArabicText(
                      'مبلغ الحساب',
                      arabicFont,
                      fontSize: 6,
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            
            pw.SizedBox(width: 3),
            
            // Currency Box
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1),
                  borderRadius: pw.BorderRadius.circular(2),
                ),
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    _buildArabicText(
                      currency,
                      arabicBoldFont,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 1),
                    _buildArabicText(
                      'عملة الحساب',
                      arabicFont,
                      fontSize: 6,
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        
        pw.SizedBox(height: 3),
        
        // Amount in Words (compact)
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1),
            borderRadius: pw.BorderRadius.circular(2),
          ),
          child: _buildArabicText(
            amountInWords,
            arabicFont,
            fontSize: 7,
            textAlign: pw.TextAlign.center,
            maxLines: 1,
          ),
        ),
        
        pw.SizedBox(height: 3),
        
        // Description Section (compact)
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1),
            borderRadius: pw.BorderRadius.circular(2),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              _buildArabicText(
                'البيان:',
                arabicBoldFont,
                fontSize: 6,
                fontWeight: pw.FontWeight.bold,
                textAlign: pw.TextAlign.right,
              ),
              pw.SizedBox(height: 1),
              _buildArabicText(
                description.isNotEmpty ? description : operationType,
                arabicFont,
                fontSize: 7,
                textAlign: pw.TextAlign.right,
                maxLines: 2,
              ),
            ],
          ),
        ),
        
        pw.SizedBox(height: 4),
        
        // Footer Section (compact)
        _buildVoucherFooter(arabicFont, arabicBoldFont, formattedDate),
      ],
    );
  }

  Future<void> _shareReport(BuildContext context) async {
    try {
      // Create a temporary file with report data
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/report_${DateTime.now().millisecondsSinceEpoch}.txt');
      await file.writeAsString(_generateTextReport());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: widget.title,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToPDF(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('جارٍ إنشاء ملف PDF...'),
          backgroundColor: Colors.blue,
        ),
      );

      final pdf = await _generatePDF();
      final bytes = await pdf.save();

      final tempDir = await getTemporaryDirectory();
      final fileName = 'report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      // Share the PDF file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'تقرير PDF: ${widget.title}',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء ملف PDF بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToExcel(BuildContext context) async {
    try {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('جارٍ إنشاء ملف Excel...'),
        backgroundColor: Colors.blue,
      ),
    );

      final excel = Excel.createExcel();
      excel.delete('Sheet1');
      final sheet = excel[widget.title.length > 31 ? widget.title.substring(0, 31) : widget.title];
      
      final userProfileService = UserProfileService();
      final userProfile = await userProfileService.getUserProfile();
      final currentUser = FirebaseAuth.instance.currentUser;

      int row = 0;

      // Company Header
      final headerCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      headerCell.value = userProfile?.name ?? 'شركة الظفري المالي';
      row++;

      if (userProfile?.address != null) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = userProfile!.address!;
        row++;
      }
      if (userProfile?.phone != null) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 'هاتف: ${userProfile!.phone!}';
        row++;
      }
      if (currentUser?.email != null) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 'البريد: ${currentUser!.email}';
        row++;
      }

      row++;
      
      // Report Title
      final titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      titleCell.value = widget.title;
      row += 2;

      // Metadata
      final metadata = widget.metadata;
      if (metadata != null) {
        if (metadata['accountName'] != null) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 'الحساب:';
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = metadata['accountName'];
          row++;
        }
        if (metadata['dateRange'] != null) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 'الفترة:';
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = metadata['dateRange'];
          row++;
        }
        if (metadata['count'] != null) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 'عدد السجلات:';
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = metadata['count'];
          row++;
        }
        if (metadata['totalAmount'] != null) {
          final totalAmount = metadata['totalAmount'];
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 'الإجمالي:';
          if (totalAmount is num) {
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = NumberFormat('#,##0.00').format(totalAmount);
          } else {
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = totalAmount.toString();
          }
          row++;
        }
      }

      row++;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 'تاريخ التقرير:';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
      row += 2;

      // Check for statementsByCurrency (account statement with multiple currencies)
      if (metadata?['statementsByCurrency'] != null) {
        final metadata = widget.metadata;
        if (metadata == null || metadata['statementsByCurrency'] == null) {
          return;
        }
        final statementsByCurrency = metadata['statementsByCurrency'] as Map<String, AccountStatementByCurrency>?;
        if (statementsByCurrency == null) return;
        
        for (var statement in statementsByCurrency.values) {
          // Currency Header
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 'العملة: ${statement.currencySymbol}';
          row += 2;
          
          // Table Headers
          final headers = ['التاريخ', 'العملية', 'مدين', 'دائن', 'الرصيد', 'النوع'];
          for (int col = 0; col < headers.length; col++) {
            final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
            cell.value = headers[col];
          }
          row++;

          // Table Data
          for (var dataRow in statement.rows) {
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = DateFormat('yyyy-MM-dd').format(dataRow.date);
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = _getTranslatedOperationType(dataRow.operationType);
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = dataRow.debit > 0 ? NumberFormat('#,##0.00').format(dataRow.debit) : '-';
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = dataRow.credit > 0 ? NumberFormat('#,##0.00').format(dataRow.credit) : '-';
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = NumberFormat('#,##0.00').format(dataRow.balance.abs());
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = dataRow.balance >= 0 ? 'مدين' : 'دائن';
            row++;
          }
          
          row++;
          
          // Balance Summary
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 'الرصيد الافتتاحي:';
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = '${NumberFormat('#,##0.00').format(statement.openingBalance.abs())} ${statement.currencySymbol} ${statement.openingBalance >= 0 ? 'مدين' : 'دائن'}';
          row++;
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 'إجمالي المدين:';
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = '${NumberFormat('#,##0.00').format(statement.totalDebit)} ${statement.currencySymbol}';
          row++;
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 'إجمالي الدائن:';
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = '${NumberFormat('#,##0.00').format(statement.totalCredit)} ${statement.currencySymbol}';
          row++;
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 'الرصيد النهائي:';
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = '${NumberFormat('#,##0.00').format(statement.closingBalance.abs())} ${statement.currencySymbol} ${statement.closingBalance >= 0 ? 'مدين' : 'دائن'}';
          row += 2;
        }
      } else {
        // Standard table (headers and rows)
        final metadata2 = widget.metadata;
        if (metadata2?['headers'] != null && metadata2!['headers'] is List) {
          final headers = metadata2!['headers'] as List<String>;
          for (int col = 0; col < headers.length; col++) {
            final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
            cell.value = headers[col];
          }
          row++;

          // Table Data
          if (metadata2?['rows'] != null && metadata2!['rows'] is List) {
            final rows = metadata2!['rows'] as List;
            for (var dataRow in rows) {
              final rowData = dataRow is List ? dataRow : dataRow.toString().split('\t');
              for (int col = 0; col < rowData.length && col < headers.length; col++) {
                sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row)).value = rowData[col].toString();
              }
              row++;
            }
          }
        }
      }

      final excelBytes = excel.encode();
      if (excelBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final fileName = 'report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(excelBytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'تقرير Excel: ${widget.title}',
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إنشاء ملف Excel بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _generateTextReport() {
    final buffer = StringBuffer();
    buffer.writeln(widget.title);
    buffer.writeln('=' * 50);
    buffer.writeln();
    
    final metadata = widget.metadata;
    if (metadata != null) {
      if (metadata['accountName'] != null) {
        buffer.writeln('الحساب: ${metadata['accountName']}');
      }
      if (metadata['dateRange'] != null) {
        buffer.writeln('الفترة: ${metadata['dateRange']}');
      }
      if (metadata['count'] != null) {
        buffer.writeln('عدد السجلات: ${metadata['count']}');
      }
      if (metadata['operationType'] != null) {
        buffer.writeln('نوع العملية: ${metadata['operationType']}');
      }
      buffer.writeln();
    }
    
    buffer.writeln('تاريخ التقرير: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
    buffer.writeln();
    buffer.writeln('ملاحظة: هذا تقرير تم إنشاؤه من التطبيق المحاسبي');
    
    return buffer.toString();
  }
}

