import 'dart:io';

import 'package:baakhapaa/helpers/helpers.dart';
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/screens/shop/search_product_screen.dart';
import 'package:baakhapaa/screens/story/video_screen.dart';
// ignore: unused_import
import 'package:baakhapaa/widgets/nav_bar.dart';
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
import '../../widgets/loading.dart';
import 'single_product_screen.dart';

class ShopScreen extends StatefulWidget {
  static const routeName = '/shop-screen';

  const ShopScreen({Key? key}) : super(key: key);

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
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
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
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
              ? SingleChildScrollView(
                  child: Container(
                    constraints: BoxConstraints(
                      minHeight: 900,
                      minWidth: 300,
                    ),
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
                              : Color.fromARGB(255, 188, 186, 186),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: <Widget>[
                        SizedBox(height: 10),
                        Column(
                          children: <Widget>[
                            Stack(
                                alignment: Alignment.topCenter,
                                clipBehavior: Clip.none,
                                children: [
                                  Column(
                                    children: [
                                      !_isLoading
                                          ? Container(height: 0)
                                          : _productSliders.isNotEmpty
                                              ? ImageSlideshow(
                                                  initialPage: 0,
                                                  indicatorColor:
                                                      Color.fromARGB(
                                                          255, 243, 187, 33),
                                                  indicatorBackgroundColor:
                                                      Colors.grey,
                                                  children: [
                                                    for (Map slider
                                                        in _productSliders)
                                                      InkWell(
                                                        onTap: () async {
                                                          _handleSliderTap(
                                                              slider);
                                                        },
                                                        child: AspectRatio(
                                                          aspectRatio: 16 / 9,
                                                          child:
                                                              CachedNetworkImage(
                                                            imageUrl: slider[
                                                                            'images'] !=
                                                                        null &&
                                                                    slider['images']
                                                                        .isNotEmpty &&
                                                                    slider['images']
                                                                            [
                                                                            0] !=
                                                                        null
                                                                ? slider[
                                                                        'images']
                                                                    [0]['url']
                                                                : '',
                                                            fit: BoxFit.contain,
                                                            errorWidget:
                                                                (context, url,
                                                                        error) =>
                                                                    Container(
                                                              color: Colors
                                                                  .grey[300],
                                                              child: Icon(
                                                                  Icons.error),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                  onPageChanged: (value) {},
                                                  autoPlayInterval: 5000,
                                                  isLoop: true,
                                                )
                                              : Container(
                                                  height: 200,
                                                  color: Colors.grey[300]),
                                      const SizedBox(height: 10),
                                      // Search and Filter Row
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              autofocus: false,
                                              readOnly: true,
                                              onTap: () {
                                                Navigator.of(context).pushNamed(
                                                  SearchProductScreen.routeName,
                                                );
                                              },
                                              decoration: InputDecoration(
                                                labelText: 'Search Products',
                                                labelStyle: TextStyle(
                                                  color: Theme.of(context)
                                                              .brightness ==
                                                          Brightness.dark
                                                      ? Colors.white
                                                      : Colors.black,
                                                ),
                                                prefixIcon: Padding(
                                                  padding:
                                                      const EdgeInsets.all(4.0),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context)
                                                                  .brightness ==
                                                              Brightness.dark
                                                          ? Colors.white
                                                          : Colors.grey,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                      border:
                                                          Border.all(width: 1),
                                                    ),
                                                    child: Icon(
                                                      Icons.search,
                                                      color: Theme.of(context)
                                                                  .brightness ==
                                                              Brightness.dark
                                                          ? Colors
                                                              .amber.shade500
                                                          : Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () {
                                              productFilterModal(context);
                                            },
                                            icon: Icon(Icons.tune),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        height: 1,
                                        child: Stack(
                                          alignment: Alignment.topCenter,
                                          clipBehavior: Clip.none,
                                          children: [
                                            Positioned(
                                              child: Container(
                                                margin: const EdgeInsets.only(
                                                    top: 5),
                                                decoration: BoxDecoration(
                                                  border: Border.all(width: 1),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  boxShadow:
                                                      kElevationToShadow[1],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ]),
                          ],
                        ),
                        SizedBox(height: 20),
                        filtered.isNotEmpty
                            ? Column(
                                children: <Widget>[
                                  TextButton(
                                    onPressed: () => clearFilters(),
                                    child: Text(
                                      'Clear Filters',
                                      style: TextStyle(
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                  Product(filtered),
                                ],
                              )
                            : Column(
                                children: productKeys
                                    .map(
                                        (key) => Product(products[key] as List))
                                    .toList(),
                              ),
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
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text('Price Range:'),
                  SizedBox(height: 10),
                  _buildPriceRangeInput(),
                  SizedBox(height: 16),
                  Text('Categories:'),
                  _buildCategorySelect(setState),
                  SizedBox(height: 16),
                  Text('Brands:'),
                  _buildBrandSelect(setState),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => applyFilter(context),
                    child: Text('Apply Filters'),
                  ),
                  filtered.isNotEmpty
                      ? ElevatedButton(
                          onPressed: () => clearFilters(),
                          child: Text('Clear Filters'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                        )
                      : Container(height: 0),
                ],
              ),
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
}
