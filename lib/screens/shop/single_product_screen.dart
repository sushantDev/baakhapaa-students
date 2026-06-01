// ignore_for_file: unused_import

import 'dart:convert';

import 'package:baakhapaa/helpers/helpers.dart';
import 'package:baakhapaa/models/url.dart';
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/screens/gift/single_gift_screen.dart';
import 'package:baakhapaa/screens/others/challenge_request_screen.dart';
import 'package:baakhapaa/utils/guest_auth_helper.dart';
import 'package:baakhapaa/widgets/popup.dart';
import 'package:baakhapaa/widgets/rating_sheet.dart';
import 'package:baakhapaa/widgets/rating_summary.dart';
// import 'package:baakhapaa/widgets/subscriptionBanner.dart';
import 'package:baakhapaa/services/rating_service.dart';
import 'package:baakhapaa/models/rating_model.dart';
import 'package:baakhapaa/providers/currency_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:provider/provider.dart';
import '../../widgets/skeleton_loading.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/shop.dart';
import '../../providers/cart.dart';
import '../../providers/favorites.dart';
import '../../widgets/header.dart';
import '../../widgets/share_with_qr_modal.dart';
import '../../widgets/footer.dart';
import '../../widgets/product.dart';
import 'package:share_plus/share_plus.dart';
import '../../utils/puppet_screen_mapping.dart';
import '../../../utils/debug_logger.dart';

class SingleProductScreen extends StatefulWidget {
  static const routeName = '/single-product-screen';

  const SingleProductScreen({Key? key}) : super(key: key);

  @override
  State<SingleProductScreen> createState() => _SingleProductScreenState();
}

class _SingleProductScreenState extends State<SingleProductScreen>
    with PuppetInteractionMixin {
  var _isInit = true;
  var _isLoading = true;
  late int _navArgs;
  late int singleProductImageCount;
  final Uri _url = Uri.parse('https://creators.baakhapaa.com');
  Map<String, dynamic> product = {};
  late int _selectedAchievementId = 0;
  late double _selectedAchievementDiscountPercentage = 0.0;
  int _selectedTab = 0; // 0: Description, 1: Specification, 2: Reviews
  String? _selectedColor;
  String? _selectedSize;
  String? _selectedCompatibility;
  int? _selectedVariantId;
  int? _affiliateId;
  final double _actionBarHeight = 76;

  @override
  void didChangeDependencies() {
    if (_isInit) {
      // Safely handle arguments that might be either int or String
      final arguments = ModalRoute.of(context)!.settings.arguments;
      if (arguments is int) {
        _navArgs = arguments;
      } else if (arguments is String) {
        _navArgs = int.tryParse(arguments) ?? 0;
      } else if (arguments is Map) {
        _navArgs = int.tryParse(arguments['id'].toString()) ?? 0;
        if (arguments['affiliateId'] != null) {
          _affiliateId = int.tryParse(arguments['affiliateId'].toString());
        }
      } else {
        _navArgs = 0; // Default fallback
      }

      DebugLogger.info('_navArgs = $_navArgs');
      DebugLogger.info(
          'DEBUG: SingleProductScreen _affiliateId = $_affiliateId');
    }

    // Call super first so mixin initializes its provider reference
    super.didChangeDependencies();

    if (_isInit) {
      // Set puppet context AFTER mixin has initialized, using post-frame callback
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          DebugLogger.info(
              '🎭 🎭 SCREEN: Setting puppet context for product $_navArgs');
          setPuppetProductContext(_navArgs);
        }
      });

      var shopProvider = Provider.of<Shop>(context, listen: false);
      shopProvider.getSingleProduct(_navArgs).then((_) {
        setState(() {
          product = shopProvider.singleProduct;
          if (product['type'] == 'gift') {
            Navigator.of(context).pop();
            Navigator.of(context).pushNamed(
              SingleGiftScreen.routeName,
              arguments: product['id'],
            );
          }
          singleProductImageCount = shopProvider.singleProductImageCount;

          // Auto-select first variant if available
          if (product['variants'] != null && product['variants'] is List) {
            final variants = product['variants'] as List;
            if (variants.isNotEmpty) {
              // Find first variant with an image
              Map<String, dynamic>? firstVariantWithImage;
              for (var variant in variants) {
                if (variant is Map &&
                    variant['image'] != null &&
                    variant['image'].toString().isNotEmpty) {
                  firstVariantWithImage = Map<String, dynamic>.from(variant);
                  break;
                }
              }

              // If no variant with image, use first variant
              final firstVariant = firstVariantWithImage ??
                  (variants.first is Map
                      ? Map<String, dynamic>.from(variants.first as Map)
                      : null);

              if (firstVariant != null && firstVariant['id'] != null) {
                // Extract color and size from first variant
                if (firstVariant['option_values'] != null &&
                    firstVariant['option_values'] is List) {
                  final optionValues = firstVariant['option_values'] as List;
                  String? firstColor;
                  String? firstSize;

                  for (var optionValue in optionValues) {
                    if (optionValue is Map &&
                        optionValue['option'] != null &&
                        optionValue['option'] is Map) {
                      final option = optionValue['option'] as Map;
                      final optionName =
                          option['name']?.toString().toLowerCase() ?? '';
                      final optionValueStr =
                          optionValue['value']?.toString() ?? '';
                      if (optionName == 'color' &&
                          firstColor == null &&
                          optionValueStr.isNotEmpty) {
                        firstColor = optionValueStr;
                      }
                      if (optionName == 'size' &&
                          firstSize == null &&
                          optionValueStr.isNotEmpty) {
                        firstSize = optionValueStr;
                      }
                    }
                  }

                  // Set selected color and size
                  if (firstColor != null) {
                    _selectedColor = firstColor;
                  }
                  if (firstSize != null) {
                    _selectedSize = firstSize;
                  }

                  // Set selected variant ID
                  _selectedVariantId = firstVariant['id'] is int
                      ? firstVariant['id'] as int
                      : int.tryParse(firstVariant['id'].toString());
                }
              }
            }
          }

          _isLoading = false;
        });
      }).catchError((error) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load product: $error')),
        );
      });
      _isInit = false;
    }
  }

  Future<void> _launchUrl() async {
    if (!await launchUrl(_url)) {
      throw Exception('Could not launch $_url');
    }
  }

  String get productImageUrl {
    // First try to get image from selected variant
    final selectedVariant = _getSelectedVariant();
    if (selectedVariant != null && selectedVariant['image'] != null) {
      final image = selectedVariant['image'].toString();
      if (image.isNotEmpty) {
        return _getImageUrl(image);
      }
    }

    // If selected color but no image for that variant, try to get image for the color
    if (_selectedColor != null) {
      final colorImage = _getImageForColor(_selectedColor!);
      if (colorImage != null && colorImage.isNotEmpty) {
        return _getImageUrl(colorImage);
      }
    }

    // Fallback to main product images
    if (product['images'] != null && product['images'] is List) {
      final images = product['images'] as List;
      if (images.isNotEmpty) {
        final firstImage = images[0];
        if (firstImage is Map && firstImage['url'] != null) {
          return _getImageUrl(firstImage['url'].toString());
        }
      }
    }

    // Fallback to first variant image if available
    if (product['variants'] != null && product['variants'] is List) {
      final variants = product['variants'] as List;
      for (var variant in variants) {
        if (variant is Map && variant['image'] != null) {
          final image = variant['image'].toString();
          if (image.isNotEmpty) {
            return _getImageUrl(image);
          }
        }
      }
    }

    return 'https://baakhapaa.com/images/logo.png';
  }

  // Helper method to construct proper image URL from API response
  String _getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return '';
    }

    // Fix double URL: backend sometimes returns "https://app.baakhapaa.com/storage/https://cdn..."
    // Strip everything up to and including "/storage/" when the remainder is itself a full URL.
    final storageIdx = imagePath.indexOf('/storage/http');
    if (storageIdx != -1) {
      return imagePath.substring(storageIdx + '/storage/'.length);
    }

    final trimmedPath = imagePath.trim();

    // If it already starts with http, return as-is
    if (trimmedPath.startsWith('http')) {
      return trimmedPath;
    }

    var normalizedPath = trimmedPath.replaceFirst(RegExp(r'^/+'), '');
    normalizedPath = normalizedPath.replaceFirst(
        RegExp(r'^(storage/storage/)+'), 'storage/');
    normalizedPath = normalizedPath.replaceFirst(RegExp(r'^storage/'), '');

    if (normalizedPath.startsWith('http')) {
      return normalizedPath;
    }

    if (normalizedPath.isEmpty) {
      return imagePath;
    }

    // Prepend the CDN base URL for relative paths
    return '${Url.mediaUrl}/$normalizedPath';
  }

  // Build specification images widget
  List<Widget> _buildSpecificationImages(List<dynamic> images) {
    if (images.isEmpty) {
      return [];
    }

    return [
      SizedBox(height: 20),
      Text(
        'Color Specifications',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black87,
        ),
      ),
      SizedBox(height: 12),
      GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        itemCount: images.length,
        itemBuilder: (context, index) {
          final imageData = images[index];

          // Handle different image data formats
          String? imagePath;
          String? imageTitle;

          if (imageData is Map) {
            // If it's a map, try to get the image URL
            imagePath = imageData['image']?.toString() ??
                imageData['url']?.toString() ??
                imageData['path']?.toString() ??
                imageData['full']?.toString();
            imageTitle = imageData['title']?.toString() ??
                imageData['name']?.toString() ??
                'Specification ${index + 1}';
          } else if (imageData is String) {
            // If it's a string, use it as the URL
            imagePath = imageData;
            imageTitle = 'Specification ${index + 1}';
          }

          // Construct full URL using helper
          final imageUrl = _getImageUrl(imagePath);

          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade200,
                    ),
                    child: imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey.shade300,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade300,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.image_not_supported, size: 32),
                                  SizedBox(height: 4),
                                  Text(
                                    'Image failed',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.grey.shade300,
                            child: Icon(Icons.image_not_supported, size: 32),
                          ),
                  ),
                ),
                if (imageTitle != null && imageTitle.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Text(
                    imageTitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ];
  }

  void _claimDiscount(int achievementId) {
    setState(() {
      if (product['discountable_on_achievements'] != null &&
          product['discountable_on_achievements'] is List) {
        final achievements = product['discountable_on_achievements'] as List;
        for (var achievement in achievements) {
          if (achievement is Map && achievement['id'] == achievementId) {
            achievement['discount_claimed'] = 1;
            break;
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<Cart>(context, listen: false);

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Color(0xFF1A1A1A)
          : Colors.grey.shade50,
      appBar: header(
          context: context,
          titleText: product['title']?.toString() ?? 'Product Details'),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStickyPurchaseBar(cart),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : product.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Product not found',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                )
              : Container(
                  child: SingleChildScrollView(
                    physics: BouncingScrollPhysics(),
                    child: Popup(
                      popupArr: (product['popups'] != null &&
                              product['popups'] is List)
                          ? product['popups'] as List
                          : <dynamic>[],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // SubscriptionBanner(
                          //   bannerType: 'png',
                          // ),
                          // Product Image Section
                          _buildProductImageSection(),

                          // Product Info Section with Share Button
                          _buildProductInfoSection(),

                          // Challenge Form Section (if applicable)
                          product['id'] == 234
                              ? _buildChallengeSection()
                              : SizedBox.shrink(),

                          // Description Section with Tabs
                          if (product['description'] != null)
                            _buildDescriptionSection(),

                          // Achievement Discount Section
                          _buildAchievementDiscountSection(),
                          SizedBox(height: _actionBarHeight + 16),
                        ],
                      ),
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
        child: ListSkeleton(itemCount: 5),
      ),
    );
  }

  Widget _buildProductImageSection() {
    return Container(
      margin: EdgeInsets.all(16),
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
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Builder(
              builder: (context) {
                // Get images from selected variant or main product images
                List<String> imageUrls = [];

                // If variant is selected, use variant image
                if (_selectedVariantId != null &&
                    product['variants'] != null &&
                    product['variants'] is List) {
                  final variants = product['variants'] as List;
                  try {
                    final selectedVariant = variants.firstWhere(
                      (v) =>
                          v is Map &&
                          v['id'] != null &&
                          v['id'] == _selectedVariantId,
                      orElse: () => null,
                    );
                    if (selectedVariant != null &&
                        selectedVariant is Map &&
                        selectedVariant['image'] != null) {
                      imageUrls.add(
                          _getImageUrl(selectedVariant['image'].toString()));
                    }
                  } catch (e) {
                    // Variant not found, continue
                  }
                }

                // Add main product images
                if (product['images'] != null && product['images'] is List) {
                  final images = product['images'] as List;
                  for (var image in images) {
                    if (image is Map && image['url'] != null) {
                      final imageUrl = _getImageUrl(image['url'].toString());
                      if (!imageUrls.contains(imageUrl)) {
                        imageUrls.add(imageUrl);
                      }
                    }
                  }
                }

                // If no images found, use default
                if (imageUrls.isEmpty) {
                  imageUrls.add('https://baakhapaa.com/images/logo.png');
                }

                if (imageUrls.length == 1) {
                  return Container(
                    height: 280,
                    width: double.infinity,
                    child: CachedNetworkImage(
                      imageUrl: imageUrls.first,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        height: 280,
                        width: double.infinity,
                        color: Colors.grey.shade300,
                        child: Icon(Icons.image_not_supported, size: 48),
                      ),
                    ),
                  );
                } else {
                  return Container(
                    height: 280,
                    child: ImageSlideshow(
                      key: ValueKey(_selectedVariantId ?? 'no_variant'),
                      initialPage: 0,
                      indicatorColor: Colors.blue.shade400,
                      indicatorBackgroundColor:
                          Colors.grey.withValues(alpha: 0.3),
                      children: imageUrls.map((imageUrl) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorWidget: (context, url, error) => Container(
                              height: 280,
                              width: double.infinity,
                              color: Colors.grey.shade300,
                              child: Icon(Icons.image_not_supported, size: 48),
                            ),
                          ),
                        );
                      }).toList(),
                      onPageChanged: (value) {},
                      autoPlayInterval: 5000,
                      isLoop: true,
                    ),
                  );
                }
              },
            ),
          ),
          // Favorite and Share Icons
          Positioned(
            top: 16,
            left: 16,
            child: Consumer<Favorites>(
              builder: (context, favorites, child) {
                final isFavorite =
                    favorites.isFavorite(product['id'].toString());
                return InkWell(
                  onTap: () {
                    favorites.toggleFavorite(product['id'].toString());
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isFavorite
                              ? 'Removed from favorites'
                              : 'Added to favorites',
                        ),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.white,
                      size: 20,
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: InkWell(
              onTap: () async {
                String bs64str1 =
                    base64Url.encode(utf8.encode(json.encode(product['id'])));
                final shareText =
                    'Baakhapaa Product ${Url.deepLink('/product/$bs64str1')}';

                await showModalBottomSheet(
                  context: context,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (BuildContext context) {
                    return _buildShareModal(context, shareText);
                  },
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.share,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductInfoSection() {
    var authProvider = Provider.of<Auth>(context, listen: false);
    // Get price from selected variant or main product
    double currentPrice = 0.0;

    final selectedVariant = _getSelectedVariant();
    if (selectedVariant != null && selectedVariant['price'] != null) {
      currentPrice =
          double.tryParse(selectedVariant['price'].toString()) ?? 0.0;
    }

    // Fallback to main product price
    if (currentPrice == 0.0 && product['price'] != null) {
      currentPrice = double.tryParse(product['price'].toString()) ?? 0.0;
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(20),
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
                : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 12,
            spreadRadius: 0,
            offset: Offset(0, 4),
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
          // Product Title
          Text(
            product['title']?.toString() ?? 'Product',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 12),
          // Price Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Rs: ${currentPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (currentPrice > 0)
                    Consumer<CurrencyProvider>(
                      builder: (_, currency, __) => Text(
                        '~${currency.formatNprAsUsd(currentPrice)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                ],
              ),
              // Rating and Reviews
              InkWell(
                onTap: () {
                  final authProvider =
                      Provider.of<Auth>(context, listen: false);
                  if (authProvider.isGuest) {
                    GuestAuthHelper.showGuestLoginDialog(context, 'CANT BUY');
                    return;
                  }
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => RatingSheet(
                        ratingType: RatingType.product,
                        currentUserId: authProvider.userId,
                        authToken: authProvider.token,
                        ratingId: product['id'],
                        ratingTitle: product['title']),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 18,
                        ),
                        SizedBox(width: 4),
                        RatingSummery(
                          starSize: 16,
                          ratingTo: RatingTo.product,
                          ratingId: product['id'],
                          authToken: authProvider.token,
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    FutureBuilder<RatingResponse>(
                      future: RatingService(authToken: authProvider.token)
                          .getProductRatings(product['id']),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return SizedBox.shrink();
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return SizedBox.shrink();
                        }
                        final reviewCount = snapshot.data!.stats.totalRatings;
                        return Text(
                          '($reviewCount ${reviewCount == 1 ? 'Review' : 'Reviews'})',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Product Attributes (Color, Size, Compatibility)
          _buildProductAttributesContent(),
          SizedBox(height: 16),
          // Point Reward, Achievement, and Stock Row (Horizontal)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Point Reward
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade400, Colors.orange.shade400],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/coins.png',
                        width: 14,
                        height: 14,
                        fit: BoxFit.contain,
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Point Reward',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.white.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                            ),
                            Text(
                              '${product['coin'] ?? 0} Bpts',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),
              // Achievement Badges
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.emoji_events,
                        size: 14,
                        color: Colors.blue,
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Achievement',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                            ),
                            Text(
                              '${product['discountable_on_achievements'] != null ? (product['discountable_on_achievements'] as List).length : 0} badges',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),
              // Stock Available
              Expanded(
                child: Builder(
                  builder: (context) {
                    // Get stock from selected variant or main product
                    int stock = 0;
                    final selectedVariant = _getSelectedVariant();
                    if (selectedVariant != null &&
                        selectedVariant['qty'] != null) {
                      stock =
                          int.tryParse(selectedVariant['qty'].toString()) ?? 0;
                    }

                    // Fallback to main product stock
                    if (stock == 0) {
                      stock = product['available_stock'] != null
                          ? int.tryParse(
                                  product['available_stock'].toString()) ??
                              0
                          : (product['qty'] != null
                              ? int.tryParse(product['qty'].toString()) ?? 0
                              : 0);
                    }

                    final stockColor = stock > 0 ? Colors.green : Colors.red;
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: stockColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: stockColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_rounded,
                            color: stockColor,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Stock Available',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                ),
                                Text(
                                  '$stock pieces',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: stockColor,
                                  ),
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to check if product is gadget category
  bool _isGadgetCategory() {
    if (product['categories'] != null && product['categories'] is List) {
      final categories = product['categories'] as List;
      for (var category in categories) {
        if (category is Map<String, dynamic>) {
          final title = category['title']?.toString().toLowerCase() ?? '';
          if (title.contains('gadget') ||
              title.contains('phone') ||
              title.contains('mobile') ||
              title.contains('accessory') ||
              title.contains('case') ||
              title.contains('protector')) {
            return true;
          }
        }
      }
    }
    return false;
  }

  // Helper method to check if product is Points category
  bool _isPointsCategory() {
    if (product['categories'] != null && product['categories'] is List) {
      final categories = product['categories'] as List;
      for (var category in categories) {
        if (category is Map<String, dynamic>) {
          final title = category['title']?.toString().toLowerCase() ?? '';
          if (title.contains('point') || title.contains('points')) {
            return true;
          }
        }
      }
    }
    return false;
  }

  // Helper method to check if product is Accessories category
  bool _isAccessoriesCategory() {
    if (product['categories'] != null && product['categories'] is List) {
      final categories = product['categories'] as List;
      for (var category in categories) {
        if (category is Map<String, dynamic>) {
          final title = category['title']?.toString().toLowerCase() ?? '';
          if (title.contains('accessory') || title.contains('accessories')) {
            return true;
          }
        }
      }
    }
    return false;
  }

  List<dynamic> _getSkeletonCompatibility() {
    return [
      'Google Pixel 6 Pro',
      'Google Pixel 7',
      'Google Pixel 7 Pro',
      'Google Pixel 6',
      'Google Pixel 6A',
      'Google Pixel 8 Pro',
      'Google Pixel 8',
      'Google Pixel 9 / Pro',
      'Google Pixel 9 Pro XL',
    ];
  }

  // Extract unique colors from variants with image fallback
  List<Map<String, dynamic>> _getUniqueColorsFromVariants() {
    if (product['variants'] == null || product['variants'] is! List) {
      return [];
    }

    final variants = product['variants'] as List;
    final colorMap = <String, Map<String, dynamic>>{};

    // First pass: collect all colors
    for (var variant in variants) {
      if (variant is Map &&
          variant['option_values'] != null &&
          variant['option_values'] is List) {
        final optionValues = variant['option_values'] as List;
        String? colorValue;
        for (var optionValue in optionValues) {
          if (optionValue is Map &&
              optionValue['option'] != null &&
              optionValue['option'] is Map) {
            final option = optionValue['option'] as Map;
            if (option['name']?.toString().toLowerCase() == 'color') {
              colorValue = optionValue['value']?.toString() ?? '';
              break;
            }
          }
        }

        if (colorValue != null && colorValue.isNotEmpty) {
          // If color not in map, add it
          if (!colorMap.containsKey(colorValue)) {
            colorMap[colorValue] = {
              'name': colorValue,
              'value': colorValue,
              'variant_id': variant['id'],
              'image': variant['image'],
            };
          } else {
            // If color exists but current variant has image and stored one doesn't, update it
            final storedImage = colorMap[colorValue]!['image']?.toString();
            final currentImage = variant['image']?.toString();
            if ((storedImage == null || storedImage.isEmpty) &&
                currentImage != null &&
                currentImage.isNotEmpty) {
              colorMap[colorValue] = {
                'name': colorValue,
                'value': colorValue,
                'variant_id': variant['id'],
                'image': variant['image'],
              };
            }
          }
        }
      }
    }

    return colorMap.values.toList();
  }

  // Get image for a specific color (with fallback to any variant with same color)
  String? _getImageForColor(String color) {
    if (product['variants'] == null || product['variants'] is! List) {
      return null;
    }

    final variants = product['variants'] as List;

    // First try to find a variant with this color that has an image
    for (var variant in variants) {
      if (variant is Map &&
          variant['option_values'] != null &&
          variant['option_values'] is List) {
        final optionValues = variant['option_values'] as List;
        bool hasColor = false;
        for (var optionValue in optionValues) {
          if (optionValue is Map &&
              optionValue['option'] != null &&
              optionValue['option'] is Map) {
            final option = optionValue['option'] as Map;
            if (option['name']?.toString().toLowerCase() == 'color' &&
                optionValue['value']?.toString() == color) {
              hasColor = true;
              break;
            }
          }
        }

        if (hasColor &&
            variant['image'] != null &&
            variant['image'].toString().isNotEmpty) {
          return variant['image'].toString();
        }
      }
    }

    return null;
  }

  // Get the selected variant based on color and size
  Map<String, dynamic>? _getSelectedVariant() {
    if (_selectedColor == null) {
      return null;
    }

    if (product['variants'] == null || product['variants'] is! List) {
      return null;
    }

    final variants = product['variants'] as List;

    for (var variant in variants) {
      if (variant is! Map ||
          variant['option_values'] == null ||
          variant['option_values'] is! List) {
        continue;
      }

      final optionValues = variant['option_values'] as List;
      bool matchesColor = false;
      // If no size is selected, skip size matching entirely
      bool matchesSize = _selectedSize == null;

      for (var optionValue in optionValues) {
        if (optionValue is Map &&
            optionValue['option'] != null &&
            optionValue['option'] is Map) {
          final option = optionValue['option'] as Map;
          final optionName = option['name']?.toString().toLowerCase() ?? '';
          final optionValueStr = optionValue['value']?.toString() ?? '';

          if (optionName == 'color' && optionValueStr == _selectedColor) {
            matchesColor = true;
          }
          if (optionName == 'size' && optionValueStr == _selectedSize) {
            matchesSize = true;
          }
        }
      }

      if (matchesColor && matchesSize) {
        return Map<String, dynamic>.from(variant);
      }
    }

    return null;
  }

  // Extract unique sizes from variants
  List<String> _getUniqueSizesFromVariants() {
    if (product['variants'] == null || product['variants'] is! List) {
      return [];
    }

    final variants = product['variants'] as List;
    final sizeSet = <String>{};

    for (var variant in variants) {
      if (variant is Map &&
          variant['option_values'] != null &&
          variant['option_values'] is List) {
        final optionValues = variant['option_values'] as List;
        for (var optionValue in optionValues) {
          if (optionValue is Map &&
              optionValue['option'] != null &&
              optionValue['option'] is Map) {
            final option = optionValue['option'] as Map;
            if (option['name']?.toString().toLowerCase() == 'size') {
              final sizeValue = optionValue['value']?.toString() ?? '';
              if (sizeValue.isNotEmpty) {
                sizeSet.add(sizeValue);
              }
            }
          }
        }
      }
    }

    return sizeSet.toList()..sort();
  }

  // Get variants filtered by color only
  List<dynamic> _getVariantsByColor(String? color) {
    if (product['variants'] == null || product['variants'] is! List) {
      return [];
    }

    if (color == null) {
      return product['variants'] as List;
    }

    final variants = product['variants'] as List;
    return variants.where((variant) {
      if (variant is! Map ||
          variant['option_values'] == null ||
          variant['option_values'] is! List) {
        return false;
      }

      final optionValues = variant['option_values'] as List;
      for (var optionValue in optionValues) {
        if (optionValue is Map &&
            optionValue['option'] != null &&
            optionValue['option'] is Map) {
          final option = optionValue['option'] as Map;
          if (option['name']?.toString().toLowerCase() == 'color' &&
              optionValue['value']?.toString() == color) {
            return true;
          }
        }
      }
      return false;
    }).toList();
  }

  // Get variants filtered by selected color and size

  Widget _buildProductAttributesContent() {
    final isGadget = _isGadgetCategory();
    final isPoints = _isPointsCategory();
    final isAccessories = _isAccessoriesCategory();

    // Don't show attributes for Points category
    if (isPoints) {
      return SizedBox.shrink();
    }

    // Get colors and sizes from variants
    final colors = _getUniqueColorsFromVariants();
    final sizes = _getUniqueSizesFromVariants();

    // Get compatibility (for gadgets)
    List<dynamic> compatibility = product['compatibility'] ??
        product['compatible_models'] ??
        product['compatibility_by_model'] ??
        [];

    // For gadget category: show compatibility
    if (isGadget && compatibility.isEmpty) {
      compatibility = _getSkeletonCompatibility();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Variant Images (Color Selection) - Show variant images instead of color swatches
        if (colors.isNotEmpty && !isGadget && !isAccessories) ...[
          Text(
            'Color: ${_selectedColor ?? "Please Select"}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
            ),
          ),
          SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: colors.map<Widget>((colorData) {
                final colorName = colorData['name']?.toString() ?? '';
                final isSelected = _selectedColor == colorName;

                // Get image for this color (with fallback)
                String? variantImage = colorData['image']?.toString();
                if (variantImage == null || variantImage.isEmpty) {
                  variantImage = _getImageForColor(colorName);
                }

                // Construct proper image URL
                final imageUrl = _getImageUrl(variantImage);

                return Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = colorName;
                        // Reset size so _getSelectedVariant() matches any variant
                        // with the new color (avoids cross-color size mismatch).
                        _selectedSize = null;
                        // Find the first variant for this color
                        final selectedVariant = _getSelectedVariant();
                        if (selectedVariant != null) {
                          _selectedVariantId = selectedVariant['id'] is int
                              ? selectedVariant['id'] as int
                              : int.tryParse(selectedVariant['id'].toString());
                          // Sync size from the matched variant for UI consistency
                          if (selectedVariant['option_values'] is List) {
                            for (var ov
                                in selectedVariant['option_values'] as List) {
                              if (ov is Map && ov['option'] is Map) {
                                if ((ov['option']['name'] as String?)
                                        ?.toLowerCase() ==
                                    'size') {
                                  _selectedSize = ov['value']?.toString();
                                  break;
                                }
                              }
                            }
                          }
                        }
                      });
                    },
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.amber
                              : Colors.grey.withValues(alpha: 0.3),
                          width: isSelected ? 3 : 2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.amber.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey.shade300,
                                  child:
                                      Icon(Icons.image_not_supported, size: 24),
                                ),
                              )
                            : Container(
                                color: Colors.grey.shade300,
                                child:
                                    Icon(Icons.image_not_supported, size: 24),
                              ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 24),
        ],

        // Size Selection (for clothing only, not gadgets or accessories)
        if (sizes.isNotEmpty && !isGadget && !isAccessories) ...[
          Text(
            'Size: ${_selectedSize ?? "Please Select"}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
            ),
          ),
          SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: sizes.map<Widget>((size) {
                final sizeName = size.toString();
                final isSelected = _selectedSize == sizeName;

                // Check if this size is available for selected color
                // Use variants filtered by color only (not by size)
                final variantsByColor = _getVariantsByColor(_selectedColor);
                final isAvailable = variantsByColor.any((v) {
                  if (v is! Map ||
                      v['option_values'] == null ||
                      v['option_values'] is! List) {
                    return false;
                  }
                  final optionValues = v['option_values'] as List;
                  return optionValues.any((ov) {
                    if (ov is! Map ||
                        ov['option'] == null ||
                        ov['option'] is! Map) {
                      return false;
                    }
                    final option = ov['option'] as Map;
                    return option['name']?.toString().toLowerCase() == 'size' &&
                        ov['value']?.toString() == sizeName;
                  });
                });

                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: isAvailable
                        ? () {
                            setState(() {
                              _selectedSize = sizeName;
                              // Update selected variant based on color and size
                              final selectedVariant = _getSelectedVariant();
                              if (selectedVariant != null) {
                                _selectedVariantId = selectedVariant['id'];
                              }
                            });
                          }
                        : null,
                    child: Opacity(
                      opacity: isAvailable ? 1.0 : 0.5,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.amber
                              : (Theme.of(context).brightness == Brightness.dark
                                  ? Color(0xFF2A2A2A)
                                  : Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? Colors.amber
                                : (Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey.withValues(alpha: 0.3)
                                    : Colors.grey.withValues(alpha: 0.5)),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          sizeName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : (Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black87),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 24),
        ],

        // Compatibility by Model (for gadgets)
        if (compatibility.isNotEmpty && isGadget) ...[
          Row(
            children: [
              Text(
                'Compatibility by model',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                ),
              ),
              if (_selectedCompatibility != null) ...[
                SizedBox(width: 8),
                Text(
                  _selectedCompatibility!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.amber,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: compatibility.map<Widget>((model) {
              final modelName = model is Map
                  ? (model['name'] ??
                      model['title'] ??
                      model['model'] ??
                      model.toString())
                  : model.toString();
              final isSelected = _selectedCompatibility == modelName;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCompatibility = modelName;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.transparent
                        : (Theme.of(context).brightness == Brightness.dark
                            ? Color(0xFF2A2A2A)
                            : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? Colors.amber
                          : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.withValues(alpha: 0.3)
                              : Colors.grey.withValues(alpha: 0.5)),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    modelName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? Colors.amber
                          : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildChallengeSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(20),
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
                : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 12,
            spreadRadius: 0,
            offset: Offset(0, 4),
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
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.pink.shade400],
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
                  Icons.emoji_events_rounded,
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
                      'CHALLENGE FORM',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Win from Rs.10,000 to iPhone 16".toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Container(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                setState(() {
                  _isLoading = true;
                });
                var authProvider = Provider.of<Auth>(context, listen: false);
                await authProvider.checkChallangeSubmission().then((_) {
                  String _checkScriptStatus = authProvider.checkScriptStatus;
                  if (_checkScriptStatus == 'NOT_ENROLLED') {
                    Navigator.pushNamed(
                        context, ChallengeRequestScreen.routeName);
                  } else if (_checkScriptStatus == 'PENDING') {
                    showScaffoldMessenger(
                        context, 'Your script is under review. Best of luck!');
                  } else if (_checkScriptStatus == 'REJECTED') {
                    var remarks = authProvider.checkScriptRemarks['remarks'];
                    var rejectionCount =
                        authProvider.checkScriptRemarks['rejection_count'];
                    var purchaseCount =
                        authProvider.checkScriptRemarks['purchase_count'];
                    if (purchaseCount > rejectionCount) {
                      Navigator.pushNamed(
                          context, ChallengeRequestScreen.routeName);
                    } else {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Rejection Status'),
                            content: Text(
                              'Rejected with remarks: $remarks.\n'
                              'You have been rejected $rejectionCount times.\n'
                              'You have purchased the ticket $purchaseCount times.\n'
                              'Please purchase the ticket again to proceed.\n'
                              'NOTE: TICKET MUST BE PURCHASED MORE THAN REJECTION COUNT',
                            ),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  Navigator.of(context).pushNamed(
                                    SingleProductScreen.routeName,
                                    arguments: 234,
                                  );
                                },
                                child: Text('Purchase Ticket Again'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: Text('Ok'),
                              ),
                            ],
                          );
                        },
                      );
                    }
                  } else {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('Approval Status'),
                          content: Text(
                            'Approved with remarks: ${authProvider.checkScriptRemarks['remarks']}. You can now start competing in challenges.',
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _launchUrl();
                              },
                              child: Text('Let\'s Compete'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text('Later'),
                            ),
                          ],
                        );
                      },
                    );
                  }
                  setState(() {
                    _isLoading = false;
                  });
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.pink.shade400],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Submit Entry',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
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
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 12,
            spreadRadius: 0,
            offset: Offset(0, 4),
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
          // Tabs
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                _buildTab('Description', 0),
                _buildTab('Specification', 1),
                _buildTab('Reviews', 2),
              ],
            ),
          ),
          Divider(height: 1),
          // Content
          Padding(
            padding: EdgeInsets.all(20),
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [Colors.amber.shade400, Colors.orange.shade400],
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[600]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0: // Description
        return Text(
          product['description']?.toString() ?? 'No description available.',
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
          ),
        );
      case 1: // Specification
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Specification Text
              if (product['specification'] != null &&
                  product['specification'].toString().isNotEmpty)
                Text(
                  product['specification']?.toString() ??
                      'No specification available.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),

              // Specification Images
              if (product['specification_images'] != null &&
                  product['specification_images'] is List)
                ..._buildSpecificationImages(
                    product['specification_images'] as List)
              else if (product['specification'] == null ||
                  product['specification'].toString().isEmpty)
                Text(
                  'No specification available.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
        );
      case 2: // Reviews
        return _buildReviewsContent();
      default:
        return SizedBox.shrink();
    }
  }

  Widget _buildReviewsContent() {
    var authProvider = Provider.of<Auth>(context, listen: false);

    // Get user avatar
    String getUserAvatar() {
      if (authProvider.image != null && authProvider.image!.isNotEmpty) {
        return authProvider.image!.first['thumbnail'] ??
            'https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg';
      }
      return 'https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg';
    }

    String formatTimeAgo(DateTime date) {
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}min ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}hr ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}day${difference.inDays > 1 ? 's' : ''} ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    }

    return _ReviewsContentWidget(
      productId: product['id'],
      productTitle: product['title']?.toString() ?? 'Product',
      getUserAvatar: getUserAvatar,
      formatTimeAgo: formatTimeAgo,
    );
  }

  Widget _buildAchievementDiscountSection() {
    if (product['discountable_on_achievements'] == null ||
        (product['discountable_on_achievements'] as List).isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(20),
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
                : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 12,
            spreadRadius: 0,
            offset: Offset(0, 4),
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
          // Header with Blue Tag Icon
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.local_offer_rounded,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Achievement Discount',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Use your achievements to earn discounts',
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
          SizedBox(height: 20),
          // Achievement List
          ...((product['discountable_on_achievements'] as List)
              .map<Widget>((achievement) {
            final isAvailable = achievement['unlocked'] == 1 &&
                achievement['discount_claimed'] == 0;
            final progress = achievement['progress'] != null
                ? double.tryParse(achievement['progress'].toString()) ?? 0.0
                : (achievement['unlocked'] == 1 ? 100.0 : 0.0);

            return InkWell(
              onTap: isAvailable
                  ? () {
                      setState(() {
                        _selectedAchievementId = achievement['id'];
                        _selectedAchievementDiscountPercentage =
                            double.tryParse(
                                    achievement['discount'].toString()) ??
                                0.0;
                      });
                    }
                  : null,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Color(0xFF1E1E1E)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isAvailable
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Radio Button (Green Circle)
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isAvailable ? Colors.green : Colors.grey,
                          width: 2,
                        ),
                        color: _selectedAchievementId == achievement['id']
                            ? Colors.green
                            : Colors.transparent,
                      ),
                      child: _selectedAchievementId == achievement['id']
                          ? Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            achievement['title'] ?? 'Achievement',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isAvailable
                                  ? (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black87)
                                  : Colors.grey,
                            ),
                          ),
                          if (!isAvailable &&
                              achievement['discount_claimed'] != 1)
                            Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 100,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: progress / 100,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '${progress.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (!isAvailable &&
                              achievement['discount_claimed'] == 1)
                            Text(
                              'Already claimed',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Discount Percentage Badge
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isAvailable ? Colors.green : Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${achievement['discount']}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList()),
          SizedBox(height: 12),
          // Warning Note
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Note: Once added to cart achievement discount expires.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickBuyPaymentDialog(BuildContext context, Auth auth) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => QuickBuyDialog(
        item: product,
        auth: auth,
        affiliateId: _affiliateId,
      ),
    );
  }

  Future<void> _handleAddToCart(
    Cart cart, {
    bool goToCart = false,
  }) async {
    // Get stock from selected variant or main product
    int productStock = 0;
    double productPrice = 0.0;

    if (_selectedVariantId != null &&
        product['variants'] != null &&
        product['variants'] is List) {
      final variants = product['variants'] as List;
      try {
        final selectedVariant = variants.firstWhere(
          (v) => v is Map && v['id'] != null && v['id'] == _selectedVariantId,
          orElse: () => null,
        );
        if (selectedVariant != null && selectedVariant is Map) {
          productStock = selectedVariant['qty'] != null
              ? int.tryParse(selectedVariant['qty'].toString()) ?? 0
              : 0;
          productPrice = selectedVariant['price'] != null
              ? double.tryParse(selectedVariant['price'].toString()) ?? 0.0
              : 0.0;
        }
      } catch (e) {
        // Variant not found, continue
      }
    }

    // Fallback to main product
    if (productStock == 0) {
      productStock = product['available_stock'] != null
          ? int.tryParse(product['available_stock'].toString()) ?? 0
          : (product['qty'] != null
              ? int.tryParse(product['qty'].toString()) ?? 0
              : 0);
    }
    if (productPrice == 0.0 && product['price'] != null) {
      productPrice = double.tryParse(product['price'].toString()) ?? 0.0;
    }

    final isOutOfStock = productStock <= 0;
    if (isOutOfStock) {
      showScaffoldMessenger(context, 'Product is out of stock.');
      return;
    }

    // Check if we can add more items to cart
    if (!cart.canAddMoreItems(product['id'].toString()) &&
        cart.items.containsKey(product['id'].toString())) {
      showScaffoldMessenger(context,
          'Cannot add more items. Only $productStock available in stock.');
      return;
    }

    // Apply achievement discount if selected
    if (product["discountable_on_achievements"] != null &&
        product["discountable_on_achievements"] is List &&
        (product["discountable_on_achievements"] as List).isNotEmpty &&
        _selectedAchievementId != 0) {
      productPrice = productPrice -
          ((_selectedAchievementDiscountPercentage / 100) * productPrice);
      var auth = Provider.of<Auth>(context, listen: false);
      await auth.claimAchievementDiscount(_selectedAchievementId).then((value) {
        showScaffoldMessenger(context, 'Discount applied to product\'s price.');
        _claimDiscount(_selectedAchievementId);
      });
    }

    // Build attributes map from selected color and size
    Map<String, String>? attributes;
    if (_selectedColor != null || _selectedSize != null) {
      attributes = {};
      if (_selectedColor != null) {
        attributes['Color'] = _selectedColor!;
      }
      if (_selectedSize != null) {
        attributes['Size'] = _selectedSize!;
      }
    }

    DebugLogger.info('DEBUG: Adding to cart with affiliateId: $_affiliateId');
    final productType = product['type']?.toString().toLowerCase() ?? '';
    final productTitle = product['title']?.toString().toLowerCase() ?? '';
    final isDigital = productType == 'digital' ||
        productType == 'coins' ||
        productTitle.contains('points');
    cart.addItem(
      product['id'].toString(),
      productPrice,
      product['title'].toString(),
      productImageUrl,
      productStock, // Pass the available stock
      attributes: attributes,
      affiliateId: _affiliateId,
      isDigital: isDigital,
    );

    showCartAddedDialog(
      context,
      cart,
      product['id'].toString(),
      product['title'].toString(),
      attributes: attributes,
    );

    if (goToCart) {
      Navigator.of(context).pushNamed('/cart');
    }
  }

  Widget _buildStickyPurchaseBar(Cart cart) {
    // Get stock from selected variant or main product
    int productStock = 0;

    final selectedVariant = _getSelectedVariant();
    if (selectedVariant != null && selectedVariant['qty'] != null) {
      productStock = int.tryParse(selectedVariant['qty'].toString()) ?? 0;
    }

    if (productStock == 0) {
      productStock = product['available_stock'] != null
          ? int.tryParse(product['available_stock'].toString()) ?? 0
          : (product['qty'] != null
              ? int.tryParse(product['qty'].toString()) ?? 0
              : 0);
    }
    final isOutOfStock = productStock <= 0;
    final auth = Provider.of<Auth>(context, listen: false);

    return SafeArea(
      top: false,
      child: Container(
        height: _actionBarHeight,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF151515)
              : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: isOutOfStock
                    ? null
                    : () {
                        if (auth.isGuest) {
                          GuestAuthHelper.showGuestLoginDialog(
                              context, 'CANT BUY');
                          return;
                        }
                        _showQuickBuyPaymentDialog(context, auth);
                      },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  isOutOfStock ? 'Out of Stock' : 'Buy Now',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: isOutOfStock
                    ? null
                    : () {
                        if (auth.isGuest) {
                          GuestAuthHelper.showGuestLoginDialog(
                              context, 'CANT BUY');
                          return;
                        }
                        _handleAddToCart(cart);
                      },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  isOutOfStock ? 'Out of Stock' : context.l10n.addToCart,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareModal(BuildContext context, String shareText) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF2A2A2A)
            : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.purple.shade400],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.share_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              SizedBox(width: 16),
              Text(
                'Share Product',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Consumer<Auth>(
            builder: (ctx, auth, _) => FutureBuilder(
              future: auth.fetchConversations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const GridSkeleton(crossAxisCount: 4, itemCount: 8);
                }
                final conversations = auth.conversations;
                return Container(
                  height: 200,
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: conversations.length,
                    itemBuilder: (ctx, index) {
                      final conversation = conversations[index];
                      final userImage = conversation['user_image'] ?? '';
                      final name = conversation['name'] ?? '';
                      final username = conversation['username'];

                      return GestureDetector(
                        onTap: () {
                          final authProvider =
                              Provider.of<Auth>(context, listen: false);
                          authProvider
                              .sendMessages(
                            conversation['conversation_id'],
                            shareText,
                            'text',
                            null,
                            null,
                          )
                              .then((_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Shared Successfully!')),
                            );
                            Navigator.pop(context);
                          }).catchError((error) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Failed to share. Please try again.')),
                            );
                          });
                        },
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundImage: userImage.isNotEmpty
                                  ? CachedNetworkImageProvider(userImage)
                                  : null,
                              child: userImage.isEmpty
                                  ? Text(name.isEmpty ? username[0] : name[0])
                                  : null,
                            ),
                            SizedBox(height: 4),
                            Text(
                              name.isEmpty ? username : name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 20),
          Divider(),
          SizedBox(height: 10),
          ListTile(
            leading: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.share,
                color: Colors.green,
                size: 20,
              ),
            ),
            title: Text('Share to Other Apps'),
            trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () {
              SharePlus.instance.share(
                ShareParams(
                  text: shareText,
                  subject: "Join Skill Sikka and earn points!",
                  sharePositionOrigin: Rect.fromLTWH(0, 0, 100, 100),
                ),
              );
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.qr_code),
            title: Text('Share using QR'),
            onTap: () {
              showModalBottomSheet(
                context: context,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) => ShareWithQrModal(
                  data: shareText,
                  subject: "Join Skill Sikka and earn points!",
                ),
              );
            },
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ReviewsContentWidget extends StatefulWidget {
  final int productId;
  final String productTitle;
  final String Function() getUserAvatar;
  final String Function(DateTime) formatTimeAgo;

  const _ReviewsContentWidget({
    required this.productId,
    required this.productTitle,
    required this.getUserAvatar,
    required this.formatTimeAgo,
  });

  @override
  State<_ReviewsContentWidget> createState() => _ReviewsContentWidgetState();
}

class _ReviewsContentWidgetState extends State<_ReviewsContentWidget> {
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;
  late Future<RatingResponse> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    var authProvider = Provider.of<Auth>(context, listen: false);
    _reviewsFuture = RatingService(authToken: authProvider.token)
        .getProductRatings(widget.productId);
  }

  Future<void> _submitReview() async {
    if (_reviewController.text.trim().isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      var authProvider = Provider.of<Auth>(context, listen: false);
      final ratingService = RatingService(authToken: authProvider.token);

      // Default to 5 stars if no rating dialog
      final ratingRequest = RatingRequest(
        stars: 5,
        description: _reviewController.text.trim(),
      );

      final success = await ratingService.postProductRating(
        widget.productId,
        ratingRequest,
      );

      if (success) {
        _reviewController.clear();

        // Add small delay to allow backend to process the review
        await Future.delayed(Duration(milliseconds: 500));

        // Refresh reviews after the delay
        if (mounted) {
          setState(() {
            _reviewsFuture = ratingService.getProductRatings(widget.productId);
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Review added successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add review')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var authProvider = Provider.of<Auth>(context, listen: false);

    return FutureBuilder<RatingResponse>(
      future: _reviewsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CommentsSkeleton(count: 3);
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Failed to load reviews',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
          );
        }

        final ratingResponse = snapshot.data;
        final reviews = ratingResponse?.ratings ?? [];
        final showAllReviews = reviews.length > 3;
        final displayedReviews =
            showAllReviews ? reviews.take(3).toList() : reviews;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add Review Input Section
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Color(0xFF1E1E1E)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage:
                        CachedNetworkImageProvider(widget.getUserAvatar()),
                    onBackgroundImageError: (_, __) {},
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _reviewController,
                      decoration: InputDecoration(
                        hintText: 'Add a review...',
                        hintStyle: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.blue.withValues(alpha: 0.5),
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Color(0xFF2A2A2A)
                                : Colors.white,
                        suffixIcon: _isSubmitting
                            ? Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: Icon(Icons.send),
                                onPressed: _submitReview,
                                color: Colors.blue,
                              ),
                      ),
                      maxLines: null,
                      style: TextStyle(fontSize: 14),
                      onSubmitted: (_) => _submitReview(),
                    ),
                  ),
                ],
              ),
            ),

            // Reviews List
            if (reviews.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No reviews yet',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              )
            else
              ...displayedReviews.map((rating) {
                return Container(
                  margin: EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Color(0xFF1E1E1E)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey.shade300,
                            ),
                            child: rating.user.image != null &&
                                    rating.user.image!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: rating.user.image!,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) =>
                                          Image.asset(
                                        'assets/images/logo-lony.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  )
                                : Image.asset(
                                    'assets/images/logo-lony.png',
                                    fit: BoxFit.contain,
                                  ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        rating.user.name.isNotEmpty
                                            ? rating.user.name
                                            : rating.user.username,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      widget.formatTimeAgo(rating.createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                if (rating.description.isNotEmpty)
                                  Text(
                                    rating.description,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.5,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),

            // Show All Reviews Button
            if (showAllReviews)
              Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: TextButton(
                    onPressed: () {
                      // Show all reviews - could open a modal or navigate
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => RatingSheet(
                          ratingType: RatingType.product,
                          currentUserId: authProvider.userId,
                          authToken: authProvider.token,
                          ratingId: widget.productId,
                          ratingTitle: widget.productTitle,
                        ),
                      );
                    },
                    child: Text(
                      'Show all reviews',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
