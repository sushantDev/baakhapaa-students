import 'dart:convert';
// import 'dart:math' as math;

// import 'package:baakhapaa/helpers/helpers.dart';
import 'package:baakhapaa/utils/guest_auth_helper.dart';
import 'package:baakhapaa/services/rating_service.dart';
import 'package:baakhapaa/models/rating_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'package:khalti_checkout_flutter/khalti_checkout_flutter.dart';

import '../screens/shop/single_product_screen.dart';
import '../screens/shop/cart_screen.dart';
import '../../providers/cart.dart';
import '../providers/auth.dart';
import '../providers/orders.dart';
import '../providers/currency_provider.dart';
// import '../utils/guest_auth_helper.dart';
import '../services/khalti_service.dart' as app_khalti;
import '../services/stripe_service.dart';
import '../utils/debug_logger.dart';
import '../providers/favorites.dart';

// Function to show cart addition dialog
void showCartAddedDialog(
    BuildContext context, Cart cart, String productId, String productTitle,
    {Map<String, String>? attributes}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF1E1E1E)
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with success icon
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Added to Cart!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      productTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Display attributes if available
                    if (attributes != null && attributes.isNotEmpty) ...[
                      SizedBox(height: 12),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade800
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected Attributes:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                              ),
                            ),
                            SizedBox(height: 6),
                            ...attributes.entries.map((entry) {
                              return Padding(
                                padding: EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Text(
                                      '${entry.key}: ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                    Text(
                                      entry.value,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: 8),
                    Text(
                      'has been added to your cart successfully!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // Action section
              Padding(
                padding: EdgeInsets.only(left: 24, right: 24, bottom: 20),
                child: Column(
                  children: [
                    // Primary action button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pushNamed(CartScreen.routeName);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'View Cart',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    // Secondary clickable text
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Continue Shopping',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade600,
                            decoration: TextDecoration.underline,
                            decorationColor:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// Simplified Product widget class for product.dart - now just passes data to the unified design
class Product extends StatelessWidget {
  final List<dynamic> _product;

  Product(this._product);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        children: <Widget>[
          for (Map<String, dynamic> item in _product)
            Container(
              margin: EdgeInsets.only(right: 12),
              child: ProductItem(item),
            ),
        ],
      ),
    );
  }
}

// Replace the entire ProductItem class build method and related methods
class ProductItem extends StatelessWidget {
  final Map<String, dynamic> _item;
  final bool showPurchaseActions;
  final bool compactReward;

  // Simple in-memory cache to avoid spamming the ratings API while scrolling
  static final Map<int, Future<RatingResponse>> _ratingFutureCache = {};

  const ProductItem(
    this._item, {
    Key? key,
    this.showPurchaseActions = true,
    this.compactReward = false,
  }) : super(key: key);

  String get productImageUrl {
    try {
      // Handle different image formats
      if (_item['images'] != null && _item['images'] is List) {
        final images = _item['images'] as List;
        if (images.isNotEmpty) {
          final first = images.first;

          // If image is a Map with 'full' field
          if (first is Map && first['full'] != null) {
            return _getImageUrl(first['full'].toString());
          }

          // If image is a Map with 'url' field
          if (first is Map && first['url'] != null) {
            return _getImageUrl(first['url'].toString());
          }

          // If image is a Map with 'thumbnail' field
          if (first is Map && first['thumbnail'] != null) {
            return _getImageUrl(first['thumbnail'].toString());
          }

          // If image is a string directly
          if (first is String && first.isNotEmpty) {
            return _getImageUrl(first);
          }
        }
      }

      // Fallback to legacy JSON encode/decode method
      final images = json.encode(_item['images']);
      final decodedImage = json.decode(images);
      if (decodedImage is List && decodedImage.isNotEmpty) {
        final firstImage = decodedImage[0];
        if (firstImage is Map && firstImage['full'] != null) {
          return _getImageUrl(firstImage['full'].toString());
        }
      }
    } catch (_) {}
    return 'https://baakhapaa.com/images/logo.png';
  }

  // Helper method to construct proper image URL from API response
  String _getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return 'https://baakhapaa.com/images/logo.png';
    }

    // If API already returns a full URL (like "full"), don't rewrite it.
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    // Otherwise, build absolute URL from a relative path.
    // API sometimes returns paths like:
    // - "storage/products/xxx.jpg"
    // - "storage/storage/products/xxx.jpg"
    // - "products/xxx.jpg"
    var normalizedPath = imagePath.trim();
    normalizedPath = normalizedPath.replaceFirst(RegExp(r'^/+'), '');
    normalizedPath = normalizedPath.replaceFirst(
        RegExp(r'^(storage/storage/)+'), 'storage/');
    normalizedPath = normalizedPath.replaceFirst(RegExp(r'^storage/'), '');

    return 'https://student.baakhapaa.com/storage/storage/$normalizedPath';
  }

  int? _normalizedId() {
    final dynamic id = _item['id'];
    if (id is int) return id;
    if (id is String) return int.tryParse(id);
    return null;
  }

  Future<RatingResponse>? _getRatingFuture(Auth auth) {
    final id = _normalizedId();
    if (id == null) return null;

    // Reuse the same future so rebuilds don't hammer the API (helps avoid 429s)
    return _ratingFutureCache[id] ??=
        RatingService(authToken: auth.token).getProductRatings(id);
  }

  // Helper to get quantity with fallback field names
  int get productQuantity {
    return _item['qty'] ??
        _item['quantity'] ??
        _item['stock'] ??
        _item['available_quantity'] ??
        0;
  }

  // Helper to get price with fallback field names
  dynamic get productPrice {
    return _item['price'] ?? _item['selling_price'] ?? _item['cost'] ?? 0;
  }

  // Check if product has a price range (from variations)
  String? get productPriceRange {
    final range = _item['price_range'];
    if (range == null) return null;
    final rangeStr = range.toString();
    // Only return if it's an actual range (contains ' - ')
    if (rangeStr.contains(' - ')) return rangeStr;
    return null;
  }

  // Helper to get coin/points with fallback field names
  dynamic get productCoin {
    return _item['coin'] ?? _item['points'] ?? _item['reward_points'] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context, listen: false);
    final theme = Theme.of(context);

    return Container(
      width: 220,
      margin: EdgeInsets.only(top: 2, right: 0, bottom: 2, left: 0),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(
            SingleProductScreen.routeName,
            arguments: _item['id'],
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).brightness == Brightness.dark
                    ? Color(0xFF2A2A2A)
                    : Colors.white,
                Theme.of(context).brightness == Brightness.dark
                    ? Color(0xFF1E1E1E)
                    : Colors.grey.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.15),
                blurRadius: 15,
                spreadRadius: 0,
                offset: Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Product Image Section
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade800
                      : Colors.grey.shade100,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  child: CachedNetworkImage(
                    imageUrl: productImageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 140,
                    placeholder: (context, url) => Container(
                      width: double.infinity,
                      height: 140,
                      color: Colors.grey.shade300,
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.amber),
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: double.infinity,
                      height: 140,
                      color: Colors.grey.shade200,
                      child: Center(
                        child: Icon(
                          Icons.image_not_supported,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Product Info Section
              Padding(
                padding: EdgeInsets.all(5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Product Title
                    Text(
                      _item['title'].toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                        color: theme.brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    // Price Range (below title, only for variant products)
                    if (productPriceRange != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Rs. $productPriceRange',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color.fromARGB(255, 102, 177, 105),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: 5),
                    // Price with Rating on the right
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Consumer<CurrencyProvider>(
                            builder: (_, currency, __) {
                              final dynamic rawPrice = productPrice;
                              final double numPrice =
                                  double.tryParse(rawPrice.toString()) ?? 0;
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Rs. ${productPrice}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: const Color.fromARGB(
                                            255, 102, 177, 105),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (numPrice > 0) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '~${currency.formatNprAsUsd(numPrice)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                        SizedBox(width: 6),
                        // Rating on far right
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 12,
                            ),
                            SizedBox(width: 2),
                            Builder(builder: (context) {
                              final ratingFuture = _getRatingFuture(auth);
                              if (ratingFuture == null) {
                                return Text(
                                  '0.0',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: theme.brightness == Brightness.dark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                );
                              }

                              return FutureBuilder<RatingResponse>(
                                future: ratingFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.amber),
                                      ),
                                    );
                                  }
                                  if (snapshot.hasError || !snapshot.hasData) {
                                    return Text(
                                      '0.0',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            theme.brightness == Brightness.dark
                                                ? Colors.white
                                                : Colors.black87,
                                      ),
                                    );
                                  }
                                  final rating =
                                      snapshot.data!.stats.averageRating;
                                  return Text(
                                    rating.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: theme.brightness == Brightness.dark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  );
                                },
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    // Reward Points - Wrapped in box like image
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compactReward ? 8 : 12,
                        vertical: compactReward ? 4 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1C), // dark pill background
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Coin icon
                          Container(
                            width: 16,
                            height: 16,
                            // decoration: const BoxDecoration(
                            //   shape: BoxShape.circle,
                            //   color: Color(0xFFFFC107), // gold
                            // ),
                            child: Center(
                              child: Image.asset(
                                'assets/images/coins.png',
                                width: 20,
                                height: 20,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Text
                          Flexible(
                            child: RichText(
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: compactReward ? 10 : 12,
                                  color: Colors.white,
                                ),
                                children: [
                                  if (!compactReward)
                                    const TextSpan(text: 'Reward Points: '),
                                  TextSpan(
                                    text: productCoin.toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFFFC107),
                                    ),
                                  ),
                                  const TextSpan(
                                    text: ' Sikka',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (showPurchaseActions) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (auth.isGuest) {
                                  GuestAuthHelper.showGuestLoginDialog(
                                      context, 'Add to cart');
                                  return;
                                }
                                final qty = productQuantity;
                                if (qty <= 0) {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      title: Text('Out of Stock'),
                                      content: Text(
                                        'This product is currently out of stock and will be restocked soon due to high demand.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: Text('OK'),
                                        ),
                                      ],
                                    ),
                                  );
                                  return;
                                }

                                final cart =
                                    Provider.of<Cart>(context, listen: false);
                                if (!cart.canAddMoreItems(
                                        _item['id'].toString()) &&
                                    cart.items
                                        .containsKey(_item['id'].toString())) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Cannot add more items. Only $qty available in stock.'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                  return;
                                }

                                cart.addItem(
                                  _item['id'].toString(),
                                  double.parse(productPrice.toString()),
                                  _item['title'].toString(),
                                  productImageUrl,
                                  qty,
                                  attributes:
                                      null, // No attributes for quick add from product list
                                  isDigital: () {
                                    final t = _item['type']
                                            ?.toString()
                                            .toLowerCase() ??
                                        '';
                                    final n = _item['title']
                                            ?.toString()
                                            .toLowerCase() ??
                                        '';
                                    return t == 'digital' ||
                                        t == 'coins' ||
                                        n.contains('points');
                                  }(),
                                );
                                showCartAddedDialog(
                                  context,
                                  cart,
                                  _item['id'].toString(),
                                  _item['title'].toString(),
                                  attributes: null,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: productQuantity <= 0
                                    ? Colors.grey.shade400
                                    : Color(0xFF7DD761),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 0,
                              ),
                              icon: Icon(Icons.shopping_cart, size: 12),
                              label: Text(
                                productQuantity <= 0
                                    ? 'Out of Stock'
                                    : 'Add to Cart',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          // Favorite (heart) button
                          Consumer<Favorites>(
                            builder: (context, favorites, _) {
                              final productId = _item['id'].toString();
                              final isFavorite =
                                  favorites.isFavorite(productId);

                              return InkWell(
                                onTap: () async {
                                  if (auth.isGuest) {
                                    GuestAuthHelper.showGuestLoginDialog(
                                        context, 'save favorite');
                                    return;
                                  }
                                  await favorites.toggleFavorite(productId);
                                },
                                borderRadius: BorderRadius.circular(18),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: theme.brightness == Brightness.dark
                                        ? Colors.grey[850]
                                        : Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.08),
                                        blurRadius: 6,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: isFavorite
                                          ? Colors.red
                                          : (theme.brightness == Brightness.dark
                                              ? Colors.white
                                                  .withValues(alpha: 0.3)
                                              : Colors.grey
                                                  .withValues(alpha: 0.6)),
                                    ),
                                  ),
                                  child: Icon(
                                    isFavorite
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    size: 18,
                                    color: isFavorite
                                        ? Colors.red
                                        : (theme.brightness == Brightness.dark
                                            ? Colors.white
                                            : Colors.grey[700]),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuickBuyDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final Auth auth;
  final int? affiliateId;

  const QuickBuyDialog({
    Key? key,
    required this.item,
    required this.auth,
    this.affiliateId,
  }) : super(key: key);

  @override
  State<QuickBuyDialog> createState() => _QuickBuyDialogState();
}

class _QuickBuyDialogState extends State<QuickBuyDialog> {
  String? _selectedPaymentMethod;
  bool _isProcessing = false;
  String? _currentPidx;

  @override
  void initState() {
    super.initState();
    DebugLogger.info(
        'DEBUG: QuickBuyDialog initialized with affiliateId: ${widget.affiliateId}');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _quickBuyPaymentSuccess(PaymentPayload payload) async {
    if (!mounted) return;

    DebugLogger.success('Processing quick buy payment: ${payload.pidx}');

    if (_currentPidx != null && _currentPidx != payload.pidx) {
      DebugLogger.info(
          "Ignoring payment for different PIDX: ${payload.pidx} (current: $_currentPidx)");
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _isProcessing = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Payment Completed. Placing Order...'),
        duration: Duration(seconds: 2),
      ));
    });

    try {
      Map<String, dynamic> paymentData = {
        'idx': payload.pidx,
        'token': payload.transactionId,
        'amount': payload.totalAmount,
        'mobile': '',
        'source': 'Khalti',
      };

      DebugLogger.info("Quick buy payment data: $paymentData");

      // Place direct order using new method
      await Provider.of<Orders>(context, listen: false).addDirectOrder(
        productId: widget.item['id'].toString(),
        quantity: 1,
        paymentId: paymentData['idx'] is int
            ? paymentData['idx']
            : int.tryParse(paymentData['idx'].toString()) ?? 0,
        affiliateId: widget.affiliateId,
      );

      _currentPidx = null;

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
            try {
              Navigator.of(context, rootNavigator: true).popUntil(
                  (route) => route.settings.name == 'ProcessingDialog');
              if (Navigator.of(context, rootNavigator: true).canPop()) {
                Navigator.of(context, rootNavigator: true).pop();
              }
            } catch (e) {}
            _showQuickBuySuccessDialog();
            app_khalti.KhaltiService.clearPaymentState();
          }
        });
      }
    } catch (e) {
      DebugLogger.error("Error processing quick buy Khalti payment: $e");
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('Payment Verification Issue'),
                content: Text(
                    'Your payment was processed successfully by Khalti, but we couldn\'t verify it with our system. '
                    'Please contact customer support with your transaction ID: ${payload.transactionId}.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('OK'),
                  ),
                ],
              ),
            );
          }
        });
      }
    } finally {
      app_khalti.KhaltiService.clearPaymentState();
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
          }
        });
      }
    }
  }

  Future<void> _payWithKhalti(double amount) async {
    try {
      if (!mounted) return;

      setState(() {
        _isProcessing = true;
      });

      final orderId = 'quick_order_${DateTime.now().millisecondsSinceEpoch}';
      final titleStr = widget.item['title'].toString();
      final orderName = titleStr.length > 20
          ? 'Quick Buy - ${titleStr.substring(0, 20)}...'
          : 'Quick Buy - $titleStr';

      String? customerName = widget.auth.userName;
      String? customerEmail = widget.auth.user['email'];
      String? customerPhone = widget.auth.user['phone_number'];

      app_khalti.KhaltiService.clearPaymentState();

      String pidx = await app_khalti.KhaltiService.initiatePaymentServer(
        amount: amount,
        orderName: orderName,
        orderId: orderId,
        customerName: customerName,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
      );

      if (pidx.isEmpty) {
        throw Exception("Failed to get valid PIDX from server");
      }

      _currentPidx = pidx;
      DebugLogger.info("Quick buy PIDX: $pidx");

      await app_khalti.KhaltiService.makePayment(
        context,
        pidx,
        _quickBuyPaymentSuccess,
      );
    } catch (e) {
      if (!mounted) return;
      DebugLogger.error("Error initiating quick buy payment: $e");
      _showMessage('Error processing payment: $e');
      _currentPidx = null;
      app_khalti.KhaltiService.clearPaymentState();
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processCODOrder() async {
    if (!mounted) return;

    // Store the BuildContext before any async operations
    final BuildContext dialogContext = context;

    setState(() {
      _isProcessing = true;
    });

    try {
      DebugLogger.info(
          'Starting COD order process for product: ${widget.item['id']}');

      // Create cart items map for single product
      final imageUrl =
          'https://student.baakhapaa.com/storage/storage/${json.decode(json.encode(widget.item['images']))[0]['full']}';
      Map<String, CartItem> cartItems = {
        widget.item['id'].toString(): CartItem(
          id: widget.item['id'].toString(),
          title: widget.item['title'].toString(),
          price: double.parse(widget.item['price'].toString()),
          image: imageUrl,
          quantity: 1,
          availableStock: widget.item['qty'] ?? 0,
          attributes: null, // No attributes for quick buy
          affiliateId: widget.affiliateId,
        ),
      };

      DebugLogger.info('Placing COD order for product: ${widget.item['id']}');

      // Place the order
      await Provider.of<Orders>(dialogContext, listen: false).addOrder(
        cartItems: cartItems,
        paymentMethod: 'Cash on Delivery',
      );

      DebugLogger.success('Quick buy COD order placed successfully');

      if (!mounted) return;

      // Close the QuickBuyDialog using the stored context
      Navigator.of(dialogContext).pop();

      // Wait for the dialog to close completely
      await Future.delayed(Duration(milliseconds: 5));

      // Verify context is still valid before showing success dialog
      if (!mounted) return;

      // Schedule success dialog to show after frame
      Future.delayed(Duration(milliseconds: 10), () {
        if (mounted) {
          _showQuickBuySuccessDialog();
        }
      });
    } catch (e) {
      DebugLogger.error('Error processing quick buy COD order: $e');

      if (!mounted) return;

      // Prepare error message
      String errorMessage = 'Error processing order';
      if (e.toString().contains('HTML error page')) {
        errorMessage = 'Server error. Please try again later.';
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        errorMessage = 'Network error. Please check your connection.';
      } else if (e.toString().contains('not authenticated')) {
        errorMessage = 'Please log in to place an order.';
      } else if (e.toString().contains('401')) {
        errorMessage = 'Session expired. Please log in again.';
      }

      // Close the QuickBuyDialog if still open
      if (Navigator.canPop(dialogContext)) {
        Navigator.of(dialogContext).pop();
      }

      // Wait a bit before showing error
      await Future.delayed(Duration(milliseconds: 100));

      if (!mounted) return;

      // Show error message using post frame callback
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processStripeOrder() async {
    if (!mounted) return;

    final BuildContext dialogContext = context;

    setState(() {
      _isProcessing = true;
    });

    try {
      final authToken = widget.auth.token;
      if (authToken.isEmpty) {
        throw Exception('not authenticated');
      }

      final productPrice = double.parse(widget.item['price'].toString());
      final currency =
          Provider.of<CurrencyProvider>(dialogContext, listen: false);
      final int amountInCents =
          currency.nprToCents(productPrice).clamp(50, 999999);

      final int productId = int.tryParse(widget.item['id'].toString()) ?? 0;

      await StripeService.purchaseProducts(
        authToken: authToken,
        productIds: [productId],
        amountInCents: amountInCents,
        shippingAddressId: null,
        shippingProviderId: null,
      );

      DebugLogger.success('Quick buy Stripe payment completed');

      if (!mounted) return;
      Navigator.of(dialogContext).pop();

      await Future.delayed(const Duration(milliseconds: 10));
      if (mounted) {
        _showQuickBuySuccessDialog();
      }
    } on StripeException catch (e) {
      DebugLogger.error('Stripe quick buy exception: $e');
      if (!mounted) return;
      if (e.error.code != FailureCode.Canceled) {
        final msg = e.error.localizedMessage ?? 'Card payment failed.';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg), backgroundColor: Colors.red),
            );
          }
        });
      }
    } catch (e) {
      DebugLogger.error('Error processing Stripe quick buy: $e');
      if (!mounted) return;

      // Extract the actual message from Exception("...") so users see what went wrong
      String raw = e.toString();
      if (raw.startsWith('Exception: '))
        raw = raw.substring('Exception: '.length);

      String errorMessage;
      if (raw.contains('not authenticated') || raw.contains('401')) {
        errorMessage = 'Session expired. Please log in again.';
      } else if (raw.contains('SocketException') ||
          raw.contains('TimeoutException')) {
        errorMessage = 'Network error. Please check your connection.';
      } else {
        errorMessage =
            raw.isNotEmpty ? raw : 'Payment error. Please try again.';
      }

      if (Navigator.canPop(dialogContext)) {
        Navigator.of(dialogContext).pop();
      }

      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showQuickBuySuccessDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.teal.shade400],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.check_circle_rounded,
                size: 64,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Order Successful!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 12),
            Text(
              '${widget.item['title']} has been ordered successfully. We will get back to you soon with order details.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop(); // Close success dialog
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Continue Shopping',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double productPrice = double.parse(widget.item['price'].toString());

    return PopScope(
      canPop: !_isProcessing,
      onPopInvokedWithResult: (didPop, result) {
        if (_isProcessing && !didPop) {
          _showMessage(
              'Please wait while we process your order. Do not close this window.');
        }
      },
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Quick Buy - Select Payment',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.item['title'].toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Qty: 1 | Rs. $productPrice',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Payment Methods
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Khalti Option
                    _buildPaymentOption(
                      'khalti',
                      'Khalti Wallet',
                      'Fast & Secure Payment',
                      null,
                      Color(0xFF5D2E8C),
                      Icons.account_balance_wallet,
                      (value) {
                        setState(() => _selectedPaymentMethod = value);
                      },
                    ),
                    SizedBox(height: 12),

                    // COD Option
                    _buildPaymentOption(
                      'cod',
                      'Cash on Delivery',
                      'Pay when you receive',
                      null,
                      Colors.orange,
                      Icons.local_shipping,
                      (value) {
                        setState(() => _selectedPaymentMethod = value);
                      },
                    ),
                    SizedBox(height: 12),

                    // Stripe Option
                    _buildPaymentOption(
                      'stripe',
                      'Credit / Debit Card',
                      'Visa, Mastercard — charged in USD',
                      null,
                      Color(0xFF635BFF),
                      Icons.credit_card_rounded,
                      (value) {
                        setState(() => _selectedPaymentMethod = value);
                      },
                    ),
                    SizedBox(height: 20),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isProcessing
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isProcessing ||
                                    _selectedPaymentMethod == null
                                ? null
                                : () async {
                                    if (_selectedPaymentMethod == 'khalti') {
                                      await _payWithKhalti(productPrice);
                                    } else if (_selectedPaymentMethod ==
                                        'cod') {
                                      await _processCODOrder();
                                    } else if (_selectedPaymentMethod ==
                                        'stripe') {
                                      await _processStripeOrder();
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedPaymentMethod == null
                                  ? Colors.grey
                                  : Colors.green,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _isProcessing
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Text(
                                    'Confirm',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption(
    String value,
    String title,
    String subtitle,
    String? imagePath,
    Color color,
    IconData fallbackIcon,
    Function(String) onSelected,
  ) {
    bool isSelected = _selectedPaymentMethod == value;

    return InkWell(
      onTap: _isProcessing ? null : () => onSelected(value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [
                    color.withValues(alpha: 0.2),
                    color.withValues(alpha: 0.1),
                  ]
                : [
                    Colors.grey.shade50,
                    Colors.grey.shade100,
                  ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                fallbackIcon,
                color: color,
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : Colors.grey.shade300,
                  width: 2,
                ),
                color: isSelected ? color : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
