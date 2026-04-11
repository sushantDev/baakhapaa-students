import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/puppet_interaction.dart';
import '../utils/debug_logger.dart';

class AssistiveTouchProvider with ChangeNotifier {
  bool _isEnabled = true;
  bool _showMessage = false;
  bool _isRewardsOverlayActive = false;
  List<String> _messages = [];
  PuppetInteraction? _currentPuppet;
  Timer? _autoDismissTimer;
  int _puppetDismissCount = 0;
  int _maxPuppetShows =
      kDebugMode ? 100 : 25; // Show puppet many times per session

  // Smart timing settings
  static const int _maxDisplayDuration = 15; // 15 seconds max
  static const int _minDisplayDuration = 5; // 5 seconds min

  bool get isEnabled => _isEnabled && !_isRewardsOverlayActive;
  bool get showMessage => _showMessage;
  bool get isRewardsOverlayActive => _isRewardsOverlayActive;
  List<String> get messages => _messages;
  PuppetInteraction? get currentPuppet => _currentPuppet;
  int get puppetDismissCount => _puppetDismissCount;
  bool get canShowPuppet => _puppetDismissCount < _maxPuppetShows;

  Future<void> initState() async {
    final prefs = await SharedPreferences.getInstance();
    // Always enabled - cannot be disabled
    _isEnabled = true;
    await prefs.setBool('assistive_touch_enabled', true);

    // Check if this is a new session (app restart)
    final lastSessionDate = prefs.getString('last_puppet_session_date');
    final today =
        DateTime.now().toIso8601String().split('T')[0]; // Get date part only

    // In debug mode, reset puppet limits on every app restart for testing
    if (kDebugMode || lastSessionDate != today) {
      // New day/session or debug mode - reset puppet limits
      _puppetDismissCount = 0;
      await prefs.setInt('puppet_dismiss_count', 0);
      await prefs.setString('last_puppet_session_date', today);
      DebugLogger.puppet(
          '🎭 AssistiveTouch: ${kDebugMode ? "Debug mode" : "New session"} detected - reset puppet limits');
    } else {
      // Same session - load existing count
      _puppetDismissCount = prefs.getInt('puppet_dismiss_count') ?? 0;
      DebugLogger.puppet(
          '🎭 AssistiveTouch: Continuing session - loaded dismissCount: $_puppetDismissCount');
    }

    _maxPuppetShows =
        prefs.getInt('max_puppet_shows') ?? (kDebugMode ? 100 : 25);

    DebugLogger.puppet(
        '🎭 AssistiveTouch: Initialized - enabled: $_isEnabled (always enabled), dismissCount: $_puppetDismissCount, canShow: $canShowPuppet');
    notifyListeners();
  }

  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  void setMessages(List<String> messages) {
    _messages = messages;
    notifyListeners();
  }

  Future<void> toggleMessage(bool show) async {
    _showMessage = show;
    notifyListeners();
  }

  // Add tutorial-specific methods
  void setTutorialMessage(String message) {
    _messages = [message];
    _showMessage = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void clearTutorialMessage() {
    _messages = [];
    _showMessage = false;
    _currentPuppet = null;
    notifyListeners();
  }

  // Puppet integration methods with smart timing
  void showPuppetMessage(PuppetInteraction puppet) {
    // Check if we should still show puppet messages
    if (!canShowPuppet) {
      DebugLogger.puppet(
          'AssistiveTouch: Puppet limit reached, not showing message');
      return;
    }

    DebugLogger.puppet(
        '🎭 AssistiveTouch: Showing puppet message - ${puppet.title}: ${puppet.message}');

    // Clear any existing timer
    _autoDismissTimer?.cancel();

    _currentPuppet = puppet;
    _messages = [puppet.message];
    _showMessage = true;

    // Calculate display duration based on message length
    int displayDuration = _calculateDisplayDuration(puppet.message);

    // Set auto-dismiss timer
    _autoDismissTimer = Timer(Duration(seconds: displayDuration), () {
      _autoDismissPuppet();
    });

    notifyListeners();
  }

  void clearPuppetMessage() {
    DebugLogger.puppet('AssistiveTouch: Clearing puppet message');
    _autoDismissTimer?.cancel();
    _currentPuppet = null;
    _messages = [];
    _showMessage = false;
    notifyListeners();
  }

  void _autoDismissPuppet() {
    DebugLogger.puppet('AssistiveTouch: Auto-dismissing puppet message');
    _puppetDismissCount++;
    _savePuppetPreferences(); // Save updated count
    clearPuppetMessage();
  }

  // Calculate smart display duration based on message length and complexity
  int _calculateDisplayDuration(String message) {
    // Base duration on reading speed (average 200 words per minute)
    int wordCount = message.split(' ').length;
    double readingTime = (wordCount / 200) * 60; // seconds

    // Add buffer time for comprehension
    int duration = (readingTime + 3).round();

    // Apply constraints
    duration = duration.clamp(_minDisplayDuration, _maxDisplayDuration);

    // If user has dismissed multiple puppets, reduce display time
    if (_puppetDismissCount >= 2) {
      duration = (duration * 0.7).round(); // 30% shorter
    }

    DebugLogger.puppet(
        '🎭 AssistiveTouch: Calculated display duration: ${duration}s for message length: ${message.length}');
    return duration;
  }

  // Reset puppet showing limits (call this on app restart or user preference)
  Future<void> resetPuppetLimits() async {
    _puppetDismissCount = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('puppet_dismiss_count', 0);
    DebugLogger.puppet(
        'AssistiveTouch: Reset puppet limits and saved to storage');
    notifyListeners();
  }

  // Method for immediate testing - force reset puppet limits
  Future<void> forceResetForTesting() async {
    await resetPuppetLimits();
    DebugLogger.puppet(
        '🎭 AssistiveTouch: Force reset for testing - canShowPuppet: $canShowPuppet');
  }

  // Assistive Touch cannot be disabled - always remains enabled
  Future<void> toggleEnabled(bool enabled) async {
    // Ignore disable attempts - always keep enabled
    _isEnabled = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('assistive_touch_enabled', true);
    notifyListeners();
  }

  // Save puppet preferences
  Future<void> _savePuppetPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('puppet_dismiss_count', _puppetDismissCount);
  }

  // Show/hide assistive touch when rewards overlay is active
  void setRewardsOverlayActive(bool active) {
    _isRewardsOverlayActive = active;
    DebugLogger.puppet(
        'AssistiveTouch: Rewards overlay active: $active - assistive touch ${active ? "hidden" : "visible"}');
    notifyListeners();
  }
}
