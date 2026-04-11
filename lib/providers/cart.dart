import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/debug_logger.dart';
import 'dart:convert';

class CartItem {
  final String id;
  final String title;
  final int quantity;
  final double price;
  final String image;
  final int availableStock;
  final Map<String, String>?
      attributes; // Store selected attributes like size, color, etc.
  final int? affiliateId;
  final bool isDigital;

  CartItem({
    required this.id,
    required this.title,
    required this.quantity,
    required this.price,
    required this.image,
    required this.availableStock,
    this.attributes,
    this.affiliateId,
    this.isDigital = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'quantity': quantity,
      'price': price,
      'image': image,
      'availableStock': availableStock,
      'attributes': attributes,
      'affiliateId': affiliateId,
      'isDigital': isDigital,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'],
      title: json['title'],
      quantity: json['quantity'],
      price: json['price'].toDouble(),
      image: json['image'],
      availableStock: json['availableStock'],
      attributes: json['attributes'] != null
          ? Map<String, String>.from(json['attributes'])
          : null,
      affiliateId: json['affiliateId'],
      isDigital: json['isDigital'] == true,
    );
  }
}

class Cart with ChangeNotifier {
  Map<String, CartItem> _items = {};
  static const String _cartKey = 'cart_items';
  bool _isLoaded = false;

  Map<String, CartItem> get items {
    return {..._items};
  }

  bool get isLoaded => _isLoaded;

  int get itemCount {
    return _items.length;
  }

  double get totalAmount {
    var total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.price * cartItem.quantity;
    });
    return total;
  }

  /// True when every item in the cart is marked digital (no shipping needed).
  bool get allDigital =>
      _items.isNotEmpty && _items.values.every((item) => item.isDigital);

  /// Like [allDigital] but also catches old cached items that weren't tagged
  /// before the fix, by inspecting the item title for known digital keywords.
  bool get hasOnlyDigitalProducts {
    if (_items.isEmpty) return false;
    if (allDigital) return true;
    return _items.values.every((item) {
      if (item.isDigital) return true;
      final t = item.title.toLowerCase();
      return t.contains('points') ||
          t.contains('coins') ||
          t.contains('credit');
    });
  }

  // Load cart data from local storage
  Future<void> loadCartFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = prefs.getString(_cartKey);

      if (cartData != null && cartData.isNotEmpty) {
        final Map<String, dynamic> decodedData = json.decode(cartData);
        _items.clear();

        decodedData.forEach((key, value) {
          try {
            _items[key] = CartItem.fromJson(value);
          } catch (e) {
            DebugLogger.error('Error parsing cart item: $e');
            // Skip invalid cart items
          }
        });
      }

      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      DebugLogger.error('Error loading cart from storage: $e');
      _isLoaded = true;
      notifyListeners();
    }
  } // Save cart data to local storage

  Future<void> saveCartToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> cartData = {};

      _items.forEach((key, cartItem) {
        cartData[key] = cartItem.toJson();
      });

      await prefs.setString(_cartKey, json.encode(cartData));
    } catch (e) {
      DebugLogger.error('Error saving cart to storage: $e');
    }
  }

  void addItem(
    String productId,
    double price,
    String title,
    String image,
    int availableStock, {
    Map<String, String>? attributes,
    int? affiliateId,
    bool isDigital = false,
  }) {
    DebugLogger.info(
        'DEBUG: Cart.addItem called with affiliateId: $affiliateId');
    if (_items.containsKey(productId)) {
      // Check if adding one more would exceed available stock
      if (_items[productId]!.quantity < availableStock) {
        _items.update(
          productId,
          (existingCartItem) => CartItem(
            id: existingCartItem.id,
            title: existingCartItem.title,
            price: existingCartItem.price,
            quantity: existingCartItem.quantity + 1,
            image: existingCartItem.image,
            availableStock: availableStock,
            attributes: attributes ?? existingCartItem.attributes,
            affiliateId: affiliateId ?? existingCartItem.affiliateId,
            isDigital: isDigital,
          ),
        );
      }
    } else {
      // Only add if stock is available
      if (availableStock > 0) {
        _items.putIfAbsent(
          productId,
          () => CartItem(
            id: DateTime.now().toString(),
            title: title,
            price: price,
            quantity: 1,
            image: image,
            availableStock: availableStock,
            attributes: attributes,
            affiliateId: affiliateId,
            isDigital: isDigital,
          ),
        );
      }
    }
    notifyListeners();
    saveCartToStorage(); // Save to storage after changes
  }

  void removeItem(String productId) {
    _items.remove(productId);
    notifyListeners();
    saveCartToStorage(); // Save to storage after changes
  }

  void removeSingleItem(String productId) {
    if (!_items.containsKey(productId)) {
      return;
    }
    if (_items[productId]!.quantity > 1) {
      _items.update(
        productId,
        (existingCartItem) => CartItem(
          id: existingCartItem.id,
          title: existingCartItem.title,
          price: existingCartItem.price,
          quantity: existingCartItem.quantity - 1,
          image: existingCartItem.image,
          availableStock: existingCartItem.availableStock,
          affiliateId: existingCartItem.affiliateId,
          attributes: existingCartItem.attributes,
        ),
      );
    } else {
      _items.remove(productId);
    }
    notifyListeners();
    saveCartToStorage(); // Save to storage after changes
  }

  void reset() {
    _items = {};
    notifyListeners();
    saveCartToStorage(); // Save to storage after reset
  }

  bool canAddMoreItems(String productId) {
    if (!_items.containsKey(productId)) {
      return true; // Can add if not in cart yet
    }
    return _items[productId]!.quantity < _items[productId]!.availableStock;
  }

  int getRemainingStock(String productId) {
    if (!_items.containsKey(productId)) {
      return 0;
    }
    return _items[productId]!.availableStock - _items[productId]!.quantity;
  }

  void addQuantity(String productId) {
    if (!_items.containsKey(productId)) return;

    final currentItem = _items[productId]!;
    // Check if adding one more would exceed available stock
    if (currentItem.quantity < currentItem.availableStock) {
      _items.update(
        productId,
        (existingCartItem) => CartItem(
          id: existingCartItem.id,
          title: existingCartItem.title,
          quantity: existingCartItem.quantity + 1,
          price: existingCartItem.price,
          image: existingCartItem.image,
          availableStock: existingCartItem.availableStock,
          attributes: existingCartItem.attributes,
          affiliateId: existingCartItem.affiliateId,
        ),
      );
      notifyListeners();
      saveCartToStorage(); // Save to storage after changes
    }
  }

  void subtractQuantity(String productId) {
    _items.update(
      productId,
      (existingCartItem) => CartItem(
        id: existingCartItem.id,
        title: existingCartItem.title,
        quantity: existingCartItem.quantity - 1,
        price: existingCartItem.price,
        image: existingCartItem.image,
        availableStock: existingCartItem.availableStock,
        attributes: existingCartItem.attributes,
        affiliateId: existingCartItem.affiliateId,
      ),
    );
    notifyListeners();
    saveCartToStorage(); // Save to storage after changes
  }
}
