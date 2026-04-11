import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/product_draft.dart';
import '../models/url.dart';
import '../utils/debug_logger.dart';

class Vendor with ChangeNotifier {
  final String authToken;

  Vendor(this.authToken);

  List<Map<String, dynamic>> brands = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> episodes = [];
  List<Map<String, dynamic>> _products = [];
  bool _isLoadingProducts = false;

  List<Map<String, dynamic>> get products => [..._products];
  bool get isLoadingProducts => _isLoadingProducts;

  // ───────────────── Fetch brands, categories & episodes ─────────────────
  Future<void> fetchProductRequirements() async {
    try {
      final url = Uri.parse(Url.baakhapaaApi('/productRequires'));
      final response = await http.get(
        url,
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      final data = json.decode(response.body);

      if (data['success'] == true) {
        brands = List<Map<String, dynamic>>.from(data['data']['brands']);
        categories =
            List<Map<String, dynamic>>.from(data['data']['categories']);
        episodes = List<Map<String, dynamic>>.from(data['data']['episodes']);
        notifyListeners();
      } else {
        throw Exception(
            data['message'] ?? 'Failed to load product requirements');
      }
    } catch (e) {
      throw e;
    }
  }

  // ───────────────── Fetch user products ─────────────────
  Future<void> fetchProducts(int userId) async {
    _isLoadingProducts = true;
    notifyListeners();

    try {
      final url = Uri.parse(Url.baakhapaaApi('/user/products/$userId'));
      final response =
          await http.get(url, headers: Url.baakhapaaAuthHeaders(authToken));
      final data = json.decode(response.body);

      if (data['success'] == true) {
        _products = List<Map<String, dynamic>>.from(data['data']['items']);
      } else {
        throw Exception(data['message'] ?? 'Failed to load products');
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoadingProducts = false;
      notifyListeners();
    }
  }

  // ───────────────── CREATE PRODUCT ─────────────────

  Future<bool> createProduct(ProductDraft product) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(Url.baakhapaaApi('/product/create')),
    );

    request.headers.addAll(
      Url.baakhapaaAuthHeaders(authToken),
    );

    _attachFields(request, product);
    _attachOptions(request, product);
    await _attachImages(request, product.images);
    await _attachVariants(request, product);

    // Log request details
    if (kDebugMode) {
      print('═══════════════════════════════════════════');
      print('🔍 CREATE PRODUCT REQUEST');
      print('═══════════════════════════════════════════');
      print('📋 Request Fields:');
      request.fields.forEach((key, value) {
        print('   $key: $value');
      });
      print('\n📁 Request Files: ${request.files.length} file(s)');
      request.files.forEach((file) {
        print('   ${file.field}: ${file.filename} (${file.length} bytes)');
      });
      print('═══════════════════════════════════════════\n');
    }

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (kDebugMode) {
      print('🔍 Create Product Response Status: ${response.statusCode}');
      print('🔍 Create Product Response Headers: ${response.headers}');
      print('🔍 Create Product Response Body (raw): $body');
    }

    Map<String, dynamic> data;
    try {
      data = json.decode(utf8.decode(utf8.encode(body)));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Create Product JSON parse failed: $e');
        print('❌ Create Product Raw Body: $body');
      }
      throw Exception('Invalid response format from server');
    }

    if (_isSuccess(response.statusCode, data)) {
      notifyListeners();
      return true;
    }

    // More detailed error message
    final errorMsg =
        data['message'] ?? data['error'] ?? 'Create product failed';
    if (kDebugMode) {
      print(
          '❌ Create Product Failed: Status ${response.statusCode}, Message: $errorMsg');
      print('❌ Full error data: $data');
      if (response.statusCode >= 500) {
        print(
            '❗ Server error (5xx). Check backend logs for the real exception.');
      }
    }

    throw Exception(errorMsg);
  }

  // ───────────────── UPDATE PRODUCT ─────────────────

  Future<bool> updateProduct(int productId, ProductDraft product) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(Url.baakhapaaApi('/product/update/$productId')),
    );

    request.headers.addAll(
      Url.baakhapaaAuthHeaders(authToken),
    );

    request.fields['_method'] = 'PUT';

    _attachFields(request, product);
    _attachOptions(request, product);
    await _attachImages(request, product.images);
    await _attachVariants(request, product);

    final response = await request.send();
    final body = await response.stream.bytesToString();
    final data = json.decode(utf8.decode(utf8.encode(body)));

    if (_isSuccess(response.statusCode, data)) {
      notifyListeners();
      return true;
    }

    throw Exception(data['message'] ?? 'Update product failed');
  }

  // ───────────────── DELETE PRODUCT ─────────────────

  Future<void> deleteProduct(int productId) async {
    // Optimistic update
    _products.removeWhere((p) => p['id'] == productId);
    notifyListeners();

    final response = await http.delete(
      Uri.parse(Url.baakhapaaApi('/product/delete/$productId')),
      headers: Url.baakhapaaAuthHeaders(authToken),
    );

    final data = json.decode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200 && data['success'] == true) {
      return;
    }

    throw Exception(data['message'] ?? 'Delete product failed');
  }

  // ───────────────── HELPERS ─────────────────

  void _attachFields(http.MultipartRequest request, ProductDraft p) {
    // Build fields map
    final fields = {
      'title': p.title,
      'qty': p.qty.toString(),
      'coin': p.coin.toString(),
      'price': p.price.toString(),
      'type': p.type, // ✅ REQUIRED
      'brand_id': p.brandId.toString(),
      'description': p.description ?? '',
    };

    // ⚠️ CRITICAL: expires_at is REQUIRED by backend validation
    if (p.expiresAt != null) {
      fields['expires_at'] = _formatDate(p.expiresAt!);
    } else {
      // Send tomorrow's date as default if not set
      fields['expires_at'] = _formatDate(DateTime.now().add(Duration(days: 1)));
      if (kDebugMode) {
        print('⚠️ No expiry date set, using tomorrow as default');
      }
    }

    if ((p.vendorLink ?? '').trim().isNotEmpty) {
      fields['vendor_link'] = p.vendorLink!.trim();
    }
    if (p.categoryId != null) {
      fields['category_id'] = p.categoryId.toString();
    }

    // ⚠️ CHALLENGE FIELD - Send challenge_id when creating challenge products
    if (p.challengeId != null) {
      fields['challenge_id'] = p.challengeId.toString();
      if (kDebugMode) {
        print('🎯 Challenge product detected: Challenge ID ${p.challengeId}');
      }
    }

    request.fields.addAll(fields);
  }

  Future<void> _attachImages(
    http.MultipartRequest request,
    List images,
  ) async {
    for (final img in images) {
      request.files.add(
        await http.MultipartFile.fromPath('images[]', img.path),
      );
    }
  }

  Future<void> _attachVariants(
    http.MultipartRequest request,
    ProductDraft p,
  ) async {
    for (int i = 0; i < p.variants.length; i++) {
      final v = p.variants[i];

      if (v.price != null) {
        request.fields['variants[$i][price]'] = v.price.toString();
      }

      if (v.qty != null) {
        request.fields['variants[$i][qty]'] = v.qty.toString();
      }

      // attach variant image
      if (v.image != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'variants[$i][image]',
            v.image!.path,
          ),
        );
      }

      // attach option values
      for (int j = 0; j < v.optionValues.length; j++) {
        final parts = v.optionValues[j].split(':'); // Size:Small
        if (parts.length != 2) continue;

        request.fields['variants[$i][option_values][$j][option]'] = parts[0];
        request.fields['variants[$i][option_values][$j][value]'] = parts[1];
      }
    }
  }

  void _attachOptions(http.MultipartRequest request, ProductDraft p) {
    for (int i = 0; i < p.options.length; i++) {
      final opt = p.options[i];
      request.fields['options[$i][name]'] = opt.name;

      for (int j = 0; j < opt.values.length; j++) {
        request.fields['options[$i][values][$j]'] = opt.values[j];
      }
    }
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  // Consider broader "success" signals to handle inconsistent backends
  bool _isSuccess(int statusCode, Map data) {
    // Accept 200-299 status codes
    if (statusCode < 200 || statusCode >= 300) return false;

    // Check success field
    final s = data['success'];
    final booleanLike = s == true ||
        s == 1 ||
        s == '1' ||
        (s is String && s.toLowerCase() == 'true');

    // Check message for success indicators
    final msg =
        (data['message'] ?? data['status'] ?? '').toString().toLowerCase();
    final messageLooksSuccessful = msg.contains('success') ||
        msg.contains('created') ||
        msg.contains('updated');

    // Debug logging to see what backend actually returns
    if (kDebugMode) {
      DebugLogger.info('🔍 Response status: $statusCode');
      DebugLogger.info('🔍 Response data: $data');
      DebugLogger.info('🔍 Success field: $s (booleanLike: $booleanLike)');
      DebugLogger.info(
          '🔍 Message: $msg (looks successful: $messageLooksSuccessful)');
    }

    return booleanLike || messageLooksSuccessful;
  }
}
