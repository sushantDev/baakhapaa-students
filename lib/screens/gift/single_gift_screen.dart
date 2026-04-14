import 'dart:convert';

import 'package:baakhapaa/screens/story/video_screen.dart';
import 'package:baakhapaa/widgets/popup.dart';
import 'package:baakhapaa/widgets/rating_sheet.dart';
import 'package:baakhapaa/widgets/rating_summary.dart';
import 'package:baakhapaa/widgets/subscriptionBanner.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter/material.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/shop.dart';
import '../../widgets/header.dart';
import '../../providers/auth.dart';
import '../../providers/orders.dart';
import '../../helpers/helpers.dart';
import '../../widgets/skeleton_loading.dart';
import '../user/achievements_screen.dart';
import '../../widgets/share_with_qr_modal.dart';
import '../../utils/guest_auth_helper.dart';
import '../../providers/puppet_interaction_provider.dart';
import '../../utils/puppet_screen_mapping.dart';
import '../../utils/debug_logger.dart';
import '../../services/rating_service.dart';

class SingleGiftScreen extends StatefulWidget {
  static const routeName = '/single-gift-screen';

  const SingleGiftScreen({Key? key}) : super(key: key);

  @override
  State<SingleGiftScreen> createState() => _SingleGiftScreenState();
}

class _SingleGiftScreenState extends State<SingleGiftScreen>
    with PuppetInteractionMixin {
  var _isInit = true;
  var _isLoading = true;
  late int navArgs;
  late Map<String, dynamic> gift = {};
  var _isRedeemable = false;
  int qty = 0;
  GlobalKey keyNavigation = GlobalKey();
  bool isGiftToFriend = false;
  TextEditingController _friendUsernameController = TextEditingController();
  int reviewCount = 0;

  // Cooldown variables
  late DateTime _lastRedeemed;
  late int _cooldownDuration = 0;


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
    // Clear puppet interactions when leaving screen
    clearPuppetInteractions();

    super.dispose();
    _friendUsernameController.dispose();
  }

  @override
  void didChangeDependencies() {
    if (_isInit) {
      // Check if user is guest
      final auth = Provider.of<Auth>(context, listen: false);
      if (auth.isGuest) {
        // If guest user, show login dialog and navigate back
        WidgetsBinding.instance.addPostFrameCallback((_) {
          GuestAuthHelper.showGuestLoginDialog(context, 'view gift details');
          Navigator.of(context).pop();
        });
        return;
      }

      // Safely handle arguments that might be either int or String
      final arguments = ModalRoute.of(context)!.settings.arguments;
      if (arguments is int) {
        navArgs = arguments;
      } else if (arguments is String) {
        navArgs = int.tryParse(arguments) ?? 0;
      } else {
        navArgs = 0; // Default fallback
      }

      // Initialize cooldown data
      _initializeCooldown();

      Provider.of<Shop>(context, listen: false)
          .getSingleProduct(navArgs)
          .then((_) {
        if (mounted) {
          setState(() {
            gift = Provider.of<Shop>(context, listen: false).singleProduct;
            qty = gift['qty'] as int;
            _isLoading = false;
          });

          // Fetch review count
          _fetchReviewCount();

          // Set puppet context AFTER mixin has initialized, using post-frame callback
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              DebugLogger.info(
                  '🎭 🎭 SCREEN: Setting puppet context for gift $navArgs');
              // Set puppet context for this specific gift
              setPuppetGiftContext(navArgs);
            }
          });
        }
      });
      Provider.of<Shop>(context, listen: false)
          .isProductRedeemable(navArgs)
          .then(
        ((_) {
          if (mounted) {
            setState(() {
              _isRedeemable =
                  Provider.of<Shop>(context, listen: false).isProdRedeemable;
            });
          }
        }),
      );
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  void _initializeCooldown() {
    final authProvider = Provider.of<Auth>(context, listen: false);

    // Parse last redeemed time with fallback
    String? redeemTime = authProvider.giftRedeemLastUsedTime;
    if (redeemTime != null && redeemTime.isNotEmpty) {
      try {
        _lastRedeemed = DateTime.parse(redeemTime);
      } catch (e) {
        _lastRedeemed = DateTime.now().subtract(Duration(days: 1));
      }
    } else {
      _lastRedeemed = DateTime.now().subtract(Duration(days: 1));
    }

    _cooldownDuration = authProvider.cooldownTime ?? 24;
  }

  // Check if cooldown is active
  bool get isCooldownActive {
    final currentTime = DateTime.now();
    final giftCooldown = _cooldownDuration * 60 * 60 * 1000;
    final remainingTime = Duration(milliseconds: giftCooldown) -
        currentTime.difference(_lastRedeemed);
    return remainingTime.inMilliseconds > 0;
  }

  // Get remaining cooldown time
  Duration get remainingCooldownTime {
    final currentTime = DateTime.now();
    final giftCooldown = _cooldownDuration * 60 * 60 * 1000;
    final remainingTime = Duration(milliseconds: giftCooldown) -
        currentTime.difference(_lastRedeemed);
    return remainingTime.inMilliseconds > 0 ? remainingTime : Duration.zero;
  }

  String get productImageUrl {
    final images = json.encode(gift['images']);
    return 'https://student.baakhapaa.com/storage/${json.decode(images)[0]['full']}';
  }

  // Helper function to parse boolean values from different data types
  bool _parseBoolValue(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == "1" || value.toLowerCase() == "true";
    return false;
  }

  // Check if all episodes are watched
  bool get areAllEpisodesWatched {
    if (gift['episodes'] == null || (gift['episodes'] as List).isEmpty) {
      return true; // No episodes required
    }
    return (gift['episodes'] as List)
        .every((episode) => _parseBoolValue(episode['watched']));
  }

  // Check if all achievements are unlocked
  bool get areAllAchievementsUnlocked {
    if (gift['achievements'] == null ||
        (gift['achievements'] as List).isEmpty) {
      return true; // No achievements required
    }
    return (gift['achievements'] as List)
        .every((achievement) => _parseBoolValue(achievement['unlocked']));
  }

  // Get button text based on validation state
  String get buttonText {
    if (qty <= 0) {
      return 'Out of Stock';
    }
    if (isCooldownActive) {
      final remaining = remainingCooldownTime;
      final hours = remaining.inHours;
      final minutes = remaining.inMinutes.remainder(60);
      return 'Wait ${hours}h ${minutes}m';
    }
    if (!areAllEpisodesWatched) {
      return 'Complete Episodes';
    }
    if (!areAllAchievementsUnlocked) {
      return 'Complete Achievements';
    }
    return isGiftToFriend ? 'Gift to Friend' : 'Redeem Gift';
  }

  Future<void> _fetchReviewCount() async {
    try {
      final auth = Provider.of<Auth>(context, listen: false);
      final ratingService = RatingService(authToken: auth.token);
      final response = await ratingService.getProductRatings(navArgs);

      if (mounted) {
        setState(() {
          reviewCount = response.stats.totalRatings;
        });
      }
    } catch (e) {
      DebugLogger.info('Error fetching review count: $e');
      // Keep reviewCount as 0 if fetch fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: header(context: context, titleText: gift['title'].toString()),
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
                child: Popup(
                  popupArr: (gift['popups'] as List?) ?? [],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Gift Image Section
                      SubscriptionBanner(
                        bannerType: 'png',
                      ),
                      _buildGiftImageSection(),

                      // Gift Info Section
                      _buildGiftInfoSection(),
                      if (gift['description'] != null)
                        _buildDescriptionSection(),
                      // Episodes Required Section
                      if (gift['episodes'] != null &&
                          (gift['episodes'] as List).isNotEmpty)
                        _buildEpisodesRequired(gift['episodes'] as List),

                      // Achievements Required Section
                      if (gift['achievements'] != null &&
                          (gift['achievements'] as List).isNotEmpty)
                        _buildAchievementsRequired(
                            gift['achievements'] as List),

                      // Cooldown Message
                      if (isCooldownActive) _buildCooldownMessage(),

                      // Redeem Section
                      _buildRedeemSection(),

                      SizedBox(height: 100), // Bottom padding
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
        padding: EdgeInsets.all(24.0),
        child: ListSkeleton(itemCount: 5),
      ),
    );
  }

  Widget _buildGiftImageSection() {
    final screenWidth = MediaQuery.of(context).size.width;
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
          Container(
            padding: EdgeInsets.all(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ImageSlideshow(
                  width: double.infinity,
                  height: screenWidth <= 380
                      ? (0.5 * MediaQuery.of(context).size.height)
                      : screenWidth <= 480
                          ? (0.4 * MediaQuery.of(context).size.height)
                          : screenWidth >= 600 && screenWidth < 1000
                              ? (0.35 * MediaQuery.of(context).size.height)
                              : (0.3 * MediaQuery.of(context).size.height),
                  initialPage: 0,
                  indicatorColor: Colors.purple,
                  indicatorBackgroundColor: Colors.grey.withValues(alpha: 0.3),
                  children: [
                    for (Map image in gift['images'])
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [
                              Colors.purple.withValues(alpha: 0.1),
                              Colors.pink.withValues(alpha: 0.1),
                            ],
                          ),
                        ),
                        child: CachedNetworkImage(
                          imageUrl:
                              'https://student.baakhapaa.com/storage/${image['full']}',
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.purple.withValues(alpha: 0.1),
                                  Colors.pink.withValues(alpha: 0.1),
                                ],
                              ),
                            ),
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.purple),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.purple.withValues(alpha: 0.1),
                                  Colors.pink.withValues(alpha: 0.1),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.card_giftcard_rounded,
                                size: 48,
                                color: Colors.purple,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                  onPageChanged: (value) {},
                  autoPlayInterval: 5000,
                  isLoop: true,
                ),
              ),
            ),
          ),
          // Share button in top-right corner
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              onPressed: () async {
                String bs64str1 =
                    base64Url.encode(utf8.encode(json.encode(gift['id'])));
                final shareText =
                    'Baakhapaa Gift https://baakhapaa.com/gift/$bs64str1';
                showModalBottomSheet(
                  context: context,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: Icon(Icons.share),
                        title: Text('Share to Other Apps'),
                        onTap: () {
                          SharePlus.instance.share(
                            ShareParams(
                              text: shareText,
                              subject: "Share Baakhapaa Gift!",
                              sharePositionOrigin:
                                  Rect.fromLTWH(0, 0, 100, 100),
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
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(24)),
                            ),
                            builder: (context) => ShareWithQrModal(
                              data: shareText,
                              subject: "Share Baakhapaa Gift!",
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
              icon: Icon(
                Icons.share_rounded,
                color: Colors.white,
                size: 24,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.transparent,
                padding: EdgeInsets.all(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftInfoSection() {
    var authProvider = Provider.of<Auth>(context, listen: false);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF1a1a2e)
            : Color(0xFF2a2a3e),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and Rating Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  gift['title']?.toString() ?? 'Gift',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              SizedBox(width: 12),
              // Rating Badge
              InkWell(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => RatingSheet(
                        ratingType: RatingType.product,
                        currentUserId: authProvider.userId,
                        authToken: authProvider.token,
                        ratingId: gift['id'],
                        ratingTitle: gift['title']),
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RatingSummery(
                          starSize: 12,
                          ratingTo: RatingTo.product,
                          ratingId: gift['id'],
                          authToken: authProvider.token),
                      SizedBox(height: 2),
                      Text(
                        '($reviewCount ${reviewCount == 1 ? 'Review' : 'Reviews'})',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          // Points Required and Reward Row
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color.fromARGB(255, 251, 218, 121),
                            Colors.amber.shade600,
                          ],
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
                      child: Image.asset(
                        'assets/images/coins.png',
                        width: 20,
                        height: 20,
                      ),
                    ),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Point Required',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '${gift['coin']} pts',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 20),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade400,
                            Colors.green.shade600,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.card_giftcard,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reward',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '${gift['reward'] ?? '0'} pts',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodesRequired(List<dynamic> episodes) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.cyan.shade400],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.play_circle_filled_rounded,
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
                      'Episodes Required',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Watch these episodes to redeem this gift',
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

          // Episodes List
          ...episodes.map<Widget>((episode) {
            bool isWatched = _parseBoolValue(episode['watched']);
            return InkWell(
              onTap: () {
                Navigator.of(context)
                    .pushNamed(VideoScreen.routeName, arguments: episode['id']);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      isWatched
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      isWatched
                          ? Colors.green.withValues(alpha: 0.05)
                          : Colors.grey.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isWatched
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isWatched ? Colors.green : Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isWatched
                            ? Icons.check_rounded
                            : Icons.play_arrow_rounded,
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
                            episode['title']?.toString() ?? 'Episode',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (episode['description'] != null) ...[
                            SizedBox(height: 4),
                            Text(
                              episode['description'].toString(),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (episode['points'] != null &&
                        episode['points'] != 0) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/coins.png',
                            width: 16,
                            height: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${episode['points']}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: 12),
                    ],
                    Icon(
                      isWatched
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isWatched ? Colors.green : Colors.grey,
                      size: 28,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    // Parse description into bullet points (split by newlines or bullets)
    String description = gift['description'].toString();
    List<String> bulletPoints = [];

    // Try to split by common bullet point indicators
    if (description.contains('\n')) {
      bulletPoints = description
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.trim().replaceFirst(RegExp(r'^[•\-\*]\s*'), ''))
          .toList();
    } else if (description.contains('•') ||
        description.contains('-') ||
        description.contains('*')) {
      bulletPoints = description
          .split(RegExp(r'[•\-\*]'))
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.trim())
          .toList();
    } else {
      // If no clear bullet points, treat as single paragraph
      bulletPoints = [description];
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1a1a2e), // Dark background
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Description',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 16),
          // Bulleted list
          ...bulletPoints.map((point) => Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        point,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildAchievementsRequired(List<dynamic> achievements) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade400, Colors.orange.shade400],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.3),
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
                      'Achievements Required',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Unlock these achievements to redeem this gift',
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

          // Achievements List
          ...achievements.map<Widget>((achievement) {
            bool isUnlocked = _parseBoolValue(achievement['unlocked']);
            return InkWell(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  AchievementsScreen.routeName,
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      isUnlocked
                          ? Colors.amber.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      isUnlocked
                          ? Colors.amber.withValues(alpha: 0.05)
                          : Colors.grey.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isUnlocked
                        ? Colors.amber.withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isUnlocked ? Colors.amber : Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isUnlocked
                            ? Icons.emoji_events_rounded
                            : Icons.lock_rounded,
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
                            achievement['title']?.toString() ?? 'Achievement',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (achievement['description'] != null) ...[
                            SizedBox(height: 4),
                            Text(
                              achievement['description'].toString(),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (achievement['points'] != null &&
                        achievement['points'] != 0) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/coins.png',
                            width: 16,
                            height: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${achievement['points']}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: 12),
                    ],
                    Icon(
                      isUnlocked
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isUnlocked ? Colors.amber : Colors.grey,
                      size: 28,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCooldownMessage() {
    final remaining = remainingCooldownTime;
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.withValues(alpha: 0.1),
            Colors.red.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.2),
            blurRadius: 15,
            spreadRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade400, Colors.red.shade400],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.timer_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cooldown Active',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Wait $hours hours and $minutes minutes before you can redeem another gift',
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
    );
  }

  Widget _buildRedeemSection() {
    final userAvailableCoins =
        Provider.of<Auth>(context, listen: false).userAvailableCoins;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Coins Info
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.amber.withValues(alpha: 0.1),
                  Colors.orange.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset(
                    'assets/images/coins.png',
                    width: 20,
                    height: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Your Available ',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Points',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/coins.png',
                            width: 18,
                            height: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            '$userAvailableCoins points',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade700,
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

          SizedBox(height: 20),

          // Redeem Options
          if (!isGiftToFriend) ...[
            // Gift to Friend Toggle
            SwitchListTile(
              title: Text(
                'Gift to a Friend',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Send this gift to someone special',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              value: isGiftToFriend,
              onChanged: (bool value) {
                setState(() {
                  isGiftToFriend = value;
                });
              },
              activeColor: Colors.purple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],

          if (isGiftToFriend) ...[
            // Friend Username Input
            Container(
              margin: EdgeInsets.symmetric(vertical: 8),
              child: TextFormField(
                controller: _friendUsernameController,
                decoration: InputDecoration(
                  labelText: 'Friend\'s Username',
                  hintText: 'Enter username',
                  prefixIcon: Icon(Icons.person_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: Colors.grey.withValues(alpha: 0.1),
                ),
              ),
            ),

            // Back to Self Button
            TextButton(
              onPressed: () {
                setState(() {
                  isGiftToFriend = false;
                  _friendUsernameController.clear();
                });
              },
              child: Text('Redeem for myself instead'),
            ),
          ],

          SizedBox(height: 20),

          // Redeem Button
          Container(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: userAvailableCoins >= gift['coin'] &&
                      _isRedeemable &&
                      qty > 0 &&
                      !isCooldownActive
                  ? () async {
                      // Check if all episodes are watched
                      if (!areAllEpisodesWatched) {
                        showDialogEpisodeNotCompleted(context);
                        return;
                      }

                      // Check if all achievements are unlocked
                      if (!areAllAchievementsUnlocked) {
                        showDialogAchievementNotCompleted(context);
                        return;
                      }

                      // Validate friend username if gift to friend is selected
                      if (isGiftToFriend &&
                          _friendUsernameController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Please enter friend\'s username')),
                        );
                        return;
                      }

                      // Show loading state
                      setState(() {
                        _isLoading = true;
                      });

                      try {
                        // Check if profile is completed
                        bool isProfileCompleted =
                            await checkAndShowProfileDialog(context);

                        if (isProfileCompleted) {
                          // Place the order
                          if (isGiftToFriend) {
                            // Gift to friend - need to implement friend lookup first
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Gift to friend feature will be implemented soon')),
                            );
                          } else {
                            // Redeem for self
                            await Provider.of<Orders>(context, listen: false)
                                .addGiftOrder(gift['id'] as int, 1)
                                .then((_) {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text('Successful'),
                                  content: Text(
                                      'Your order has been placed. We will get back to you soon.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(ctx).pop();
                                        // Refresh the gift data
                                        Provider.of<Shop>(context,
                                                listen: false)
                                            .getSingleProduct(navArgs);
                                      },
                                      child: Text('Okay'),
                                    )
                                  ],
                                ),
                              );
                            });
                          }
                        }
                      } catch (error) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Failed to place order. Please try again.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } finally {
                        setState(() {
                          _isLoading = false;
                        });
                      }
                    }
                  : !areAllEpisodesWatched ||
                          !areAllAchievementsUnlocked ||
                          qty <= 0 ||
                          isCooldownActive
                      ? () {
                          if (qty <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('This gift is out of stock')),
                            );
                          } else if (isCooldownActive) {
                            final remaining = remainingCooldownTime;
                            final hours = remaining.inHours;
                            final minutes = remaining.inMinutes.remainder(60);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Please wait $hours hours and $minutes minutes before redeeming another gift'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          } else if (!areAllEpisodesWatched) {
                            showDialogEpisodeNotCompleted(context);
                          } else if (!areAllAchievementsUnlocked) {
                            showDialogAchievementNotCompleted(context);
                          }
                        }
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: qty <= 0
                    ? Colors.grey
                    : isCooldownActive
                        ? Colors.orange
                        : !areAllEpisodesWatched || !areAllAchievementsUnlocked
                            ? Colors.orange
                            : Colors.purple,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                      qty <= 0
                          ? Icons.block_rounded
                          : isCooldownActive
                              ? Icons.timer_rounded
                              : !areAllEpisodesWatched
                                  ? Icons.play_circle_filled_rounded
                                  : !areAllAchievementsUnlocked
                                      ? Icons.emoji_events_rounded
                                      : Icons.card_giftcard_rounded,
                      size: 20),
                  SizedBox(width: 8),
                  Text(
                    buttonText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (userAvailableCoins < gift['coin'])
            Container(
              margin: EdgeInsets.only(top: 12),
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
                children: [
                  Icon(Icons.warning_rounded, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        children: [
                          TextSpan(text: 'Insufficient points. You need '),
                          WidgetSpan(
                            child: Image.asset(
                              'assets/images/coins.png',
                              width: 12,
                              height: 12,
                            ),
                          ),
                          TextSpan(
                              text:
                                  ' ${gift['coin'] - userAvailableCoins} more points.'),
                        ],
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

  Future<dynamic> showDialogEpisodeNotCompleted(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Oops! Episodes not completed.'),
        content: Text(
            "You have not completed all the episodes required to purchase this item."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text(
              'Okay',
            ),
          )
        ],
      ),
    );
  }

  Future<dynamic> showDialogAchievementNotCompleted(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Oops! Achievements not obtained.'),
        content: Text(
            "You have not obtained all the achievements required to purchase this item."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text(
              'Okay',
            ),
          )
        ],
      ),
    );
  }

  Future<dynamic> showDialogueInsufficientPoints(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Oops! Insufficient Points.'),
        content:
            Text("You don't have a sufficient points to purchase this item."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text(
              'Okay',
            ),
          )
        ],
      ),
    );
  }
}
