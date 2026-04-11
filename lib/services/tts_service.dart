import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../utils/debug_logger.dart';

class TtsService extends ChangeNotifier {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  bool _isPaused = false;
  double _speed = 0.5;
  String _language = 'en-US';
  VoidCallback? onComplete;

  bool get isSpeaking => _isSpeaking;
  bool get isPaused => _isPaused;
  double get speed => _speed;
  String get language => _language;

  TtsService._internal() {
    _init();
  }

  Future<void> _init() async {
    await _tts.setLanguage(_language);
    await _tts.setSpeechRate(_speed);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    _tts.setStartHandler(() {
      _isSpeaking = true;
      _isPaused = false;
      notifyListeners();
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      _isPaused = false;
      notifyListeners();
      onComplete?.call();
    });

    _tts.setCancelHandler(() {
      _isSpeaking = false;
      _isPaused = false;
      notifyListeners();
    });

    _tts.setPauseHandler(() {
      _isPaused = true;
      _isSpeaking = false;
      notifyListeners();
    });

    _tts.setContinueHandler(() {
      _isSpeaking = true;
      _isPaused = false;
      notifyListeners();
    });

    _tts.setErrorHandler((msg) {
      DebugLogger.error('🔊 TTS Error: $msg');
      _isSpeaking = false;
      _isPaused = false;
      notifyListeners();
    });
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await stop();
    await _tts.speak(text);
  }

  Future<void> pause() async {
    if (_isSpeaking) {
      await _tts.pause();
    }
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
    _isPaused = false;
    notifyListeners();
  }

  Future<void> setLanguage(String langCode) async {
    _language = langCode;

    // Check if the requested language is available
    final available = await isLanguageAvailable(langCode);
    if (available) {
      await _tts.setLanguage(langCode);
    } else if (langCode == 'ne-NP') {
      // Nepali not natively available on most devices — use Hindi as fallback
      // Hindi voices can read Devanagari script used by Nepali
      final hindiAvailable = await isLanguageAvailable('hi-IN');
      if (hindiAvailable) {
        DebugLogger.info(
            '🔊 ne-NP not available, using hi-IN (Hindi) for Devanagari');
        await _tts.setLanguage('hi-IN');
      } else {
        DebugLogger.error('🔊 Neither ne-NP nor hi-IN available for TTS');
        await _tts.setLanguage(langCode); // Try anyway as last resort
      }
    } else {
      await _tts.setLanguage(langCode); // Try anyway
    }
    notifyListeners();
  }

  Future<void> setSpeed(double speed) async {
    _speed = speed;
    await _tts.setSpeechRate(speed);
    notifyListeners();
  }

  /// Cycle through speed presets: 0.25 → 0.5 → 0.75 → 1.0 → 1.5
  double cycleSpeed() {
    const speeds = [0.25, 0.5, 0.75, 1.0, 1.5];
    final currentIndex = speeds.indexOf(_speed);
    final nextIndex = (currentIndex + 1) % speeds.length;
    final newSpeed = speeds[nextIndex];
    setSpeed(newSpeed);
    return newSpeed;
  }

  Future<bool> isLanguageAvailable(String langCode) async {
    try {
      final result = await _tts.isLanguageAvailable(langCode);
      return result == true || result == 1;
    } catch (e) {
      DebugLogger.error('🔊 Language check failed: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
