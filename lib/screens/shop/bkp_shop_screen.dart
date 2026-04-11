import 'dart:io';

import 'package:baakhapaa/helpers/helpers.dart';
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/screens/shop/search_product_screen.dart';
import 'package:baakhapaa/screens/shop/vendor_product_screen.dart';
import 'package:baakhapaa/screens/story/video_screen.dart';
import 'package:baakhapaa/screens/subscription/subscription_screen.dart';
import 'package:baakhapaa/widgets/loading.dart';
import 'package:baakhapaa/widgets/refresh_indicator.dart';
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

  bool _isUserLoggedIn() {
    final authProvider = Provider.of<Auth>(context, listen: false);
    return authProvider.isAuth;
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
                        // Hero Banner Section
                        _buildHeroBanner(),

                        // Quick Actions Section
                        _buildQuickActions(),

                        // Active Filters Section
                        if (filtered.isNotEmpty) _buildActiveFilters(),

                        // Products Section
                        _buildProductsSection(),

                        SizedBox(height: 100), // Bottom padding
                      ],
                    ),
                  ),
                )
              : Loading(),
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
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Search Bar
          Container(
            padding: EdgeInsets.all(4),
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
            child: InkWell(
              onTap: () {
                Navigator.of(context).pushNamed(
                  SearchProductScreen.routeName,
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                ),
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
                        Icons.search_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        '${context.l10n.search} ${context.l10n.products}...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.shade400, Colors.teal.shade400],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () {
                          _showFilterModal();
                        },
                        child: Icon(
                          Icons.tune_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 12),
        ],
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

  // Fixed _buildProductsSection method for shop_screen.dart
  Widget _buildProductsSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Single Unified Card containing header and all vendor products
          Container(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main Header Section
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.purple.withValues(alpha: 0.1),
                        Colors.pink.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.purple.shade400,
                              Colors.pink.shade400
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.inventory_2_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${context.l10n.products} & ${context.l10n.store}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              context.l10n.browseByVendorsAndCollections,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // All Vendor Products Sections
                Column(
                  children: filtered.isNotEmpty
                      ? _buildFilteredVendorSections()
                      : _buildAllVendorSections(),
                ),
              ],
            ),
          ),
        ],
      ),
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

// Individual vendor section within the main card
  Widget _buildVendorSection(List<dynamic> vendorProducts) {
    if (vendorProducts.isEmpty) return SizedBox.shrink();

    final vendor = vendorProducts.first['user'];

    return Container(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vendor Header (Compact)
          Container(
            margin: EdgeInsets.symmetric(horizontal: 20),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.withValues(alpha: 0.08),
                  Colors.purple.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.blue.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Vendor Icon
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.purple.shade400],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.store_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                SizedBox(width: 12),

                // Vendor Info (Flexible to prevent overflow)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vendor['username'].toString().toUpperCase(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 12,
                            color: Colors.green,
                          ),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Verified • ${vendorProducts.length} items',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // View All Button (Compact)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade400, Colors.orange.shade400],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          VendorProductScreen.routeName,
                          arguments: vendorProducts,
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.l10n.viewAll,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 12),

          // Products Horizontal List
          Container(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: vendorProducts.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: EdgeInsets.only(right: 12),
                  child: ProductItem(vendorProducts[index]),
                );
              },
            ),
          ),

          // Divider between vendors (except last one)
          if (productKeys.isNotEmpty &&
              vendorProducts != (products[productKeys.last] as List) &&
              filtered.isEmpty)
            Container(
              margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.grey.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
        ],
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
}
