import 'package:baakhapaa/providers/assistive_touch_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../utils/debug_logger.dart';

class TutorialFlowProvider with ChangeNotifier {
  SharedPreferences? _prefs;
  int _currentStep = -1;
  bool _isActive = true;
  TutorialCoachMark? _tutorialCoachMark;
  bool _isShowingTutorial = false;

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  // Add map of tutorial target keys
  final Map<String, GlobalKey> _tutorialKeys = {};

  // Add getter for tutorial keys
  GlobalKey getTutorialKey(String targetName) {
    return _tutorialKeys.putIfAbsent(
      targetName,
      () => GlobalKey(debugLabel: '${targetName}_tutorial'),
    );
  }

  bool get isShowingTutorial => _isShowingTutorial;

  TutorialFlowProvider() {
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      // Set current step before checking state
      _currentStep = _prefs?.getInt('tutorial_step_v4') ?? 0;
      _isActive = _prefs?.getBool('tutorial_active_v4') ?? true;

      // Handle first time initialization
      if (!_prefs!.containsKey('tutorial_step_v4')) {
        await _prefs?.setInt('tutorial_step_v4', 0);
        await _prefs?.setBool('tutorial_active_v4', true);
        DebugLogger.info('Initializing fresh tutorial: $_currentStep');
      } else if (!_isActive) {
        _currentStep = 12;
        DebugLogger.success('Tutorial already completed');
      }

      DebugLogger.info(
          'Tutorial state initialized: step=$_currentStep, active=$_isActive');
      notifyListeners();
    } catch (e) {
      DebugLogger.error('Error in _initPrefs: $e');
      _currentStep = 0;
      _isActive = true;
    }
  }

  int get currentStep => _currentStep;
  bool get isActive => _isActive;
  bool get isTutorialComplete => currentStep >= 12;

  @override
  void dispose() {
    _tutorialCoachMark?.finish();
    _tutorialKeys.clear();
    super.dispose();
  }

  Future<void> showTutorialFor(BuildContext context, String targetKey) async {
    if (!_isActive || isTutorialComplete) return;

    // Cancel any existing tutorial
    _tutorialCoachMark?.finish();

    // Wait for any animations to complete
    await Future.delayed(Duration(milliseconds: 100));

    final targets = await _createTargets(context, targetKey);
    if (targets.isEmpty) return;

    try {
      _tutorialCoachMark = TutorialCoachMark(
        targets: targets,
        colorShadow: Colors.amber,
        onFinish: () {
          _isShowingTutorial = false;
          notifyListeners();
        },
      );

      _isShowingTutorial = true;
      notifyListeners();

      // Give time for UI to update
      await Future.delayed(Duration(milliseconds: 100));
      if (_tutorialCoachMark != null) {
        _tutorialCoachMark!.show(context: context);
      }
    } catch (e) {
      DebugLogger.error('Error showing tutorial: $e');
      _isShowingTutorial = false;
      notifyListeners();
    }
  }

  Future<List<TargetFocus>> _createTargets(
      BuildContext context, String targetKey) async {
    switch (targetKey) {
      case 'shorts_icon':
        return [
          _createTarget(
            'shorts_tutorial',
            'Watch Shorts',
            'Click here to start watching short videos and earn points!',
            targetKey,
            ContentAlign.top,
          )
        ];

      case 'quiz_icon':
        // final quizKey = getTutorialKey('quiz_button_key');
        return [];
      // return [
      //   TargetFocus(
      //     identify: 'quiz_tutorial',
      //     keyTarget: quizKey,
      //     alignSkip: Alignment.topRight,
      //     enableOverlayTab: true,
      //     shape: ShapeLightFocus.RRect,
      //     radius: 5,
      //     contents: [
      //       TargetContent(
      //         align: ContentAlign.top,
      //         builder: (context, controller) {
      //           return Container(
      //             padding: EdgeInsets.all(16),
      //             child: Column(
      //               mainAxisSize: MainAxisSize.min,
      //               children: [
      //                 Text(
      //                   'Take Quiz',
      //                   style: TextStyle(
      //                       fontSize: 20,
      //                       fontWeight: FontWeight.bold,
      //                       color: Colors.white),
      //                 ),
      //                 SizedBox(height: 8),
      //                 Text(
      //                   'Click this quiz icon to answer questions and earn points!',
      //                   style: TextStyle(color: Colors.white),
      //                   textAlign: TextAlign.center,
      //                 ),
      //                 SizedBox(height: 16),
      //                 ElevatedButton(
      //                   onPressed: () => controller.next(),
      //                   child: Text('Got it!'),
      //                 ),
      //               ],
      //             ),
      //           );
      //         },
      //       ),
      //     ],
      //   ),
      // ];

      case 'quiz_answers':
        return [
          _createTarget(
            'answers_tutorial',
            'Select Answer',
            'Choose the correct answer to earn your points!',
            targetKey,
            ContentAlign.bottom,
          )
        ];

      case 'gift_icon':
        return [
          _createTarget(
            'gift_tutorial',
            'Redeem Rewards',
            'Click here to see available rewards you can redeem!',
            targetKey,
            ContentAlign.top,
          )
        ];

      // Add more cases for other tutorial steps
      case 'shop_items':
        return [
          _createTarget(
            'shop_tutorial',
            'Shop Items',
            'Browse through available items you can purchase!',
            targetKey,
            ContentAlign.bottom,
          )
        ];

      case 'story_episodes':
        return [
          _createTarget(
            'episodes_tutorial',
            'Story Episodes',
            'Watch these episodes to earn more points!',
            targetKey,
            ContentAlign.top,
          )
        ];

      default:
        return [];
    }
  }

  TargetFocus _createTarget(
    String identify,
    String title,
    String description,
    String keyTarget,
    ContentAlign align,
  ) {
    return TargetFocus(
      identify: identify,
      keyTarget: getTutorialKey(keyTarget),
      alignSkip: Alignment.topRight,
      enableOverlayTab: true,
      contents: [
        TargetContent(
          align: align,
          builder: (context, controller) {
            return Container(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => controller.next(),
                    child: Text('Got it!'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> nextStep() async {
    if (_currentStep >= 11) {
      await completeTutorial();
      return;
    }

    try {
      final prevStep = _currentStep;
      _currentStep++;

      await _prefs?.setInt('tutorial_step_v4', _currentStep);
      DebugLogger.info('Tutorial step updated in prefs: $_currentStep');

      final context = _navigatorKey.currentContext;
      if (context != null) {
        final assistiveTouchProvider = Provider.of<AssistiveTouchProvider>(
          context,
          listen: false,
        );

        // Clear old message first
        await assistiveTouchProvider.toggleMessage(false);
        await Future.delayed(Duration(milliseconds: 100));
        assistiveTouchProvider.clearTutorialMessage();

        // Show new message
        final message = getCurrentStepMessage();
        if (message.isNotEmpty) {
          assistiveTouchProvider.setTutorialMessage(message);
          await assistiveTouchProvider.toggleMessage(true);
        }

        // Handle tutorial focus
        final targetKey = getCurrentStepTarget();
        if (targetKey.isNotEmpty) {
          await Future.delayed(Duration(milliseconds: 300));
          await showTutorialFor(context, targetKey);
        }

        notifyListeners();
        DebugLogger.info('Tutorial step changed: $prevStep -> $_currentStep');
      }
    } catch (e) {
      DebugLogger.error('Error in nextStep: $e');
    }
  }

  Future<void> completeTutorial() async {
    try {
      // Cancel any existing tutorial UI
      _tutorialCoachMark?.finish();
      _isShowingTutorial = false;
      _isActive = false;
      _currentStep = 12;

      // Reset all preferences - Save completed state
      await _prefs?.setBool('tutorial_active_v4', false);
      await _prefs?.setInt('tutorial_step_v4', 12);

      // Clear messages in AssistiveTouchProvider
      final context = _navigatorKey.currentContext;
      if (context != null) {
        final assistiveTouchProvider =
            Provider.of<AssistiveTouchProvider>(context, listen: false);

        // Force clear all messages
        await assistiveTouchProvider.toggleMessage(false);
        await Future.delayed(Duration(milliseconds: 100));
        assistiveTouchProvider.clearTutorialMessage();
      }

      notifyListeners();
      DebugLogger.success('Tutorial completed and state persisted');
    } catch (e) {
      DebugLogger.error('Error completing tutorial: $e');
    }
  }

  Future<void> resetTutorial() async {
    _currentStep = 0;
    _isActive = true;
    await _prefs?.setInt('tutorial_step_v4', 0);
    await _prefs?.setBool('tutorial_active_v4', true);
    notifyListeners();
  }

  String getCurrentStepMessage() {
    switch (_currentStep) {
      case 0:
        return '🎉 Congratulations! Now you can start earning.\n➡️ Click on the Shorts icon in the navigation bar to begin.';
      case 1:
        return '🎥 Watch this short video to earn your first point.\n➡️ Click on the Quiz icon to continue.';
      case 2:
        return '❓ What did you learn? Answer correctly to proceed.';
      case 3:
        return '🌟 WELL DONE! You\'re getting the hang of our app.\n➡️ Click on the Gift icon to see available rewards.\n➡️ Click on the Redeem in the top right.';
      case 4:
        return '🎁 Redeem your points for exciting rewards! \n 💡 Don’t worry! You can earn more points by watching stories.\n ➡ Click on the Story icon to start earning more.';
      case 5:
        return '📖 Choose your reward path:\n➡ Watch the Tutorial Story and earn 38 points.\n➡ Watch Season 1 and earn 570 points.\n➡ Click on the first season to begin.';
      case 6:
        return '🎬 Start your journey!\n➡ Click on the first episode to continue.';
      case 7:
        return '👀 Watch carefully! Get ready for the quiz.\n➡ Click "Go to Questions" when you\'re ready.';
      case 8:
        return '❓ What have you learned? Answer correctly to win points.';
      case 9:
        return '🏆 WELL DONE, WINNER! You\'ve earned rewards!\n➡️ Click on the Gift icon to redeem your prize.';
      case 10:
        return '🎉 Let\'s redeem your reward!\n💰 Claim ₹150 Top-up!\n⚠️ A new challenge has appeared! Earn a badge to unlock more rewards.';
      case 11:
        return '🏅 Make your account redeemable!\n➡️ Click below to unlock badges:\n[Earn Bronze Investor]\n[Become a Creator]';
      default:
        return '';
    }
  }

  String getCurrentStepTarget() {
    switch (_currentStep) {
      case 0:
        return 'shorts_icon';
      case 1:
        return 'quiz_icon';
      case 2:
        return 'quiz_answers';
      case 3:
        return 'gift_icon';
      case 4:
        return 'shop_items';
      case 5:
        return 'story_episodes';
      case 6:
        return 'first_episode';
      case 7:
        return 'go_to_questions';
      case 8:
        return 'quiz_answers_story';
      case 9:
        return 'gift_icon_win';
      case 10:
        return 'redeem_gift';
      case 11:
        return 'account_redeemable';
      default:
        return '';
    }
  }

  // Make showCurrentStepMessage more robust
  void showCurrentStepMessage(BuildContext context) {
    if (!_isActive || isTutorialComplete || _currentStep >= 12) {
      // Clear any lingering messages if tutorial is complete
      try {
        final assistiveTouchProvider = Provider.of<AssistiveTouchProvider>(
          context,
          listen: false,
        );
        assistiveTouchProvider.toggleMessage(false);
        assistiveTouchProvider.clearTutorialMessage();
      } catch (e) {
        DebugLogger.error('Error clearing messages: $e');
      }
      return;
    }

    try {
      final message = getCurrentStepMessage();
      if (message.isEmpty) return;

      final assistiveTouchProvider = Provider.of<AssistiveTouchProvider>(
        context,
        listen: false,
      );

      // Clear old message
      assistiveTouchProvider.clearTutorialMessage();

      // Show new message
      assistiveTouchProvider.setTutorialMessage(message);
      assistiveTouchProvider.toggleMessage(true);

      // Force rebuild
      notifyListeners();

      DebugLogger.info(
          'Showing tutorial message: $message for step: $_currentStep');
    } catch (e) {
      DebugLogger.error('Error showing message: $e');
    }
  }
}
