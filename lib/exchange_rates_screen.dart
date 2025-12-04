import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:untitled/features/exchange_rates/screens/add_edit_exchange_rate_screen.dart';
import 'package:untitled/core/services/exchange_rate_service.dart';
import 'package:untitled/core/services/currency_service.dart';
import 'package:untitled/core/models/currency_model.dart';
import 'package:untitled/core/models/exchange_rate_model.dart';
import 'package:untitled/shared/widgets/app_card.dart';
import 'package:untitled/shared/widgets/confirm_dialog.dart';
import 'package:untitled/shared/widgets/loading_overlay.dart';
import 'package:untitled/theme/app_colors.dart';
import 'package:untitled/shared/theme/app_theme.dart';

class ExchangeRatesScreen extends StatefulWidget {
  const ExchangeRatesScreen({super.key});

  @override
  State<ExchangeRatesScreen> createState() => _ExchangeRatesScreenState();
}

class _ExchangeRatesScreenState extends State<ExchangeRatesScreen> {
  final _exchangeRateService = ExchangeRateService();
  final _currencyService = CurrencyService();
  
  Map<String, String> _currencyNames = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrencies();
  }

  Future<void> _fetchCurrencies() async {
    try {
      final currencies = await _currencyService.streamCurrencies().first;
      final Map<String, String> names = {};
      for (var currency in currencies) {
        names[currency.id] = currency.name;
      }
      if (mounted) {
        setState(() {
          _currencyNames = names;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ في تحميل العملات: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteRate(ExchangeRateModel rate) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'حذف سعر التحويل',
      message: 'هل أنت متأكد أنك تريد حذف سعر التحويل هذا؟',
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _exchangeRateService.deleteExchangeRate(rate.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف سعر التحويل بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('إدارة أسعار التحويل'),
        backgroundColor: AppColors.primaryMaroon,
        foregroundColor: AppColors.textOnDark,
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: StreamBuilder<List<ExchangeRateModel>>(
          stream: _exchangeRateService.streamExchangeRatesAsModels(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'حدث خطأ: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.currency_exchange, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد أسعار تحويل',
                      style: AppTheme.bodyLarge.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'انقر على زر + لإضافة سعر تحويل جديد',
                      style: AppTheme.bodyMedium.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              );
            }

            final rates = snapshot.data!;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rates.length,
              itemBuilder: (context, index) {
                final rate = rates[index];
                final fromCurrencyName = _currencyNames[rate.fromCurrencyId] ?? rate.fromCurrencyId;
                final toCurrencyName = _currencyNames[rate.toCurrencyId] ?? rate.toCurrencyId;

                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryMaroon.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.swap_horiz_rounded,
                        color: AppColors.primaryMaroon,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      '$fromCurrencyName → $toCurrencyName',
                      style: AppTheme.heading3.copyWith(fontSize: 16),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'السعر الرئيسي: ${rate.basePrice.toStringAsFixed(4)}',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppColors.primaryMaroon,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'النطاق: ${rate.minPrice.toStringAsFixed(4)} - ${rate.maxPrice.toStringAsFixed(4)}',
                            style: AppTheme.bodySmall.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AddEditExchangeRateScreen(
                                  exchangeRate: {
                                    'id': rate.id,
                                    'fromCurrencyId': rate.fromCurrencyId,
                                    'toCurrencyId': rate.toCurrencyId,
                                    'basePrice': rate.basePrice,
                                    'maxPrice': rate.maxPrice,
                                    'minPrice': rate.minPrice,
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteRate(rate),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AddEditExchangeRateScreen(),
            ),
          );
        },
        backgroundColor: AppColors.primaryMaroon,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
