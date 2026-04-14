import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import './cart.dart';
import '../models/url.dart';
import '../utils/debug_logger.dart';

class Orders with ChangeNotifier {
  List<dynamic> _orders = [];
  final String authToken;
  final String _username;

  Orders(this.authToken, this._orders, this._username);

  List<dynamic> get orders {
    return _orders;
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> addDirectOrder({
    required String productId,
    required int quantity,
    required int paymentId,
    int? affiliateId,
  }) async {
    try {
      if (authToken.isEmpty) {
        throw Exception('User not authenticated. Please log in again.');
      }

      List<Map<String, dynamic>> products = [
        {
          'product_id': productId,
          'qty': quantity,
          if (affiliateId != null) 'affiliate_id': affiliateId,
        }
      ];

      final data = json.encode({'products': products, 'payment_id': paymentId});

      DebugLogger.info('Sending direct order data: $data');
      DebugLogger.api('URL: ${Url.baakhapaaApi('/purchase')}');

      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/purchase')),
        headers: Url.baakhapaaAuthHeaders(authToken),
        body: data,
      );

      DebugLogger.api('Response status: ${response.statusCode}');
      DebugLogger.api('Response headers: ${response.headers}');
      DebugLogger.api('Response body length: ${response.body.length}');
      DebugLogger.api(
          'Response body (first 200 chars));: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');

      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        throw Exception(
            'Server returned HTML error page. Status: ${response.statusCode}');
      }

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success'] == true) {
        if (!_disposed) notifyListeners();
      } else {
        throw Exception('API returned error: ${responseData.toString()}');
      }
    } catch (error) {
      DebugLogger.error('Direct order error details: $error');
      throw (error);
    }
  }

  Future<void> addOrder(
      {List<CartItem>? cartProducts,
      int? paymentId,
      String? paymentMethod,
      Map<String, CartItem>? cartItems,
      int? shippingAddressId}) async {
    try {
      // Check if user is authenticated
      if (authToken.isEmpty) {
        throw Exception('User not authenticated. Please log in again.');
      }

      List<Map<String, dynamic>> products = [];

      if (cartItems != null) {
        // Use the cart items with proper product IDs as keys
        cartItems.forEach((productId, cartItem) {
          products.add({
            'product_id': productId,
            'qty': cartItem.quantity,
            if (cartItem.affiliateId != null)
              'affiliate_id': cartItem.affiliateId,
          });
          DebugLogger.info(
              'DEBUG: Order Item - Product: $productId, Affiliate: ${cartItem.affiliateId}');
        });
      } else if (cartProducts != null) {
        // Fallback to old method (though this won't work correctly)
        products = cartProducts
            .map((cp) => {
                  'product_id': cp.id,
                  'qty': cp.quantity,
                  if (cp.affiliateId != null) 'affiliate_id': cp.affiliateId,
                })
            .toList();
      }

      final data = json.encode({
        'products': products,
        if (paymentId != null) 'payment_id': paymentId,
        if (shippingAddressId != null) 'shipping_address_id': shippingAddressId,
      });

      DebugLogger.info('Sending order data: $data');
      DebugLogger.api('URL: ${Url.baakhapaaApi('/purchase')}');

      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/purchase')),
        headers: Url.baakhapaaAuthHeaders(authToken),
        body: data,
      );

      DebugLogger.api('Response status: ${response.statusCode}');
      DebugLogger.api('Response headers: ${response.headers}');
      DebugLogger.api('Response body length: ${response.body.length}');
      DebugLogger.api(
          'Response body (first 200 chars));: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');

      // Check if response is HTML (error page)
      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        throw Exception(
            'Server returned HTML error page. Status: ${response.statusCode}');
      }

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success'] == true) {
        if (!_disposed) notifyListeners();
      } else {
        throw Exception('API returned error: ${responseData.toString()}');
      }
    } catch (error) {
      DebugLogger.error('Order error details: $error');
      throw (error);
    }
  }

  Future<void> addGiftOrder(int giftId, int friendId) async {
    try {
      final data = json.encode({
        'product_id': [giftId],
        'friend_id': friendId,
      });

      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/purchase-gift')),
        headers: Url.baakhapaaAuthHeaders(authToken),
        body: data,
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success'] == true) {
        if (!_disposed) notifyListeners();
      } else {
        throw ('error');
      }
    } catch (error) {
      throw (error);
    }
  }

  Future<void> getOrders() async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/user/${_username}/orders')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success'] == true) {
        _orders = responseData['data']['items'];
        if (!_disposed) notifyListeners();
      }
    } catch (error) {
      throw (error);
    }
  }

  Future<void> khaltiPayment(
      Map<String, dynamic> txn, Map<String, CartItem> cartItems) async {
    try {
      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/products/payment')),
        headers: Url.baakhapaaAuthHeaders(authToken),
        body: json.encode(txn),
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['message'] == 'OK') {
        this.addOrder(
          cartItems: cartItems,
          paymentId: responseData['data']['item']['id'],
          shippingAddressId: txn['shipping_address_id'] as int?,
        );
        if (!_disposed) notifyListeners();
      } else {
        throw ('error');
      }
    } catch (error) {
      throw (error);
    }
  }
}
