import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/debug_logger.dart';

class Favorites with ChangeNotifier {
  Set<String> _favoriteProductIds = {};
  static const String _favoritesKey = 'favorite_products';
  bool _isLoaded = false;

  Set<String> get favoriteProductIds {
    return {..._favoriteProductIds};
  }

  bool get isLoaded => _isLoaded;

  int get favoriteCount {
    return _favoriteProductIds.length;
  }

  bool isFavorite(String productId) {
    return _favoriteProductIds.contains(productId);
  }

  // Load favorites from local storage
  Future<void> loadFavoritesFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesData = prefs.getStringList(_favoritesKey);

      if (favoritesData != null) {
        _favoriteProductIds = favoritesData.toSet();
      }

      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      DebugLogger.error('Error loading favorites from storage: $e');
      _isLoaded = true;
      notifyListeners();
    }
  }

  // Save favorites to local storage
  Future<void> saveFavoritesToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favoritesKey, _favoriteProductIds.toList());
    } catch (e) {
      DebugLogger.error('Error saving favorites to storage: $e');
    }
  }

  // Toggle favorite status
  Future<void> toggleFavorite(String productId) async {
    if (_favoriteProductIds.contains(productId)) {
      _favoriteProductIds.remove(productId);
    } else {
      _favoriteProductIds.add(productId);
    }
    notifyListeners();
    await saveFavoritesToStorage();
  }

  // Add to favorites
  Future<void> addFavorite(String productId) async {
    if (!_favoriteProductIds.contains(productId)) {
      _favoriteProductIds.add(productId);
      notifyListeners();
      await saveFavoritesToStorage();
    }
  }

  // Remove from favorites
  Future<void> removeFavorite(String productId) async {
    if (_favoriteProductIds.contains(productId)) {
      _favoriteProductIds.remove(productId);
      notifyListeners();
      await saveFavoritesToStorage();
    }
  }

  // Clear all favorites
  Future<void> clearFavorites() async {
    _favoriteProductIds.clear();
    notifyListeners();
    await saveFavoritesToStorage();
  }
}
