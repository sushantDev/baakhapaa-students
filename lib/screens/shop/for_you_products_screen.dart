import 'package:flutter/material.dart';
import '../../widgets/product.dart';
import '../../utils/puppet_screen_mapping.dart';

import '../../widgets/header.dart';
import '../../providers/cart.dart';
import '../../providers/shop.dart';
import 'package:provider/provider.dart';
import '../../widgets/skeleton_loading.dart';
import 'cart_screen.dart';
import '../../../utils/debug_logger.dart';

class ForYouProductsScreen extends StatefulWidget {
  static const routeName = '/for-you-products-screen';

  const ForYouProductsScreen({Key? key}) : super(key: key);

  @override
  State<ForYouProductsScreen> createState() => _ForYouProductsScreenState();
}

class _ForYouProductsScreenState extends State<ForYouProductsScreen>
    with PuppetInteractionMixin {
  var _isInit = true;
  var _isLoading = true;
  late List<dynamic> _products = [];
  List<dynamic> searchResults = [];

  @override
  void didChangeDependencies() {
    if (_isInit) {
      _loadProducts();
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  void _loadProducts() async {
    try {
      final shopProvider = Provider.of<Shop>(context, listen: false);
      // Always fetch fresh data from API to ensure we have the latest structure
      await shopProvider.getForYouProducts();
      final forYouProducts = shopProvider.forYouProducts;
      if (forYouProducts.isNotEmpty) {
        final tempProducts = <Map<String, dynamic>>[];
        for (var product in forYouProducts) {
          // Use a more robust conversion that preserves all fields
          Map<String, dynamic> productMap;
          if (product is Map<String, dynamic>) {
            // Deep copy to ensure all nested structures are preserved
            productMap = Map<String, dynamic>.from(product.map((key, value) {
              // Preserve the value as-is, including nested structures
              return MapEntry(key.toString(), value);
            }));
          } else if (product is Map) {
            // Convert from any Map type
            productMap = Map<String, dynamic>.from(product.map((key, value) {
              return MapEntry(key.toString(), value);
            }));
          } else {
            // Try to convert from any other format
            try {
              productMap = Map<String, dynamic>.from(product as Map);
            } catch (e) {
              DebugLogger.info('Error converting product: $e');
              continue; // Skip this product if conversion fails
            }
          }
          tempProducts.add(productMap);
          // Debug: DebugLogger.info first product to verify structure
          if (tempProducts.length == 1) {
            DebugLogger.info('=== For You Product Structure ===');
            DebugLogger.info('First product: $productMap');
            DebugLogger.info('ID: ${productMap['id']}');
            DebugLogger.info('Title: ${productMap['title']}');
            DebugLogger.info(
                'Price: ${productMap['price']} (type: ${productMap['price'].runtimeType})');
            DebugLogger.info(
                'Coin: ${productMap['coin']} (type: ${productMap['coin'].runtimeType})');
            DebugLogger.info(
                'Qty: ${productMap['qty']} (type: ${productMap['qty'].runtimeType})');
            DebugLogger.info('Quantity: ${productMap['quantity']}');
            DebugLogger.info('Stock: ${productMap['stock']}');
            DebugLogger.info('All keys: ${productMap.keys.toList()}');
            DebugLogger.info('Images: ${productMap['images']}');
          }
        }
        _products = tempProducts;
      } else {
        // Fallback: try to use arguments if provider has no data
        final arguments = ModalRoute.of(context)!.settings.arguments;
        if (arguments != null &&
            arguments is List<dynamic> &&
            arguments.isNotEmpty) {
          final tempProducts = <Map<String, dynamic>>[];
          for (var product in arguments) {
            Map<String, dynamic> productMap;
            if (product is Map<String, dynamic>) {
              productMap = Map<String, dynamic>.from(product);
            } else if (product is Map) {
              productMap = Map<String, dynamic>.from(product);
            } else {
              productMap = Map<String, dynamic>.from(product as Map);
            }
            tempProducts.add(productMap);
          }
          _products = tempProducts;
        } else {
          _products = [];
        }
      }
      // Debug: DebugLogger.info summary
      DebugLogger.info('=== Loaded ${_products.length} products ===');
      if (_products.isNotEmpty) {
        final first = _products[0];
        DebugLogger.info('Sample product keys: ${first.keys.toList()}');
        DebugLogger.info(
            'Sample product: id=${first['id']}, title=${first['title']}');
        DebugLogger.info(
            'Price: ${first['price']} (${first['price'].runtimeType}), Coin: ${first['coin']} (${first['coin'].runtimeType})');
        DebugLogger.info(
            'Qty: ${first['qty']} (${first['qty'].runtimeType}), Quantity: ${first['quantity']}, Stock: ${first['stock']}');
        // Verify critical fields
        if (first['qty'] == null &&
            first['quantity'] == null &&
            first['stock'] == null) {
          DebugLogger.info('⚠️ WARNING: No quantity field found in product!');
        }
        if (first['price'] == null) {
          DebugLogger.info('⚠️ WARNING: No price field found in product!');
        }
        if (first['coin'] == null) {
          DebugLogger.info('⚠️ WARNING: No coin field found in product!');
        }
      }
    } catch (e) {
      DebugLogger.info('Error loading products: $e');
      _products = [];
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<dynamic> search(String query) {
    List<dynamic> results = [];
    if (query.isEmpty) {
      return results;
    }
    // Iterate through the list and add items that match the search query to the results list
    for (int i = 0; i < _products.length; i++) {
      final product = _products[i];
      if (product is Map<String, dynamic>) {
        final title = product['title'];
        if (title != null &&
            title.toString().toLowerCase().contains(query.toLowerCase())) {
          results.add(product);
        }
      }
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Color(0xFF1A1A1A)
          : Colors.grey.shade50,
      appBar: header(context: context, titleText: 'For You'),
      body: _isLoading
          ? _buildLoadingState()
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).brightness == Brightness.dark
                        ? Color.fromARGB(255, 9, 9, 9)
                        : Colors.white,
                    Theme.of(context).brightness == Brightness.dark
                        ? Color(0xFF082032)
                        : Color.fromARGB(255, 248, 248, 248),
                  ],
                ),
              ),
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Column(
                  children: <Widget>[
                    // Search Bar Section
                    _buildSearchBar(),

                    // For You Products Section
                    _buildForYouProductsSection(),

                    SizedBox(height: 100), // Bottom padding
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).brightness == Brightness.dark
                ? Color.fromARGB(255, 9, 9, 9)
                : Colors.white,
            Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF082032)
                : Color.fromARGB(255, 248, 248, 248),
          ],
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: GridSkeleton(crossAxisCount: 2, itemCount: 6),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and Cart Icon Row
          Row(
            children: [
              Expanded(
                child: Text(
                  'All For You Products',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ),
              // Cart Icon
              Consumer<Cart>(
                builder: (context, cart, child) {
                  return InkWell(
                    onTap: () {
                      Navigator.of(context).pushNamed(CartScreen.routeName);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.all(8),
                      child: Stack(
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                            size: 24,
                          ),
                          if (cart.itemCount > 0)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  cart.itemCount > 9
                                      ? '9+'
                                      : '${cart.itemCount}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          SizedBox(height: 12),
          // Search Bar - Direct rounded input field
          TextField(
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'Search for product',
              hintStyle: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[600],
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[600],
                size: 20,
              ),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[900]
                  : Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (text) {
              setState(() {
                searchResults = search(text);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildForYouProductsSection() {
    final productsToShow = searchResults.isNotEmpty ? searchResults : _products;

    if (productsToShow.isEmpty) {
      return Container(
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.all(40),
        child: Center(
          child: Text(
            'No products found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                ? Colors.black.withValues(alpha: 0.18)
                : Colors.grey.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.grey.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[700]!
                          : Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo-lony.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: Icon(Icons.error, size: 16),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'For You',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'You might like this',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            // Grid layout using the same ProductItem design
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                // Give cards more vertical room to avoid overflow of ProductItem
                childAspectRatio: 0.55,
              ),
              itemCount: productsToShow.length,
              itemBuilder: (context, index) {
                final product = productsToShow[index];
                // Ensure product is a Map<String, dynamic> with all required fields
                Map<String, dynamic> productMap;
                if (product is Map<String, dynamic>) {
                  productMap = Map<String, dynamic>.from(product);
                } else if (product is Map) {
                  productMap = Map<String, dynamic>.from(product);
                } else {
                  productMap = Map<String, dynamic>.from(product as Map);
                }

                // Verify product has required fields, if not log for debugging
                if (productMap['price'] == null || productMap['coin'] == null) {
                  DebugLogger.info(
                      'Warning: Product at index $index missing price or coin');
                  DebugLogger.info('Product keys: ${productMap.keys.toList()}');
                  DebugLogger.info('Product data: $productMap');
                }

                return ProductItem(
                  productMap,
                  compactReward: true,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
