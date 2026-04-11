import 'package:flutter/material.dart';
import '../../widgets/product.dart';
import '../../utils/puppet_screen_mapping.dart';

import '../../widgets/header.dart';
import '../../providers/cart.dart';
import 'package:provider/provider.dart';
import '../../widgets/skeleton_loading.dart';
import 'cart_screen.dart';

class VendorProductScreen extends StatefulWidget {
  static const routeName = '/vendor-product-screen';

  const VendorProductScreen({Key? key}) : super(key: key);

  @override
  State<VendorProductScreen> createState() => _VendorProductScreenState();
}

class _VendorProductScreenState extends State<VendorProductScreen>
    with PuppetInteractionMixin {
  var _isInit = true;
  var _isLoading = true;
  late List<dynamic> _products = [];
  List<dynamic> searchResults = [];

  @override
  void didChangeDependencies() {
    if (_isInit) {
      _products = ModalRoute.of(context)!.settings.arguments as List<dynamic>;
      _isLoading = false;
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  List<dynamic> search(String query) {
    List<dynamic> results = [];
    // Iterate through the list and add items that match the search query to the results list
    for (int i = 0; i < _products.length; i++) {
      if (_products[i]['title'].toLowerCase().contains(query.toLowerCase())) {
        results.add(_products[i]);
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
      appBar: header(
          context: context,
          titleText: _products.isNotEmpty
              ? _products.first['user']['username'].toUpperCase()
              : 'Vendor Products'),
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
                    // Vendor Profile Section
                    _buildVendorProfileSection(),

                    // Vendor Products Section
                    _buildVendorProductsSection(),

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
                  'All Products',
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

  Widget _buildVendorProductsSection() {
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
            // Row(
            //   children: [
            //     Container(
            //       padding: EdgeInsets.all(8),
            //       decoration: BoxDecoration(
            //         color: Colors.black,
            //         shape: BoxShape.circle,
            //       ),
            //       child: Text(
            //         vendorDisplayName,
            //         style: TextStyle(color: Colors.white, fontSize: 12),
            //       ),
            //     ),
            //     SizedBox(width: 12),
            //     Expanded(
            //       child: Column(
            //         crossAxisAlignment: CrossAxisAlignment.start,
            //         children: [
            //           Text(
            //             "${vendorName}'s products",
            //             style: TextStyle(
            //               fontSize: 16,
            //               fontWeight: FontWeight.bold,
            //             ),
            //           ),
            //           Text(
            //             'Recommended to you...',
            //             style: TextStyle(
            //               fontSize: 12,
            //               color: Colors.grey[600],
            //             ),
            //           ),
            //         ],
            //       ),
            //     ),
            //   ],
            // ),
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
                return ProductItem(
                  productsToShow[index],
                  compactReward: true,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorProfileSection() {
    final vendorData = _products.isNotEmpty ? _products.first['user'] : null;
    final vendorName = vendorData?['username'] ?? 'Baakhapaa';

    // Determine vendor profile image and description based on username
    String? vendorProfileImage;
    String vendorDescription;
    final nameLower = vendorName.toLowerCase().trim();
    if (nameLower == 'baakhapaa-admin') {
      vendorProfileImage = 'assets/images/logo-lony.png';
      vendorDescription = vendorData?['description'] ??
          'We provide products with gifts attached to it like Point reward, Discounts, gift package and more.';
    } else if (nameLower.contains('sudip') ||
        nameLower.contains('sudip gurung')) {
      vendorProfileImage = 'assets/images/sudip.png';
      vendorDescription =
          'Delivering premium mobile accessories that keep your devices protected and powered.';
    } else {
      vendorDescription = vendorData?['description'] ??
          'We provide products with gifts attached to it like Point reward, Discounts, gift package and more.';
    }

    // Fallback to API data if available
    vendorProfileImage ??= vendorData?['profileImage'] ??
        vendorData?['profile_image'] ??
        'assets/images/logo-lony.png';

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
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vendor Logo
            Container(
              width: 72,
              height: 72,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.black,
              ),
              child: vendorProfileImage != null && vendorProfileImage.isNotEmpty
                  ? (vendorProfileImage.startsWith('http')
                      ? Image.network(
                          vendorProfileImage,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              'assets/images/logo-lony.png',
                              fit: BoxFit.contain,
                            );
                          },
                        )
                      : Image.asset(
                          vendorProfileImage,
                          fit: BoxFit.contain,
                        ))
                  : Image.asset(
                      'assets/images/logo-lony.png',
                      fit: BoxFit.contain,
                    ),
            ),
            const SizedBox(width: 12),
            // Vendor Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Subtitle
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$vendorName ',
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Color(0xFFFFC857)
                                    : Colors.orange.shade600,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Description
                  Text(
                    vendorDescription,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white60
                          : Colors.grey[600],
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
