import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _currentLocale = const Locale('en');

  Locale get currentLocale => _currentLocale;

  List<Locale> get supportedLocales => const [
        Locale('en'), // English
        Locale('es'), // Spanish
        Locale('fr'), // French
        Locale('ne'), // Nepali
        Locale('hi'), // Nepali
        Locale('ko'), // Korean
        Locale('zh'), // Mandarin (Simplified Chinese)
        Locale('ja'), // Japanese
      ];

  Map<String, String> get languageNames => {
        'en': 'English',
        'es': 'Español',
        'fr': 'Français',
        'ne': 'नेपाली', // Nepali
        'hi': 'हिन्दी', // hindi
        'ko': '한국어', // Korean
        'zh': '中文 (简体)', // Mandarin Simplified
        'ja': '日本語', // Japanese
      };
  LanguageProvider() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'en';
    _currentLocale = Locale(languageCode);
    notifyListeners();
  }

  Future<void> changeLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
    _currentLocale = Locale(languageCode);
    notifyListeners();
  }
}
