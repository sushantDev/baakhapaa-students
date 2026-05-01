import 'dart:io';
import 'dart:async';

import 'package:baakhapaa/helpers/helpers.dart';
// import 'package:baakhapaa/l10n/app_localizations.dart';
import 'package:baakhapaa/providers/tutorial_flow_provider.dart';
import 'package:baakhapaa/screens/gift/gift_screen.dart';
import 'package:baakhapaa/screens/story/episode_screen.dart';
import 'package:baakhapaa/screens/story/search_screen.dart';
// import 'package:baakhapaa/screens/leaderboard/leaderboard_screen.dart';
import 'package:baakhapaa/screens/story/video_screen.dart';
import 'package:baakhapaa/screens/story/creator_story_screen.dart';
import 'package:baakhapaa/screens/user/points_screen.dart';
// import 'package:baakhapaa/screens/user/points_screen.dart';
import 'package:baakhapaa/utils/exit_confirmation_dialog.dart';
import 'package:baakhapaa/utils/guest_auth_helper.dart';
import 'package:baakhapaa/widgets/nav_bar.dart';
import 'package:baakhapaa/widgets/popup.dart';

import 'package:baakhapaa/widgets/tutorial_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upgrader/upgrader.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../providers/auth.dart';
import '../shop/single_product_screen.dart';
// import '../user/user_screen.dart';
// import '../discover/discover_screen.dart';
import '../../widgets/footer.dart';
import '../../providers/story.dart';
import '../../widgets/header.dart';
import '../../widgets/story_card.dart';
import '../../widgets/my_upgrader_messages.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/refresh_indicator.dart';
import '../../models/url.dart';
import '../../providers/puppet_interaction_provider.dart';
import '../../utils/puppet_screen_mapping.dart';
import '../../utils/debug_logger.dart';
import '../challenges/challenge_detail_screen.dart';
import '../../providers/challenge.dart';
import '../story/creators_screen.dart';
import '../challenges/all_challenges_screen.dart';
import '../../utils/season_unlock_helper.dart';
import '../../services/ad_service.dart';

class StoryScreen extends StatefulWidget {
  static const routeName = '/story-screen';

  const StoryScreen({Key? key}) : super(key: key);

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen>
    with PuppetInteractionMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Keep state alive for performance

  var _isInit = true;
  var _isLoading = false;
  var _authProvider;
  late List<dynamic> _sliders = [];
  late Map<String, dynamic> storyPopup = {};
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Add this flag to prevent multiple initializations
  bool _initInProgress = false;
  bool _mainInitInProgress = false;

  // Performance: Track last known data state to prevent unnecessary rebuilds
  int _lastKnownSuggestedCount = 0;
  int _lastKnownDifficultCount = 0;

  // For banner ads auto-scroll
  late PageController _bannerPageController;
  Timer? _bannerTimer;
  int _currentBannerIndex = 0;

  // For gifts/rewards data
  List<Map<String, dynamic>> _gifts = [];

  // Cache for featured seasons to prevent data loss during rebuilds
  List<Map<String, dynamic>> _cachedFeaturedSeasons = [];
  List<dynamic> _cachedMyListItems = [];
  List<dynamic> _cachedContinueWatchingItems = [];
  List<dynamic> _cachedDifficultSeasons = [];
  List<dynamic> _cachedReadableSeasons = [];
  bool _hasCheckedInterestPrompt = false;
  bool _showInterestPrompt = false;
  bool _booksRetryTriggered = false;

  // Cache positioning decisions to prevent excessive recalculation
  // REMOVED: Dynamic positioning variables - now using fixed bottom position
  bool _positioningCalculated = false;

  // For stories scroll tracking
  late ScrollController _storiesScrollController;
  double _scrollPosition = 0.0;
  int _currentStoryIndex = 0;

  // Continue watching refresh tracking
  DateTime? _lastContinueWatchingRefresh;
  static const Duration _refreshCooldown = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _bannerPageController = PageController();
    _storiesScrollController = ScrollController();

    // Initialize tutorial with proper delay and state check
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Initialize puppet provider
      try {
        context.read<PuppetInteractionProvider>().initState();
      } catch (e) {
        DebugLogger.puppet('Puppet provider not available: $e');
      }

      final tutorialProvider =
          Provider.of<TutorialFlowProvider>(context, listen: false);
      DebugLogger.info(
          'Initial tutorial state: ${tutorialProvider.currentStep}');

      // Wait for provider to fully initialize
      await Future.delayed(Duration(milliseconds: 100));

      if (tutorialProvider.currentStep == 0 && tutorialProvider.isActive) {
        DebugLogger.info('Starting tutorial flow');
        // Show initial message with delay
        await Future.delayed(Duration(milliseconds: 500));
        if (!mounted) return;

        tutorialProvider.showCurrentStepMessage(context);
        DebugLogger.info('Showing tutorial step 0');
      } else if (tutorialProvider.currentStep == 4) {
        DebugLogger.info('Processing step 4');
        await tutorialProvider.nextStep();
        if (mounted) {
          tutorialProvider.showCurrentStepMessage(context);
        }
      } else if (tutorialProvider.currentStep == 11) {
        await tutorialProvider.completeTutorial();
      }

      // Initialize data only once
      if (_isInit && !_initInProgress) {
        _initInProgress = true;
        try {
          if (mounted) {
            await _mainInit();
          }
        } catch (e) {
          DebugLogger.error('Error in initialization: $e');
        } finally {
          _isInit = false;
          _initInProgress = false;
        }
      }
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerPageController.dispose();
    _storiesScrollController.dispose();

    // Clear puppet interactions when leaving screen
    clearPuppetInteractions();

    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check if we're returning to this screen from another screen
    // CRITICAL: Skip during initial load (_isInit=true or _mainInitInProgress=true)
    // to prevent Auth.getUser() from triggering Story provider recreation
    // while _mainInit() API calls are still in-flight (race condition).
    final route = ModalRoute.of(context);
    if (route != null && !_isInit && !_mainInitInProgress) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // If the Story provider was recreated with empty data (e.g. triggered by
        // user_screen calling auth.getUser() before this screen's data loaded),
        // run a full re-init to restore all content sections.
        final story = Provider.of<Story>(context, listen: false);
        final hasNoData = story.featuredSeasons.isEmpty &&
            story.suggestedSeasons.isEmpty &&
            _cachedFeaturedSeasons.isEmpty &&
            !_isLoading;
        if (hasNoData) {
          _mainInit();
        } else if (route.isCurrent) {
          _refreshContinueWatchingIfNeeded();
        }
      });
    }
  }

  Future<void> _refreshContinueWatchingIfNeeded() async {
    try {
      // Check cooldown to prevent excessive API calls
      final now = DateTime.now();
      if (_lastContinueWatchingRefresh != null &&
          now.difference(_lastContinueWatchingRefresh!) < _refreshCooldown) {
        DebugLogger.info(
            '⏯️ StoryScreen: Continue watching refresh on cooldown, skipping');
        return;
      }

      _lastContinueWatchingRefresh = now;

      final authProvider = Provider.of<Auth>(context, listen: false);

      DebugLogger.info(
          '⏯️ StoryScreen: Refreshing continue watching data and user points after returning to screen');

      // Refresh user data to get updated available points
      await authProvider.getUser();

      if (!mounted) return;

      // Re-read provider after await (Auth update may have recreated it)
      final freshStoryProvider = Provider.of<Story>(context, listen: false);

      // Always refresh continue watching when returning to story screen
      await freshStoryProvider.fetchContinueWatching();

      // Update cache if new data is available
      if (mounted && freshStoryProvider.continueWatchingItems.isNotEmpty) {
        final newCount = freshStoryProvider.continueWatchingItems.length;
        final oldCount = _cachedContinueWatchingItems.length;

        setState(() {
          _cachedContinueWatchingItems =
              List<dynamic>.from(freshStoryProvider.continueWatchingItems);
        });

        DebugLogger.success(
            '⏯️ Continue watching refreshed: $newCount items (was $oldCount)');

        // Log progress of first item for debugging
        if (newCount > 0) {
          final firstItem = freshStoryProvider.continueWatchingItems.first;
          final percentage = firstItem['completion_percentage'] ?? 0;
          final seasonTitle = firstItem['season']['title'] ?? 'Unknown';
          DebugLogger.info(
              '⏯️ First item: "$seasonTitle" - $percentage% complete (Type: ${percentage.runtimeType})');
        }
      } else if (mounted && freshStoryProvider.continueWatchingItems.isEmpty) {
        // If API returns empty, also update cache to reflect current state
        setState(() {
          _cachedContinueWatchingItems = [];
        });
        DebugLogger.info('⏯️ Continue watching is now empty after refresh');
      }
    } catch (e) {
      DebugLogger.error('⏯️ Error refreshing continue watching: $e');
    }
  }

  Future<void> _mainInit() async {
    DebugLogger.info("🏛️ StoryScreen - _mainInit called");

    // Prevent multiple simultaneous initializations
    if (_mainInitInProgress) {
      DebugLogger.info(
          "🏛️ StoryScreen - _mainInit already in progress, skipping");
      return;
    }

    _mainInitInProgress = true;

    if (!mounted) {
      _mainInitInProgress = false;
      return;
    }

    try {
      final authProv = Provider.of<Auth>(context, listen: false);
      var _storyProvider = Provider.of<Story>(context, listen: false);

      // Set _authProvider immediately with setState so the UI can dismiss
      // the Loading() widget gate in _upgradeAlertWidget()
      setState(() {
        _authProvider = authProv;
        _isLoading = true;
      });

      DebugLogger.info("🏛️ StoryScreen - Auth provider initialized");

      if (!mounted) return;

      try {
        // Fetch both featured seasons and all seasons for continue watching
        DebugLogger.info('🏛️ Starting Future.wait for API calls...');

        // Use allSettled pattern to handle partial failures gracefully
        await Future.wait([
          _storyProvider.fetchFeaturedSeasons().catchError((e) {
            DebugLogger.error('Featured seasons API failed: $e');
            return Future.value(); // Continue with other APIs
          }),
          _storyProvider.fetchSuggestedSeasons().catchError((e) {
            DebugLogger.error('Suggested seasons API failed: $e');
            return Future.value(); // Continue with other APIs
          }),
          _storyProvider.fetchDifficultSeasons().catchError((e) {
            DebugLogger.error(
                'Difficult seasons API failed (backend error): $e');
            // This is expected to fail due to backend DatePoint::addMinutes() error
            return Future.value(); // Continue with other APIs
          }),
          _storyProvider.fetchMyList().catchError((e) {
            DebugLogger.error('My List API failed: $e');
            return Future.value(); // Continue with other APIs
          }),
          _storyProvider.fetchContinueWatching().catchError((e) {
            DebugLogger.error('Continue watching API failed: $e');
            return Future.value(); // Continue with other APIs
          }),
          _storyProvider.fetchPremiumCreatorSeasons().catchError((e) {
            DebugLogger.error('Premium creator seasons API failed: $e');
            return Future.value();
          }),
          _storyProvider.fetchReadableSeasons().catchError((e) {
            DebugLogger.error('Readable seasons API failed: $e');
            return Future.value();
          }),
          _storyProvider.fetchReadingStreak().catchError((e) {
            DebugLogger.error('Reading streak API failed: $e');
            return Future.value();
          }),
        ], eagerError: false); // Don't fail fast, wait for all to complete

        DebugLogger.info(
            '🏛️ Future.wait completed (some APIs may have failed gracefully)');

        // Re-read the provider after await — the ChangeNotifierProxyProvider
        // may have created a new Story instance while the API calls were
        // in-flight (triggered by Auth.notifyListeners inside getUser()).
        if (!mounted) return;
        _storyProvider = Provider.of<Story>(context, listen: false);

        // Books can disappear if the provider is recreated while the initial
        // readable request was still in-flight on the previous instance.
        if (_storyProvider.readableSeasons.isEmpty) {
          try {
            await _storyProvider.fetchReadableSeasons();
            if (mounted) {
              _storyProvider = Provider.of<Story>(context, listen: false);
            }
          } catch (e) {
            DebugLogger.error('Readable seasons retry failed: $e');
          }
        }

        // Cache the featured seasons data to prevent loss during rebuilds
        if (_storyProvider.featuredSeasons.isNotEmpty) {
          _cachedFeaturedSeasons =
              List<Map<String, dynamic>>.from(_storyProvider.featuredSeasons);
          DebugLogger.info(
              'Cached ${_cachedFeaturedSeasons.length} featured seasons');
        }

        // Cache the My List data to prevent loss during rebuilds
        if (_storyProvider.myListItems.isNotEmpty) {
          _cachedMyListItems = List<dynamic>.from(_storyProvider.myListItems);
          DebugLogger.info('Cached ${_cachedMyListItems.length} my list items');
        }

        // Cache the Continue Watching data to prevent loss during rebuilds
        if (_storyProvider.continueWatchingItems.isNotEmpty) {
          _cachedContinueWatchingItems =
              List<dynamic>.from(_storyProvider.continueWatchingItems);
          DebugLogger.info(
              'Cached ${_cachedContinueWatchingItems.length} continue watching items');
        }

        // Cache the Difficult Seasons data to prevent loss during rebuilds
        // Note: This may be empty due to backend API error
        if (_storyProvider.difficultSeasons.isNotEmpty) {
          _cachedDifficultSeasons =
              List<dynamic>.from(_storyProvider.difficultSeasons);
          DebugLogger.info(
              'Cached ${_cachedDifficultSeasons.length} difficult season categories');
        } else {
          DebugLogger.info(
              'Difficult seasons API failed - likely backend DatePoint::addMinutes() error');
        }

        // Cache readable seasons
        if (_storyProvider.readableSeasons.isNotEmpty) {
          _cachedReadableSeasons =
              List<dynamic>.from(_storyProvider.readableSeasons);
          DebugLogger.info(
              'Cached ${_cachedReadableSeasons.length} readable seasons');
        }

        DebugLogger.info(
            'Fetched ${_storyProvider.seasons.length} total seasons for continue watching');
        DebugLogger.info(
            'Fetched ${_storyProvider.suggestedSeasons.length} suggested season categories');
        DebugLogger.info(
            'Difficult seasons: ${_storyProvider.difficultSeasons.length} categories (may be 0 due to backend error)');

        // Calculate positioning once after all data is loaded
        _calculateDifficultSeasonsPositioning();
      } catch (e) {
        DebugLogger.info('🏛️ ERROR in Future.wait: $e');
        DebugLogger.info('🏛️ Stack trace: ${StackTrace.current}');
        DebugLogger.error('Error fetching seasons: $e');
      }

      // Mark loading complete early — core content data is ready
      // Sequential operations below (slider, gifts, creators, challenges) load in background
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (!mounted) return;

      // Use try-catch for each provider operation to handle disposal errors
      // Re-read provider reference since Auth updates may have created a new Story
      try {
        var freshProvider = Provider.of<Story>(context, listen: false);
        await freshProvider.fetchStorySlider();
        if (mounted) {
          setState(() {
            _sliders = freshProvider.sliders;
          });
          _startBannerAutoScroll();
          refreshPuppetSuggestions();
        }
      } catch (e) {
        DebugLogger.error('Error fetching story slider: $e');
      }

      if (!mounted) return;

      // Fetch gifts for rewards
      try {
        await _fetchGifts();
      } catch (e) {
        DebugLogger.error('Error fetching gifts: $e');
      }

      if (!mounted) return;

      // Fetch creators for storytellers section
      try {
        await _authProvider.fetchCreators();
      } catch (e) {
        DebugLogger.error('Error fetching creators: $e');
      }

      if (!mounted) return;

      // Fetch challenges for challenges section with better error handling
      try {
        if (mounted) {
          await Future.delayed(Duration(
              milliseconds: 200)); // Extra delay for Challenge provider
          if (mounted) {
            final challengeProvider =
                Provider.of<Challenge>(context, listen: false);
            await challengeProvider.fetchChallenges();
            DebugLogger.info('✅ Challenges fetched successfully');
          }
        }
      } catch (e) {
        DebugLogger.error('Error fetching challenges: $e');
        // Continue execution - challenges are not critical for the main story flow
      }

      // Sync caches as safety net after sequential operations
      // (provider may have been recreated by Auth notifications)
      if (!mounted) return;
      final currentProvider = Provider.of<Story>(context, listen: false);
      setState(() {
        // Force-sync caches from whichever provider instance is current
        if (currentProvider.featuredSeasons.isNotEmpty) {
          _cachedFeaturedSeasons =
              List<Map<String, dynamic>>.from(currentProvider.featuredSeasons);
        }
        if (currentProvider.myListItems.isNotEmpty) {
          _cachedMyListItems = List<dynamic>.from(currentProvider.myListItems);
        }
        if (currentProvider.continueWatchingItems.isNotEmpty) {
          _cachedContinueWatchingItems =
              List<dynamic>.from(currentProvider.continueWatchingItems);
        }
        if (currentProvider.difficultSeasons.isNotEmpty) {
          _cachedDifficultSeasons =
              List<dynamic>.from(currentProvider.difficultSeasons);
        }
        if (currentProvider.readableSeasons.isNotEmpty) {
          _cachedReadableSeasons =
              List<dynamic>.from(currentProvider.readableSeasons);
        }
      });

      // Continue with non-critical operations (wrapped individually
      // so failures don't affect the main screen)
      if (!mounted) return;
      try {
        await _fetchStoryPopup();
      } catch (e) {
        DebugLogger.error('Error fetching story popup: $e');
      }

      if (!mounted) return;
      try {
        await _authProvider.getUnreadMessageCount();
      } catch (e) {
        DebugLogger.error('Error fetching unread message count: $e');
      }

      if (!mounted) return;
      try {
        if (!_authProvider.isLoadingUser) {
          await _authProvider.getUser();
        }
      } catch (e) {
        DebugLogger.error('Error fetching user: $e');
      }

      if (!mounted) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        String? storedToken = prefs.getString('fcmToken');

        if (storedToken != null && mounted) {
          await _authProvider.saveFCMToken(storedToken);
        }
      } catch (e) {
        DebugLogger.error('Error saving FCM token: $e');
      }

      // Note: Notification count is now retrieved from getUser() API
      // No need to call fetchAnnouncement() separately
    } catch (e) {
      DebugLogger.error('Error in _mainInit: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } finally {
      _mainInitInProgress = false;
    }
  }

  void onScreenReload() {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final story = Provider.of<Story>(context, listen: false);
      Future.wait([
        story.fetchFeaturedSeasons().catchError((e) => Future.value()),
        story.fetchSuggestedSeasons().catchError((e) => Future.value()),
        story.fetchDifficultSeasons().catchError((e) => Future.value()),
        story.fetchMyList().catchError((e) => Future.value()),
        story.fetchContinueWatching().catchError((e) => Future.value()),
        story.fetchReadableSeasons().catchError((e) => Future.value()),
      ], eagerError: false)
          .then((_) {
        if (mounted) {
          _calculateDifficultSeasonsPositioning();
          // Re-read current provider and sync caches
          final current = Provider.of<Story>(context, listen: false);
          setState(() {
            _isLoading = false;
            if (current.featuredSeasons.isNotEmpty) {
              _cachedFeaturedSeasons =
                  List<Map<String, dynamic>>.from(current.featuredSeasons);
            }
            if (current.myListItems.isNotEmpty) {
              _cachedMyListItems = List<dynamic>.from(current.myListItems);
            }
            if (current.continueWatchingItems.isNotEmpty) {
              _cachedContinueWatchingItems =
                  List<dynamic>.from(current.continueWatchingItems);
            }
            if (current.difficultSeasons.isNotEmpty) {
              _cachedDifficultSeasons =
                  List<dynamic>.from(current.difficultSeasons);
            }
            if (current.readableSeasons.isNotEmpty) {
              _cachedReadableSeasons =
                  List<dynamic>.from(current.readableSeasons);
            }
          });
        }
      }).catchError((e) {
        DebugLogger.error('Error in onScreenReload: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      DebugLogger.error('Error accessing Story provider in onScreenReload: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Calculate difficult seasons positioning once based on current data state
  void _calculateDifficultSeasonsPositioning() {
    if (!mounted || _authProvider == null) return;

    // FIXED: Always show difficult seasons at the bottom to prevent movement
    // The difficult seasons section should be stable and not jump around
    _positioningCalculated = true;

    DebugLogger.info(
        '🎯 POSITIONING FIXED: Difficult seasons always at bottom for consistency');
  }

  void toggleLoadingState() {
    setState(() {
      _isLoading = !_isLoading;
    });
  }

  void launchMessengerApp() async {
    final url = Uri.parse("http://m.me/baakhapaa");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  String get userImageUrl {
    if (_authProvider == null ||
        _authProvider.image == null ||
        _authProvider.image.isEmpty) {
      return 'https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg';
    }
    return _authProvider.image.first['thumbnail'];
  }

  Future<void> _fetchStoryPopup() async {
    try {
      var storyProvider = Provider.of<Story>(context, listen: false);
      await storyProvider.fetchStoryPopup();
      setState(() {
        storyPopup = {'popups': storyProvider.storyPopups};
      });
    } catch (error) {
      DebugLogger.error('Error fetching story popup: $error');
    }
  }

  // Start banner auto-scroll
  void _startBannerAutoScroll() {
    if (_sliders.isNotEmpty) {
      _bannerTimer = Timer.periodic(Duration(seconds: 3), (timer) {
        if (mounted && _bannerPageController.hasClients) {
          _currentBannerIndex = (_currentBannerIndex + 1) % _sliders.length;
          _bannerPageController.animateToPage(
            _currentBannerIndex,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  // Fetch gifts from API
  Future<void> _fetchGifts() async {
    try {
      final url = Uri.parse('${Url.rootUrl}/gifts/home-screen');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${_authProvider.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _gifts = List<Map<String, dynamic>>.from(data['data']);
          });
        }
      }
    } catch (e) {
      DebugLogger.api('Error fetching gifts: $e');
    }
  }

  Widget _buildRewardsSection() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      padding: const EdgeInsets.all(15),
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
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.8),
            blurRadius: 1,
            spreadRadius: 0,
            offset: Offset(0, 1),
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
          Row(
            children: [
              Text(
                context.l10n.giftRewards,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  Navigator.of(context).pushNamed(GiftScreen.routeName);
                },
                child: Text(
                  'See More',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_gifts.isNotEmpty)
            Container(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _gifts.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: EdgeInsets.only(
                      right: index == _gifts.length - 1 ? 0 : 6,
                    ),
                    child: _buildGiftCard(_gifts[index], index),
                  );
                },
              ),
            )
          else
            ShimmerLoading(
              child: SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: 5,
                  itemBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: SkeletonBox(width: 56, height: 56, borderRadius: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // SIMPLIFIED _buildContinueWatchingSection() in story_screen.dart
// (Normalization is now handled in Story provider)

  Widget _buildContinueWatchingSection() {
    return Selector<Story, List<dynamic>>(
      selector: (context, story) => story.continueWatchingItems,
      builder: (context, continueWatchingItems, child) {
        // Check if user is authenticated
        if (_authProvider.isGuest) {
          DebugLogger.info('   ❌ User is guest, hiding section');
          return SizedBox.shrink();
        }

        // Use cached data if provider data is empty but cache has data
        List<dynamic> continueWatchingItemsToShow =
            continueWatchingItems.isNotEmpty
                ? continueWatchingItems
                : _cachedContinueWatchingItems;

        // Update cache if provider has newer data
        if (continueWatchingItems.isNotEmpty &&
            continueWatchingItems != _cachedContinueWatchingItems) {
          _cachedContinueWatchingItems =
              List<dynamic>.from(continueWatchingItems);
          // FIXED: Don't reset positioning to prevent UI jumping
          DebugLogger.info(
              'Updated continue watching cache - positioning remains stable');
        }

        if (continueWatchingItemsToShow.isEmpty) {
          DebugLogger.info('   ℹ️ No continue watching items to display');
          return SizedBox.shrink();
        }

        DebugLogger.info(
            '   ✅ Building Continue Watching section with ${continueWatchingItemsToShow.length} items');

        // Debug: Log raw continue watching data
        DebugLogger.info('⏯️ RAW Continue Watching Data:');
        for (int i = 0; i < continueWatchingItemsToShow.length; i++) {
          final item = continueWatchingItemsToShow[i];
          DebugLogger.info('⏯️ Item $i: ${json.encode(item)}');
        }

        // Convert Continue Watching items to season format for unified widget
        // (reward_details are already normalized in the provider)
        List<dynamic> seasonsForUnifiedWidget =
            continueWatchingItemsToShow.map((item) {
          final season = Map<String, dynamic>.from(item['season'] ?? {});
          final rewards =
              Map<String, dynamic>.from(item['reward_details'] ?? {});
          final completionPercentage = item['completion_percentage'] ?? 0.0;

          DebugLogger.info(
              '   - Season: ${season['title']}, Completion: $completionPercentage%, Rewards: $rewards');

          return {
            ...season,
            'watched': item['watched'] ?? false,
            'completion_percentage': completionPercentage,
            'rewards': rewards,
          };
        }).toList();

        return _buildUnifiedSeasonCategory(
          title: 'Continue Watching',
          seasons: seasonsForUnifiedWidget,
          isWatchTitle: false,
          showDifficulty: false,
        );
      },
    );
  }

  // storyteller card
  Widget _buildStorytellerCard(Map<String, dynamic> creator) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 44;
    final cardWidth = (availableWidth / 5.5) - 3;

    return Container(
      width: cardWidth,
      margin: const EdgeInsets.only(right: 4),
      child: InkWell(
        onTap: () async {
          try {
            final auth = Provider.of<Auth>(context, listen: false);
            if (auth.isGuest) {
              await GuestAuthHelper.showGuestLoginDialog(
                context,
                'view storyteller profile',
              );
              return;
            }
            if (creator['id'] != null) {
              await Navigator.of(context).pushNamed(
                CreatorStoryScreen.routeName,
                arguments: [
                  creator['id'],
                  creator['name'] ?? creator['username']
                ],
              );
            }
          } catch (e) {
            DebugLogger.error('Error navigating to creator story: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Unable to open creator profile')),
            );
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Profile Image
            Container(
              width: cardWidth - 8, // Make image proportional to card width
              height: cardWidth - 8, // Square image
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
              ),
              child: ClipOval(
                child: creator['images'] != null && creator['images'].isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: creator['images'][0]['thumbnail'],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Icon(
                          Icons.person,
                          size: 30, // Increased from 24
                          color: Colors.grey[400],
                        ),
                        errorWidget: (context, url, error) => Icon(
                          Icons.person,
                          size: 30, // Increased from 24
                          color: Colors.grey[400],
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: 30, // Increased from 24
                        color: Colors.grey[400],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// challenge card
  Widget _buildChallengeCard(Map<String, dynamic> challenge) {
    // Calculate width to show 6 items in first view
    double screenWidth = MediaQuery.of(context).size.width;
    double availableWidth = screenWidth - 44; // Container padding and margins
    double cardWidth =
        (availableWidth - (5 * 6)) / 6; // 6 items with 6px spacing
    double cardSize =
        cardWidth < 50 ? 50 : cardWidth; // Minimum size constraint

    return InkWell(
      onTap: () async {
        try {
          final auth = Provider.of<Auth>(context, listen: false);
          if (auth.isGuest) {
            GuestAuthHelper.showGuestLoginDialog(context, 'view challenges');
            return;
          }
          await Navigator.of(context).pushNamed(
            ChallengeDetailScreen.routeName,
            arguments: challenge['id'],
          );
        } catch (e) {
          DebugLogger.error('Error navigating to challenge: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to open challenge'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: cardSize,
        height: cardSize,
        margin:
            const EdgeInsets.only(right: 6), // Reduced margin for better fit
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF2A2A2A)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 3,
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: challenge['image_url'] != null
              ? CachedNetworkImage(
                  imageUrl: challenge['image_url'],
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.amber.withValues(alpha: 0.1),
                    child: const Icon(
                      FontAwesomeIcons.trophy,
                      color: Colors.amber,
                      size: 20,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.amber.withValues(alpha: 0.1),
                    child: const Icon(
                      FontAwesomeIcons.trophy,
                      color: Colors.amber,
                      size: 20,
                    ),
                  ),
                )
              : Container(
                  color: Colors.amber.withValues(alpha: 0.1),
                  child: const Icon(
                    FontAwesomeIcons.trophy,
                    color: Colors.amber,
                    size: 20,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildGiftCard(Map<String, dynamic> gift, int index) {
    // Calculate width to show 6 items in first view
    double screenWidth = MediaQuery.of(context).size.width;
    double availableWidth = screenWidth - 44; // Container padding and margins
    double cardWidth =
        (availableWidth - (5 * 6)) / 6; // 6 items with 6px spacing
    double cardSize =
        cardWidth < 50 ? 50 : cardWidth; // Minimum size constraint

    // Get the image URL if available (supports new CDN urls + legacy paths)
    String? imageUrl;
    final images = gift['images'];
    if (images is List && images.isNotEmpty) {
      final firstImage = images.first;
      String? rawImage;

      if (firstImage is Map) {
        rawImage = firstImage['url']?.toString();
        rawImage ??= firstImage['thumbnail']?.toString();
        rawImage ??= firstImage['full']?.toString();
        rawImage ??= firstImage['path']?.toString();
      } else if (firstImage is String) {
        rawImage = firstImage;
      }

      if (rawImage != null && rawImage.trim().isNotEmpty) {
        if (rawImage.startsWith('http://') || rawImage.startsWith('https://')) {
          imageUrl = rawImage;
        } else {
          var normalizedPath = rawImage.trim();
          normalizedPath = normalizedPath.replaceFirst(RegExp(r'^/+'), '');
          normalizedPath = normalizedPath.replaceFirst(
              RegExp(r'^(storage/storage/)+'), 'storage/');
          normalizedPath =
              normalizedPath.replaceFirst(RegExp(r'^storage/'), '');
          imageUrl =
              'https://student.baakhapaa.com/storage/storage/$normalizedPath';
        }
      }
    }
    final auth = Provider.of<Auth>(context, listen: false);
    return InkWell(
      onTap: () {
        if (auth.isGuest) {
          GuestAuthHelper.showGuestLoginDialog(context, 'view gifts');
          return;
        }
        // Navigate to single product screen with the gift ID
        Navigator.of(context).pushNamed(
          SingleProductScreen.routeName,
          arguments: gift['id'],
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: cardSize,
        height: cardSize,
        margin:
            const EdgeInsets.only(right: 6), // Reduced margin for better fit
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 3,
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        colors: [
                          _getGiftColor(index).withValues(alpha: 0.3),
                          _getGiftColor(index).withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        _getGiftIcon(index),
                        color: _getGiftColor(index),
                        size: 20,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        colors: [
                          _getGiftColor(index).withValues(alpha: 0.3),
                          _getGiftColor(index).withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        _getGiftIcon(index),
                        color: _getGiftColor(index),
                        size: 20,
                      ),
                    ),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      colors: [
                        _getGiftColor(index).withValues(alpha: 0.3),
                        _getGiftColor(index).withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      _getGiftIcon(index),
                      color: _getGiftColor(index),
                      size: 20,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Color _getGiftColor(int index) {
    final colors = [Colors.green, Colors.blue, Colors.purple, Colors.orange];
    return colors[index % colors.length];
  }

  IconData _getGiftIcon(int index) {
    final icons = [
      FontAwesomeIcons.coins,
      FontAwesomeIcons.trophy,
      FontAwesomeIcons.crown,
      FontAwesomeIcons.gift,
    ];
    return icons[index % icons.length];
  }

  // Difficulty helper methods for beautiful styling
  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'high':
        return Colors.red.shade600;
      case 'medium':
        return Colors.orange.shade600;
      case 'low':
      default:
        return Colors.green.shade600;
    }
  }

  List<Color> _getDifficultyGradient(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'high':
        return [
          Colors.red.shade500,
          Colors.red.shade700,
          Colors.deepOrange.shade800,
        ];
      case 'medium':
        return [
          Colors.orange.shade400,
          Colors.orange.shade600,
          Colors.amber.shade700,
        ];
      case 'low':
      default:
        return [
          Colors.green.shade400,
          Colors.green.shade600,
          Colors.teal.shade700,
        ];
    }
  }

  IconData _getDifficultyIcon(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'high':
        return Icons.whatshot; // Fire icon for high difficulty
      case 'medium':
        return Icons.flash_on; // Lightning for medium difficulty
      case 'low':
      default:
        return Icons.wb_sunny; // Sun icon for low difficulty
    }
  }

  // Unified season card widget for both suggested and difficult seasons
  Widget _buildUnifiedSeasonCard(dynamic seasonData, bool showDifficulty) {
    // Safely cast to Map<String, dynamic>
    final Map<String, dynamic> season = seasonData is Map<String, dynamic>
        ? seasonData
        : Map<String, dynamic>.from(seasonData as Map);

    final String? thumbnail = season['thumbnail'];
    final int seasonId = season['id'] ?? 0;
    final dynamic rawRewards = season['rewards'];
    final Map<String, dynamic>? rewards = rawRewards != null
        ? (rawRewards is Map<String, dynamic>
            ? rawRewards
            : Map<String, dynamic>.from(rawRewards as Map))
        : null;
    final String difficulty = season['difficulty'] ?? 'low';
    final String contentType = season['content_type'] ?? '';
    final bool isReadable = contentType == 'readable';
    final double completionPercentage = (season['completion_percentage'] is int
            ? (season['completion_percentage'] as int).toDouble()
            : season['completion_percentage']?.toDouble()) ??
        0.0;

    // Check if season is unlocked using helper function
    final bool hasUnlocked = isSeasonUnlocked(season);

    // Debug completion percentage
    if (completionPercentage > 0) {
      DebugLogger.info(
          '🎯 Card for "${season['title']}": $completionPercentage% complete - SHOULD SHOW PROGRESS BAR');
    }

    return InkWell(
      onTap: () async {
        try {
          // Always navigate to episode screen - let users see unlock requirements for locked seasons
          final story = context.read<Story>();
          await story.setSelectedSeason({
            'id': seasonId,
            'thumbnail': thumbnail,
            'isCreatorSeason': false,
            ...season,
          });
          Navigator.of(context).pushNamed(EpisodeScreen.routeName);
        } catch (e) {
          final seasonType =
              showDifficulty ? 'difficult season' : 'suggested season';
          DebugLogger.info('Error navigating to $seasonType: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to open season'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
            // Add difficulty-based glow only for difficult seasons
            if (showDifficulty) ...[
              BoxShadow(
                color: _getDifficultyColor(difficulty).withValues(alpha: 0.2),
                blurRadius: 12,
                spreadRadius: 0,
                offset: Offset(0, 0),
              ),
            ],
          ],
          border: showDifficulty
              ? Border.all(
                  color: _getDifficultyColor(difficulty).withValues(alpha: 0.3),
                  width: 1,
                )
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              // Thumbnail Image
              Positioned.fill(
                child: thumbnail != null && thumbnail.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: thumbnail,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[800],
                          child: ShimmerLoading(
                            child: Container(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[800],
                          child: Icon(
                            isReadable ? Icons.menu_book : Icons.movie,
                            color: Colors.grey[400],
                            size: 30,
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: Icon(
                          isReadable ? Icons.phone : Icons.movie,
                          color: Colors.grey[400],
                          size: 30,
                        ),
                      ),
              ),

              // Gradient overlay for the specified filter effect
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.2),
                ),
              ),

              // Play icon for continue watching video items only
              if (!isReadable && completionPercentage > 0.0)
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Color(0xFFFFE88C),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isReadable ? Icons.menu_book : Icons.play_arrow,
                        color: Color(0xFFFFE88C),
                        size: 14,
                      ),
                    ),
                  ),
                ),

              // Book badge for readable content (always visible)
              if (isReadable)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.menu_book,
                      color: Color(0xFFFFE88C),
                      size: 12,
                    ),
                  ),
                ), // Gradient overlay and content
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Difficulty level display (only for difficult seasons)
                      if (showDifficulty) ...[
                        Flexible(
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 1500),
                            curve: Curves.easeInOut,
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _getDifficultyGradient(difficulty),
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                stops: [0.0, 0.6, 1.0],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: _getDifficultyColor(difficulty)
                                      .withValues(
                                    alpha: difficulty.toLowerCase() == 'high'
                                        ? 0.6
                                        : 0.4,
                                  ),
                                  blurRadius: difficulty.toLowerCase() == 'high'
                                      ? 8
                                      : 6,
                                  spreadRadius:
                                      difficulty.toLowerCase() == 'high'
                                          ? 1
                                          : 0,
                                  offset: Offset(0, 2),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getDifficultyIcon(difficulty),
                                  size: 8,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    difficulty.toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],

                      // Rewards section - Full width
                      if (rewards != null) ...[
                        Container(
                          width: double.infinity,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Product reward
                              if (rewards['product'] != null &&
                                  rewards['product'] > 0) ...[
                                Flexible(
                                  flex: 1,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      FaIcon(
                                        FontAwesomeIcons.gift,
                                        color: Color(0xFFF96544),
                                        size: 10,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${rewards['product']}',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w400,
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Reward points
                              if (rewards['reward_points'] != null &&
                                  rewards['reward_points'] > 0) ...[
                                Flexible(
                                  flex: 1,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: Colors.amber,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Image.asset(
                                            'assets/images/coins.png',
                                            width: 9,
                                            height: 10,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${rewards['reward_points']}',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w400,
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Achievement
                              if (rewards['achievement'] != null &&
                                  rewards['achievement'] > 0) ...[
                                Flexible(
                                  flex: 1,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SvgPicture.asset(
                                        'assets/svgs/star-badge-solid.svg',
                                        width: 9,
                                        height: 9,
                                        colorFilter: ColorFilter.mode(
                                          Color(0xFFA7DCFF),
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${rewards['achievement']}',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w400,
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      // Completion percentage for continue watching items (video only)
                      if (!isReadable && completionPercentage > 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: completionPercentage / 100,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFFFE88C),
                                    Color(0xFFFFD700),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFFFFE88C)
                                        .withValues(alpha: 0.5),
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Lock indicator (enhanced visibility)
              // Show lock when season is not unlocked (same logic as StoryCard)
              if (!hasUnlocked)
                Positioned(
                  top: 8,
                  left: 8,
                  child: SvgPicture.asset(
                    'assets/svgs/lock.svg',
                    width: 10.5,
                    height: 14,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultSeasonsSection() {
    return Selector<Story, List<dynamic>>(
      selector: (context, story) => story.difficultSeasons,
      builder: (context, difficultSeasons, child) {
        // Add safety check to prevent widget disposal errors
        if (!mounted) return SizedBox.shrink();

        // Use cached data if provider data is empty but cache has data
        List<dynamic> difficultSeasonsToShow = difficultSeasons.isNotEmpty
            ? difficultSeasons
            : _cachedDifficultSeasons;

        // Update cache if provider has newer data
        if (difficultSeasons.isNotEmpty &&
            difficultSeasons != _cachedDifficultSeasons) {
          _cachedDifficultSeasons = List<dynamic>.from(difficultSeasons);
          DebugLogger.info(
              '🎯 CACHE: Updated difficult seasons cache with ${_cachedDifficultSeasons.length} categories');
        }

        // Reduce debug frequency to prevent log spam
        if (_lastKnownDifficultCount != difficultSeasonsToShow.length) {
          _lastKnownDifficultCount = difficultSeasonsToShow.length;
          DebugLogger.info(
              '🎯 UI: Building difficult seasons section - ${difficultSeasonsToShow.length} categories');

          // Only log details if there are actual categories to show
          if (difficultSeasonsToShow.isNotEmpty) {
            for (int i = 0; i < difficultSeasonsToShow.length; i++) {
              final category = difficultSeasonsToShow[i];
              final String title = category['heading_title'] ?? 'Unknown';
              final List<dynamic> seasons = category['seasons'] ?? [];
              DebugLogger.info(
                  '🎯 Category "$title": ${seasons.length} seasons');
            }
          }
        }

        // Don't show empty state if we have cached data
        if (difficultSeasonsToShow.isEmpty) {
          // Only log warning once to prevent spam
          if (_lastKnownDifficultCount != 0) {
            DebugLogger.info(
                '🎯 INFO: No difficult seasons available (API may have failed)');
          }
          return SizedBox.shrink();
        }

        // Split categories into groups to insert challenges between them
        List<Widget> sections = [];

        try {
          for (int i = 0; i < difficultSeasonsToShow.length; i++) {
            final category = difficultSeasonsToShow[i];
            String title = category['heading_title'] ?? '';
            final List<dynamic> seasons = category['seasons'] ?? [];

            // Transform "Stories" to "Courses" in the title for consistency
            title = title.replaceAll('Stories', 'Courses');

            // Skip categories with no seasons
            if (seasons.isEmpty) {
              continue;
            }

            // Add the difficult season category with error handling
            sections.add(_buildDifficultSeasonCategory(title, seasons));
          }
        } catch (e) {
          DebugLogger.error('Error building difficult seasons: $e');
          return SizedBox.shrink();
        }

        return Column(children: sections);
      },
    );
  }

  Widget _buildSuggestedSeasonsSection() {
    return Selector<Story, List<dynamic>>(
      selector: (context, story) => story.suggestedSeasons,
      builder: (context, suggestedSeasons, child) {
        // Reduce debug logging frequency for performance
        if (_lastKnownSuggestedCount != suggestedSeasons.length) {
          _lastKnownSuggestedCount = suggestedSeasons.length;
          DebugLogger.info(
              '🎬 UI: Building suggested seasons section - ${suggestedSeasons.length} categories');
        }

        // Don't trigger API calls from UI rebuild - only from explicit user actions
        if (suggestedSeasons.isEmpty) {
          return SizedBox.shrink();
        }

        // Split categories into groups to insert challenges between them
        List<Widget> sections = [];

        for (int i = 0; i < suggestedSeasons.length; i++) {
          final category = suggestedSeasons[i];
          final String title = category['heading_title'] ?? '';
          final List<dynamic> seasons = category['seasons'] ?? [];

          // Reduce debug frequency - only log every 5th rebuild
          if (_lastKnownSuggestedCount % 5 == 0) {
            DebugLogger.info(
                '🎬 UI: Building category "$title" with ${seasons.length} seasons');
          }

          // Skip categories with no seasons
          if (seasons.isEmpty) {
            continue;
          }

          // Add the suggested season category
          sections.add(_buildSuggestedSeasonCategory(title, seasons));

          // Add challenges section after the first category
          if (i == 0 && suggestedSeasons.length > 1) {
            sections.add(_buildRewardsSection());
          }
        }

        return Column(children: sections);
      },
    );
  }

  // Unified season category widget for both suggested and difficult seasons
  Widget _buildUnifiedSeasonCategory({
    required String title,
    required List<dynamic> seasons,
    required bool
        isWatchTitle, // true for "Watch $title", false for just "$title"
    required bool
        showDifficulty, // true for difficult seasons, false for suggested
    bool showSeeMore = false, // true to show "See More" button
    String?
        seeMoreQuery, // override search query for See More (null = use title)
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(15),
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
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.8),
              blurRadius: 1,
              spreadRadius: 0,
              offset: Offset(0, 1),
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
            // Section Title
            Row(
              children: [
                Text(
                  isWatchTitle ? '$title Courses' : title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                if (showSeeMore)
                  InkWell(
                    onTap: () {
                      if (seeMoreQuery == 'content_type:readable') {
                        // Show all readable books via search screen with pre-loaded results
                        final storyProvider =
                            Provider.of<Story>(context, listen: false);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SearchScreen(
                              initialQuery: null,
                              preloadedResults: storyProvider.readableSeasons,
                              preloadedTitle: 'All Books',
                            ),
                          ),
                        );
                      } else {
                        Navigator.of(context).pushNamed(
                          '/search-screen',
                          arguments: seeMoreQuery ?? title,
                        );
                      }
                    },
                    child: Text(
                      'See More',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Horizontal scrolling seasons list
            Container(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: seasons.length,
                itemBuilder: (context, index) {
                  final season = seasons[index];

                  // Calculate width to show 3 items with last one 80% visible
                  double screenWidth = MediaQuery.of(context).size.width;
                  double cardWidth;
                  // Available width = screen width - container padding and margins
                  double availableWidth = screenWidth - 44;

                  if (index < 3) {
                    // First 3 cards - equal width
                    cardWidth = availableWidth / 3;
                  } else if (index == 3) {
                    // 4th card - 80% visible to indicate scrolling
                    cardWidth = (availableWidth / 3) * 1;
                  } else {
                    // Rest of the cards - normal width
                    cardWidth = availableWidth / 3;
                  }

                  return Container(
                    width: cardWidth,
                    margin: EdgeInsets.only(
                      right: index == seasons.length - 1 ? 0 : 8.0,
                    ),
                    child: _buildUnifiedSeasonCard(season, showDifficulty),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Legacy wrapper methods for backward compatibility (can be removed later)
  Widget _buildSuggestedSeasonCategory(String title, List<dynamic> seasons) {
    return _buildUnifiedSeasonCategory(
      title: title,
      seasons: seasons,
      isWatchTitle: true,
      showDifficulty: false,
      showSeeMore: true, // Show See More for suggested seasons
    );
  }

  Widget _buildDifficultSeasonCategory(String title, List<dynamic> seasons) {
    return _buildUnifiedSeasonCategory(
      title: title,
      seasons: seasons,
      isWatchTitle: false,
      showDifficulty: true,
    );
  }

  Widget _buildChallengesSection() {
    return Consumer<Challenge>(
      builder: (context, challengeProvider, child) {
        try {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(15),
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
                  BoxShadow(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.8),
                    blurRadius: 1,
                    spreadRadius: 0,
                    offset: Offset(0, 1),
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
                  Row(
                    children: [
                      Text(
                        context.l10n.challenges,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () {
                          final auth =
                              Provider.of<Auth>(context, listen: false);
                          if (auth.isGuest) {
                            GuestAuthHelper.showGuestLoginDialog(
                                context, 'view all challenges');
                            return;
                          }
                          Navigator.of(context)
                              .pushNamed(AllChallengesScreen.routeName);
                        },
                        child: Text(
                          'See More',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (challengeProvider.challenges.isEmpty)
                    Container(
                      height: 60,
                      child: Center(
                        child: Text('No challenges available',
                            style: TextStyle(color: Colors.grey[600])),
                      ),
                    )
                  else
                    Container(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: challengeProvider.challenges.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: EdgeInsets.only(
                              right: index ==
                                      challengeProvider.challenges.length - 1
                                  ? 0
                                  : 6,
                            ),
                            child: _buildChallengeCard(
                                challengeProvider.challenges[index]),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        } catch (e) {
          DebugLogger.info('Error in challenges section: $e');
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(Icons.error_outline, size: 32, color: Colors.red),
                const SizedBox(height: 8),
                Text(
                  'Error loading challenges',
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildBannerAds() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      height: 200, // Increased height for more impact
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
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.8),
            blurRadius: 1,
            spreadRadius: 0,
            offset: Offset(0, 1),
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
        padding: EdgeInsets.all(4), // Padding for the inner content
        child: _sliders.isNotEmpty
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: PageView.builder(
                      controller: _bannerPageController,
                      itemCount: _sliders.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentBannerIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final slider = _sliders[index];
                        final auth = Provider.of<Auth>(context, listen: false);
                        return InkWell(
                          onTap: () async {
                            var gotoUrl = slider['goto'];
                            var gotoPlatformId = slider['goto_platform_id'];
                            var gotoPlatformType = slider['goto_platform_type'];
                            if (auth.isGuest) {
                              GuestAuthHelper.showGuestLoginDialog(
                                  context, 'view gifts');
                              return;
                            }
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
                                  DebugLogger.info('Could not launch $_url');
                                }
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.amber.withValues(alpha: 0.1),
                                  Colors.orange.withValues(alpha: 0.1),
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
                                  ),
                                  child: ShimmerLoading(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          FontAwesomeIcons.image,
                                          color: Colors.amber,
                                          size: 40,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Image not available',
                                          style: TextStyle(
                                            color: Colors.amber,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Enhanced page indicator
                  if (_sliders.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _sliders.asMap().entries.map((entry) {
                          return AnimatedContainer(
                            duration: Duration(milliseconds: 300),
                            width: _currentBannerIndex == entry.key ? 24 : 8,
                            height: 8,
                            margin: EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: _currentBannerIndex == entry.key
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
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
                        FontAwesomeIcons.bullhorn,
                        color: Colors.amber,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Featured Content',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Discover amazing content and offers',
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

  Widget _buildMyListSection() {
    return Selector<Story, List<dynamic>>(
      selector: (context, story) => story.myListItems,
      builder: (context, myListItems, child) {
        // Check if user is authenticated
        if (_authProvider.isGuest) {
          return SizedBox.shrink();
        }

        // Use cached data if provider data is empty but cache has data
        List<dynamic> myListItemsToShow =
            myListItems.isNotEmpty ? myListItems : _cachedMyListItems;

        // Update cache if provider has newer data
        if (myListItems.isNotEmpty && myListItems != _cachedMyListItems) {
          _cachedMyListItems = List<dynamic>.from(myListItems);
          // FIXED: Don't reset positioning to prevent UI jumping
          DebugLogger.info(
              'Updated my list cache - positioning remains stable');
        }

        if (myListItemsToShow.isEmpty) {
          return SizedBox.shrink();
        }

        // Convert My List items to season format for unified widget
        List<dynamic> seasonsForUnifiedWidget = myListItemsToShow.map((item) {
          final season = Map<String, dynamic>.from(item['season'] ?? {});
          return {
            ...season,
            'watched': item['watched'] ?? false,
            'rewards': item['reward_details'] != null
                ? Map<String, dynamic>.from(item['reward_details'])
                : null,
          };
        }).toList();

        return _buildUnifiedSeasonCategory(
          title: 'My List',
          seasons: seasonsForUnifiedWidget,
          isWatchTitle: false,
          showDifficulty: false,
        );
      },
    );
  }

  Widget _buildStoriesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: _isLoading && _cachedFeaturedSeasons.isEmpty
          ? StoryCardSkeleton()
          : Selector<Story, List<Map<String, dynamic>>>(
              selector: (context, story) => story.featuredSeasons,
              builder: (context, featuredSeasons, child) {
                // Add safety check for disposed provider
                try {
                  // Use cached data if story provider data is empty but cache has data
                  List<Map<String, dynamic>> featuredSeasonsToShow =
                      featuredSeasons.isNotEmpty
                          ? featuredSeasons
                          : _cachedFeaturedSeasons;

                  // Update cache if provider has newer data
                  if (featuredSeasons.isNotEmpty &&
                      featuredSeasons != _cachedFeaturedSeasons) {
                    _cachedFeaturedSeasons =
                        List<Map<String, dynamic>>.from(featuredSeasons);
                  }

                  DebugLogger.info(
                      '📺 Featured Seasons: Showing ${featuredSeasonsToShow.length} seasons from API');

                  if (featuredSeasonsToShow.isEmpty) {
                    // If empty after loading, auto-retry once
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted &&
                          !_isLoading &&
                          _cachedFeaturedSeasons.isEmpty) {
                        final story =
                            Provider.of<Story>(context, listen: false);
                        story.fetchFeaturedSeasons().then((_) {
                          if (mounted && story.featuredSeasons.isNotEmpty) {
                            setState(() {
                              _cachedFeaturedSeasons =
                                  List<Map<String, dynamic>>.from(
                                      story.featuredSeasons);
                            });
                          }
                        }).catchError((_) {});
                      }
                    });
                    // Show skeleton while retrying instead of empty state
                    return StoryCardSkeleton();
                  }

                  return Container(
                    height: 380,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (ScrollNotification notification) {
                        if (notification is ScrollUpdateNotification) {
                          setState(() {
                            _scrollPosition = _storiesScrollController.offset;

                            // Calculate current index based on scroll position for individual cards
                            double itemWidth =
                                MediaQuery.of(context).size.width -
                                    90; // Account for peek
                            _currentStoryIndex =
                                (_scrollPosition / itemWidth).round();
                            if (_currentStoryIndex >=
                                featuredSeasonsToShow.length) {
                              _currentStoryIndex =
                                  featuredSeasonsToShow.length - 1;
                            }
                            if (_currentStoryIndex < 0) {
                              _currentStoryIndex = 0;
                            }
                          });
                        }
                        return false;
                      },
                      child: ListView.builder(
                        controller: _storiesScrollController,
                        scrollDirection: Axis.horizontal,
                        physics: BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                            horizontal: 0, vertical: 0), // Remove all padding
                        itemCount: featuredSeasonsToShow.length,
                        itemBuilder: (_, index) {
                          if (index >= featuredSeasonsToShow.length) {
                            return SizedBox.shrink();
                          }

                          return Consumer<TutorialFlowProvider>(
                            builder: (context, tutorial, _) => Container(
                              width: MediaQuery.of(context).size.width - 90,
                              margin: EdgeInsets.only(
                                right: 10,
                                top: 0,
                                bottom: 0,
                              ),
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 600),
                                curve: Curves.easeInOut,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Color(0xFF2A2A2A)
                                          : Colors.white,
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Color(0xFF1E1E1E)
                                          : Colors.grey.shade50,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.black.withValues(alpha: 0.3)
                                          : Colors.grey.withValues(alpha: 0.15),
                                      blurRadius: 20,
                                      spreadRadius: 0,
                                      offset: Offset(0, 8),
                                    ),
                                    BoxShadow(
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : Colors.white.withValues(alpha: 0.8),
                                      blurRadius: 1,
                                      spreadRadius: 0,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : Colors.grey.withValues(alpha: 0.1),
                                    width: 1,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    StoryCard(
                                      index,
                                      featuredSeasonsToShow[index],
                                      _authProvider.user,
                                      'storyScreen',
                                      [],
                                    ),
                                    if (tutorial.currentStep == 5 &&
                                        tutorial.isActive)
                                      Positioned(
                                        right: 30,
                                        child: TutorialIndicator(),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                } catch (e) {
                  DebugLogger.error('Error in stories section: $e');
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 600),
                    curve: Curves.easeInOut,
                    height: 380,
                    padding: const EdgeInsets.all(16),
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
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading stories',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            onScreenReload();
                          },
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return ExitConfirmationDialog.wrapWithExitConfirmation(
      context: context,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: header(
          context: context,
          titleText: context.l10n.courses,
          scaffoldKey: _scaffoldKey,
        ),
        drawer: NavBar(),
        body: (storyPopup['popups']?.isNotEmpty ?? false)
            ? Popup(
                popupArr: storyPopup['popups'] as List<dynamic>,
                child: _upgradeAlertWidget(),
              )
            : _upgradeAlertWidget(),
        bottomNavigationBar: Footer(0),
      ),
    );
  }

  Widget _buildForYouHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          // "For You" text on the left
          Text(
            'Featured Course',
            style: GoogleFonts.poppins(
              textStyle: Theme.of(context).textTheme.displayLarge,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
            ),
          ),

          const Spacer(),

          // Search bar and user points on the right
          Row(
            children: [
              // Search bar
              Container(
                width: 120,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Color(0xFF2A2A2A)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(
                      Icons.search,
                      size: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          hintText: 'Search',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withValues(alpha: 0.5)
                                    : Colors.grey.shade500,
                          ),
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        textAlignVertical: TextAlignVertical.center,
                        onTap: () {
                          // Navigate to search screen when tapped
                          Navigator.of(context).pushNamed('/search-screen');
                        },
                        onChanged: (value) {
                          // Navigate to search screen when user starts typing
                          if (value.isNotEmpty) {
                            Navigator.of(context).pushNamed(
                              '/search-screen',
                              arguments: value,
                            );
                          }
                        },
                        onSubmitted: (value) {
                          // Navigate to search screen with query
                          if (value.trim().isNotEmpty) {
                            Navigator.of(context).pushNamed(
                              '/search-screen',
                              arguments: value.trim(),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // User points
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    PageTransition(
                      child: PointsScreen(),
                      type: PageTransitionType.fade,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(25),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.amber.shade400,
                        Colors.amber.shade600,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 0,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Image.asset(
                          'assets/images/coins.png',
                          width: 20,
                          height: 20,
                          fit: BoxFit.contain,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        '${_authProvider.userAvailableCoins.toString()}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStorytellersSection() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 8), // Reduced padding
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF2A2A2A)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            spreadRadius: 0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Row
          Row(
            children: [
              Text(
                context.l10n.teachers,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () async {
                  final auth = Provider.of<Auth>(context, listen: false);
                  if (auth.isGuest) {
                    await GuestAuthHelper.showGuestLoginDialog(
                      context,
                      'browse tutors',
                    );
                    return;
                  }
                  Navigator.of(context).pushNamed(CreatorsScreen.routeName);
                },
                child: Text(
                  'See More',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Storytellers List
          Consumer<Auth>(
            builder: (_, auth, __) {
              if (auth.creators.isEmpty) {
                return Container(
                  height: 80,
                  child: Center(
                    child: Text(
                      'No tutors available',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                );
              }
              return Container(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  itemCount:
                      auth.creators.length > 10 ? 10 : auth.creators.length,
                  itemBuilder: (_, index) {
                    return _buildStorytellerCard(auth.creators[index]);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _upgradeAlertWidget() {
    if (_authProvider == null || _authProvider.role == null) {
      return const StoryScreenSkeleton();
    }
    return UpgradeAlert(
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
        child: RawScrollbar(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            child: _buildMainContent(),
          ),
        ),
      ),
    );
  }

  // Performance optimized main content without global Consumer
  Widget _buildMainContent() {
    // Calculate positioning if not done yet or if data has changed
    if (!_positioningCalculated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _calculateDifficultSeasonsPositioning();
        }
      });
    }

    return Column(
      children: [
        const SizedBox(height: 8),

        // For You Header with Search and Points
        _buildForYouHeader(),

        // 1. Stories Section
        _buildStoriesSection(),

        // 2. Storytellers Section
        _buildStorytellersSection(),

        // 3. Continue Watching Section
        _buildContinueWatchingSection(),

        // 3.5. Books Section (Readable Seasons)
        _buildBooksSection(),

        // 4. My List Section
        _buildMyListSection(),

        // 5. Conditional Difficult Seasons Section (early position)
        _buildConditionalDifficultSeasonsSection(),

        // 6. Challenges Section
        _buildChallengesSection(),

        // 7. Suggested Seasons Section (Netflix-style)
        _buildSuggestedSeasonsSection(),

        // AdMob Banner Ad
        const BaakhaBannerAd(),

        // 8. Banner Ads
        _buildBannerAds(),

        // 9. Difficult Seasons Section (default position)
        _buildDefaultDifficultSeasonsSection(),

        // AdMob Banner Ad
        const BaakhaBannerAd(),

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildBooksSection() {
    return Selector<Story, List<dynamic>>(
      selector: (context, story) => story.readableSeasons,
      builder: (context, readableSeasons, child) {
        // Use cached data if provider data is empty but cache has data
        List<dynamic> readableSeasonsToShow = readableSeasons.isNotEmpty
            ? readableSeasons
            : _cachedReadableSeasons;

        // Update cache if provider has newer data
        if (readableSeasons.isNotEmpty &&
            readableSeasons != _cachedReadableSeasons) {
          _cachedReadableSeasons = List<dynamic>.from(readableSeasons);
        }

        if (readableSeasonsToShow.isEmpty) {
          if (!_isLoading && !_booksRetryTriggered) {
            _booksRetryTriggered = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) return;
              try {
                final storyProvider =
                    Provider.of<Story>(context, listen: false);
                await storyProvider.fetchReadableSeasons();
              } catch (e) {
                DebugLogger.error('Books section retry failed: $e');
              } finally {
                if (mounted) {
                  setState(() {
                    _booksRetryTriggered = false;
                  });
                }
              }
            });
          }
          return SizedBox.shrink();
        }

        // One-time interest prompt check
        if (!_hasCheckedInterestPrompt) {
          _hasCheckedInterestPrompt = true;
          _checkInterestPrompt();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_showInterestPrompt) _buildInterestPromptBanner(),
            _buildUnifiedSeasonCategory(
              title: 'Books 📖',
              seasons: readableSeasonsToShow,
              isWatchTitle: false,
              showDifficulty: false,
              showSeeMore: true,
              seeMoreQuery:
                  'content_type:readable', // special marker for showing all books
            ),
          ],
        );
      },
    );
  }

  void _checkInterestPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool('interest_prompt_dismissed') ?? false;
    if (dismissed) return;

    // Also check if user already has interests saved
    try {
      final auth = Provider.of<Auth>(context, listen: false);
      final response = await http
          .get(
            Uri.parse(Url.baakhapaaApi('/user/interests')),
            headers: Url.baakhapaaAuthHeaders(auth.token),
          )
          .timeout(const Duration(seconds: 5));
      final data = json.decode(utf8.decode(response.bodyBytes));
      final interests = data['data']?['interests'] ?? [];
      if (interests is List && interests.isNotEmpty) {
        // User already has interests, dismiss permanently
        await prefs.setBool('interest_prompt_dismissed', true);
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _showInterestPrompt = true);
    }
  }

  Widget _buildInterestPromptBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade800, Colors.orange.shade700],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Text('🎯', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personalize your books',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Pick your favorite genres for better recommendations',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              final result =
                  await Navigator.of(context).pushNamed('/interest-selection');
              if (result == true && mounted) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('interest_prompt_dismissed', true);
                setState(() => _showInterestPrompt = false);
                // Refresh readable seasons with personalized sorting
                Provider.of<Story>(context, listen: false)
                    .fetchReadableSeasons();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Pick',
                style: TextStyle(
                  color: Colors.amber.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('interest_prompt_dismissed', true);
              if (mounted) setState(() => _showInterestPrompt = false);
            },
            child: const Icon(Icons.close, color: Colors.white54, size: 20),
          ),
        ],
      ),
    );
  }

  // Shows difficult seasons in early position
  Widget _buildConditionalDifficultSeasonsSection() {
    // FIXED: Always return empty since we show at bottom consistently
    return SizedBox.shrink();
  }

  // Shows difficult seasons in default position only if user HAS continue watching OR my list items
  Widget _buildDefaultDifficultSeasonsSection() {
    // FIXED: Always show at bottom for consistency - no conditional logic
    if (!mounted) return SizedBox.shrink();

    DebugLogger.info(
        '🎯 POSITIONING: Always showing difficult seasons at BOTTOM for stability');

    return _buildDifficultSeasonsSection();
  }
}
