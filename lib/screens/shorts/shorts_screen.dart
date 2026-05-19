import 'dart:io';

import 'package:baakhapaa/providers/tutorial_flow_provider.dart';
import 'package:baakhapaa/providers/video_state_provider.dart';
import 'package:baakhapaa/utils/exit_confirmation_dialog.dart';
import 'package:baakhapaa/widgets/affilated_product.dart';
import 'package:baakhapaa/widgets/language_selector_popup.dart';
import 'package:baakhapaa/widgets/popup.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upgrader/upgrader.dart';
import 'package:filter_list/filter_list.dart';

import '../../providers/shorts.dart';
import '../../providers/auth.dart';
import '../../models/short_topic.dart';
import '../../models/url.dart';
// ignore: unused_import
import '../../widgets/footer.dart';
import '../../widgets/shorts_side_bar.dart';
import '../../widgets/shorts_detail.dart';
import '../../widgets/shorts_video_tile.dart';
import '../../widgets/puppet_dashboard.dart';
import '../../helpers/helpers.dart';
import '../../widgets/my_upgrader_messages.dart';
import '../../widgets/skeleton_loading.dart';
import '../../utils/guest_auth_helper.dart';
import '../../utils/puppet_screen_mapping.dart';
import '../../utils/debug_logger.dart';
import '../../services/ad_service.dart';
import '../../services/analytics_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../navigation/root_navigator_key.dart' show mainNavigatorKey;
import './challenges_screen.dart';

class ShortsScreen extends StatefulWidget {
  static const routeName = '/shorts-screen';

  const ShortsScreen({Key? key}) : super(key: key);

  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen>
    with
        WidgetsBindingObserver,
        RouteAware,
        SingleTickerProviderStateMixin,
        PuppetInteractionMixin {
  bool _isInit = false;
  bool _isLoading = true;
  int _snappedPageIndex = 0;
  late List<dynamic> _shorts = [];
  final GlobalKey _quizButtonKey = GlobalKey(debugLabel: 'quiz_button_key');
  bool _isLoadingMoreShorts = false;
  final PageController _pageController = PageController();
  VideoStateProvider? _videoStateProvider;
  bool _hasOpenedFilter = false;
  late List<ShortTopic> _shortTopic = [];
  late List<ShortTopic> selectedShortTopicList = [];
  bool _languageChecked = false;

  // Track video state better
  bool _isReturningFromWin = false;
  bool _isTapping = false; // Debounce for tap events

  @override
  void initState() {
    super.initState();
    DebugLogger.puppet('ShortsScreen: initState called');
    _checkLanguageSelected();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        DebugLogger.puppet('ShortsScreen: Post-frame callback');

        final tutorialProvider =
            Provider.of<TutorialFlowProvider>(context, listen: false);
        if (tutorialProvider.currentStep == 0 && tutorialProvider.isActive) {
          tutorialProvider.nextStep();
          tutorialProvider.showCurrentStepMessage(context);
        } else if (tutorialProvider.currentStep == 1 &&
            tutorialProvider.isActive) {
          Future.delayed(Duration(milliseconds: 50), () {
            if (mounted) {
              tutorialProvider.showTutorialFor(context, 'quiz_icon');
            }
          });
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final videoStateProvider =
          Provider.of<VideoStateProvider>(context, listen: false);
      videoStateProvider.setScreen('shorts');
    });
  }

  Future<void> _checkLanguageSelected() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedLanguage = prefs.getString('selectedLanguage');

    if (selectedLanguage == null) {
      // show language selector popup as dialog
      Future.delayed(Duration.zero, () async {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const LanguageSelectorPopup(),
        );
      });
    }

    setState(() {
      _languageChecked = true;
    });
  }

  void _navigateToChallenges() async {
    final authProvider = Provider.of<Auth>(context, listen: false);
    if (!authProvider.isAuth) {
      bool shouldLogin =
          await GuestAuthHelper.showGuestLoginDialog(context, 'challenges');
      if (!shouldLogin) {
        return;
      }
      return;
    }

    // Pause current video before navigation
    _videoStateProvider?.pauseVideo();
    _videoStateProvider?.clearAllActiveVideos();

    Navigator.of(context).pushReplacementNamed(ChallengesScreen.routeName);
  }

  @override
  void dispose() {
    // Ensure all videos are properly stopped before disposing
    // Use post frame callback to avoid calling during widget tree lock
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _videoStateProvider?.pauseVideo();
      _videoStateProvider?.setScreen('');
    });

    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final videoStateProvider =
        Provider.of<VideoStateProvider>(context, listen: false);

    switch (state) {
      case AppLifecycleState.resumed:
        if (videoStateProvider.currentScreen == 'shorts') {
          // Only play if we're not navigating to create screen and not returning from win
          if (!videoStateProvider.isNavigatingToCreate &&
              !_isReturningFromWin) {
            videoStateProvider.playVideo();
          }
        }
        break;
      case AppLifecycleState.paused:
        // Always pause when app goes to background
        videoStateProvider.pauseVideo();
        break;
      default:
        break;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_videoStateProvider == null) {
      _videoStateProvider =
          Provider.of<VideoStateProvider>(context, listen: false);
    }

    if (!_isInit) {
      final arguments =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (arguments != null) {
        // Handle navigation from win/lose screen with specific video
        final returnToShortsId = arguments['returnToShortsId'] as int?;
        final fromWinScreen = arguments['fromWinScreen'] as bool? ?? false;

        if (returnToShortsId != null) {
          _isReturningFromWin = fromWinScreen;

          // Ensure we're in clean state for shorts
          _videoStateProvider?.setScreen('shorts');

          _loadInitialData().then((_) {
            if (mounted) {
              _handleVideoNavigation(returnToShortsId, fromWinScreen);
            }
          });
        } else {
          // Normal initialization
          _videoStateProvider?.setScreen('shorts');
          _loadInitialData().then((_) {
            if (mounted) {
              _initializeVideoState();
            }
          });
        }
      } else {
        // No arguments - normal initialization
        _videoStateProvider?.setScreen('shorts');
        _loadInitialData().then((_) {
          if (mounted) {
            _initializeVideoState();
          }
        });
      }

      _isInit = true;
    }
  }

// Add this helper method for normal video initialization
  void _initializeVideoState() {
    DebugLogger.info('🚀 ShortsScreen: _initializeVideoState(); called');
    if (!mounted) {
      return;
    }

    // Clean state completely
    _videoStateProvider?.exitQuiz();
    _videoStateProvider?.exitResultScreen();

    // Clear all active videos to prevent background playback from other screens
    _videoStateProvider?.clearAllActiveVideos();

    _videoStateProvider?.setScreen('shorts');

    // Ensure we have shorts to play
    if (_shorts.isEmpty) {
      return;
    }

    // Force play the first video
    _videoStateProvider?.forcePlayVideo();

    // Single backup attempt to handle edge case where controller wasn't ready
    Future.delayed(Duration(milliseconds: 300), () {
      if (mounted &&
          _shorts.isNotEmpty &&
          !_videoStateProvider!.isInQuiz &&
          !_videoStateProvider!.isInResultScreen) {
        _videoStateProvider?.forcePlayVideo();
      }
    });
  }

  Future<void> _loadInitialData() async {
    final shortsProvider = Provider.of<Shorts>(context, listen: false);
    final authProvider = Provider.of<Auth>(context, listen: false);

    setState(() {
      _isLoading = true;
    });

    try {
      // Load shorts for "For You" tab only
      await shortsProvider.fetchShorts();
      setState(() {
        _shorts = shortsProvider.shorts;
      });

      // Load short topics for filter
      await shortsProvider.fetchShortsTopic();
      setState(() {
        _shortTopic = shortsProvider.shortsTopic
            .map<ShortTopic>((item) => ShortTopic(
                  id: item['id'] as int,
                  title: item['title'] as String,
                ))
            .toList();
      });

      // Fetch creators for storytellers section
      if (mounted) {
        try {
          await authProvider.fetchCreators();
          if (mounted) {
            setState(() {});
          }
        } catch (e) {
          DebugLogger.error('Error fetching creators: $e');
        }
      }
    } catch (error) {
      DebugLogger.error('Error loading shorts: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // New method to handle video navigation more cleanly
  void _handleVideoNavigation(int returnToShortsId, bool fromWinScreen) {
    DebugLogger.info(
        '🎯 ShortsScreen: _handleVideoNavigation called with ID: $returnToShortsId, fromWin: $fromWinScreen');

    // Validate the video ID
    if (returnToShortsId <= 0) {
      DebugLogger.error(
          '❌ ShortsScreen: Invalid video ID: $returnToShortsId, navigating to first video');
      _navigateToVideoIndex(0, fromWinScreen);
      return;
    }

    // First check if video exists in current shorts
    int indexToJumpTo =
        _shorts.indexWhere((short) => short['id'] == returnToShortsId);
    DebugLogger.info(
        '🔍 ShortsScreen: Searching for video ID $returnToShortsId in ${_shorts.length} shorts, found at index: $indexToJumpTo');

    // If found and coming from win screen, advance to next video if possible
    if (fromWinScreen &&
        indexToJumpTo != -1 &&
        indexToJumpTo + 1 < _shorts.length) {
      indexToJumpTo += 1; // Move to next video after winning
      DebugLogger.info(
          '🏆 ShortsScreen: Moving to next video after win, new index: $indexToJumpTo');
    }

    // If video found in current list, navigate to it
    if (indexToJumpTo != -1) {
      DebugLogger.success(
          '✅ ShortsScreen: Video found locally, navigating to index: $indexToJumpTo');
      _navigateToVideoIndex(indexToJumpTo, fromWinScreen);
    } else {
      // If not found, try to load more videos to find it
      DebugLogger.info(
          '🔄 ShortsScreen: Video not found locally, loading additional pages...');
      _loadAdditionalPagesUntilVideoFound(returnToShortsId, fromWinScreen);
    }
  }

  void _navigateToVideoIndex(int index, bool fromWinScreen) {
    // Clean up video state completely
    _videoStateProvider?.exitQuiz();
    _videoStateProvider?.exitResultScreen();
    _videoStateProvider?.clearAllActiveVideos();
    _videoStateProvider?.setScreen('shorts');

    Future.delayed(Duration(milliseconds: 200), () {
      if (mounted && _pageController.hasClients && index < _shorts.length) {
        _pageController.jumpToPage(index);

        // Reset state and start video
        Future.delayed(Duration(milliseconds: 400), () {
          if (mounted) {
            setState(() {
              _isReturningFromWin = false;
              _snappedPageIndex = index;
            });

            _videoStateProvider?.forcePlayVideo();

            // Multiple backup attempts to ensure video starts
            for (int delay in [300, 800, 1500]) {
              Future.delayed(Duration(milliseconds: delay), () {
                if (mounted &&
                    !_videoStateProvider!.isInQuiz &&
                    !_videoStateProvider!.isInResultScreen &&
                    _snappedPageIndex == index) {
                  _videoStateProvider?.forcePlayVideo();
                }
              });
            }
          }
        });
      } else if (mounted) {
        // PageController not ready yet - retry after more time
        Future.delayed(Duration(milliseconds: 500), () {
          if (mounted && _pageController.hasClients && index < _shorts.length) {
            _pageController.jumpToPage(index);
            setState(() {
              _isReturningFromWin = false;
              _snappedPageIndex = index;
            });
            _videoStateProvider?.forcePlayVideo();
          }
        });
      }
    });

    _videoStateProvider?.clearQuizSource();
  }

  Future<void> _loadAdditionalPagesUntilVideoFound(
      int shortsId, bool advanceToNext) async {
    DebugLogger.info(
        '🔍 ShortsScreen: _loadAdditionalPagesUntilVideoFound called - ID: $shortsId, advance: $advanceToNext');
    if (!mounted) {
      DebugLogger.error(
          'ShortsScreen: Widget not mounted, cancelling video search');
      return;
    }

    // Validate video ID
    if (shortsId <= 0) {
      DebugLogger.error(
          '❌ ShortsScreen: Invalid shortsId: $shortsId, jumping to first video');
      if (_shorts.isNotEmpty && _pageController.hasClients) {
        _navigateToVideoIndex(0, advanceToNext);
      }
      return;
    }

    final shortsProvider = Provider.of<Shorts>(context, listen: false);
    int maxAttempts = 3; // Reduced further for invalid IDs
    int attempts = 0;
    bool foundVideo = false;

    DebugLogger.info('🔄 ShortsScreen: Setting loading state for video search');
    setState(() {
      _isLoadingMoreShorts = true;
    });

    // Pause any playing videos during loading
    DebugLogger.info('⏸️ ShortsScreen: Pausing videos during search');
    _videoStateProvider?.pauseVideo();
    _videoStateProvider?.setScreen('shorts');

    DebugLogger.info('🎯 ShortsScreen: Looking for video with ID: $shortsId');

    while (
        !foundVideo && attempts < maxAttempts && shortsProvider.hasMorePages) {
      attempts++;
      DebugLogger.info('Attempt $attempts to find video $shortsId');

      try {
        // Load more shorts based on current filter state
        if (shortsProvider.filtered) {
          DebugLogger.info('🔍 ShortsScreen: Loading more filtered shorts...');
          await shortsProvider.loadMoreFilteredShorts();
        } else {
          DebugLogger.info('📥 ShortsScreen: Loading more regular shorts...');
          await shortsProvider.loadMoreShorts();
        }

        List<dynamic> updatedShorts = shortsProvider.shorts;

        if (!mounted) {
          DebugLogger.error(
              'ShortsScreen: Widget no longer mounted during loading');
          return;
        }

        DebugLogger.info(
            '📋 ShortsScreen: Updating shorts list with ${updatedShorts.length} items');
        // Update the shorts list
        setState(() {
          _shorts = List.from(updatedShorts);
        });

        // Search for the video in updated list
        int indexToJumpTo =
            _shorts.indexWhere((short) => short['id'] == shortsId);

        if (indexToJumpTo != -1) {
          foundVideo = true;
          DebugLogger.success(
              'ShortsScreen: Found video at index: $indexToJumpTo');

          if (advanceToNext && indexToJumpTo + 1 < _shorts.length) {
            indexToJumpTo += 1;
            DebugLogger.info(
                '⏭️ ShortsScreen: Advancing to next video, new index: $indexToJumpTo');
          }

          _navigateToVideoIndex(indexToJumpTo, advanceToNext);
          break;
        } else {
          DebugLogger.error(
              'ShortsScreen: Video $shortsId not found in current page');
        }
      } catch (error) {
        DebugLogger.error('ShortsScreen: Error loading more shorts: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error loading videos: ${error.toString()}')),
          );
        }
        break;
      }
    }

    if (mounted) {
      DebugLogger.info('🔄 ShortsScreen: Resetting loading state after search');
      setState(() {
        _isLoadingMoreShorts = false;
      });

      if (!foundVideo) {
        DebugLogger.error(
            '❌ ShortsScreen: Video $shortsId not found after $attempts attempts');

        // Fallback to first video
        if (_shorts.isNotEmpty && _pageController.hasClients) {
          DebugLogger.info('🔄 ShortsScreen: Falling back to first video');
          _navigateToVideoIndex(0, false);
        }
      } else {
        DebugLogger.success(
            '✅ ShortsScreen: Successfully found and navigated to video $shortsId');
      }
    }
  }

  void _playOrPauseVideo() {
    // Debounce rapid taps
    if (_isTapping) {
      return;
    }
    _isTapping = true;
    Future.delayed(Duration(milliseconds: 300), () {
      _isTapping = false;
    });

    if (!mounted) {
      return;
    }

    final videoStateProvider =
        Provider.of<VideoStateProvider>(context, listen: false);

    if (videoStateProvider.isNavigatingWithAssistiveTouch) {
      videoStateProvider.setNavigatingWithAssistiveTouch(false);
    }

    if (videoStateProvider.isPlaying) {
      videoStateProvider.pauseVideo();
    } else {
      videoStateProvider.playVideo();
    }
  }

  void _pauseVideo() {
    final videoStateProvider =
        Provider.of<VideoStateProvider>(context, listen: false);
    videoStateProvider.pauseVideo();
  }

  Future<void> _loadMoreShorts() async {
    if (_isLoadingMoreShorts) {
      return;
    }

    final shortsProvider = Provider.of<Shorts>(context, listen: false);

    if (!shortsProvider.hasMorePages) {
      DebugLogger.info('📄 ShortsScreen: No more pages available');
      return;
    }

    DebugLogger.info('📥 ShortsScreen: Starting to load more shorts...');

    // Set loading state BEFORE setState to prevent race condition
    _isLoadingMoreShorts = true;

    setState(() {
      // State already updated above
    });

    try {
      DebugLogger.info(
          '📡 ShortsScreen: Calling provider to fetch more shorts');
      if (shortsProvider.filtered) {
        await shortsProvider.loadMoreFilteredShorts();
      } else {
        await shortsProvider.loadMoreShorts();
      }

      if (mounted) {
        DebugLogger.info(
            '✅ ShortsScreen: Successfully loaded more shorts, updating state');
        setState(() {
          _shorts = List.from(
              shortsProvider.shorts); // Create new list to trigger rebuild
        });
        DebugLogger.info(
            '📊 ShortsScreen: Updated shorts list, now has ${_shorts.length} items');
      }
    } catch (error) {
      DebugLogger.error('❌ ShortsScreen: Error loading more shorts: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load more shorts: ${error.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        DebugLogger.info('🏁 ShortsScreen: Resetting loading state');
        setState(() {
          _isLoadingMoreShorts = false;
        });
      }
    }
  }

  void _onPageChanged(int index) {
    DebugLogger.info('📄 ShortsScreen: _onPageChanged called - index: $index');
    if (!mounted) {
      DebugLogger.error('ShortsScreen: Widget not mounted in _onPageChanged');
      return;
    }

    // Show interstitial ad every N shorts viewed — delayed to avoid interrupting scroll
    if (AdService().incrementShortsViewAndCheckAd()) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          AdService().showInterstitial(
            context: context,
            onAdDismissed: () {
              // Resume video after ad closes
              if (mounted && _videoStateProvider != null) {
                _videoStateProvider!.forcePlayVideo();
              }
            },
          );
        }
      });
    }

    setState(() {
      _snappedPageIndex = index;
    });
    DebugLogger.info('📱 ShortsScreen: Updated snapped page index to: $index');

    // Track shorts viewed event
    if (_shorts.isNotEmpty && index < _shorts.length) {
      final short = _shorts[index];
      AnalyticsService.logShortsViewed(
        shortsId: short['id'] is int
            ? short['id']
            : int.tryParse(short['id'].toString()) ?? 0,
        topicName: short['topic']?['title'],
      );
    }

    if (_shorts.isNotEmpty && index < _shorts.length) {
      final videoStateProvider = _videoStateProvider;
      if (videoStateProvider != null) {
        // Save position first
        DebugLogger.info(
            '💾 ShortsScreen: Saving position - index: $index, id: ${_shorts[index]['id']}');
        videoStateProvider.saveCurrentShortsPosition(
            index, _shorts[index]['id']);

        // Only start video if not in quiz or result screen
        if (!videoStateProvider.isInQuiz &&
            !videoStateProvider.isInResultScreen) {
          DebugLogger.info(
              '▶️ ShortsScreen: Immediately playing video for index: $index');

          // Clear all active videos first to allow new video to register
          videoStateProvider.clearAllActiveVideos();

          // Immediately force play without delay for responsive video switching
          videoStateProvider.forcePlayVideo();

          // Add a backup attempt to ensure video plays
          Future.delayed(Duration(milliseconds: 100), () {
            if (mounted &&
                _snappedPageIndex == index &&
                !videoStateProvider.isInQuiz &&
                !videoStateProvider.isInResultScreen) {
              DebugLogger.info(
                  '🔄 ShortsScreen: Backup video play attempt for index: $index');
              videoStateProvider.forcePlayVideo();
            }
          });

          // Reset the returning from win flag after starting video
          if (_isReturningFromWin) {
            DebugLogger.info(
                '🏆 ShortsScreen: Resetting returning from win flag');
            setState(() {
              _isReturningFromWin = false;
            });
          }
        } else {
          DebugLogger.info(
              '🚫 ShortsScreen: Video playback blocked - inQuiz: ${videoStateProvider.isInQuiz}, inResult: ${videoStateProvider.isInResultScreen}');
        }
      } else {
        DebugLogger.error('ShortsScreen: Video state provider is null');
      }
    } else {
      DebugLogger.error(
          '❌ ShortsScreen: Invalid shorts state - count: ${_shorts.length}, index: $index');
    }

    // Load more shorts if approaching end (3 items before end for smoother loading)
    final shortsProvider = Provider.of<Shorts>(context, listen: false);
    DebugLogger.info(
        '📊 ShortsScreen: Pagination check - index: $index, length: ${_shorts.length}, threshold: ${_shorts.length - 3}, isLoading: $_isLoadingMoreShorts, hasMore: ${shortsProvider.hasMorePages}');

    if (index >= _shorts.length - 3 && !_isLoadingMoreShorts) {
      DebugLogger.info(
          '🔄 ShortsScreen: Near end of list (index $index of ${_shorts.length}), loading more shorts...');
      _loadMoreShorts();
    } else {
      DebugLogger.info(
          '⏭️ ShortsScreen: Skipping load more - condition not met or already loading');
    }
  }

  void fetchFilteredShorts(List<ShortTopic> shortTopics) {
    setState(() {
      _isLoading = true;
    });

    var updatedShorts = Provider.of<Shorts>(context, listen: false);
    updatedShorts.filterShorts(shortTopics).then((_) {
      showScaffoldMessenger(context, 'Short topics filter activated.');
      setState(() {
        _shorts.clear();
        _shorts.addAll(updatedShorts.shorts);
        _isLoading = false;
        _snappedPageIndex = 0; // Reset to first video
      });

      // Immediately start playing the first video
      if (mounted && updatedShorts.shorts.isNotEmpty) {
        _videoStateProvider?.forcePlayVideo();
      }
    }).catchError((error) {
      throw ('Error fetching Short topics: $error');
    });
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).canvasColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  context.l10n.filterShortStories,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Divider(),
                ListTile(
                  leading: Icon(Icons.category, color: Colors.blue),
                  title: Text(context.l10n.shortStoriesTopics),
                  onTap: () {
                    Navigator.pop(context);
                    var shorts = Provider.of<Shorts>(context, listen: false);
                    shorts.fetchShortsTopic().then((_) {
                      if (!_hasOpenedFilter) {
                        setState(() {
                          _shortTopic = shorts.shortsTopic
                              .map((item) => ShortTopic(
                                    id: item['id'] as int,
                                    title: item['title'] as String,
                                  ))
                              .toList();
                          selectedShortTopicList = _shortTopic;
                          _hasOpenedFilter = true;
                        });
                      }
                      _openFilterDialog();
                    });
                  },
                ),
                Divider(),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(context.l10n.sortBy,
                        style: Theme.of(context).textTheme.labelLarge),
                  ),
                ),
                ListTile(
                  leading:
                      Icon(Icons.thumb_up_alt_outlined, color: Colors.pink),
                  title: Text(context.l10n.mostLiked),
                  onTap: () {
                    Navigator.pop(context);
                    fetchMostLikedShorts();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.attach_money, color: Colors.amber[700]),
                  title: Text(context.l10n.mostPoints),
                  onTap: () {
                    Navigator.pop(context);
                    fetchMostPointsShorts();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.shuffle, color: Colors.green),
                  title: Text(context.l10n.random),
                  onTap: () {
                    Navigator.pop(context);
                    fetchRandomShorts();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.update, color: Colors.blueGrey),
                  title: Text(context.l10n.latest),
                  onTap: () {
                    Navigator.pop(context);
                    fetchLatestShorts();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.history, color: Colors.deepPurple),
                  title: Text(context.l10n.oldest),
                  onTap: () {
                    Navigator.pop(context);
                    fetchOldestShorts();
                  },
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openFilterDialog() async {
    await FilterListDialog.display<ShortTopic>(
      context,
      listData: _shortTopic,
      selectedListData: [],
      choiceChipLabel: (st) => st!.title,
      validateSelectedItem: (list, val) => list!.contains(val),
      onItemSearch: (st, query) {
        return st.title!.toLowerCase().contains(query.toLowerCase());
      },
      onApplyButtonClick: (list) {
        setState(() {
          selectedShortTopicList = List.from(list as Iterable);
        });
        Navigator.pop(context);
        fetchFilteredShorts(selectedShortTopicList);
      },
    );
  }

  void likeAndUnlike(int shortsId) {
    // Get current state values before update
    bool? newLikedState;
    int? newLikesCount;

    // Find and update in the current shorts list first
    int index = _shorts.indexWhere((short) => short['id'] == shortsId);
    if (index != -1) {
      newLikedState = !(_shorts[index]['liked'] ?? false);
      newLikesCount = (_shorts[index]['likes'] ?? 0) + (newLikedState ? 1 : -1);
    }

    if (newLikedState == null || newLikesCount == null) return;

    // Update provider state to persist changes across all lists
    final shortsProvider = Provider.of<Shorts>(context, listen: false);

    // Update in the main provider shorts list (ForYou source)
    int mainIndex =
        shortsProvider.shorts.indexWhere((short) => short['id'] == shortsId);
    if (mainIndex != -1) {
      shortsProvider.shorts[mainIndex]['liked'] = newLikedState;
      shortsProvider.shorts[mainIndex]['likes'] = newLikesCount;
    }

    // Update in challenge shorts list in provider (for when user switches to challenges)
    int challengeIndex = shortsProvider.challengeShorts
        .indexWhere((short) => short['id'] == shortsId);
    if (challengeIndex != -1) {
      shortsProvider.challengeShorts[challengeIndex]['liked'] = newLikedState;
      shortsProvider.challengeShorts[challengeIndex]['likes'] = newLikesCount;
    }

    // Update local _shorts list
    int forYouIndex = _shorts.indexWhere((short) => short['id'] == shortsId);
    if (forYouIndex != -1) {
      _shorts[forYouIndex]['liked'] = newLikedState;
      _shorts[forYouIndex]['likes'] = newLikesCount;
    }

    // Trigger UI rebuild
    if (mounted) {
      setState(() {});
    }

    // Track like event (only when liking, not unliking)
    if (newLikedState == true) {
      AnalyticsService.logShortsLiked(shortsId: shortsId);
    }
  }

  // Helper method for filter functions to ensure consistent video state management
  void _applyFilter(Future<void> Function() filterFunction, String message) {
    setState(() {
      _isLoading = true;
    });

    var updatedShorts = Provider.of<Shorts>(context, listen: false);
    filterFunction().then((_) {
      showScaffoldMessenger(context, message);
      setState(() {
        _shorts.clear();
        _shorts.addAll(updatedShorts.shorts);
        _isLoading = false;
        _snappedPageIndex = 0; // Reset to first video
      });

      // Immediately start playing the first video
      if (mounted && updatedShorts.shorts.isNotEmpty) {
        _videoStateProvider?.forcePlayVideo();
      }
    }).catchError((error) {
      setState(() {
        _isLoading = false;
      });
      throw ('Error applying filter: $error');
    });
  }

  void fetchMostLikedShorts() {
    var updatedShorts = Provider.of<Shorts>(context, listen: false);
    _applyFilter(() => updatedShorts.fetchMostLikedShorts(),
        'Most liked shorts filter activated.');
  }

  void fetchMostPointsShorts() {
    var updatedShorts = Provider.of<Shorts>(context, listen: false);
    _applyFilter(() => updatedShorts.fetchMostPointsShorts(),
        'Most points shorts filter activated.');
  }

  void fetchOldestShorts() {
    var updatedShorts = Provider.of<Shorts>(context, listen: false);
    _applyFilter(() => updatedShorts.fetchOldestShorts(),
        'Oldest shorts filter activated.');
  }

  void fetchLatestShorts() {
    var updatedShorts = Provider.of<Shorts>(context, listen: false);
    _applyFilter(() => updatedShorts.fetchLatestShorts(),
        'Latest shorts filter activated.');
  }

  void fetchRandomShorts() {
    var updatedShorts = Provider.of<Shorts>(context, listen: false);
    _applyFilter(() => updatedShorts.fetchRandomShorts(),
        'Random shorts filter activated.');
  }

  Widget _buildHeader() {
    return Container(
      height: 50,
      margin: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 8,
        right: 80, // Space for filter button
      ),
      child: Row(
        children: [
          // Puppet avatar circle
          Consumer<Auth>(
            builder: (context, auth, _) {
              String puppetUrl = '${Url.mediaUrl}/assets/puppetdev.png';
              try {
                if (auth.puppetImage != null && auth.puppetImage!.isNotEmpty) {
                  puppetUrl = auth.puppetImage!;
                } else {
                  final puppet = auth.user['current_puppet'];
                  if (puppet != null && puppet['image'] != null) {
                    puppetUrl = puppet['image'];
                  }
                }
              } catch (_) {}

              return GestureDetector(
                onTap: () {
                  if (auth.isGuest) {
                    GuestAuthHelper.showGuestLoginDialog(context, 'open menu');
                    return;
                  }
                  PuppetDashboard.show(context, navigatorKey: mainNavigatorKey);
                },
                child: Container(
                  width: 42,
                  height: 42,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF4B625),
                      width: 2,
                    ),
                    color: Colors.grey.shade900,
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: puppetUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => Container(
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.smart_toy,
                            color: Color(0xFFF4B625), size: 20),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.smart_toy,
                            color: Color(0xFFF4B625), size: 20),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // For You / Challenges pill
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // For You button (active)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        color: Colors.white.withValues(alpha: 0.2),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          context.l10n.forYou,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                offset: Offset(1, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Challenges button (navigates to ChallengesScreen)
                  Expanded(
                    child: GestureDetector(
                      onTap: _navigateToChallenges,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Center(
                          child: Text(
                            context.l10n.challenges,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  offset: Offset(1, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ExitConfirmationDialog.wrapWithExitConfirmation(
      context: context,
      child: Scaffold(
        body: !_languageChecked
            ? const ShortsVideoSkeleton()
            : UpgradeAlert(
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
                child: Consumer2<VideoStateProvider, Shorts>(
                  builder: (context, videoState, shortsProvider, _) {
                    if (_isLoading) {
                      return const ShortsVideoSkeleton();
                    } else if (_shorts.isEmpty) {
                      return Stack(
                        children: [
                          Container(color: Colors.black),
                          _buildHeader(),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'No shorts available.',
                                  style: TextStyle(color: Colors.white),
                                ),
                                TextButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context)
                                        .hideCurrentSnackBar();
                                    shortsProvider.clearFilter().then((_) {
                                      Navigator.of(context)
                                          .pushReplacementNamed(
                                              ShortsScreen.routeName);
                                    });
                                  },
                                  child: Text('Clear Filter'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    return Stack(
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          onPageChanged: _onPageChanged,
                          scrollDirection: Axis.vertical,
                          itemCount: _shorts.length,
                          itemBuilder: (context, index) {
                            if (index >= _shorts.length) {
                              return const SizedBox.shrink();
                            }

                            return Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                ShortsVideoTile(
                                  key: ValueKey(
                                      'shorts_${_shorts[index]['id']}'),
                                  video: _shorts[index]['video_url'],
                                  currentIndex: index,
                                  snappedPageIndex: _snappedPageIndex,
                                  isVideoPlaying: videoState.isPlaying &&
                                      _snappedPageIndex == index &&
                                      !videoState.isInQuiz &&
                                      !videoState.isInResultScreen,
                                  onPlayPause: _playOrPauseVideo,
                                  shortsId: _shorts[index]['id'],
                                  likeAndUnlikeCallback: likeAndUnlike,
                                  isLiked: _shorts[index]['liked'] ?? false,
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 8.0, bottom: 8.0),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  // Only show Affiliated Product button if products exist
                                                  if (_shorts[index][
                                                              'linked_content'] !=
                                                          null &&
                                                      _shorts[index][
                                                                  'linked_content']
                                                              ['products'] !=
                                                          null &&
                                                      (_shorts[index][
                                                                  'linked_content']
                                                              [
                                                              'products'] as List)
                                                          .isNotEmpty)
                                                    AnimatedOpacity(
                                                      duration: const Duration(
                                                          milliseconds: 300),
                                                      opacity: _shorts[index][
                                                                  'show_product'] ==
                                                              true
                                                          ? 0.0
                                                          : 1.0,
                                                      child: GestureDetector(
                                                        onTap: () =>
                                                            setState(() {
                                                          _shorts[index][
                                                                  'show_product'] =
                                                              !(_shorts[index][
                                                                      'show_product'] ??
                                                                  false);
                                                        }),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      12.0,
                                                                  vertical:
                                                                      8.0),
                                                          margin:
                                                              const EdgeInsets
                                                                  .only(
                                                                  left: 8.0),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                    0.6),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        20.0),
                                                            border: Border.all(
                                                              color: Colors
                                                                  .white
                                                                  .withOpacity(
                                                                      0.3),
                                                              width: 1,
                                                            ),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .shopping_bag_outlined,
                                                                color: Colors
                                                                    .white,
                                                                size: 18,
                                                              ),
                                                              const SizedBox(
                                                                  width: 6),
                                                              Text(
                                                                "Shop Now",
                                                                style:
                                                                    TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 13,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  width: 4),
                                                              Icon(
                                                                Icons
                                                                    .arrow_forward_ios,
                                                                color: Colors
                                                                    .white,
                                                                size: 12,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ShortsDetail(
                                                    _shorts[index]['title'],
                                                    _shorts[index]
                                                        ['description'],
                                                    _shorts[index]['user_id'],
                                                    _shorts[index]['username'],
                                                    _shorts[index]
                                                        ['shorts_topic'],
                                                    _shorts[index]
                                                        ['created_at'],
                                                    _shorts[index]
                                                        ['challenge_details'],
                                                    _pauseVideo,
                                                    linkedContent:
                                                        _shorts[index]
                                                            ['linked_content'],
                                                    collaborators:
                                                        _shorts[index]
                                                            ['collaborators'],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 100,
                                            child:
                                                Consumer<TutorialFlowProvider>(
                                              builder: (context, tutorial, _) =>
                                                  ShortsSideBar(
                                                index: index,
                                                shortsId: _shorts[index]['id'],
                                                image: _shorts[index]
                                                            ['user_image'] ==
                                                        null
                                                    ? 'https://baakhapaa.com/images/logo.png'
                                                    : _shorts[index]
                                                        ['user_image'],
                                                questions: _shorts[index]
                                                    ['questions'],
                                                likes: _shorts[index]['likes'],
                                                liked: _shorts[index]['liked'],
                                                lives: _shorts[index]['lives'],
                                                title: _shorts[index]['title'],
                                                coins: _shorts[index]['coins'],
                                                coins_users: _shorts[index]
                                                    ['coins_users'],
                                                viewed: _shorts[index]
                                                    ['viewed'],
                                                user_id: _shorts[index]
                                                    ['user_id'],
                                                username: _shorts[index]
                                                    ['username'],
                                                fetchMostLikedShortsCallback:
                                                    fetchMostLikedShorts,
                                                fetchMostPointsShortsCallback:
                                                    fetchMostPointsShorts,
                                                fetchLatestShortsCallback:
                                                    fetchLatestShorts,
                                                fetchOldestShortsCallback:
                                                    fetchOldestShorts,
                                                fetchRandomShortsCallback:
                                                    fetchRandomShorts,
                                                fetchFilteredShortsCallback:
                                                    fetchFilteredShorts,
                                                likeAndUnlikeCallback:
                                                    likeAndUnlike,
                                                onPlayPause: _pauseVideo,
                                                quizButtonKey: index == 0
                                                    ? _quizButtonKey
                                                    : null,
                                                videoUrl: _shorts[index]
                                                    ['video_url'],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      AnimatedSize(
                                        duration:
                                            const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                        child: AnimatedOpacity(
                                          duration:
                                              const Duration(milliseconds: 300),
                                          opacity: _shorts[index]
                                                      ['show_product'] ==
                                                  true
                                              ? 1.0
                                              : 0.0,
                                          child: (_shorts[index]
                                                          ['show_product'] ==
                                                      true &&
                                                  _shorts[index]
                                                          ['linked_content'] !=
                                                      null &&
                                                  _shorts[index]
                                                              ['linked_content']
                                                          ['products'] !=
                                                      null &&
                                                  (_shorts[index]
                                                              ['linked_content']
                                                          ['products'] as List)
                                                      .isNotEmpty)
                                              ? Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 8.0,
                                                          right: 8.0,
                                                          bottom: 8.0),
                                                  child: AffiliatedProduct(
                                                    products: _shorts[index]
                                                            ['linked_content']
                                                        ['products'],
                                                    affiliateId: _shorts[index]
                                                        ['user_id'],
                                                    onClose: () => setState(() {
                                                      _shorts[index]
                                                              ['show_product'] =
                                                          false;
                                                    }),
                                                  ),
                                                )
                                              : const SizedBox.shrink(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Popup(
                                  popupArr: _shorts[index]['popups'],
                                  child: Container(),
                                ),
                              ],
                            );
                          },
                        ),

                        // Tab bar at the top
                        _buildHeader(),

                        if (_isLoadingMoreShorts)
                          Positioned(
                            bottom: 80,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                            ),
                          ),
                        // Filter button at top-right
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 16,
                          right: 8,
                          child: GestureDetector(
                            onTap: () async {
                              final authProvider =
                                  Provider.of<Auth>(context, listen: false);
                              if (!authProvider.isAuth) {
                                bool shouldLogin =
                                    await GuestAuthHelper.showGuestLoginDialog(
                                        context, 'filters');
                                if (!shouldLogin) {
                                  return;
                                }
                                return;
                              }
                              _showFilterModal();
                            },
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.tune,
                                color: Colors.white,
                                size: 24,
                                shadows: [
                                  Shadow(
                                    color: Colors.black,
                                    offset: Offset(1.0, 1.0),
                                    blurRadius: 3.0,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }
}
