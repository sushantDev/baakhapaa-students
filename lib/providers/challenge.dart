import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/url.dart';

class Challenge with ChangeNotifier {
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  List<dynamic> _challenges = [];
  final String authToken;

  // 🔥 Season challenge progression state
  Map<String, dynamic>? _seasonDetails;
  Map<String, dynamic>? get seasonDetails => _seasonDetails;

  void setChallengeSeasonDetails(Map<String, dynamic> data) {
    _seasonDetails = data;
    notifyListeners();
  }

  Challenge(this.authToken, this._challenges);

  List<dynamic> get challenges {
    return _challenges;
  }

  Future<void> fetchChallenges() async {
    try {
      final response = await http
          .get(Uri.parse(Url.baakhapaaApi('/challenges')),
              headers: Url.baakhapaaAuthHeaders(authToken))
          .timeout(const Duration(seconds: 15));

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        _challenges = responseData['data']['items'];
        notifyListeners();
      }
    } catch (error) {
      debugPrint('Error fetching challenges: $error');
    }
  }

  Future<void> unlockChallenge(int challengeId) async {
    try {
      final response = await http.post(
        Uri.parse(
          Url.baakhapaaApi('/challenge/unlock-challenge'),
        ),
        headers: Url.baakhapaaAuthHeaders(authToken),
        body: json.encode({'challenge_id': challengeId}),
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        notifyListeners();
      } else {
        throw ('Error');
      }
    } catch (error) {
      throw error;
    }
  }

  // List of seasons for a challenge (from /seasons/challenge/{challengeId})
  List<dynamic> _challengeSeasons = [];
  List<dynamic> get challengeSeasons => _challengeSeasons;

  // List of products for a challenge
  List<dynamic> _challengeProducts = [];
  List<dynamic> get challengeProducts => _challengeProducts;

  // List of user's own products
  List<dynamic> _userProducts = [];
  List<dynamic> get userProducts => _userProducts;

  /// Fetch all seasons for a challenge (for leaderboard and step logic)
  Future<void> fetchChallengeSeasonsForChallenge(int challengeId) async {
    try {
      final response = await http
          .get(
            Uri.parse(Url.baakhapaaApi('/seasons/challenge/$challengeId')),
            headers: Url.baakhapaaAuthHeaders(authToken),
          )
          .timeout(const Duration(seconds: 15));
      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success'] == true) {
        final data = responseData['data'];
        if (data is Map<String, dynamic> && data.containsKey('items')) {
          _challengeSeasons = data['items'] ?? [];
        } else if (data is List) {
          _challengeSeasons = data;
        } else {
          _challengeSeasons = [];
        }
        notifyListeners();
      } else {
        _challengeSeasons = [];
        notifyListeners();
      }
    } catch (e) {
      _challengeSeasons = [];
      notifyListeners();
      debugPrint('Error fetching challenge seasons: $e');
    }
  }

  /// Fetch user's own products from /api/user/products/{userId}
  Future<void> fetchUserProducts(int userId) async {
    try {
      final response = await http
          .get(
            Uri.parse(Url.baakhapaaApi('/user/products/$userId')),
            headers: Url.baakhapaaAuthHeaders(authToken),
          )
          .timeout(const Duration(seconds: 15));
      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success'] == true) {
        final data = responseData['data'];
        if (data is Map<String, dynamic> && data.containsKey('items')) {
          _userProducts = data['items'] ?? [];
        } else if (data is List) {
          _userProducts = data;
        } else {
          _userProducts = [];
        }
        notifyListeners();
      } else {
        _userProducts = [];
        notifyListeners();
      }
    } catch (e) {
      _userProducts = [];
      notifyListeners();
      debugPrint('Error fetching user products: $e');
    }
  }

  /// Fetch all products for a challenge (for leaderboard and participants gallery)
  Future<void> fetchChallengeProductsForChallenge(int challengeId) async {
    try {
      final response = await http
          .get(
            Uri.parse(Url.baakhapaaApi('/products/challenge/$challengeId')),
            headers: Url.baakhapaaAuthHeaders(authToken),
          )
          .timeout(const Duration(seconds: 15));
      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success'] == true) {
        final data = responseData['data'];
        if (data is Map<String, dynamic> && data.containsKey('participants')) {
          _challengeProducts = data['participants'] ?? [];
        } else if (data is Map<String, dynamic> && data.containsKey('items')) {
          _challengeProducts = data['items'] ?? [];
        } else if (data is List) {
          _challengeProducts = data;
        } else {
          _challengeProducts = [];
        }
        notifyListeners();
      } else {
        _challengeProducts = [];
        notifyListeners();
      }
    } catch (e) {
      _challengeProducts = [];
      notifyListeners();
      debugPrint('Error fetching challenge products: $e');
    }
  }

  /// Create a challenge user entry when participating in a challenge
  /// Links the challenge with the created season
  // Future<Map<String, dynamic>> createChallengeUser({
  //   required int challengeId,
  //   required int seasonId,
  // }) async {
  //   try {
  //     final response = await http.post(
  //       Uri.parse(
  //         Url.baakhapaaApi('/challenge/participate'),
  //       ),
  //       headers: Url.baakhapaaAuthHeaders(authToken),
  //       body: json.encode({
  //         'challenge_id': challengeId,
  //         'season_id': seasonId,
  //       }),
  //     );

  //     var responseData = json.decode(utf8.decode((response.bodyBytes)));
  //     if (responseData['success']) {
  //       notifyListeners();
  //       return responseData['data'] ?? {};
  //     } else {
  //       throw Exception(
  //           responseData['message'] ?? 'Failed to create challenge user');
  //     }
  //   } catch (error) {
  //     throw error;
  //   }
  // }
}
