import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../utils/debug_logger.dart';

class VideoStateProvider with ChangeNotifier {
  bool _isPlaying = true;
  bool _wasPlaying = true;
  String _currentScreen = '';
  bool _isNavigatingWithAssistiveTouch = false;
  int lastWatchedShortsIndex = 0;
  int lastWatchedShortsId = 0;
  int quizSourceShortsId = 0;
  bool _returningFromQuiz = false;
  bool _isNavigatingToCreate = false; // New flag for create navigation

  // Simple single video tracking
  int? _currentActiveVideoId;
  VideoPlayerController? _currentActiveController;

  int? get currentActiveVideoId => _currentActiveVideoId;

  bool get isPlaying => _isPlaying;
  String get currentScreen => _currentScreen;
  bool get isNavigatingWithAssistiveTouch => _isNavigatingWithAssistiveTouch;
  bool get isNavigatingToCreate => _isNavigatingToCreate; // New getter

  void setActiveVideo(int videoId, VideoPlayerController controller) {
    // Prevent setting the same video as active multiple times
    if (_currentActiveVideoId == videoId) {
      DebugLogger.info(
          '🔄 VideoStateProvider: Video $videoId is already active, ignoring duplicate setActiveVideo call');
      return;
    }

    DebugLogger.info(
        '🎯 VideoStateProvider: Setting active video to ID: $videoId (previous: $_currentActiveVideoId)');

    // Stop the previous active video
    if (_currentActiveController != null &&
        _currentActiveController!.value.isInitialized &&
        _currentActiveController!.value.isPlaying) {
      DebugLogger.info(
          '⏸️ VideoStateProvider: Stopping previous video ID: $_currentActiveVideoId');
      _currentActiveController!.pause();
    }

    // Set new active video
    _currentActiveVideoId = videoId;
    _currentActiveController = controller;

    DebugLogger.success(
        '✅ VideoStateProvider: Active video set to ID: $videoId');
    notifyListeners();
  }

  void clearActiveVideo(int videoId) {
    if (_currentActiveVideoId == videoId) {
      DebugLogger.info(
          '🧹 VideoStateProvider: Clearing active video ID: $videoId');
      _currentActiveVideoId = null;
      _currentActiveController = null;
      notifyListeners();
    }
  }

  void clearAllActiveVideos() {
    DebugLogger.info(
        '🧹 VideoStateProvider: Clearing all active videos for page transition');
    if (_currentActiveController != null &&
        _currentActiveController!.value.isInitialized &&
        _currentActiveController!.value.isPlaying) {
      DebugLogger.info(
          '⏸️ VideoStateProvider: Stopping active video ID: $_currentActiveVideoId');
      _currentActiveController!.pause();
    }
    _currentActiveVideoId = null;
    _currentActiveController = null;
    notifyListeners();
  }

  void forceStopAllRegisteredVideos() {
    DebugLogger.info(
        '🚨 VideoStateProvider: Force stopping current active video');
    if (_currentActiveController != null &&
        _currentActiveController!.value.isInitialized &&
        _currentActiveController!.value.isPlaying) {
      _currentActiveController!.pause();
    }
    _currentActiveVideoId = null;
    _currentActiveController = null;
    _isPlaying = false;
    notifyListeners();
  }

  void setNavigatingWithAssistiveTouch(bool value) {
    _isNavigatingWithAssistiveTouch = value;
  }

  void setNavigatingToCreate(bool value) {
    _isNavigatingToCreate = value;
    if (value) {
      // When navigating to create, pause the video but don't reset screen yet
      _wasPlaying = _isPlaying;
      _isPlaying = false;
      notifyListeners();
    }
  }

  bool get returningFromQuiz => _returningFromQuiz;

  void saveCurrentShortsPosition(int index, int shortsId) {
    lastWatchedShortsIndex = index;
    lastWatchedShortsId = shortsId;
  }

  // Add a persist flag to clearQuizSource to avoid clearing it in certain scenarios
  void clearQuizSource() {
    // Only for debugging - can be removed in production
    DebugLogger.info('Clearing quiz source ID: $quizSourceShortsId');
    quizSourceShortsId = 0;
    _returningFromQuiz = false;
  }

  void saveQuizSourceShorts(int shortsId) {
    if (shortsId <= 0) {
      DebugLogger.error(
          'Warning: Attempted to save invalid quiz source ID: $shortsId');
      return;
    }

    // Only for debugging - can be removed in production
    DebugLogger.info('Saving quiz source ID: $shortsId');
    quizSourceShortsId = shortsId;
    lastWatchedShortsId = shortsId; // Backup
    _returningFromQuiz = true;
  }

  int getQuizSourceShortsId() {
    if (quizSourceShortsId > 0) {
      return quizSourceShortsId;
    }
    return lastWatchedShortsId;
  }

  void setScreen(String screenName) {
    if (_currentScreen == screenName) return;

    String previousScreen = _currentScreen;
    _currentScreen = screenName;

    if (_currentScreen == 'shorts') {
      // Only reset if entering shorts and not using assistive touch
      if (!_isNavigatingWithAssistiveTouch && !_returningFromQuiz) {
        // If returning from create screen, restore the previous playing state
        if (_isNavigatingToCreate) {
          _isNavigatingToCreate = false;
          // Restore the video state after a small delay to ensure UI is ready
          Future.delayed(Duration(milliseconds: 300), () {
            if (_wasPlaying) {
              _isPlaying = true;
              notifyListeners();
            }
          });
        } else {
          Future.microtask(() {
            resetState();
          });
        }
      } else {
        // Reset the assistive touch navigation flag
        _isNavigatingWithAssistiveTouch = false;
      }
    } else {
      // When leaving shorts screen, pause video if it's playing
      if (previousScreen == 'shorts' && _isPlaying) {
        _wasPlaying = true;
        _isPlaying = false;
        notifyListeners();
      }
    }
  }

  void forcePlayAfterNavigation() {
    if (_currentScreen != 'shorts') return;
    _isPlaying = true;
    _wasPlaying = true;
    _returningFromQuiz = false;
    _isNavigatingToCreate = false; // Reset create navigation flag
    notifyListeners();
  }

  void resetState() {
    if (_currentScreen != 'shorts') return;
    _isPlaying = true;
    _wasPlaying = true;
    _isNavigatingToCreate = false; // Reset create navigation flag
    notifyListeners();
  }

  void restoreState() {
    if (_currentScreen != 'shorts') return;
    _isPlaying = _wasPlaying;
    _isNavigatingToCreate = false; // Reset create navigation flag
    notifyListeners();
  }

  void pauseVideo() {
    if (_currentScreen != 'shorts') return;
    _wasPlaying = _isPlaying;
    _isPlaying = false;
    notifyListeners();
  }

  void playVideo() {
    if (_currentScreen != 'shorts') return;
    _isPlaying = true;
    _wasPlaying = true;
    notifyListeners();
  }

  // Method to handle proper cleanup when navigating away
  void handleNavigationAway() {
    if (_currentScreen == 'shorts' && _isPlaying) {
      _wasPlaying = true;
      _isPlaying = false;
      notifyListeners();
    }
  }

  // Quiz and result screen state management
  bool _isInQuiz = false;
  bool _isInResultScreen = false;

  bool get isInQuiz => _isInQuiz;
  bool get isInResultScreen => _isInResultScreen;

  void enterQuiz() {
    DebugLogger.info('🧠 VideoStateProvider: ENTERING QUIZ MODE');
    _isInQuiz = true;
    _isInResultScreen = false;
    _wasPlaying = _isPlaying;
    _isPlaying = false;
    DebugLogger.info('⏹️ VideoStateProvider: All videos STOPPED for quiz');
    notifyListeners();
  }

  void exitQuiz() {
    DebugLogger.info('🧠 VideoStateProvider: EXITING QUIZ MODE');
    _isInQuiz = false;
    _returningFromQuiz = true;

    if (_currentScreen == 'shorts') {
      _isPlaying = true;
      _wasPlaying = true;
      DebugLogger.info(
          '▶️ VideoStateProvider: Forcing video resume after quiz exit');
    }
    notifyListeners();

    // Single backup notification to handle edge case where video controller
    // wasn't ready on the first notify
    if (_currentScreen == 'shorts') {
      Future.delayed(Duration(milliseconds: 300), () {
        if (!_isInQuiz && !_isInResultScreen && _currentScreen == 'shorts') {
          _isPlaying = true;
          notifyListeners();
        }
      });
    }
  }

  void enterResultScreen() {
    DebugLogger.info('🏆 VideoStateProvider: ENTERING RESULT SCREEN MODE');
    _isInQuiz = false;
    _isInResultScreen = true;
    _isPlaying = false;
    _wasPlaying = false;
    DebugLogger.info(
        '⏹️ VideoStateProvider: All videos STOPPED for result screen');
    notifyListeners();
  }

  void exitResultScreen() {
    DebugLogger.info('🏆 VideoStateProvider: EXITING RESULT SCREEN MODE');
    _isInResultScreen = false;
    _returningFromQuiz = false;
    notifyListeners();
  }

  void forcePlayVideo() {
    DebugLogger.info('▶️ VideoStateProvider: forcePlayVideo(); called');
    // Only prevent playing if we're actively in quiz or result screen
    if (_isInQuiz || _isInResultScreen) {
      DebugLogger.error(
          '❌ VideoStateProvider: Cannot play - in quiz: $_isInQuiz, in result: $_isInResultScreen');
      return;
    }

    _isPlaying = true;
    _wasPlaying = true;
    DebugLogger.success('VideoStateProvider: Video forced to play');
    notifyListeners();
  }

  void forceStopAllVideos() {
    DebugLogger.info('🛑 VideoStateProvider: forceStopAllVideos(); called');
    _isPlaying = false;
    _wasPlaying = false;
    notifyListeners();
  }
}
