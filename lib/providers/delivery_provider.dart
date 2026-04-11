import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/shipping.dart';
import '../models/url.dart';
import '../utils/debug_logger.dart';

class DeliveryProvider with ChangeNotifier {
  final String authToken;

  DeliveryProvider(this.authToken);

  // ── State ─────────────────────────────────────────────────────────────────
  List<ShippingAddress> _addresses = [];
  List<ShippingProvider> _availableProviders = [];
  ShippingAddress? _selectedAddress;
  ShippingProvider? _selectedProvider;
  bool _isLoadingAddresses = false;
  bool _isLoadingProviders = false;
  double _currentWeightKg = 0.5;

  // ── Getters ───────────────────────────────────────────────────────────────
  List<ShippingAddress> get addresses => List.unmodifiable(_addresses);
  List<ShippingProvider> get availableProviders =>
      List.unmodifiable(_availableProviders);
  ShippingAddress? get selectedAddress => _selectedAddress;
  ShippingProvider? get selectedProvider => _selectedProvider;
  bool get isLoadingAddresses => _isLoadingAddresses;
  bool get isLoadingProviders => _isLoadingProviders;

  bool get isReadyForInternationalCheckout =>
      _selectedAddress != null && _selectedProvider != null;

  double get totalShippingCostUsd => _selectedProvider?.costUsd ?? 0.0;
  double get totalShippingCostNpr => _selectedProvider?.costNpr ?? 0.0;

  // ── Shipping Addresses ────────────────────────────────────────────────────

  Future<void> fetchAddresses() async {
    if (authToken.isEmpty) return;
    _isLoadingAddresses = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/shipping/addresses')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // ResponseBuilder v9 wraps collections under 'items': { "data": {"items": [...]} }
        final rawData = data['data'];
        final list = rawData is List
            ? rawData.cast<dynamic>()
            : (rawData is Map
                ? (rawData['items'] as List<dynamic>? ?? [])
                : <dynamic>[]);
        _addresses = list
            .map((e) => ShippingAddress.fromJson(e as Map<String, dynamic>))
            .toList();

        // Auto-select default address
        if (_selectedAddress == null) {
          _selectedAddress = _addresses.firstWhere(
            (a) => a.isDefault,
            orElse: () => _addresses.isNotEmpty
                ? _addresses.first
                : throw StateError('empty'),
          );
        }
      }
    } catch (e) {
      DebugLogger.error('DeliveryProvider: fetchAddresses error: $e');
    } finally {
      _isLoadingAddresses = false;
      notifyListeners();
    }
  }

  Future<ShippingAddress?> addAddress(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/shipping/addresses')),
        headers: Url.baakhapaaAuthHeaders(authToken),
        body: json.encode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = json.decode(response.body);
        // ResponseBuilder v9 wraps single models under 'item': { "data": {"item": {...}} }
        final rawData = result['data'];
        final addressMap =
            // ignore: unnecessary_cast
            (rawData is Map && (rawData as Map).containsKey('item'))
                ? rawData['item'] as Map<String, dynamic>
                : rawData as Map<String, dynamic>;
        final address = ShippingAddress.fromJson(addressMap);
        _addresses.insert(0, address);

        if (address.isDefault) {
          _selectedAddress = address;
          await _loadProvidersForAddress(address);
        }

        notifyListeners();
        return address;
      }
    } catch (e) {
      DebugLogger.error('DeliveryProvider: addAddress error: $e');
    }
    return null;
  }

  Future<void> deleteAddress(int id) async {
    try {
      await http.delete(
        Uri.parse(Url.baakhapaaApi('/shipping/addresses/$id')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );
      _addresses.removeWhere((a) => a.id == id);
      if (_selectedAddress?.id == id) {
        _selectedAddress = _addresses.isNotEmpty ? _addresses.first : null;
        if (_selectedAddress != null) {
          await _loadProvidersForAddress(_selectedAddress!);
        } else {
          _availableProviders = [];
          _selectedProvider = null;
        }
      }
      notifyListeners();
    } catch (e) {
      DebugLogger.error('DeliveryProvider: deleteAddress error: $e');
    }
  }

  void selectAddress(ShippingAddress address) {
    _selectedAddress = address;
    _selectedProvider = null;
    _availableProviders = [];
    notifyListeners();
    _loadProvidersForAddress(address);
  }

  // ── Shipping Providers ────────────────────────────────────────────────────

  Future<void> loadProviders(
      {required String countryCode, double weightKg = 0.5}) async {
    _currentWeightKg = weightKg;
    _isLoadingProviders = true;
    notifyListeners();

    try {
      final uri = Uri.parse(Url.baakhapaaApi('/shipping/providers')).replace(
        queryParameters: {
          'country_code': countryCode,
          'weight_kg': weightKg.toStringAsFixed(3),
        },
      );

      final response =
          await http.get(uri, headers: Url.baakhapaaAuthHeaders(authToken));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = (data['data']?['providers'] as List<dynamic>? ?? []);
        _availableProviders = list
            .map((e) => ShippingProvider.fromJson(e as Map<String, dynamic>))
            .toList();

        // Auto-select cheapest
        if (_availableProviders.isNotEmpty && _selectedProvider == null) {
          _selectedProvider = _availableProviders.reduce(
            (a, b) => a.costUsd <= b.costUsd ? a : b,
          );
        }
      } else {
        _availableProviders = [];
      }
    } catch (e) {
      DebugLogger.error('DeliveryProvider: loadProviders error: $e');
      _availableProviders = [];
    } finally {
      _isLoadingProviders = false;
      notifyListeners();
    }
  }

  void selectProvider(ShippingProvider provider) {
    _selectedProvider = provider;
    notifyListeners();
  }

  // ── Order Tracking ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> fetchOrderTracking(int orderId) async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/orders/$orderId/tracking')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as Map<String, dynamic>?;
      }
    } catch (e) {
      DebugLogger.error('DeliveryProvider: fetchOrderTracking error: $e');
    }
    return null;
  }

  // ── Reset ──────────────────────────────────────────────────────────────────

  void resetSelection() {
    _selectedProvider = null;
    notifyListeners();
  }

  void clearAll() {
    _selectedAddress = null;
    _selectedProvider = null;
    _availableProviders = [];
    notifyListeners();
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _loadProvidersForAddress(ShippingAddress address) async {
    await loadProviders(
      countryCode: address.countryCode,
      weightKg: _currentWeightKg,
    );
  }
}
