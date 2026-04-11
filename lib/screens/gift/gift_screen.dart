import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

import 'package:baakhapaa/helpers/helpers.dart';
import 'package:baakhapaa/models/url.dart';
import 'package:baakhapaa/l10n/app_localizations.dart';
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/providers/tutorial_flow_provider.dart';
import 'package:baakhapaa/screens/story/video_screen.dart';
import 'package:baakhapaa/screens/subscription/subscription_screen.dart';
import 'package:baakhapaa/screens/user/points_screen.dart';
import 'package:baakhapaa/widgets/header.dart';
import 'package:baakhapaa/widgets/nav_bar.dart';
import 'package:baakhapaa/widgets/refresh_indicator.dart';
import 'package:baakhapaa/widgets/skeleton_loading.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:upgrader/upgrader.dart';
import '../../providers/shop.dart';
import '../../widgets/gift.dart';
import '../../widgets/my_upgrader_messages.dart';
import '../shop/single_product_screen.dart';
import 'single_gift_screen.dart';
import '../../providers/puppet_interaction_provider.dart';
import '../../utils/puppet_screen_mapping.dart';
import '../../utils/debug_logger.dart';

class GiftScreen extends StatefulWidget {
  static const routeName = '/gift-screen';

  const GiftScreen({Key? key}) : super(key: key);

  @override
  State<GiftScreen> createState() => _GiftScreenState();
}

class _GiftScreenState extends State<GiftScreen> with PuppetInteractionMixin {
  var _isInit = true;
  late List<dynamic> _gifts = [];
  var _isLoading = false;
  late List<dynamic> searchResults = [];
  late DateTime _lastRedeemed;
  late int _cooldownDuration = 0;
  late List<dynamic> _giftSliders = [];
  bool _hasRequiredLevel = false;
  int _userLevel = 0;
  static const int REQUIRED_LEVEL = 10;
  Map<String, dynamic>? _userProgressData;
  bool _isLoadingProgress = true;

  /// Category definitions: API value (as used in `gifts/{Category}`) + UI label.
  /// The `api` string should match exactly what the backend expects after `gifts/`.
  final List<Map<String, String>> _categories = [
    {'api': 'Digital Product', 'label': 'Digital Product'},
    {'api': 'Clothing', 'label': 'Clothing'},
    {'api': 'Points', 'label': 'Points'},
    {'api': 'Gadgets', 'label': 'Gadgets'},
    {'api': 'Bags', 'label': 'Bags'},
    {'api': 'Bottle', 'label': 'Bottle'},
    {'api': 'Shoes', 'label': 'Shoes'},
    {'api': 'Shades', 'label': 'Shades'},
    {'api': 'Accessories', 'label': 'Accessories'},
  ];

  /// Currently selected category (API value).
  String _selectedCategoryApi = 'Digital Product';

  /// Per-category gifts and loading state.
  final Map<String, List<dynamic>> _categoryGifts = {};
  final Map<String, bool> _categoryLoading = {};
  final Map<String, String?> _categoryError = {};

  @override
  void initState() {
    super.initState();
    _initializePreferences();

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
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  @override
  void didChangeDependencies() {
    if (_isInit) {
      _mainInit();
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  Future<void> _mainInit() async {
    // Check user level first
    final authProvider = Provider.of<Auth>(context, listen: false);
    _userLevel = authProvider.user['level'] ?? 0;
    _hasRequiredLevel = _userLevel >= REQUIRED_LEVEL;

    // Fetch gifts for all users (so locked users can see preview)
    var _shopProvider = Provider.of<Shop>(context, listen: false);
    _shopProvider.fetchGiftSlider().then((___) {
      _giftSliders = _shopProvider.giftSliders;
    });
    await _fetchForYou();
    await _fetchGiftsByCategory(_selectedCategoryApi);

    if (!_hasRequiredLevel) {
      // Fetch user progress data for locked screen
      await _fetchUserProgress();
      setState(() {
        _isLoading = true;
      });
      return;
    }

    // Refresh puppet suggestions when gifts load
    refreshPuppetSuggestions();
    final tutorialProvider =
        Provider.of<TutorialFlowProvider>(context, listen: false);
    if (tutorialProvider.currentStep == 3 ||
        tutorialProvider.currentStep == 10) {
      tutorialProvider.nextStep().then((_) {
        if (mounted) {
          tutorialProvider.showCurrentStepMessage(context);
        }
      });
    }
  }

  List<dynamic> search(String query) {
    List<dynamic> results = [];
    // Iterate through the list and add items that match the search query to the results list
    for (int i = 0; i < _gifts.length; i++) {
      if (_gifts[i]['title'].toLowerCase().contains(query.toLowerCase())) {
        results.add(_gifts[i]);
      }
    }
    return results;
  }

  Future<void> _initializePreferences() async {
    var authProvider = Provider.of<Auth>(context, listen: false);

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

  Future<void> _fetchUserProgress() async {
    setState(() {
      _isLoadingProgress = true;
    });

    try {
      final authProvider = Provider.of<Auth>(context, listen: false);
      final token = authProvider.token;

      final response = await http.get(
        Uri.parse('${Url.rootUrl}/levels/user-progress'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _userProgressData = data['data'];
            _isLoadingProgress = false;
          });
          DebugLogger.info('✅ User progress data fetched successfully');
        } else {
          throw Exception('API returned success: false');
        }
      } else {
        throw Exception('Failed to load user progress: ${response.statusCode}');
      }
    } catch (e) {
      DebugLogger.error('❌ Error fetching user progress: $e');
      setState(() {
        _isLoadingProgress = false;
      });
    }
  }

  /// Fetch "For You" gifts from backend API `gift/forYou`.
  Future<void> _fetchForYou() async {
    try {
      final authProvider = Provider.of<Auth>(context, listen: false);
      final token = authProvider.token;

      final response = await http.get(
        Uri.parse('${Url.rootUrl}/gift/forYou'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      DebugLogger.info('📡 ForYou API Response Status: ${response.statusCode}');
      DebugLogger.info(
          '📝 ForYou API Response Body: ${response.body.substring(0, min(200, response.body.length))}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        DebugLogger.info('📊 ForYou Response Keys: ${data.keys.toList()}');

        // Handle different possible response structures
        List<dynamic>? gifts;

        if (data['success'] == true) {
          // Try data.data (nested structure)
          if (data['data'] is List) {
            gifts = data['data'] as List<dynamic>;
            DebugLogger.info('✅ Found gifts in data (List)');
          } else if (data['data'] is Map &&
              (data['data'] as Map)['data'] is List) {
            gifts = (data['data'] as Map)['data'] as List<dynamic>;
            DebugLogger.info('✅ Found gifts in data.data (nested)');
          } else if (data['data'] is Map &&
              (data['data'] as Map)['items'] is List) {
            gifts = (data['data'] as Map)['items'] as List<dynamic>;
            DebugLogger.info('✅ Found gifts in data.items');
          }
        }

        if (gifts != null && gifts.isNotEmpty) {
          setState(() {
            _gifts = gifts!;
            _isLoading = true;
          });
          DebugLogger.info(
              '✅ ForYou gifts fetched successfully: ${gifts.length} items');
          return;
        } else {
          DebugLogger.warning('⚠️ No gifts found in API response');
          throw Exception('No gifts in API response');
        }
      } else {
        throw Exception(
            'Failed to load gifts: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      DebugLogger.error('❌ Error fetching ForYou gifts: $e');
      // Fallback: try Shop provider to populate gifts
      try {
        final shop = Provider.of<Shop>(context, listen: false);
        await shop.getAllProducts();
        setState(() {
          _gifts = shop.gifts['1'] as List;
          _isLoading = true;
        });
        DebugLogger.info('✅ Fallback gifts loaded from Shop provider');
      } catch (inner) {
        DebugLogger.error('❌ Fallback failed: $inner');
        setState(() {
          _gifts = [];
          _isLoading = true;
        });
      }
    }
  }

  /// Fetch gifts for a specific category using backend API `gifts/{Category}`.
  /// The [categoryApiValue] must match exactly what backend expects
  /// (e.g. 'Digital Product', 'Clothing', etc.).
  Future<void> _fetchGiftsByCategory(String categoryApiValue) async {
    // Mark loading for this category
    setState(() {
      _categoryLoading[categoryApiValue] = true;
      _categoryError[categoryApiValue] = null;
    });

    try {
      final authProvider = Provider.of<Auth>(context, listen: false);
      final token = authProvider.token;

      // Encode category as a path segment to safely handle spaces like "Digital Product".
      final encodedCategory = Uri.encodeComponent(categoryApiValue);

      final uri = Uri.parse('${Url.rootUrl}/gifts/$encodedCategory');

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      DebugLogger.info(
          '📡 Category gifts API [$categoryApiValue] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        List<dynamic>? gifts;

        if (data is Map && data['success'] == true) {
          if (data['data'] is List) {
            gifts = data['data'] as List<dynamic>;
          } else if (data['data'] is Map &&
              (data['data'] as Map)['data'] is List) {
            gifts = (data['data'] as Map)['data'] as List<dynamic>;
          } else if (data['data'] is Map &&
              (data['data'] as Map)['items'] is List) {
            gifts = (data['data'] as Map)['items'] as List<dynamic>;
          }
        }

        setState(() {
          _categoryGifts[categoryApiValue] = gifts ?? [];
          _categoryLoading[categoryApiValue] = false;
        });
      } else {
        setState(() {
          _categoryGifts[categoryApiValue] = [];
          _categoryLoading[categoryApiValue] = false;
          _categoryError[categoryApiValue] =
              'Failed: ${response.statusCode} - ${response.body}';
        });
      }
    } catch (e) {
      DebugLogger.error(
          '❌ Error fetching gifts for category [$categoryApiValue]: $e');
      setState(() {
        _categoryGifts[categoryApiValue] = [];
        _categoryLoading[categoryApiValue] = false;
        _categoryError[categoryApiValue] = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget cooldownMessage = SizedBox.shrink();
    if (_isLoading) {
      final currentTime = DateTime.now();
      final giftCooldown = _cooldownDuration * 60 * 60 * 1000;
      final remainingTime = Duration(milliseconds: giftCooldown) -
          currentTime.difference(_lastRedeemed);
      final remainingHours = remainingTime.inHours;
      final remainingMinutes = remainingTime.inMinutes.remainder(60);

      if (remainingHours > 0 || remainingMinutes > 0) {
        cooldownMessage = Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: EdgeInsets.all(16),
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
                      'Wait $remainingHours hours and $remainingMinutes minutes for next redeem',
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
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: header(
        context: context,
        titleText: context.l10n.gift,
        scaffoldKey: Navigator.canPop(context) ? null : _scaffoldKey,
      ),
      drawer: Navigator.canPop(context) ? null : NavBar(),
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
              ? (!_hasRequiredLevel
                  ? _buildLockedScreen()
                  : Container(
                      child: SingleChildScrollView(
                        physics: BouncingScrollPhysics(),
                        child: Column(
                          children: <Widget>[
                            // Quick Actions (title, search, points chip)
                            _buildQuickActions(),

                            // For You Section
                            _buildForYouSection(),

                            // Featured Gifts Section
                            // _buildFeaturedGiftsSection(),

                            // Gifts by Category Section
                            _buildCategoryGiftsSection(),

                            // Hero Banner Section
                            _buildHeroBanner(),

                            // Cooldown Message
                            if (cooldownMessage != SizedBox.shrink())
                              cooldownMessage,

                            // All Gifts Section
                            _buildAllGiftsSection(),

                            SizedBox(height: 100), // Bottom padding
                          ],
                        ),
                      ),
                    ))
              : const GiftScreenSkeleton(),
        ),
      ),
    );
  }

  /// Locked screen for users below level 10 - shows blurred preview of gifts
  Widget _buildLockedScreen() {
    final currentLevelData = _userProgressData?['current_level'];
    final currentLevelName = currentLevelData?['name'] ?? 'Level $_userLevel';

    return Stack(
      children: [
        // Background: Gift content preview (blurred)
        IgnorePointer(
          child: SingleChildScrollView(
            physics: NeverScrollableScrollPhysics(),
            child: Column(
              children: <Widget>[
                // Quick Actions (title, search, points chip)
                _buildQuickActions(),
                // For You Section
                _buildForYouSection(),
                // Gifts by Category Section
                _buildCategoryGiftsSection(),
                // Hero Banner Section
                _buildHeroBanner(),
                // All Gifts Section (main gift list)
                _buildAllGiftsSection(),
                SizedBox(height: 100),
              ],
            ),
          ),
        ),
        // Blur overlay (reduced intensity)
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
        // Lock modal on top
        Center(
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              padding: EdgeInsets.all(32),
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
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 0,
                    offset: Offset(0, 10),
                  ),
                ],
                border: Border.all(
                  color: Colors.purple.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lock Icon with gradient background
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.purple.shade400,
                          Colors.purple.shade600,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 32),

                  // Title
                  Text(
                    'Gifts Locked',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),

                  // Description
                  Text(
                    'You need to reach Level $REQUIRED_LEVEL to unlock the Gift Store',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),

                  // Current Level Display
                  _isLoadingProgress
                      ? const ShimmerLoading(
                          child: SkeletonBox(
                              width: 160, height: 50, borderRadius: 20),
                        )
                      : Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.amber.shade400.withValues(alpha: 0.2),
                                Colors.amber.shade600.withValues(alpha: 0.2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.stars_rounded,
                                color: Colors.amber.shade700,
                                size: 28,
                              ),
                              SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your Current Level',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    currentLevelName,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                  SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Quick Actions section similar to ShopScreen: title, search bar and points chip.
  Widget _buildQuickActions() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title, Search Bar, Points Chip
          Row(
            children: [
              // "All Gifts" Title
              Expanded(
                flex: 2,
                child: Text(
                  'All Gifts',
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
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Color(0xFF2A2A2A), // Dark gray like in image
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: Colors.grey[500],
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[300],
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          onChanged: (text) {
                            setState(() {
                              searchResults = search(text);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12),

              // Points Chip
              Consumer<Auth>(
                builder: (context, auth, child) {
                  final coins = auth.userAvailableCoins;

                  return InkWell(
                    onTap: () {
                      Navigator.of(context).pushNamed(PointsScreen.routeName);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color.fromARGB(255, 251, 218, 121),
                            Colors.amber.shade600,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/coins.png',
                            width: 20,
                            height: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '$coins',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Bpts',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.amber.shade100,
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
        ],
      ),
    );
  }

  /// "For you" carousel with new dark card design and discount badges.
  Widget _buildForYouSection() {
    final items = _forYouList(limit: 8);
    if (items.isEmpty) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A), // Dark background
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with "For you" title and arrow
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'For you',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),
          // Horizontal scrolling product cards
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              itemBuilder: (ctx, idx) {
                return _buildForYouCard(items[idx]);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Individual card for "For you" section with discount badge
  Widget _buildForYouCard(Map<String, dynamic> item) {
    final title = item['title']?.toString() ?? 'Gift';
    final discount = item['discount'] ?? item['discount_percentage'];
    final hasDiscount = discount != null && discount > 0;

    // Get image URL
    String imageUrl = 'https://baakhapaa.com/images/logo.png';
    try {
      final images = item['images'];
      if (images != null && images is List && images.isNotEmpty) {
        final firstImage = images[0];
        if (firstImage is Map) {
          imageUrl = firstImage['full']?.toString() ??
              firstImage['url']?.toString() ??
              imageUrl;
        } else if (firstImage is String) {
          imageUrl = firstImage;
        }
        // Handle relative URLs
        if (!imageUrl.startsWith('http://') &&
            !imageUrl.startsWith('https://')) {
          var normalizedPath = imageUrl.trim();
          normalizedPath = normalizedPath.replaceFirst(RegExp(r'^/+'), '');
          normalizedPath = normalizedPath.replaceFirst(
              RegExp(r'^(storage/storage/)+'), 'storage/');
          normalizedPath =
              normalizedPath.replaceFirst(RegExp(r'^storage/'), '');
          imageUrl =
              'https://app.baakhapaa.com/storage/storage/$normalizedPath';
        }
      }
    } catch (e) {
      // Use default image
    }

    return GestureDetector(
      onTap: () {
        final auth = Provider.of<Auth>(context, listen: false);
        if (auth.isGuest) {
          // Handle guest user
          return;
        }
        Navigator.of(context).pushNamed(
          SingleGiftScreen.routeName,
          arguments: item['id'],
        );
      },
      child: Container(
        width: 120,
        margin: EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Image container with discount badge
            Stack(
              children: [
                // Product image
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: _getBackgroundColor(idx: title.hashCode),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
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
                            Icons.card_giftcard_rounded,
                            size: 40,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Discount badge at bottom right
                if (hasDiscount)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Image.asset(
                      'assets/images/dis2.png',
                      width: 28,
                      height: 28,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8),
            // Product title
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get a varied background color for product cards
  Color _getBackgroundColor({required int idx}) {
    final colors = [
      Color(0xFFF5A623), // Orange
      Color(0xFF2D2D2D), // Dark gray
      Color(0xFF1E3A5F), // Dark blue
      Color(0xFF3D2314), // Brown
    ];
    return colors[idx.abs() % colors.length];
  }

  /// Collect a small list of gifts to show in "For you" carousel.
  List<dynamic> _forYouList({int limit = 6}) {
    if (_gifts.isEmpty) return [];

    final List<dynamic> list = [];
    for (var g in _gifts) {
      if (g != null) list.add(g);
      if (list.length >= limit) break;
    }
    return list;
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
        child: _giftSliders.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ImageSlideshow(
                  initialPage: 0,
                  indicatorColor: Colors.purple,
                  indicatorBackgroundColor: Colors.grey.withValues(alpha: 0.3),
                  children: [
                    for (Map slider in _giftSliders)
                      InkWell(
                        onTap: () => _handleSliderTap(slider),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.amber.shade400,
                                Colors.amber.shade600,
                              ],
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: CachedNetworkImage(
                              imageUrl: slider['images'][0]['url'],
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.amber.shade400,
                                      Colors.amber.shade600,
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
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.amber.shade400,
                                      Colors.amber.shade600,
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
                        ),
                      ),
                  ],
                  onPageChanged: (value) {},
                  autoPlayInterval: _giftSliders.isNotEmpty &&
                          _giftSliders.any((slider) =>
                              slider['images'][0]['url'].endsWith('.gif'))
                      ? 8000
                      : 5000,
                  isLoop: true,
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.shade400,
                      Colors.amber.shade600,
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.card_giftcard_rounded,
                        color: Colors.purple,
                        size: 48,
                      ),
                      SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.giftRewards,
                        style: TextStyle(
                          color: Colors.purple,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Redeem amazing gifts and rewards',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
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

  /// Featured Gifts section with horizontal carousel.
  // Widget _buildFeaturedGiftsSection() {
  //   final items = _featuredGiftsList(limit: 8);
  //   if (items.isEmpty) return SizedBox.shrink();

  //   return Container(
  //     margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  //     decoration: BoxDecoration(
  //       gradient: LinearGradient(
  //         begin: Alignment.topLeft,
  //         end: Alignment.bottomRight,
  //         colors: [
  //           Theme.of(context).brightness == Brightness.dark
  //               ? Color(0xFF2A2A2A)
  //               : Colors.white,
  //           Theme.of(context).brightness == Brightness.dark
  //               ? Color(0xFF1E1E1E)
  //               : Colors.grey.shade50,
  //         ],
  //       ),
  //       borderRadius: BorderRadius.circular(20),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Theme.of(context).brightness == Brightness.dark
  //               ? Colors.black.withValues(alpha: 0.18)
  //               : Colors.grey.withValues(alpha: 0.12),
  //           blurRadius: 12,
  //           offset: Offset(0, 6),
  //         ),
  //       ],
  //       border: Border.all(
  //         color: Theme.of(context).brightness == Brightness.dark
  //             ? Colors.white.withValues(alpha: 0.04)
  //             : Colors.grey.withValues(alpha: 0.08),
  //         width: 1,
  //       ),
  //     ),
  //     child: Padding(
  //       padding: const EdgeInsets.all(12.0),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Row(
  //             children: [
  //               Container(
  //                 width: 32,
  //                 height: 32,
  //                 decoration: BoxDecoration(
  //                   shape: BoxShape.circle,
  //                   border: Border.all(
  //                     color: Theme.of(context).brightness == Brightness.dark
  //                         ? Colors.grey[700]!
  //                         : Colors.grey[300]!,
  //                     width: 1,
  //                   ),
  //                 ),
  //                 child: ClipOval(
  //                   child: Image.asset(
  //                     'assets/images/logo-lony.png',
  //                     fit: BoxFit.cover,
  //                     errorBuilder: (context, error, stackTrace) {
  //                       return Container(
  //                         color: Colors.grey[300],
  //                         child: Icon(Icons.error, size: 16),
  //                       );
  //                     },
  //                   ),
  //                 ),
  //               ),
  //               SizedBox(width: 12),
  //               Expanded(
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Text(
  //                       'Featured Gifts',
  //                       style: TextStyle(
  //                         fontSize: 18,
  //                         fontWeight: FontWeight.bold,
  //                         color: Theme.of(context).brightness == Brightness.dark
  //                             ? Colors.white
  //                             : Colors.black87,
  //                       ),
  //                       maxLines: 1,
  //                       overflow: TextOverflow.ellipsis,
  //                     ),
  //                     SizedBox(height: 4),
  //                     Text(
  //                       'Latest High rewarding gifts...',
  //                       style: TextStyle(
  //                         fontSize: 13,
  //                         color: Colors.grey[600],
  //                         height: 1.3,
  //                       ),
  //                       maxLines: 2,
  //                       overflow: TextOverflow.ellipsis,
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //               // Icon(Icons.chevron_right, color: Colors.grey),
  //             ],
  //           ),
  //           SizedBox(height: 12),
  //           // Featured gifts horizontal carousel
  //           SizedBox(
  //             height: 280,
  //             child: ListView.builder(
  //               scrollDirection: Axis.horizontal,
  //               padding: EdgeInsets.symmetric(horizontal: 8),
  //               itemCount: items.length,
  //               itemBuilder: (ctx, idx) {
  //                 return Container(
  //                   width: 200,
  //                   margin: EdgeInsets.only(right: 12),
  //                   child: GiftItem(items[idx]),
  //                 );
  //               },
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // /// Collect a list of gifts to show in "Featured Gifts" carousel.
  // List<dynamic> _featuredGiftsList({int limit = 8}) {
  //   if (_gifts.isEmpty) return [];

  //   // Show gifts starting from index 0, can be filtered later for "featured" logic
  //   final List<dynamic> list = [];
  //   for (var i = 0; i < _gifts.length && list.length < limit; i++) {
  //     if (_gifts[i] != null) list.add(_gifts[i]);
  //   }
  //   return list;
  // }

  /// Gifts by Category section - horizontal carousel for the selected category.
  Widget _buildCategoryGiftsSection() {
    final currentCategoryApi = _selectedCategoryApi;
    final isLoading = _categoryLoading[currentCategoryApi] == true;
    final items = _categoryGifts[currentCategoryApi] ?? [];

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
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color.fromARGB(255, 251, 218, 121),
                        Colors.amber.shade600,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.category_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gifts by Category',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Pick a category to see matching gifts',
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
              ],
            ),
            SizedBox(height: 16),

            // Category chips with modern styling
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final api = cat['api']!;
                  final label = cat['label']!;
                  final isSelected = api == currentCategoryApi;

                  return Padding(
                    padding: const EdgeInsets.only(right: 10.0),
                    child: GestureDetector(
                      onTap: () async {
                        if (api == _selectedCategoryApi) return;
                        setState(() {
                          _selectedCategoryApi = api;
                        });
                        await _fetchGiftsByCategory(api);
                      },
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                                  colors: [
                                    const Color.fromARGB(255, 251, 218, 121),
                                    Colors.amber.shade600,
                                  ],
                                )
                              : LinearGradient(
                                  colors: [
                                    Colors.grey.shade800,
                                    Colors.grey.shade700,
                                  ],
                                ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.amber.withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                          border: Border.all(
                            color: isSelected
                                ? Colors.amber.shade300
                                : Colors.grey.shade600,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.grey[300],
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 12),

            if (isLoading)
              const ShimmerLoading(
                child: SizedBox(
                  height: 280,
                  child: Row(
                    children: [
                      SkeletonBox(width: 160, height: 260, borderRadius: 16),
                      SizedBox(width: 12),
                      SkeletonBox(width: 160, height: 260, borderRadius: 16),
                    ],
                  ),
                ),
              )
            else if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No gifts available in this category yet.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              )
            else
              SizedBox(
                height: 280,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  itemCount: items.length,
                  itemBuilder: (ctx, idx) {
                    return Container(
                      width: 200,
                      margin: EdgeInsets.only(right: 12),
                      child: GiftItem(items[idx]),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// All Gifts section - main grid below Featured Gifts.
  Widget _buildAllGiftsSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                ? Colors.black.withValues(alpha: 0.15)
                : Colors.grey.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color.fromARGB(255, 251, 218, 121),
                      Colors.amber.shade600,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.card_giftcard_rounded,
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
                      searchResults.isNotEmpty
                          ? context.l10n.searchResults
                          : 'All Gifts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      searchResults.isNotEmpty
                          ? context.l10n.giftsMatchingSearch
                          : 'Redeem Gifts...',
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
          // Gifts grid/list
          Gift(searchResults.isNotEmpty ? searchResults : _gifts),
        ],
      ),
    );
  }

  void _handleSliderTap(Map slider) async {
    var gotoUrl = slider['goto'];
    var gotoPlatformId = slider['goto_platform_id'];
    var gotoPlatformType = slider['goto_platform_type'];

    if (gotoPlatformType == 'App\\Product') {
      DebugLogger.info(
          "Go to Platform type ${gotoPlatformType} & go to platform id ${gotoPlatformId}");
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
  }
}
