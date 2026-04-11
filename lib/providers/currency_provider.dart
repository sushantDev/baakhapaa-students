import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/url.dart';
import '../utils/debug_logger.dart';

class CurrencyProvider extends ChangeNotifier {
  /// NPR to USD rate, e.g. 0.00740 (= 1 NPR in USD)
  double _nprToUsd = 1 / 135.0;

  /// USD to NPR rate, e.g. 135.0
  double _usdToNpr = 135.0;

  String _source = 'default';
  bool _isLoading = false;
  DateTime? _lastFetched;

  double get nprToUsd => _nprToUsd;
  double get usdToNpr => _usdToNpr;
  String get source => _source;
  bool get isLoading => _isLoading;

  CurrencyProvider() {
    _loadCachedRate();
    fetchRate();
  }

  /// Convert NPR amount to USD.
  double convertNprToUsd(double npr) => npr * _nprToUsd;

  /// Convert NPR amount to USD cents (for Stripe).
  int nprToCents(double npr) => (convertNprToUsd(npr) * 100).round();

  /// Format NPR price as formatted USD string: "$9.99"
  String formatNprAsUsd(double npr) {
    return '\$${convertNprToUsd(npr).toStringAsFixed(2)}';
  }

  /// Format as "Rs. 1,350 (~\$9.99)"
  String formatNprWithUsd(double npr) {
    return 'Rs. ${npr.toStringAsFixed(0)}  (~${formatNprAsUsd(npr)})';
  }

  /// Fetch live NPR↔USD rate from our own backend (which auto-caches from er-api.com).
  Future<void> fetchRate() async {
    if (_isLoading) return;
    if (_lastFetched != null &&
        DateTime.now().difference(_lastFetched!).inHours < 6) return;

    _isLoading = true;
    notifyListeners();

    try {
      final response = await http
          .get(Uri.parse(Url.baakhapaaApi('/currency/rate')))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rateData = data['data'] as Map<String, dynamic>? ?? {};
        _usdToNpr = (rateData['usd_to_npr'] as num?)?.toDouble() ?? 135.0;
        _nprToUsd = _usdToNpr > 0 ? 1 / _usdToNpr : 1 / 135.0;
        _source = rateData['source'] as String? ?? 'auto';
        _lastFetched = DateTime.now();

        await _cacheRate();
        DebugLogger.info('CurrencyProvider: 1 USD = Rs. $_usdToNpr ($_source)');
      }
    } catch (e) {
      DebugLogger.error(
          'CurrencyProvider: fetchRate error: $e — using cached/default');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _cacheRate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('cached_usd_to_npr', _usdToNpr);
  }

  Future<void> _loadCachedRate() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getDouble('cached_usd_to_npr');
    if (cached != null && cached > 0) {
      _usdToNpr = cached;
      _nprToUsd = 1 / cached;
      notifyListeners();
    }
  }
}
