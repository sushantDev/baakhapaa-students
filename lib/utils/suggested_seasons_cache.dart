class SuggestedSeasonsCache {
  static final SuggestedSeasonsCache _instance =
      SuggestedSeasonsCache._internal();
  factory SuggestedSeasonsCache() => _instance;
  SuggestedSeasonsCache._internal();

  List<Map<String, dynamic>> _cachedSuggestedSeasons = [];

  void updateCache(List<Map<String, dynamic>> suggestedSeasons) {
    _cachedSuggestedSeasons = List<Map<String, dynamic>>.from(suggestedSeasons);
  }

  List<Map<String, dynamic>> getCache() {
    return _cachedSuggestedSeasons;
  }

  void clearCache() {
    _cachedSuggestedSeasons = [];
  }

  bool get hasCache => _cachedSuggestedSeasons.isNotEmpty;
}
