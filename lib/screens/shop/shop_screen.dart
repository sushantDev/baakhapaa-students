import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:baakhapaa/helpers/helpers.dart';
// import 'package:baakhapaa/l10n/app_localizations.dart';
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/screens/shop/search_product_screen.dart';
import 'package:baakhapaa/screens/shop/vendor_product_screen.dart';
import 'package:baakhapaa/screens/shop/cart_screen.dart';
import 'package:baakhapaa/screens/story/video_screen.dart';
import 'package:baakhapaa/screens/subscription/subscription_screen.dart';
import '../../providers/cart.dart';
import '../../providers/favorites.dart';
import 'package:baakhapaa/widgets/header.dart';
import 'package:baakhapaa/widgets/nav_bar.dart';
import 'package:baakhapaa/widgets/refresh_indicator.dart';
import 'package:baakhapaa/widgets/skeleton_loading.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:provider/provider.dart';
import 'package:upgrader/upgrader.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/product.dart';
import '../../providers/shop.dart';
import '../../widgets/my_upgrader_messages.dart';
import 'single_product_screen.dart';
import '../../providers/puppet_interaction_provider.dart';
import '../../utils/puppet_screen_mapping.dart';
import '../../utils/debug_logger.dart';
import '../../services/ad_service.dart';
import 'for_you_products_screen.dart';

class ShopScreen extends StatefulWidget {
  static const routeName = '/shop-screen';

  const ShopScreen({Key? key}) : super(key: key);

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with PuppetInteractionMixin {
  var _isInit = true;
  late Map<String, dynamic> products = {};
  var _isLoading = false;
  late List<String> productKeys;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String selectedCategory = '';
  List<String> selectedBrands = [];
  TextEditingController _minPriceController = TextEditingController();
  TextEditingController _maxPriceController = TextEditingController();
  List<Map<String, dynamic>> filtered = [];
  late List<dynamic> _productSliders = [];
  late Shop shopProvider;
  String? _selectedFilter; // For filter buttons (Top Favorites, Latest, etc.)
  bool _isFilterLoading = false;

  bool _isUserLoggedIn() {
    final authProvider = Provider.of<Auth>(context, listen: false);
    return authProvider.isAuth;
  }

  // Map filter key to API sort parameter
  String _mapFilterKeyToSort(String filterKey) {
    switch (filterKey) {
      case 'high_rewarding':
        return 'high_rewarding';
      case 'latest':
        return 'latest';
      case 'creators_product':
        return 'creators_product';
      default:
        return 'latest';
    }
  }

  // Fetch products from the filter API
  Future<void> _fetchFilteredProducts(String filterKey) async {
    if (_isFilterLoading) return;

    try {
      setState(() => _isFilterLoading = true);

      final auth = Provider.of<Auth>(context, listen: false);
      final token = auth.token;
      final sortParam = _mapFilterKeyToSort(filterKey);

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final response = await http.get(
        Uri.parse(
          'https://app.baakhapaa.com/api/products/filter?sort=$sortParam',
        ),
        headers: headers,
      );

      DebugLogger.info(
        '🔍 Product Filter API Response: ${response.statusCode} - Fetching products for sort: $sortParam',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        DebugLogger.info('🔍 Raw API response keys: ${data.keys.toString()}');
        if (data['data'] is Map) {
          DebugLogger.info(
              '🔍 data["data"] is a Map with keys: ${(data['data'] as Map).keys.toString()}');
        }

        // Parse response with flexible pattern matching (like story_creation.dart)
        List<dynamic> products = [];

        // Pattern 1: data['data'] as direct list
        if (data['data'] is List) {
          products = data['data'] as List;
          DebugLogger.info('✅ Matched Pattern 1: data["data"] is List');
        }
        // Pattern 2: data['data']['data'] as list (nested pagination structure)
        else if (data['data'] is Map && data['data']['data'] is List) {
          products = data['data']['data'] as List;
          DebugLogger.info(
              '✅ Matched Pattern 2: data["data"]["data"] is List (${products.length} items)');
        }
        // Pattern 3: data['data']['values'] as list
        else if (data['data'] is Map && data['data']['values'] is List) {
          products = data['data']['values'] as List;
          DebugLogger.info(
              '✅ Matched Pattern 3: data["data"]["values"] is List');
        }
        // Pattern 4: data['data']['products'] as list
        else if (data['data'] is Map && data['data']['products'] is List) {
          products = data['data']['products'] as List;
          DebugLogger.info(
              '✅ Matched Pattern 4: data["data"]["products"] is List');
        }
        // Pattern 5: data['data']['items'] as list
        else if (data['data'] is Map && data['data']['items'] is List) {
          products = data['data']['items'] as List;
          DebugLogger.info(
              '✅ Matched Pattern 5: data["data"]["items"] is List');
        }
        // Pattern 6: data as direct list
        else if (data is List) {
          // ignore: unnecessary_cast
          products = data as List;
          DebugLogger.info('✅ Matched Pattern 6: data is List');
        }

        setState(() {
          filtered = List<Map<String, dynamic>>.from(
            products.map((p) => Map<String, dynamic>.from(p as Map)),
          );
          _isFilterLoading = false;
        });

        DebugLogger.info(
          '✅ Filtered products loaded: ${filtered.length} products for filter "$filterKey"',
        );
      } else {
        throw Exception(
          'Failed to load filtered products: ${response.statusCode}',
        );
      }
    } catch (e) {
      DebugLogger.error('❌ Failed loading filtered products: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed loading filtered products: $e')),
        );
        setState(() => _isFilterLoading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();

    // Initialize puppet provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<PuppetInteractionProvider>().initState();
      } catch (e) {
        DebugLogger.puppet('Puppet provider not available: $e');
      }
    });
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();

    // Clear puppet interactions when leaving screen
    clearPuppetInteractions();

    super.dispose();
  }

  @override
  void didChangeDependencies() {
    if (_isInit) {
      _mainInit();
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  Future<void> _mainInit() async {
    var _productProvider = Provider.of<Shop>(context, listen: false);
    _productProvider.fetchProductSlider().then((___) {
      if (mounted) {
        setState(() {
          _productSliders = _productProvider.productSliders;
        });
      }
    });
    // Fetch For You products from API
    _productProvider.getForYouProducts().then((_) {
      if (mounted) {
        setState(() {
          // Trigger rebuild when forYou products are loaded
        });
      }
    });
    Provider.of<Shop>(context, listen: false).getAllProducts().then((_) {
      if (mounted) {
        setState(() {
          products = Provider.of<Shop>(context, listen: false).products;
          productKeys = products.keys.toList();
          _isLoading = true;
        });

        // Refresh puppet suggestions when products load
        refreshPuppetSuggestions();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: header(
        context: context,
        titleText: context.l10n.store,
        scaffoldKey: _scaffoldKey,
      ),
      drawer: NavBar(),
      body: UpgradeAlert(
        showLater: false,
        barrierDismissible: false,
        showIgnore: false,
        dialogStyle: Platform.isIOS
            ? UpgradeDialogStyle.cupertino
            : UpgradeDialogStyle.material,
        upgrader: Upgrader(
          debugDisplayAlways: false,
          messages: MyUpgraderMessages(),
        ),
        child: BkpRefreshIndicator(
          onRefresh: () async {
            _mainInit();
          },
          child: _isLoading
              ? Container(
                  child: SingleChildScrollView(
                    physics: BouncingScrollPhysics(),
                    child: Column(
                      children: <Widget>[
                        // Quick Actions Section (always show search bar)
                        _buildQuickActions(),
                        const BaakhaBannerAd(),

                        if (_selectedFilter != 'top_favorites') ...[
                          // "For you" Section
                          if (_selectedFilter == null) ...[
                            _buildForYouSection(),
                            // Hero Banner Section
                            _buildHeroBanner(),

                            // Active Filters Section
                            if (filtered.isNotEmpty) _buildActiveFilters(),

                            // Products Section
                            _buildProductsSection(),
                          ] else ...[
                            // Show sorted/filtered products (API-based filters)
                            _buildSortedProductsSection(),
                          ],
                        ] else ...[
                          // Favorites-only view
                          _buildFavoritesOnlySection(),
                        ],

                        SizedBox(height: 100), // Bottom padding
                      ],
                    ),
                  ),
                )
              : ShopScreenSkeleton(),
        ),
      ),
    );
  }

  Future<void> _handleSliderTap(Map slider) async {
    if (_isUserLoggedIn()) {
      var gotoUrl = slider['goto'];
      var gotoPlatformId = slider['goto_platform_id'];
      var gotoPlatformType = slider['goto_platform_type'];

      if (gotoPlatformType == 'App\\Product') {
        Navigator.of(context).pushNamed(
          SingleProductScreen.routeName,
          arguments: gotoPlatformId,
        );
      } else if (gotoPlatformType == 'App\\Episode') {
        Navigator.of(context).pushNamed(
          VideoScreen.routeName,
          arguments: gotoPlatformId,
        );
      } else if (gotoPlatformType == 'App\\Subscription') {
        Navigator.pushNamed(context, SubscriptionScreen.routeName);
      } else {
        if (gotoUrl != null && gotoUrl.isNotEmpty) {
          final Uri _url = Uri.parse(gotoUrl);
          if (!await launchUrl(_url)) {
            throw Exception('Could not launch $_url');
          }
        } else {
          throw ("No valid URL available");
        }
      }
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${context.l10n.loginButton} ${context.l10n.required}'),
          content: Text('You need to login to continue.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushReplacementNamed('/login');
              },
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  List<Map<String, dynamic>> filteredProducts({
    String? selectedCategory,
    List<String>? selectedBrands,
    int? minPrice,
    int? maxPrice,
  }) {
    List<Map<String, dynamic>> filteredList = [];

    // Iterate over products.values
    for (var valueList in products.values) {
      // Check if the valueList is a list of dynamic objects
      if (valueList is List<dynamic>) {
        // Iterate over each element in the list
        for (var product in valueList) {
          // Check if each product is a Map<String, dynamic>
          if (product is Map<String, dynamic>) {
            // Apply filtering logic
            bool meetsCriteria = true;

            // Category filter - only apply if category is selected and not empty
            if (selectedCategory != null && selectedCategory.isNotEmpty) {
              var productCategories = product['categories'];
              if (productCategories is List) {
                var foundCategory = false;
                for (var category in productCategories) {
                  if (category is Map<String, dynamic> &&
                      category.containsKey('title')) {
                    if (category['title'] == selectedCategory) {
                      foundCategory = true;
                      break;
                    }
                  }
                }
                if (!foundCategory) {
                  meetsCriteria = false;
                }
              } else {
                meetsCriteria = false;
              }
            }

            // Brand filter - only apply if brands are selected
            if (selectedBrands != null && selectedBrands.isNotEmpty) {
              var productBrand = product['brand'];
              if (productBrand != null &&
                  productBrand is Map<String, dynamic> &&
                  productBrand.containsKey('title')) {
                var brandTitle = productBrand['title'];
                if (!selectedBrands.contains(brandTitle)) {
                  meetsCriteria = false;
                }
              } else {
                meetsCriteria = false;
              }
            }

            // Price filter - only apply if min/max prices are set
            if (minPrice != null && product['price'] != null) {
              if ((product['price'] as num) < minPrice) {
                meetsCriteria = false;
              }
            }
            if (maxPrice != null && product['price'] != null) {
              if ((product['price'] as num) > maxPrice) {
                meetsCriteria = false;
              }
            }

            // If the product meets all criteria, add it to the filteredList
            if (meetsCriteria) {
              filteredList.add(product);
            }
          }
        }
      }
    }

    return filteredList;
  }

  Future<dynamic> productFilterModal(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) => Container(
            height: MediaQuery.of(context).size.height * 0.8,
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
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Container(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade400,
                              Colors.purple.shade400
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filter Products',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Refine your search results',
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
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFilterSection(
                          title: 'Price Range',
                          icon: Icons.monetization_on_rounded,
                          child: _buildPriceRangeInput(),
                        ),
                        SizedBox(height: 20),
                        _buildFilterSection(
                          title: 'Categories',
                          icon: Icons.category_rounded,
                          child: _buildCategorySelect(setState),
                        ),
                        SizedBox(height: 20),
                        _buildFilterSection(
                          title: 'Brands',
                          icon: Icons.business_rounded,
                          child: _buildBrandSelect(setState),
                        ),
                        SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
                // Action buttons
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (filtered.isNotEmpty)
                        Expanded(
                          child: Container(
                            margin: EdgeInsets.only(right: 12),
                            child: ElevatedButton(
                              onPressed: () => clearFilters(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.red.withValues(alpha: 0.1),
                                foregroundColor: Colors.red,
                                elevation: 0,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: Colors.red.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.clear_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Clear',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        flex: filtered.isNotEmpty ? 1 : 2,
                        child: ElevatedButton(
                          onPressed: () => applyFilter(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_rounded, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Apply Filters',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
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

  void applyFilter(BuildContext context) {
    Navigator.pop(context);
    List<Map<String, dynamic>> filteredProds = filteredProducts(
      selectedCategory: selectedCategory.isNotEmpty ? selectedCategory : null,
      selectedBrands: selectedBrands.isNotEmpty ? selectedBrands : null,
      minPrice: _minPriceController.text.isNotEmpty
          ? int.tryParse(_minPriceController.text)
          : null,
      maxPrice: _maxPriceController.text.isNotEmpty
          ? int.tryParse(_maxPriceController.text)
          : null,
    );
    setState(() {
      filtered = filteredProds;
    });
  }

  void clearFilters() {
    setState(() {
      selectedCategory = '';
      selectedBrands.clear();
      _minPriceController.clear();
      _maxPriceController.clear();
      filtered.clear();
      _selectedFilter = null;
    });
  }

  void _applyFavoritesFilter() {
    final favorites = Provider.of<Favorites>(context, listen: false);
    final favoriteIds = favorites.favoriteProductIds;

    List<Map<String, dynamic>> favoriteProducts = [];

    // Iterate over products.values
    for (var valueList in products.values) {
      // Check if the valueList is a list of dynamic objects
      if (valueList is List<dynamic>) {
        // Iterate over each element in the list
        for (var product in valueList) {
          // Check if each product is a Map<String, dynamic>
          if (product is Map<String, dynamic>) {
            // Check if product ID is in favorites
            if (favoriteIds.contains(product['id'].toString())) {
              favoriteProducts.add(product);
            }
          }
        }
      }
    }

    setState(() {
      filtered = favoriteProducts;
    });
  }

  Widget _buildPriceRangeInput() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            decoration: InputDecoration(
              labelText: 'Min Price',
              hintText: 'Enter min price',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            controller: _minPriceController,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            decoration: InputDecoration(
              labelText: 'Max Price',
              hintText: 'Enter max price',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            controller: _maxPriceController,
          ),
        ),
      ],
    );
  }

  Widget _buildBrandSelect(setState) {
    List<String> brands = [];

    products.forEach((key, valueList) {
      if (valueList is List && valueList.isNotEmpty) {
        for (var value in valueList) {
          if (value is Map<String, dynamic>) {
            var brand = value['brand'];
            if (brand is Map<String, dynamic> && brand.containsKey('title')) {
              String brandTitle = brand['title'];
              if (!brands.contains(brandTitle)) {
                brands.add(brandTitle);
              }
            }
          }
        }
      }
    });

    if (brands.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Text(
          'No brands available',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    // Build checkboxes for each brand
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: brands.map((String brand) {
        bool isSelected = selectedBrands.contains(brand);

        return CheckboxListTile(
          title: Text(brand),
          value: isSelected,
          onChanged: (bool? value) {
            setState(() {
              if (value == true) {
                selectedBrands.add(brand);
              } else {
                selectedBrands.remove(brand);
              }
            });
          },
          checkColor: Colors.black,
          activeColor: Colors.amber,
        );
      }).toList(),
    );
  }

  Widget _buildCategorySelect(setState) {
    Set<String> categories = Set();
    products.forEach((key, valueList) {
      if (valueList is List && valueList.isNotEmpty) {
        var value = valueList.first;
        if (value is Map<String, dynamic>) {
          var productCategories = value['categories'];
          if (productCategories is List) {
            for (var category in productCategories) {
              if (category is Map<String, dynamic> &&
                  category.containsKey('title')) {
                categories.add(category['title']);
              }
            }
          }
        }
      }
    });

    if (categories.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Text(
          'No categories available',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return DropdownButton<String>(
      value: selectedCategory.isNotEmpty ? selectedCategory : null,
      items: categories.map((String category) {
        return DropdownMenuItem<String>(
          value: category,
          child: Text(category),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          selectedCategory = newValue ?? '';
        });
      },
      hint: Text('Select a category'),
      isExpanded: true,
    );
  }

  Widget _buildHeroBanner() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.all(16),
      height: 200,
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.15),
            blurRadius: 20,
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
      child: Container(
        padding: EdgeInsets.all(4),
        child: _productSliders.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ImageSlideshow(
                  initialPage: 0,
                  indicatorColor: Colors.amber,
                  indicatorBackgroundColor: Colors.grey.withValues(alpha: 0.3),
                  children: [
                    for (Map slider in _productSliders)
                      InkWell(
                        onTap: () => _handleSliderTap(slider),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: CachedNetworkImage(
                            imageUrl: slider['images'] != null &&
                                    slider['images'].isNotEmpty &&
                                    slider['images'][0] != null
                                ? slider['images'][0]['url']
                                : '',
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[300],
                              child: Icon(Icons.error),
                            ),
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          ),
                        ),
                      ),
                  ],
                  onPageChanged: (value) {},
                  autoPlayInterval: 5000,
                  isLoop: true,
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.withValues(alpha: 0.1),
                      Colors.orange.withValues(alpha: 0.1),
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_bag_rounded,
                        color: Colors.amber,
                        size: 48,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Featured Products',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Discover amazing deals and offers',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title, Search Bar, Cart Icon
          Row(
            children: [
              // "All Vendors" Title
              Expanded(
                flex: 2,
                child: Text(
                  'All Vendors',
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
              SizedBox(width: 12),

              // Search Bar
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      SearchProductScreen.routeName,
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[900]
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Search',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),

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
                            Icons.shopping_cart,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                            size: 30,
                          ),
                          if (cart.itemCount > 0)
                            Positioned(
                              right: 0,
                              top: -2,
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

          SizedBox(height: 16),

          // Filter Buttons Row
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              children: [
                _buildFilterButton(
                  icon: Icons.favorite_border,
                  label: 'Favorites',
                  filterKey: 'top_favorites',
                ),
                SizedBox(width: 12),
                _buildFilterButton(
                  icon: Icons.access_time,
                  label: 'Latest',
                  filterKey: 'latest',
                ),
                SizedBox(width: 12),
                _buildFilterButton(
                  icon: Icons.verified_user,
                  label: 'Creators Product',
                  filterKey: 'creators_product',
                ),
                SizedBox(width: 12),
                _buildFilterButton(
                  icon: Icons.star_border,
                  label: 'High Rewarding',
                  filterKey: 'high_rewarding',
                ),
                SizedBox(width: 12),
                _buildFilterButton(
                  icon: Icons.tune_rounded,
                  label: 'More Filters',
                  filterKey: 'more_filters',
                  isSpecial: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton({
    required IconData icon,
    required String label,
    required String filterKey,
    bool isSpecial = false,
  }) {
    final isSelected = _selectedFilter == filterKey;

    return InkWell(
      onTap: () {
        if (isSpecial) {
          _showFilterModal();
          return;
        }
        setState(() {
          if (_selectedFilter == filterKey) {
            _selectedFilter = null; // Deselect if already selected
            filtered.clear(); // Clear filtered products when deselecting
          } else {
            _selectedFilter = filterKey;
            if (filterKey == 'top_favorites') {
              _applyFavoritesFilter();
            } else {
              // Fetch filtered products from API
              _fetchFilteredProducts(filterKey);
            }
          }
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.grey[300])
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.grey[400]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilters() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
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
            offset: Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_list_rounded,
            color: Colors.orange,
            size: 20,
          ),
          SizedBox(width: 8),
          Text(
            'Filters Applied (${filtered.length} results)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.grey[800],
            ),
          ),
          Spacer(),
          TextButton(
            onPressed: () => clearFilters(),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              backgroundColor: Colors.red.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Colors.red.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            child: Text(
              'Clear',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Favorites-only section when Top Favorites filter is active
  Widget _buildFavoritesOnlySection() {
    final favorites = Provider.of<Favorites>(context, listen: false);
    if (filtered.isEmpty && favorites.favoriteCount == 0) {
      return Container(
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.all(24),
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
              offset: Offset(0, 6),
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
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No favorites yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Like products to see them here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    // Show favorites header message + flat grid of liked products
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: EdgeInsets.all(16),
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
                offset: Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.favorite,
                  color: Colors.red,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Favorite Products',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'These are the products you liked',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 6.0,
              childAspectRatio: 0.65,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final product = filtered[index];
              return ProductItem(product);
            },
          ),
        ),
      ],
    );
  }

  // Section for sorted/filtered products (from API) - displayed in flat grid like favorites
  Widget _buildSortedProductsSection() {
    final filterLabel = {
          'latest': 'Latest Products',
          'creators_product': 'Creator\'s Products',
          'high_rewarding': 'High Rewarding Products',
        }[_selectedFilter] ??
        'Filtered Products';

    final filterEmoji = {
          'latest': '🆕',
          'creators_product': '👤',
          'high_rewarding': '⭐',
        }[_selectedFilter] ??
        '🔍';

    return Column(
      children: [
        // Header Card
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.15),
                blurRadius: 10,
                spreadRadius: 0,
                offset: Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  filterEmoji,
                  style: TextStyle(fontSize: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        filterLabel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _isFilterLoading
                            ? 'Loading products...'
                            : '${filtered.length} product${filtered.length != 1 ? 's' : ''} found',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Empty State
        if (filtered.isEmpty && !_isFilterLoading)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Text(
                  '😔',
                  style: TextStyle(fontSize: 48),
                ),
                SizedBox(height: 12),
                Text(
                  'No products found',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Try a different filter',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

        // Loading State
        if (_isFilterLoading)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: CircularProgressIndicator(
              color: Colors.red.shade400,
            ),
          ),

        // Products Grid
        if (filtered.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 12),
            child: GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 6.0,
                childAspectRatio: 0.65,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final product = filtered[index];
                return ProductItem(product);
              },
            ),
          ),
      ],
    );
  }

  // Products section: list of vendor cards (each vendor in its own box)
  Widget _buildProductsSection() {
    final vendorSections = filtered.isNotEmpty
        ? _buildFilteredVendorSections()
        : _buildAllVendorSections();

    return Column(
      children: vendorSections,
    );
  }

// Method to build all vendor sections
  List<Widget> _buildAllVendorSections() {
    return productKeys.map((key) {
      final vendorProducts = products[key] as List;
      return _buildVendorSection(vendorProducts);
    }).toList();
  }

// Method to build filtered vendor sections
  List<Widget> _buildFilteredVendorSections() {
    Map<String, List<Map<String, dynamic>>> vendorGroups = {};

    for (var product in filtered) {
      final vendorName = product['user']['username'];
      if (!vendorGroups.containsKey(vendorName)) {
        vendorGroups[vendorName] = [];
      }
      vendorGroups[vendorName]!.add(product);
    }

    return vendorGroups.entries.map((entry) {
      return _buildVendorSection(entry.value);
    }).toList();
  }

  Widget _vendorInitialAvatar(BuildContext context, String vendorName) {
    final letter =
        vendorName.isNotEmpty ? vendorName.substring(0, 1).toUpperCase() : 'V';
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[700]!
              : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
          ),
        ),
      ),
    );
  }

// Individual vendor section - rendered as its own card
  Widget _buildVendorSection(List<dynamic> vendorProducts) {
    if (vendorProducts.isEmpty) return SizedBox.shrink();

    final vendor = vendorProducts.first['user'];
    final vendorName = vendor['username']?.toString() ?? 'Vendor';
    final vendorBio =
        vendor['bio']?.toString() ?? 'Discover products from ${vendorName}';
    final displayName =
        (vendor['name'] ?? vendor['display_name'] ?? vendorName).toString();

    // Vendor-specific profile images
    String? profileImagePath;
    final nameLower = vendorName.toLowerCase().trim();
    final displayLower = displayName.toLowerCase().trim();
    if (nameLower == 'baakhapaa-admin') {
      profileImagePath = 'assets/images/logo-lony.png';
    } else if (nameLower.contains('sudip') ||
        displayLower.contains('sudip gurung')) {
      profileImagePath = 'assets/images/sudip.png';
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
            offset: Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            VendorProductScreen.routeName,
            arguments: vendorProducts,
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vendor Header - Simple row with logo, name, tagline, and chevron
              Row(
                children: [
                  // Vendor profile image (vendor-specific or initial fallback)
                  ClipOval(
                    child: profileImagePath != null
                        ? Image.asset(
                            profileImagePath,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _vendorInitialAvatar(context, vendorName),
                          )
                        : _vendorInitialAvatar(context, vendorName),
                  ),
                  SizedBox(width: 12),

                  // Vendor Name and Tagline
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vendorName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          vendorBio,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Chevron Icon
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[400],
                    size: 24,
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Products Horizontal List
              SizedBox(
                height: 310,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  itemCount: vendorProducts.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: ProductItem(vendorProducts[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterModal() {
    productFilterModal(context);
  }

  Widget _buildFilterSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: Colors.blue,
              ),
            ),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildForYouSection() {
    // Use for you products from API
    final items = Provider.of<Shop>(context).forYouProducts;
    if (items.isEmpty) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A), // Dark background
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with "For you" title and arrow
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Fire icon styled "F"
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'F',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                        color: Colors.orange,
                      ),
                    ),
                    TextSpan(
                      text: 'or you',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow button
              GestureDetector(
                onTap: () {
                  // Navigate to For You products screen with all products
                  final forYouProducts =
                      Provider.of<Shop>(context, listen: false).forYouProducts;
                  if (forYouProducts.isNotEmpty) {
                    Navigator.of(context).pushNamed(
                      ForYouProductsScreen.routeName,
                      arguments: forYouProducts,
                    );
                  }
                },
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          // Horizontal scrolling product cards
          SizedBox(
            height: 135,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              itemBuilder: (ctx, idx) {
                return _ForYouCard(product: items[idx]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Compact "For You" card style with dark theme and discount badge
class _ForYouCard extends StatelessWidget {
  final Map<String, dynamic> product;

  const _ForYouCard({required this.product});

  String _productTitle() => product['title']?.toString() ?? 'Product';

  String _productImage() {
    try {
      // Handle different image formats
      if (product['images'] != null && product['images'] is List) {
        final images = product['images'] as List;
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

          // If image is a string directly
          if (first is String && first.isNotEmpty) {
            return _getImageUrl(first);
          }
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
    var normalizedPath = imagePath.trim();
    normalizedPath = normalizedPath.replaceFirst(RegExp(r'^/+'), '');
    normalizedPath = normalizedPath.replaceFirst(
        RegExp(r'^(storage/storage/)+'), 'storage/');
    normalizedPath = normalizedPath.replaceFirst(RegExp(r'^storage/'), '');

    return 'https://app.baakhapaa.com/storage/$normalizedPath';
  }

  bool _hasDiscount() {
    // Check for discount from various possible fields
    final discount = product['discount'] ?? product['discount_percentage'];
    if (discount != null) {
      // Handle both numeric and string values
      if (discount is num && discount > 0) return true;
      if (discount is String) {
        final parsed = double.tryParse(discount);
        if (parsed != null && parsed > 0) return true;
      }
    }

    // Also check tag/badge for discount indication
    final tag = product['tag'] ?? product['badge'];
    if (tag != null) {
      final tagLower = tag.toString().toLowerCase();
      if (tagLower.contains('discount')) return true;
    }
    return false;
  }

  // Get background color based on product index
  Color _getBackgroundColor() {
    final colors = [
      Color(0xFFF5A623), // Orange
      Color(0xFF2D2D2D), // Dark gray
      Color(0xFF1E3A5F), // Dark blue
      Color(0xFF3D2314), // Brown
    ];
    return colors[_productTitle().hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(
          SingleProductScreen.routeName,
          arguments: product['id'],
        );
      },
      child: Container(
        width: 90,
        margin: EdgeInsets.only(right: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Image container with discount badge
            Stack(
              children: [
                // Product image
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: _getBackgroundColor(),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: _productImage(),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[800],
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.amber),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[800],
                        child: Center(
                          child: Icon(
                            Icons.shopping_bag_rounded,
                            size: 28,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            // Product title with badge aligned to the right
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _productTitle(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (_hasDiscount()) ...[
                  SizedBox(width: 4),
                  Image.asset(
                    'assets/images/dis2.png',
                    width: 16,
                    height: 16,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
