import 'package:flutter/material.dart';
import 'package:untitled/core/models/currency_model.dart';
import 'package:untitled/core/services/currency_service.dart';
import 'package:untitled/shared/theme/app_theme.dart';
import 'package:untitled/shared/widgets/app_card.dart';
import 'package:untitled/shared/widgets/loading_overlay.dart';
import 'package:untitled/theme/app_colors.dart';

class AddEditCurrencyScreen extends StatefulWidget {
  final CurrencyModel? currency;

  const AddEditCurrencyScreen({super.key, this.currency});

  @override
  State<AddEditCurrencyScreen> createState() => _AddEditCurrencyScreenState();
}

class _AddEditCurrencyScreenState extends State<AddEditCurrencyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _symbolController = TextEditingController();
  final _exchangeRateController = TextEditingController(text: '1.0');
  final _currencyService = CurrencyService();
  
  bool _isBaseCurrency = false;
  bool _isLoading = false;
  bool _isSuspended = false;
  
  bool get _isEditing => widget.currency != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing && widget.currency != null) {
      final currency = widget.currency!;
      _nameController.text = currency.name;
      _symbolController.text = currency.symbol;
      _exchangeRateController.text = currency.exchangeRate.toString();
      _isBaseCurrency = currency.isPrimary;
      _isSuspended = currency.isSuspended;
    }
  }

  Future<void> _saveCurrency() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currency = CurrencyModel(
        id: widget.currency?.id ?? '',
        userId: '',
        name: _nameController.text.trim(),
        symbol: _symbolController.text.trim(),
        isPrimary: _isBaseCurrency,
        isSuspended: _isEditing ? (_isBaseCurrency ? false : _isSuspended) : false, // Can't suspend primary, and new currencies are not suspended by default
        exchangeRate: _isBaseCurrency ? 1.0 : (double.tryParse(_exchangeRateController.text.trim()) ?? 1.0),
        createdAt: widget.currency?.createdAt ?? DateTime.now(),
      );

      if (_isEditing) {
        await _currencyService.updateCurrency(widget.currency!.id, currency);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث العملة بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        await _currencyService.createCurrency(currency);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حفظ العملة بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
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
        title: Text(_isEditing ? 'تعديل عملة' : 'إضافة عملة جديدة'),
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
                        _isEditing ? 'تعديل بيانات العملة' : 'بيانات العملة الجديدة',
                        style: AppTheme.heading3,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nameController,
                        decoration: AppTheme.inputDecoration('اسم العملة', icon: Icons.currency_exchange),
                        validator: (v) => v?.trim().isEmpty ?? true ? 'الرجاء إدخال اسم العملة' : null,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _symbolController,
                        decoration: AppTheme.inputDecoration('رمز العملة', icon: Icons.text_fields),
                        validator: (v) => v?.trim().isEmpty ?? true ? 'الرجاء إدخال رمز العملة' : null,
                      ),
                      const SizedBox(height: 20),
                      SwitchListTile(
                        title: const Text('تعيين كعملة أساسية'),
                        subtitle: _isBaseCurrency
                            ? const Text('العملة الأساسية سعر صرفها دائماً 1.0', style: TextStyle(fontSize: 12))
                            : (_isEditing && widget.currency!.isPrimary
                                ? const Text('لا يمكن تغيير حالة العملة الأساسية إذا كانت مستخدمة في عمليات', style: TextStyle(fontSize: 12, color: Colors.orange))
                                : null),
                        value: _isBaseCurrency,
                        activeColor: AppColors.accentGold,
                        onChanged: (_isEditing && widget.currency!.isPrimary) ? null : (value) {
                          setState(() {
                            _isBaseCurrency = value;
                            if (value) {
                              _exchangeRateController.text = '1.0';
                            }
                          });
                        },
                      ),
                      if (!_isBaseCurrency) ...[
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _exchangeRateController,
                          decoration: AppTheme.inputDecoration('سعر الصرف', icon: Icons.trending_up),
                          keyboardType: TextInputType.number,
                          enabled: !_isBaseCurrency,
                          validator: (value) {
                            if (_isBaseCurrency) return null;
                            if (value == null || value.trim().isEmpty) return 'هذا الحقل مطلوب';
                            final rate = double.tryParse(value);
                            if (rate == null || rate <= 0) return 'الرجاء إدخال رقم صحيح أكبر من الصفر';
                            return null;
                          },
                        ),
                      ],
                      if (_isEditing && !_isBaseCurrency) ...[
                        const SizedBox(height: 20),
                        SwitchListTile(
                          title: const Text('عملة موقفة'),
                          subtitle: Text(
                            _isSuspended
                                ? 'العملة موقفة ولا يمكن إجراء معاملات بها'
                                : 'العملة نشطة ويمكن إجراء المعاملات',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          value: _isSuspended,
                          onChanged: (value) => setState(() => _isSuspended = value),
                          activeColor: Colors.red,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saveCurrency,
                  style: AppTheme.primaryButtonStyle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      _isEditing ? 'حفظ التعديلات' : 'حفظ العملة',
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
    _nameController.dispose();
    _symbolController.dispose();
    _exchangeRateController.dispose();
    super.dispose();
  }
}

