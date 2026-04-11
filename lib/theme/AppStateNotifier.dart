import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class AppStateNotifier extends ChangeNotifier {
  static const String _themeKey = 'isDarkModeOn';
  bool _hasInternet = true;
  final SharedPreferences _prefs;

  bool get hasInternet => _hasInternet;

  AppStateNotifier(this._prefs);

  bool get isDarkModeOn => _prefs.getBool(_themeKey) ?? false;

  Future<void> toggleTheme() async {
    final newValue = !isDarkModeOn;
    await _prefs.setBool(_themeKey, newValue);
    notifyListeners();
  }

  Future<void> checkInternetConnectivity() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    _hasInternet = connectivityResult != ConnectivityResult.none;
    notifyListeners();
  }
}
