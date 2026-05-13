// ignore_for_file: unused_import

import 'dart:io';

import 'package:baakhapaa/providers/video_state_provider.dart';
import 'package:baakhapaa/widgets/popup.dart';
import 'package:baakhapaa/widgets/skeleton_loading.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:upgrader/upgrader.dart';

import '../../providers/shorts.dart';
import '../../services/ad_service.dart';
import '../../widgets/footer.dart';
import '../../widgets/shorts_side_bar.dart';
import '../../widgets/shorts_detail.dart';
import '../../widgets/shorts_video_tile.dart';
import '../../helpers/helpers.dart';
import '../../widgets/my_upgrader_messages.dart';
import '../../utils/debug_logger.dart';
import './shorts_screen.dart';

class ChallengesScreen extends StatefulWidget {
  static const routeName = '/challenges-screen';

  const ChallengesScreen({Key? key}) : super(key: key);

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen>
    with WidgetsBindingObserver {
  bool _isInit = false;
  bool _isLoading = true;
  int _snappedPageIndex = 0;
  late List<dynamic> _challengeShorts = [];
  bool _isLoadingMoreShorts = false;
  final PageController _pageController = PageController();
  VideoStateProvider? _videoStateProvider;

  // Track video state better
  bool _isReturningFromWin = false;
  bool _isTapping = false; // Debounce for tap events

  @override
  void initState() {
    super.initState();
    DebugLogger.puppet('ChallengesScreen: initState called');
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final videoStateProvider =
          Provider.of<VideoStateProvider>(context, listen: false);
      videoStateProvider.setScreen('shorts');
    });
  }

  @override
  void dispose() {
    // Ensure all videos are properly stopped before disposing
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
          if (!videoStateProvider.isNavigatingToCreate &&
              !_isReturningFromWin) {
            videoStateProvider.playVideo();
          }
        }
        break;
      case AppLifecycleState.paused:
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
        final returnToShortsId = arguments['returnToShortsId'] as int?;
        final fromWinScreen = arguments['fromWinScreen'] as bool? ?? false;

        if (returnToShortsId != null) {
          _isReturningFromWin = fromWinScreen;
          _videoStateProvider?.setScreen('shorts');

          _loadInitialData().then((_) {
            if (mounted) {
              _handleVideoNavigation(returnToShortsId, fromWinScreen);
            }
          });
        } else {
          _videoStateProvider?.setScreen('shorts');
          _loadInitialData().then((_) {
            if (mounted) {
              _initializeVideoState();
            }
          });
        }
      } else {
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

  void _initializeVideoState() {
    DebugLogger.info('🚀 ChallengesScreen: _initializeVideoState(); called');
    if (!mounted) {
      DebugLogger.error(
          'ChallengesScreen: Widget not mounted, skipping initialization');
      return;
    }

    DebugLogger.info('🧹 ChallengesScreen: Cleaning video state...');
    _videoStateProvider?.exitQuiz();
    _videoStateProvider?.exitResultScreen();

    DebugLogger.info(
        '🧹 ChallengesScreen: Clearing all active videos for fresh start...');
    _videoStateProvider?.clearAllActiveVideos();

    _videoStateProvider?.setScreen('shorts');

    if (_challengeShorts.isEmpty) {
      DebugLogger.error(
          '❌ ChallengesScreen: No challenges available, skipping video initialization');
      return;
    }

    DebugLogger.info('⏱️ ChallengesScreen: Starting video immediately...');
    _videoStateProvider?.forcePlayVideo();

    // Backup attempts to ensure the video starts
    Future.delayed(Duration(milliseconds: 100), () {
      if (mounted &&
          _challengeShorts.isNotEmpty &&
          !_videoStateProvider!.isInQuiz &&
          !_videoStateProvider!.isInResultScreen) {
        DebugLogger.info('🔄 ChallengesScreen: First backup play attempt');
        _videoStateProvider?.forcePlayVideo();
      }
    });

    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted &&
          _challengeShorts.isNotEmpty &&
          !_videoStateProvider!.isInQuiz &&
          !_videoStateProvider!.isInResultScreen) {
        DebugLogger.info('🔄 ChallengesScreen: Second backup play attempt');
        _videoStateProvider?.forcePlayVideo();
      }
    });
  }

  Future<void> _loadInitialData() async {
    final shortsProvider = Provider.of<Shorts>(context, listen: false);

    setState(() {
      _isLoading = true;
    });

    try {
      await shortsProvider.fetchShortsChallenges();
      setState(() {
        // fetchShortsChallenges stores data in shorts, not challengeShorts
        _challengeShorts = shortsProvider.shorts;
      });
    } catch (error) {
      DebugLogger.error('Error loading challenges: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleVideoNavigation(int returnToShortsId, bool fromWinScreen) {
    DebugLogger.info(
        '🎯 ChallengesScreen: _handleVideoNavigation called with ID: $returnToShortsId, fromWin: $fromWinScreen');

    if (returnToShortsId <= 0) {
      DebugLogger.error(
          '❌ ChallengesScreen: Invalid video ID: $returnToShortsId, navigating to first video');
      _navigateToVideoIndex(0, fromWinScreen);
      return;
    }

    int indexToJumpTo =
        _challengeShorts.indexWhere((short) => short['id'] == returnToShortsId);
    DebugLogger.info(
        '🔍 ChallengesScreen: Searching for video ID $returnToShortsId in ${_challengeShorts.length} challenges, found at index: $indexToJumpTo');

    if (fromWinScreen &&
        indexToJumpTo != -1 &&
        indexToJumpTo + 1 < _challengeShorts.length) {
      indexToJumpTo += 1;
      DebugLogger.info(
          '🏆 ChallengesScreen: Moving to next video after win, new index: $indexToJumpTo');
    }

    if (indexToJumpTo != -1) {
      DebugLogger.success(
          '✅ ChallengesScreen: Video found locally, navigating to index: $indexToJumpTo');
      _navigateToVideoIndex(indexToJumpTo, fromWinScreen);
    } else {
      DebugLogger.info(
          '🔄 ChallengesScreen: Video not found locally, loading additional pages...');
      _loadAdditionalPagesUntilVideoFound(returnToShortsId, fromWinScreen);
    }
  }

  void _navigateToVideoIndex(int index, bool fromWinScreen) {
    DebugLogger.info(
        '🎬 ChallengesScreen: _navigateToVideoIndex called - index: $index, fromWin: $fromWinScreen');

    DebugLogger.info(
        '🧹 ChallengesScreen: Cleaning video state before navigation...');
    _videoStateProvider?.exitQuiz();
    _videoStateProvider?.exitResultScreen();
    _videoStateProvider?.clearAllActiveVideos();
    _videoStateProvider?.setScreen('shorts');

    Future.delayed(Duration(milliseconds: 200), () {
      if (mounted &&
          _pageController.hasClients &&
          index < _challengeShorts.length) {
        DebugLogger.info('📖 ChallengesScreen: Jumping to page $index');
        _pageController.jumpToPage(index);

        Future.delayed(Duration(milliseconds: 400), () {
          if (mounted) {
            DebugLogger.info(
                '🎯 ChallengesScreen: Setting state after navigation - index: $index');
            setState(() {
              _isReturningFromWin = false;
              _snappedPageIndex = index;
            });

            DebugLogger.info(
                '▶️ ChallengesScreen: Force playing video after navigation');
            _videoStateProvider?.forcePlayVideo();

            // Multiple backup attempts to ensure video starts
            for (int delay in [300, 800, 1500]) {
              Future.delayed(Duration(milliseconds: delay), () {
                if (mounted &&
                    !_videoStateProvider!.isInQuiz &&
                    !_videoStateProvider!.isInResultScreen &&
                    _snappedPageIndex == index) {
                  DebugLogger.info(
                      '🔄 ChallengesScreen: Backup video play attempt at ${delay}ms');
                  _videoStateProvider?.forcePlayVideo();
                }
              });
            }
          } else {
            DebugLogger.error(
                'ChallengesScreen: Widget not mounted after navigation delay');
          }
        });
      } else if (mounted) {
        // PageController not ready yet - retry after more time
        Future.delayed(Duration(milliseconds: 500), () {
          if (mounted &&
              _pageController.hasClients &&
              index < _challengeShorts.length) {
            _pageController.jumpToPage(index);
            setState(() {
              _isReturningFromWin = false;
              _snappedPageIndex = index;
            });
            _videoStateProvider?.forcePlayVideo();
          }
        });
      } else {
        DebugLogger.error(
            '❌ ChallengesScreen: Cannot navigate - mounted: $mounted, hasClients: ${_pageController.hasClients}, index: $index, maxIndex: ${_challengeShorts.length - 1}');
      }
    });

    DebugLogger.info('🗑️ ChallengesScreen: Clearing quiz source');
    _videoStateProvider?.clearQuizSource();
  }

  Future<void> _loadAdditionalPagesUntilVideoFound(
      int shortsId, bool advanceToNext) async {
    DebugLogger.info(
        '🔍 ChallengesScreen: _loadAdditionalPagesUntilVideoFound called - ID: $shortsId, advance: $advanceToNext');
    if (!mounted) {
      DebugLogger.error(
          'ChallengesScreen: Widget not mounted, cancelling video search');
      return;
    }

    if (shortsId <= 0) {
      DebugLogger.error(
          '❌ ChallengesScreen: Invalid shortsId: $shortsId, jumping to first video');
      if (_challengeShorts.isNotEmpty && _pageController.hasClients) {
        _navigateToVideoIndex(0, advanceToNext);
      }
      return;
    }

    final shortsProvider = Provider.of<Shorts>(context, listen: false);
    int maxAttempts = 3;
    int attempts = 0;
    bool foundVideo = false;

    DebugLogger.info(
        '🔄 ChallengesScreen: Setting loading state for video search');
    setState(() {
      _isLoadingMoreShorts = true;
    });

    DebugLogger.info('⏸️ ChallengesScreen: Pausing videos during search');
    _videoStateProvider?.pauseVideo();
    _videoStateProvider?.setScreen('shorts');

    DebugLogger.info(
        '🎯 ChallengesScreen: Looking for video with ID: $shortsId');

    while (
        !foundVideo && attempts < maxAttempts && shortsProvider.hasMorePages) {
      attempts++;
      DebugLogger.info('Attempt $attempts to find video $shortsId');

      try {
        DebugLogger.info('📥 ChallengesScreen: Loading more challenges...');
        await shortsProvider.loadMoreShorts();

        // fetchShortsChallenges stores data in shorts, not challengeShorts
        List<dynamic> updatedShorts = shortsProvider.shorts;

        if (!mounted) {
          DebugLogger.error(
              'ChallengesScreen: Widget no longer mounted during loading');
          return;
        }

        DebugLogger.info(
            '📋 ChallengesScreen: Updating challenges list with ${updatedShorts.length} items');
        setState(() {
          _challengeShorts = List.from(updatedShorts);
        });

        int indexToJumpTo =
            _challengeShorts.indexWhere((short) => short['id'] == shortsId);

        if (indexToJumpTo != -1) {
          foundVideo = true;
          DebugLogger.success(
              'ChallengesScreen: Found video at index: $indexToJumpTo');

          if (advanceToNext && indexToJumpTo + 1 < _challengeShorts.length) {
            indexToJumpTo += 1;
            DebugLogger.info(
                '⏭️ ChallengesScreen: Advancing to next video, new index: $indexToJumpTo');
          }

          _navigateToVideoIndex(indexToJumpTo, advanceToNext);
          break;
        } else {
          DebugLogger.error(
              'ChallengesScreen: Video $shortsId not found in current page');
        }
      } catch (error) {
        DebugLogger.error(
            'ChallengesScreen: Error loading more challenges: $error');
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
      DebugLogger.info(
          '🔄 ChallengesScreen: Resetting loading state after search');
      setState(() {
        _isLoadingMoreShorts = false;
      });

      if (!foundVideo) {
        DebugLogger.error(
            '❌ ChallengesScreen: Video $shortsId not found after $attempts attempts');

        if (_challengeShorts.isNotEmpty && _pageController.hasClients) {
          DebugLogger.info('🔄 ChallengesScreen: Falling back to first video');
          _navigateToVideoIndex(0, false);
        }
      } else {
        DebugLogger.success(
            '✅ ChallengesScreen: Successfully found and navigated to video $shortsId');
      }
    }
  }

  void _playOrPauseVideo() {
    DebugLogger.info('⏯️ ChallengesScreen: _playOrPauseVideo called');

    // Debounce rapid taps
    if (_isTapping) {
      DebugLogger.info('🚫 ChallengesScreen: Debouncing rapid tap');
      return;
    }
    _isTapping = true;
    Future.delayed(Duration(milliseconds: 300), () {
      _isTapping = false;
    });

    if (!mounted) {
      DebugLogger.error(
          'ChallengesScreen: Widget not mounted in _playOrPauseVideo');
      return;
    }

    final videoStateProvider =
        Provider.of<VideoStateProvider>(context, listen: false);

    if (videoStateProvider.isNavigatingWithAssistiveTouch) {
      DebugLogger.puppet(
          '🎯 ChallengesScreen: Disabling assistive touch navigation');
      videoStateProvider.setNavigatingWithAssistiveTouch(false);
    }

    if (videoStateProvider.isPlaying) {
      DebugLogger.info('⏸️ ChallengesScreen: Pausing video');
      videoStateProvider.pauseVideo();
    } else {
      DebugLogger.info('▶️ ChallengesScreen: Playing video');
      videoStateProvider.playVideo();
    }
  }

  void _pauseVideo() {
    DebugLogger.info('⏸️ ChallengesScreen: _pauseVideo called');
    final videoStateProvider =
        Provider.of<VideoStateProvider>(context, listen: false);
    videoStateProvider.pauseVideo();
  }

  Future<void> _loadMoreShorts() async {
    DebugLogger.info('🔄 ChallengesScreen: _loadMoreShorts called');
    if (_isLoadingMoreShorts) {
      DebugLogger.info(
          '⏳ ChallengesScreen: Already loading more challenges, skipping');
      return;
    }

    final shortsProvider = Provider.of<Shorts>(context, listen: false);

    if (!shortsProvider.hasMorePages) {
      DebugLogger.info('📄 ChallengesScreen: No more pages available');
      return;
    }

    DebugLogger.info(
        '📥 ChallengesScreen: Starting to load more challenges...');
    setState(() {
      _isLoadingMoreShorts = true;
    });

    try {
      await shortsProvider.loadMoreShorts();

      if (mounted) {
        setState(() {
          // fetchShortsChallenges stores data in shorts, not challengeShorts
          _challengeShorts = shortsProvider.shorts;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to load more challenges: ${error.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMoreShorts = false;
        });
      }
    }
  }

  void _onPageChanged(int index) {
    DebugLogger.info(
        '📄 ChallengesScreen: _onPageChanged called - index: $index');
    if (!mounted) {
      DebugLogger.error(
          'ChallengesScreen: Widget not mounted in _onPageChanged');
      return;
    }

    // Show interstitial ad every 5 challenge shorts viewed
    if (AdService().incrementChallengeViewAndCheckAd()) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          AdService().showInterstitial(
            context: context,
            onAdDismissed: () {
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
    DebugLogger.info(
        '📱 ChallengesScreen: Updated snapped page index to: $index');

    if (_challengeShorts.isNotEmpty && index < _challengeShorts.length) {
      final videoStateProvider = _videoStateProvider;
      if (videoStateProvider != null) {
        DebugLogger.info(
            '💾 ChallengesScreen: Saving position - index: $index, id: ${_challengeShorts[index]['id']}');
        videoStateProvider.saveCurrentShortsPosition(
            index, _challengeShorts[index]['id']);

        if (!videoStateProvider.isInQuiz &&
            !videoStateProvider.isInResultScreen) {
          DebugLogger.info(
              '▶️ ChallengesScreen: Immediately playing video for index: $index');

          videoStateProvider.clearAllActiveVideos();
          videoStateProvider.forcePlayVideo();

          Future.delayed(Duration(milliseconds: 100), () {
            if (mounted &&
                _snappedPageIndex == index &&
                !videoStateProvider.isInQuiz &&
                !videoStateProvider.isInResultScreen) {
              DebugLogger.info(
                  '🔄 ChallengesScreen: Backup video play attempt for index: $index');
              videoStateProvider.forcePlayVideo();
            }
          });

          if (_isReturningFromWin) {
            DebugLogger.info(
                '🏆 ChallengesScreen: Resetting returning from win flag');
            setState(() {
              _isReturningFromWin = false;
            });
          }
        } else {
          DebugLogger.info(
              '🚫 ChallengesScreen: Video playback blocked - inQuiz: ${videoStateProvider.isInQuiz}, inResult: ${videoStateProvider.isInResultScreen}');
        }
      } else {
        DebugLogger.error('ChallengesScreen: Video state provider is null');
      }
    } else {
      DebugLogger.error(
          '❌ ChallengesScreen: Invalid challenges state - count: ${_challengeShorts.length}, index: $index');
    }

    if (index >= _challengeShorts.length - 2) {
      DebugLogger.info(
          '🔄 ChallengesScreen: Near end of list, loading more challenges...');
      _loadMoreShorts();
    }
  }

  void likeAndUnlike(int shortsId) {
    bool? newLikedState;
    int? newLikesCount;

    int index = _challengeShorts.indexWhere((short) => short['id'] == shortsId);
    if (index != -1) {
      newLikedState = !(_challengeShorts[index]['liked'] ?? false);
      newLikesCount =
          (_challengeShorts[index]['likes'] ?? 0) + (newLikedState ? 1 : -1);
    }

    if (newLikedState == null || newLikesCount == null) return;

    final shortsProvider = Provider.of<Shorts>(context, listen: false);

    // Update in provider's shorts list (challenges are stored in shorts after fetchShortsChallenges)
    int challengeIndex =
        shortsProvider.shorts.indexWhere((short) => short['id'] == shortsId);
    if (challengeIndex != -1) {
      shortsProvider.shorts[challengeIndex]['liked'] = newLikedState;
      shortsProvider.shorts[challengeIndex]['likes'] = newLikesCount;
    }

    // Update local list
    int localIndex =
        _challengeShorts.indexWhere((short) => short['id'] == shortsId);
    if (localIndex != -1) {
      _challengeShorts[localIndex]['liked'] = newLikedState;
      _challengeShorts[localIndex]['likes'] = newLikesCount;
    }

    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildHeader() {
    return Container(
      height: 50,
      margin: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
      ),
      child: Row(
        children: [
          // Back button to go to For You
          GestureDetector(
            onTap: () {
              Navigator.of(context)
                  .pushReplacementNamed(ShortsScreen.routeName);
            },
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
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
          SizedBox(width: 16),
          // Challenges title
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Text(
              context.l10n.challenges,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: Consumer2<VideoStateProvider, Shorts>(
          builder: (context, videoState, shortsProvider, _) {
            if (_isLoading) {
              return Stack(
                children: [
                  Container(color: Colors.black),
                  _buildHeader(),
                  Center(child: ShortsVideoSkeleton()),
                ],
              );
            } else if (_challengeShorts.isEmpty) {
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
                          'No challenges available.',
                          style: TextStyle(color: Colors.white),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context)
                                .pushReplacementNamed(ShortsScreen.routeName);
                          },
                          child: Text('Go to For You'),
                        )
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
                  itemCount: _challengeShorts.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        ShortsVideoTile(
                          key: ValueKey(
                              'challenge_${_challengeShorts[index]['id']}'),
                          video: _challengeShorts[index]['video_url'],
                          currentIndex: index,
                          snappedPageIndex: _snappedPageIndex,
                          isVideoPlaying: videoState.isPlaying &&
                              _snappedPageIndex == index &&
                              !videoState.isInQuiz &&
                              !videoState.isInResultScreen,
                          onPlayPause: _playOrPauseVideo,
                          shortsId: _challengeShorts[index]['id'],
                          likeAndUnlikeCallback: likeAndUnlike,
                          isLiked: _challengeShorts[index]['liked'] ?? false,
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      left: 8.0, bottom: 8.0),
                                  child: ShortsDetail(
                                    _challengeShorts[index]['title'],
                                    _challengeShorts[index]['description'],
                                    _challengeShorts[index]['user_id'],
                                    _challengeShorts[index]['username'],
                                    _challengeShorts[index]['shorts_topic'],
                                    _challengeShorts[index]['created_at'],
                                    _challengeShorts[index]
                                        ['challenge_details'],
                                    _pauseVideo,
                                    linkedContent: _challengeShorts[index]
                                        ['linked_content'],
                                    collaborators: _challengeShorts[index]
                                        ['collaborators'],
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: ShortsSideBar(
                                  index: index,
                                  shortsId: _challengeShorts[index]['id'],
                                  image: _challengeShorts[index]
                                              ['user_image'] ==
                                          null
                                      ? 'https://baakhapaa.com/images/logo.png'
                                      : _challengeShorts[index]['user_image'],
                                  questions: _challengeShorts[index]
                                      ['questions'],
                                  likes: _challengeShorts[index]['likes'],
                                  liked: _challengeShorts[index]['liked'],
                                  lives: _challengeShorts[index]['lives'],
                                  title: _challengeShorts[index]['title'],
                                  coins: _challengeShorts[index]['coins'],
                                  coins_users: _challengeShorts[index]
                                      ['coins_users'],
                                  viewed: _challengeShorts[index]['viewed'],
                                  user_id: _challengeShorts[index]['user_id'],
                                  username: _challengeShorts[index]['username'],
                                  fetchMostLikedShortsCallback: () {},
                                  fetchMostPointsShortsCallback: () {},
                                  fetchLatestShortsCallback: () {},
                                  fetchOldestShortsCallback: () {},
                                  fetchRandomShortsCallback: () {},
                                  fetchFilteredShortsCallback: (_) {},
                                  likeAndUnlikeCallback: likeAndUnlike,
                                  onPlayPause: _pauseVideo,
                                  quizButtonKey: null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Popup(
                          popupArr: _challengeShorts[index]['popups'],
                          child: Container(),
                        ),
                      ],
                    );
                  },
                ),

                // Header at the top
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
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
