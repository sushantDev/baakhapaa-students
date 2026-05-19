import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../utils/debug_logger.dart';
import '../models/url.dart';

enum AppleIapProductType {
  consumable,
  nonConsumable,
  nonRenewingSubscription,
}

extension AppleIapProductTypeX on AppleIapProductType {
  bool get usesConsumablePurchaseApi => this == AppleIapProductType.consumable;

  String get appStoreConnectType {
    switch (this) {
      case AppleIapProductType.consumable:
        return 'Consumable';
      case AppleIapProductType.nonConsumable:
        return 'Non-Consumable';
      case AppleIapProductType.nonRenewingSubscription:
        return 'Non-Renewing Subscription';
    }
  }

  bool get allowsMultipleQuantity => this == AppleIapProductType.consumable;
}

/// Generates and parses Apple IAP product IDs for Skill Sikka.
///
/// Shop products: com.baakhapaa.student.prod_{productId}
class AppleIapProducts {
  static const String _productPrefix = 'com.baakhapaa.student.prod';
  static const Map<int, AppleIapProductType> _catalog = {
    1: AppleIapProductType.nonRenewingSubscription,
    3: AppleIapProductType.nonConsumable,
    20: AppleIapProductType.consumable,
  };

  /// Returns a per-product IAP ID so each shop item can have its own price tier
  /// in App Store Connect (e.g. com.baakhapaa.student.prod_5 for product id=5).
  static String cartProductId(int productId) {
    return '${_productPrefix}_$productId';
  }

  static AppleIapProductType? catalogProductType(int productId) {
    return _catalog[productId];
  }

  static bool isCatalogAppleIapProduct(int productId) {
    return _catalog.containsKey(productId);
  }

  static bool isDigitalCatalogProduct(int productId) {
    return isCatalogAppleIapProduct(productId);
  }
}

class AppleIapService {
  AppleIapService._internal();
  static final AppleIapService instance = AppleIapService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool _isAvailable = false;
  bool _initialized = false;

  void Function(String productId, String transactionId, String receiptData)?
      _onSuccess;
  void Function(String error)? _onError;

  Future<bool> initialize({
    required void Function(
      String productId,
      String transactionId,
      String receiptData,
    ) onSuccess,
    required void Function(String error) onError,
  }) async {
    if (!Platform.isIOS) return false;

    _onSuccess = onSuccess;
    _onError = onError;

    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) {
      DebugLogger.info(
        'AppleIapService: App Store not available on this device',
      );
      return false;
    }

    await _purchaseSubscription?.cancel();
    _purchaseSubscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        DebugLogger.info('AppleIapService: Purchase stream error: $error');
        _onError?.call('Purchase stream error: $error');
      },
    );

    _initialized = true;
    DebugLogger.info('AppleIapService: Initialized successfully');
    return true;
  }

  void dispose() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    _initialized = false;
    DebugLogger.info('AppleIapService: Disposed');
  }

  Future<ProductDetails?> loadProduct(String productId) async {
    if (!_isAvailable) return null;
    DebugLogger.info('AppleIapService: Loading product: $productId');
    final response = await _iap.queryProductDetails({productId});
    if (response.error != null) {
      DebugLogger.info(
        'AppleIapService: Product query error: ${response.error}',
      );
      return null;
    }
    if (response.productDetails.isEmpty) {
      DebugLogger.info(
        'AppleIapService: Product not found in App Store: $productId',
      );
      return null;
    }
    return response.productDetails.first;
  }

  /// Purchase a product.
  ///
  /// Use [isConsumable] only for StoreKit consumables. Non-consumables and
  /// non-renewing subscriptions both use buyNonConsumable in this plugin.
  Future<bool> purchase(ProductDetails product,
      {bool isConsumable = true}) async {
    if (!_isAvailable || !_initialized) {
      _onError?.call('App Store is not available on this device.');
      return false;
    }
    try {
      final param = PurchaseParam(productDetails: product);
      if (isConsumable) {
        return await _iap.buyConsumable(purchaseParam: param);
      } else {
        return await _iap.buyNonConsumable(purchaseParam: param);
      }
    } catch (e) {
      DebugLogger.info(
          'AppleIapService: purchase error (consumable=$isConsumable): $e');
      _onError?.call('Purchase failed: $e');
      return false;
    }
  }

  Future<void> verifyProductPurchaseWithBackend({
    required String authToken,
    required String iapProductId,
    required String transactionId,
    required String receiptData,
    required String appCountryCode,
    int? cartProductId,
    int? shippingAddressId,
  }) async {
    final response = await http.post(
      Uri.parse(Url.baakhapaaApi('/products/apple-iap/verify')),
      headers: {
        ...Url.baakhapaaAuthHeaders(authToken),
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'product_id': iapProductId,
        'transaction_id': transactionId,
        'receipt_data': receiptData,
        'app_country_code': appCountryCode,
        if (cartProductId != null) 'cart_product_id': cartProductId,
        if (shippingAddressId != null) 'shipping_address_id': shippingAddressId,
      }),
    );

    final body = json.decode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200) {
      final msg =
          body['message'] ?? body['error'] ?? 'Product verification failed';
      throw Exception(msg);
    }
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.canceled:
          _onError?.call('cancelled');
          await _completePurchase(purchase);
          break;
        case PurchaseStatus.error:
          _onError?.call(purchase.error?.message ?? 'Unknown purchase error');
          await _completePurchase(purchase);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final receiptData = purchase.verificationData.serverVerificationData;
          _onSuccess?.call(
            purchase.productID,
            purchase.purchaseID ?? '',
            receiptData,
          );
          await _completePurchase(purchase);
          break;
      }
    }
  }

  Future<void> _completePurchase(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }
}
