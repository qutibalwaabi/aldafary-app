import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:untitled/core/services/exchange_rate_service.dart';
import 'package:untitled/core/services/currency_service.dart';
import 'package:untitled/core/models/currency_model.dart';
import 'package:untitled/shared/widgets/loading_overlay.dart';
import 'package:untitled/shared/theme/app_theme.dart';
import 'package:untitled/shared/widgets/app_card.dart';
import 'package:untitled/theme/app_colors.dart';

class AddEditExchangeRateScreen extends StatefulWidget {
  final Map<String, dynamic>? exchangeRate; // null for add, not null for edit

  const AddEditExchangeRateScreen({super.key, this.exchangeRate});

  @override
  State<AddEditExchangeRateScreen> createState() => _AddEditExchangeRateScreenState();
}

class _AddEditExchangeRateScreenState extends State<AddEditExchangeRateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _basePriceController = TextEditingController();
  final _maxPriceController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _exchangeRateService = ExchangeRateService();
  final _currencyService = CurrencyService();
  
  String? _fromCurrencyId;
  String? _toCurrencyId;
  bool _isLoading = false;
  bool get _isEditing => widget.exchangeRate != null;

  List<CurrencyModel> _currencies = [];
  List<DropdownMenuItem<String>> _fromCurrencyItems = [];
  List<DropdownMenuItem<String>> _toCurrencyItems = [];

  @override
  void initState() {
    super.initState();
    _fetchCurrencies();
    if (_isEditing && widget.exchangeRate != null) {
      _fromCurrencyId = widget.exchangeRate!['fromCurrencyId'];
      _toCurrencyId = widget.exchangeRate!['toCurrencyId'];
      _basePriceController.text = (widget.exchangeRate!['basePrice'] ?? widget.exchangeRate!['rate'] ?? 0.0).toStringAsFixed(4);
      _maxPriceController.text = (widget.exchangeRate!['maxPrice'] ?? widget.exchangeRate!['rate'] ?? 0.0).toStringAsFixed(4);
      _minPriceController.text = (widget.exchangeRate!['minPrice'] ?? widget.exchangeRate!['rate'] ?? 0.0).toStringAsFixed(4);
    }
  }

  Future<void> _fetchCurrencies() async {
    try {
      final currencies = await _currencyService.streamCurrencies().first;
      // Remove duplicates by ID to prevent dropdown errors
      final uniqueCurrencies = currencies.fold<Map<String, CurrencyModel>>(
        {},
        (map, currency) {
          if (!map.containsKey(currency.id)) {
            map[currency.id] = currency;
          }
          return map;
        },
      ).values.toList();
      
      setState(() {
        _currencies = uniqueCurrencies;
        _fromCurrencyItems = uniqueCurrencies.map((c) => DropdownMenuItem<String>(
          value: c.id,
          child: Text('${c.name} (${c.symbol})'),
        )).toList();
        _toCurrencyItems = uniqueCurrencies.map((c) => DropdownMenuItem<String>(
          value: c.id,
          child: Text('${c.name} (${c.symbol})'),
        )).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ في تحميل العملات: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _saveRate() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_fromCurrencyId == null || _toCurrencyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار العملات')),
      );
      return;
    }

    if (_fromCurrencyId == _toCurrencyId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن إضافة سعر تحويل للعملة نفسها')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final basePrice = double.tryParse(_basePriceController.text.trim());
      final maxPrice = double.tryParse(_maxPriceController.text.trim());
      final minPrice = double.tryParse(_minPriceController.text.trim());

      if (basePrice == null || basePrice <= 0) {
        throw Exception('السعر الرئيسي يجب أن يكون أكبر من الصفر');
      }
      if (maxPrice == null || maxPrice <= 0) {
        throw Exception('أعلى سعر يجب أن يكون أكبر من الصفر');
      }
      if (minPrice == null || minPrice <= 0) {
        throw Exception('أقل سعر يجب أن يكون أكبر من الصفر');
      }
      if (minPrice > maxPrice) {
        throw Exception('أقل سعر يجب أن يكون أقل من أو يساوي أعلى سعر');
      }
      if (basePrice < minPrice || basePrice > maxPrice) {
        throw Exception('السعر الرئيسي يجب أن يكون بين أقل سعر وأعلى سعر');
      }

      if (_isEditing) {
        await _exchangeRateService.updateExchangeRate(
          rateId: widget.exchangeRate!['id'],
          basePrice: basePrice,
          maxPrice: maxPrice,
          minPrice: minPrice,
        );
      } else {
        await _exchangeRateService.createOrUpdateExchangeRate(
          fromCurrencyId: _fromCurrencyId!,
          toCurrencyId: _toCurrencyId!,
          basePrice: basePrice,
          maxPrice: maxPrice,
          minPrice: minPrice,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'تم تحديث سعر التحويل بنجاح' : 'تم حفظ سعر التحويل بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'تعديل سعر التحويل' : 'إضافة سعر تحويل جديد'),
        backgroundColor: AppColors.primaryMaroon,
        foregroundColor: AppColors.textOnDark,
        elevation: 0,
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isEditing ? 'تعديل سعر التحويل' : 'بيانات سعر التحويل الجديد',
                        style: AppTheme.heading3,
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        value: _fromCurrencyId,
                        decoration: AppTheme.inputDecoration('من عملة', icon: Icons.arrow_forward),
                        items: _fromCurrencyItems.where((item) => item.value != _toCurrencyId || _fromCurrencyId == item.value).toList(),
                        onChanged: _isEditing ? null : (val) {
                          setState(() {
                            _fromCurrencyId = val;
                            // Reset toCurrency if same as fromCurrency
                            if (_toCurrencyId == val) {
                              _toCurrencyId = null;
                            }
                          });
                        },
                        validator: (value) => value == null ? 'الرجاء اختيار العملة المصدر' : null,
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _toCurrencyId,
                        decoration: AppTheme.inputDecoration('إلى عملة', icon: Icons.arrow_downward),
                        items: _toCurrencyItems.where((item) => item.value != _fromCurrencyId || _toCurrencyId == item.value).toList(),
                        onChanged: _isEditing ? null : (val) {
                          setState(() {
                            _toCurrencyId = val;
                            // Reset fromCurrency if same as toCurrency
                            if (_fromCurrencyId == val) {
                              _fromCurrencyId = null;
                            }
                          });
                        },
                        validator: (value) => value == null ? 'الرجاء اختيار العملة الهدف' : null,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _basePriceController,
                        decoration: AppTheme.inputDecoration('السعر الرئيسي', icon: Icons.trending_up),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'الرجاء إدخال السعر الرئيسي';
                          }
                          final price = double.tryParse(value);
                          if (price == null || price <= 0) {
                            return 'السعر الرئيسي يجب أن يكون أكبر من الصفر';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _maxPriceController,
                        decoration: AppTheme.inputDecoration('أعلى سعر مسموح', icon: Icons.arrow_upward),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'الرجاء إدخال أعلى سعر';
                          }
                          final price = double.tryParse(value);
                          if (price == null || price <= 0) {
                            return 'أعلى سعر يجب أن يكون أكبر من الصفر';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _minPriceController,
                        decoration: AppTheme.inputDecoration('أقل سعر مسموح', icon: Icons.arrow_downward),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'الرجاء إدخال أقل سعر';
                          }
                          final price = double.tryParse(value);
                          if (price == null || price <= 0) {
                            return 'أقل سعر يجب أن يكون أكبر من الصفر';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'كيفية عمل أسعار التحويل:',
                                  style: TextStyle(
                                    color: Colors.blue.shade900,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• السعر الرئيسي: السعر الافتراضي المستخدم في العمليات\n'
                              '• أعلى سعر: الحد الأقصى المسموح به\n'
                              '• أقل سعر: الحد الأدنى المسموح به\n'
                              '• عند البيع/الشراء، يجب أن يكون السعر المدخل بين أقل سعر وأعلى سعر',
                              style: TextStyle(
                                color: Colors.blue.shade900,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isEditing && _fromCurrencyId != null && _toCurrencyId != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'لا يمكن تغيير العملات بعد الإنشاء. يمكنك فقط تعديل سعر التحويل.',
                                  style: TextStyle(
                                    color: Colors.blue.shade900,
                                    fontSize: 12,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saveRate,
                  style: AppTheme.primaryButtonStyle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      _isEditing ? 'حفظ التعديلات' : 'حفظ سعر التحويل',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _basePriceController.dispose();
    _maxPriceController.dispose();
    _minPriceController.dispose();
    super.dispose();
  }
}

