import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/url.dart';
import '../utils/debug_logger.dart';

class Leaderboard with ChangeNotifier {
  List<dynamic> _leaderboard = [];
  final String authToken;
  late List<dynamic> _leaderboardPopups = [];
  List<dynamic> _referralLeaderboard = [];

  List<dynamic> get leaderboardPopups {
    return _leaderboardPopups;
  }

  List<dynamic> get referralLeaderboard {
    return [..._referralLeaderboard];
  }

  Leaderboard(this.authToken, this._leaderboard);
  List<dynamic> get leaderboard {
    return _leaderboard;
  }

  Future<void> fetchLeaderboard(int page) async {
    try {
      final response = await http.get(
          Uri.parse(
              Url.baakhapaaApi('/v2/leaderboard-infinity?page[number]=$page')),
          headers: Url.baakhapaaAuthHeaders(authToken));

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        _leaderboard = responseData['data']['data'];
        notifyListeners();
      }
    } catch (error) {
      throw (error);
    }
  }

  Future<void> fetchLeaderboardPopup() async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/leaderboard-popup')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));

      // DebugLogger.api("Response Data: $responseData");
      if (responseData['success']) {
        _leaderboardPopups = responseData['data']['items'];
      } else {
        throw ('Error fetching story popup: ${responseData['message']}');
      }
    } catch (error) {
      throw ('Error fetching story popup: $error');
    }
  }

  Future<void> fetchReferralLeaderboard() async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/leaderboard/referral')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      final responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success']) {
        _referralLeaderboard = responseData['data']['items'];
        notifyListeners();
      } else {
        throw responseData['message'] ?? 'Failed to fetch referral leaderboard';
      }
    } catch (error) {
      DebugLogger.api('Error in fetchReferralLeaderboard: $error');
      throw error;
    }
  }
}
