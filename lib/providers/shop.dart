import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../models/url.dart';
import '../utils/debug_logger.dart';

class Shop with ChangeNotifier {
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  late Map<String, dynamic> _shop = {};
  late Map<String, dynamic> _products = {};
  late Map<String, dynamic> _gifts = {};
  late Map<String, dynamic> _singleProduct = {};
  late List<dynamic> _productsOnly = [];
  late String authToken;
  late List<dynamic> _giftSliders = [];
  late List<dynamic> _productSliders = [];
  late bool _isProductRedeemable = false;
  late List<dynamic> _forYouProducts = [];

  Shop(this.authToken, this._shop);

  Map<String, dynamic> get shop {
    return _shop;
  }

  List<dynamic> get giftSliders {
    return _giftSliders;
  }

  List<dynamic> get productSliders {
    return _productSliders;
  }

  List<dynamic> get forYouProducts {
    return _forYouProducts;
  }

  Map<String, dynamic> get products {
    return _products;
  }

  List<dynamic> get productsOnly {
    return _productsOnly;
  }

  Map<String, dynamic> get gifts {
    return _gifts;
  }

  Map<String, dynamic> get singleProduct {
    return _singleProduct;
  }

  List<dynamic> get _singleProductImage {
    return _singleProduct['images'] as List<dynamic>;
  }

  int get singleProductImageCount {
    return _singleProductImage.length;
  }

  bool get isProdRedeemable {
    return _isProductRedeemable;
  }

  Future<void> getAllProducts() async {
    try {
      final url = Url.baakhapaaApi('/products');
      DebugLogger.api('Fetching shop products from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      DebugLogger.api('Shop API response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        DebugLogger.error('Shop API returned status ${response.statusCode}');
        _products = {};
        _gifts = {};
        notifyListeners();
        return;
      }

      var responseData = json.decode(utf8.decode(response.bodyBytes));
      DebugLogger.api(
          'Shop API response keys: ${responseData.keys.toString()}');

      // Try multiple response patterns
      Map<String, dynamic> items = {};

      if (responseData['success'] == true && responseData['data'] != null) {
        final data = responseData['data'];
        if (data is Map) {
          // Pattern 1: data.items (most common)
          if (data['items'] is Map) {
            items = data['items'] as Map<String, dynamic>;
            DebugLogger.api('✅ Matched pattern: data.items is Map');
          }
          // Pattern 2: data is the items directly
          else {
            items = data as Map<String, dynamic>;
            DebugLogger.api('✅ Matched pattern: data is Map');
          }
        }
      } else if (responseData is Map && !responseData.containsKey('success')) {
        // API might not use 'success' field
        if (responseData['data'] is Map) {
          items = responseData['data'] as Map<String, dynamic>;
          DebugLogger.api(
              '✅ Matched pattern: response.data is Map (no success field)');
        } else if (responseData['items'] is Map) {
          items = responseData['items'] as Map<String, dynamic>;
          DebugLogger.api('✅ Matched pattern: response.items is Map');
        }
      }

      // Parse products and gifts from items
      _shop = items;
      _products = {};
      _gifts = {};

      if (items['product'] is Map) {
        final productMap = items['product'] as Map;
        productMap.forEach((key, value) {
          if (value is List) {
            _products[key.toString()] = value;
            DebugLogger.api('Vendor $key: ${(value as List).length} products');
          } else if (value is Map) {
            // Handle if value is a map instead of list
            _products[key.toString()] = [value];
            DebugLogger.api('Vendor $key: 1 product (from map)');
          }
        });
      } else if (items['products'] is Map) {
        final productMap = items['products'] as Map;
        productMap.forEach((key, value) {
          if (value is List) {
            _products[key.toString()] = value;
          }
        });
      }

      if (items['gift'] is Map) {
        final giftMap = items['gift'] as Map;
        giftMap.forEach((key, value) {
          if (value is List) {
            _gifts[key.toString()] = value;
          }
        });
      }

      notifyListeners();

      int totalProducts = 0;
      _products.forEach((key, value) {
        if (value is List) totalProducts += (value as List).length;
      });

      DebugLogger.success(
          '✅ Shop API loaded successfully! ${_products.length} vendors, $totalProducts total products');
    } catch (error, stackTrace) {
      DebugLogger.error('Shop getAllProducts exception: $error');
      DebugLogger.error('Stack trace: $stackTrace');
      // Set empty data on error to prevent stuck loading state
      _products = {};
      _gifts = {};
      notifyListeners();
    }
  }

  Future<void> getProductsOnly() async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/products/only')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success'] == true) {
        final data = responseData['data'];
        if (data is List) {
          _productsOnly = data;
        } else if (data is Map && data['items'] != null) {
          _productsOnly = data['items'];
        } else {
          _productsOnly = [];
        }
        notifyListeners();
      } else {
        throw ('Error');
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> getSingleProduct(int productId) async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/products/${productId}')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success'] == true) {
        _singleProduct = responseData['data']['item'] as Map<String, dynamic>;
        notifyListeners();
      } else {
        throw ('Error');
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> isProductRedeemable(int productId) async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/products/${productId}/is-redeemable')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['message'] == 'EPISODES_COMPLETED') {
        _isProductRedeemable = true;
      } else {
        _isProductRedeemable = false;
      }
      notifyListeners();
    } catch (error) {
      throw error;
    }
  }

  Future<void> getEpisodeProducts(int episodeId) async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/episode/$episodeId/products')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success'] == true) {
        _productsOnly = responseData['data']['items'];
        notifyListeners();
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> fetchProductSlider() async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/product-slider')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success'] == true) {
        _productSliders = responseData['data']['items'];
        notifyListeners();
      } else {
        throw ('Error fetching story slider: ${responseData['message']}');
      }
    } catch (error) {
      throw ('Error fetching story slider: $error');
    }
  }

  Future<void> fetchGiftSlider() async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/gift-slider')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success'] == true) {
        _giftSliders = responseData['data']['items'];
        notifyListeners();
      } else {
        throw ('Error fetching story slider: ${responseData['message']}');
      }
    } catch (error) {
      throw ('Error fetching story slider: $error');
    }
  }

  Future<void> getForYouProducts() async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/product/forYou')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success'] == true) {
        // Handle different possible response structures
        if (responseData['data'] != null) {
          // Check for paginated response: data.data (most common structure)
          if (responseData['data']['data'] != null &&
              responseData['data']['data'] is List) {
            _forYouProducts = responseData['data']['data'] as List<dynamic>;
            DebugLogger.info(
                'For You products loaded: ${_forYouProducts.length} items');
          }
          // Check for items structure: data.items
          else if (responseData['data']['items'] != null) {
            _forYouProducts = responseData['data']['items'] as List<dynamic>;
            DebugLogger.info(
                'For You products loaded: ${_forYouProducts.length} items');
          }
          // Check if data itself is a list
          else if (responseData['data'] is List) {
            _forYouProducts = responseData['data'] as List<dynamic>;
            DebugLogger.info(
                'For You products loaded: ${_forYouProducts.length} items');
          } else {
            _forYouProducts = [];
            DebugLogger.info('For You products: No products found in response');
          }
        } else {
          _forYouProducts = [];
          DebugLogger.info('For You products: No data in response');
        }
        notifyListeners();
      } else {
        // If API returns success: false, set empty list
        _forYouProducts = [];
        notifyListeners();
      }
    } catch (error) {
      // On error, set empty list to prevent UI issues
      _forYouProducts = [];
      notifyListeners();
      DebugLogger.info('Error fetching for you products: $error');
    }
  }
}
