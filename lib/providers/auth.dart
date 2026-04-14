import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../models/url.dart';
import '../utils/debug_logger.dart';
import '../services/analytics_service.dart';

class Auth with ChangeNotifier {
  late String _token = '';
  late Map<String, dynamic> _user = {};
  late List<dynamic> _advertisement = [];
  late List<dynamic> _creators = [];
  late bool _usernameExists;
  late Map<String, dynamic> _creatorPreferences = {};
  late Map<String, dynamic> _teamMember = {};
  late bool _mlbbTicketPurchased;
  late bool _challengeTicketPurchased;
  late bool _mlbbRegistered;
  Map<String, dynamic> _creatorsRankings = {};
  late List<dynamic> _conversations = [];
  late int _selectedConversationId;
  late List<dynamic> _messages;
  late List<dynamic> _achievements = [];
  late List<dynamic> _challenges = []; // Add challenges list
  final Map<int, List<dynamic>> _creatorEnrolledChallenges = {};
  late String _checkScriptStatus = '';
  late Map<String, dynamic> _checkScriptRemarks = {};
  late List<dynamic> _settingPopups = [];
  int _unreadMessageCount = 0;
  int _unreadNotificationCount = 0;
  late List<dynamic> _withdrawals = [];
  Function(String)? _onLevelUpCheck;
  bool _isLoadingUser = false; // Add loading state for user fetching
// Add these properties to your Auth class (near the top with other late declarations)
  late Map<String, dynamic> _followData = {
    'followers_count': 0,
    'following_count': 0,
    'is_following': false,
    'is_followed_by': false,
  };

  late List<dynamic> _followers = [];
  late List<dynamic> _following = [];

// Add these getters
  Map<String, dynamic> get followData {
    return {..._followData};
  }

  List<dynamic> get followers {
    return [..._followers];
  }

  List<dynamic> get following {
    return [..._following];
  }

  int get followersCount {
    return _followData['followers_count'] ?? 0;
  }

  int get followingCount {
    return _followData['following_count'] ?? 0;
  }

  bool get isFollowing {
    return _followData['is_following'] ?? false;
  }

  // Player profile cache
  Map<String, dynamic> _playerProfile = {};

  // Add this map to store daily rewards data
  Map<String, dynamic> _dailyRewardsData = {
    'current_day': 1,
    'can_claim_today': false,
    'last_claim_date': null,
    'reward_points': [10, 15, 20, 25, 30, 40, 50],
  };

  List<dynamic> get withdrawals {
    return [..._withdrawals];
  }

  double get nrsPerBaakhapaaPoints =>
      double.parse(user['nrs_per_baakhapaa_points']);

  bool get isLoadingUser {
    return _isLoadingUser;
  }

  bool get hasPointsToNrsConversionBadgeId =>
      user['has_points_to_nrs_conversion_badge_id'] ?? false;

  Map<String, dynamic> get dailyRewardsData {
    return {..._dailyRewardsData};
  }

  List<dynamic> get settingPopups {
    return _settingPopups;
  }

  Future<String> get authToken => _getToken();

  Future<String> _getToken() async {
    return _token;
  }

  bool get isAuth {
    return token != '';
  }

  String get token {
    return _token;
  }

  Map<String, dynamic> get user {
    return _user;
  }

  Map<String, dynamic> get teamMember {
    return _teamMember;
  }

  List<dynamic> get creators {
    return _creators;
  }

  List<dynamic> get achievements {
    return _achievements;
  }

  List<dynamic> get challenges {
    return _challenges;
  }

  List<dynamic> getCreatorEnrolledChallenges(int creatorId) {
    final cached = _creatorEnrolledChallenges[creatorId];
    if (cached == null) {
      return [];
    }
    return List<dynamic>.from(cached);
  }

  String get checkScriptStatus {
    return _checkScriptStatus;
  }

  Map<String, dynamic> get checkScriptRemarks {
    return _checkScriptRemarks;
  }

  bool get hasReferral {
    return _user['refer_code'] != null && _user['refer_code'] != '';
  }

  bool get mlbbTicketPurchased {
    return _mlbbTicketPurchased;
  }

  bool get challengeTicketPurchased {
    return _challengeTicketPurchased;
  }

  bool get mlbbRegistered {
    return _mlbbRegistered;
  }

  List<dynamic> get advertisement {
    return _advertisement;
  }

  String get userName {
    return (_user['name'] as String?) ?? 'Baakhapaa User';
  }

  int get userId {
    return _user['id'] as int;
  }

  String? get username {
    if (_user['username'] != null &&
        _user['information'] is Map<String, dynamic>) {
      return _user['username'] as String;
    } else {
      return '';
    }
  }

  String get role {
    return (_user['role'] as String?) ?? 'guest';
  }

  bool get isGuest {
    return role == 'guest' || _token.isEmpty;
  }

  bool get isEmailVerified {
    final value = _user['email_verified_at'] ??
        (_user['information'] is Map<String, dynamic>
            ? (_user['information'] as Map<String, dynamic>)['email_verified_at']
            : null);

    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value > 0;

    final normalized = value.toString().trim().toLowerCase();
    if (normalized.isEmpty ||
        normalized == 'null' ||
        normalized == 'false' ||
        normalized == '0' ||
        normalized == 'no' ||
        normalized == 'not_verified' ||
        normalized == 'unverified') {
      return false;
    }

    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }

    // For string timestamps, only treat as verified if it parses as a valid date.
    return DateTime.tryParse(value.toString()) != null;
  }

  int get userRank {
    final rank = _user['rank'];
    if (rank == null) return 0;
    return rank is int ? rank : int.tryParse(rank.toString()) ?? 0;
  }

  int get totalCount {
    final count = _user['count'];
    if (count == null) return 0;
    return count is int ? count : int.tryParse(count.toString()) ?? 0;
  }

  int get commentPoints {
    final points = _user['comment_points'];
    if (points == null) return 0;
    return points is int ? points : int.tryParse(points.toString()) ?? 0;
  }

  int get fallBackPoints {
    final points = _user['fall_back_point'];
    if (points == null) return 0;
    return points is int ? points : int.tryParse(points.toString()) ?? 0;
  }

  String? get fcmToken {
    return _user['fcm_token'];
  }

  bool get completedProfile {
    if (_user['phone_number'] == null) return false;
    return true;
  }

  String? get subscriptionExpiresAt {
    return _user['subscription_expires_at'];
  }

  bool get isSubscribed {
    if (subscriptionExpiresAt == null) return false;
    try {
      final expiryDate = DateTime.parse(subscriptionExpiresAt!);
      return expiryDate.isAfter(DateTime.now());
    } catch (e) {
      DebugLogger.info('Error parsing subscription expiry date: $e');
      return false;
    }
  }

  bool get isFirstLogin {
    if (_user['is_first_login'] == 1) return true;
    return false;
  }

  Map<String, dynamic> get creatorsRankings {
    return _creatorsRankings;
  }

  Map<String, dynamic>? get userInformation {
    if (_user.isNotEmpty &&
        _user['information'] != null &&
        _user['information'] is Map<String, dynamic>) {
      return _user['information'] as Map<String, dynamic>;
    } else {
      return {};
    }
  }

  String? get affiliateProgramStatus {
    return _user['affiliation']?['program_status']?['status'];
  }

  bool get isAffiliate {
    return _user['affiliation']?['program_status']?['is_approved'] ?? false;
  }

  String? get affiliateRemarks {
    return _user['affiliation']?['program_status']?['remarks'];
  }

  Map<String, dynamic>? get affiliateCooldown {
    return _user['affiliation']?['cooldown'];
  }

  int get userAvailableCoins {
    final Map<String, dynamic>? information = userInformation;
    if (information != null && information.containsKey('available_coins')) {
      return information['available_coins'] as int;
    } else {
      return 0;
    }
  }

  /// Deduct coins from the local user state. Call this before/alongside
  /// the backend coin-transaction API so the UI reflects the change instantly.
  void deductCoinsLocally(int amount) {
    final info = userInformation;
    if (info != null && info.containsKey('available_coins')) {
      final current = info['available_coins'] as int? ?? 0;
      info['available_coins'] = max(0, current - amount);
      notifyListeners();
    }
  }

  /// Revert a previous deductCoinsLocally call (e.g. when backend rejects).
  void addCoinsLocally(int amount) {
    final info = userInformation;
    if (info != null && info.containsKey('available_coins')) {
      final current = info['available_coins'] as int? ?? 0;
      info['available_coins'] = current + amount;
      notifyListeners();
    }
  }

  /// Sync the local available_coins with a confirmed balance from the backend.
  void syncAvailableCoins(int balance) {
    final info = userInformation;
    if (info != null) {
      info['available_coins'] = balance;
      notifyListeners();
    }
  }

  String? get puppetImage {
    if (_user.isNotEmpty && _user.containsKey('puppet_image')) {
      return _user['puppet_image'] as String?;
    }
    return null;
  }

  String? get spinAndWinLastUsedTime {
    final Map<String, dynamic>? information = userInformation;
    if (information != null &&
        information.containsKey('spin_and_win_last_used_time')) {
      return information['spin_and_win_last_used_time'] as String?;
    } else {
      return '';
    }
  }

  String? get giftRedeemLastUsedTime {
    final Map<String, dynamic>? information = userInformation;
    if (information != null &&
        information.containsKey('gift_redeem_last_used_time')) {
      return information['gift_redeem_last_used_time'] as String?;
    } else {
      return '';
    }
  }

  int? get cooldownTime {
    final Map<String, dynamic>? information = userInformation;
    if (information != null && information.containsKey('cooldown_time')) {
      return information['cooldown_time'] as int?;
    } else {
      return 0;
    }
  }

  List<dynamic> get coinLogs {
    // Return empty list since coin logs are now fetched separately
    return [];
  }

  List<dynamic>? get image {
    final dynamic imagesData = _user['images'];
    if (imagesData != null && imagesData is List<dynamic>) {
      return imagesData;
    } else {
      return [];
    }
  }

  bool get usernameExists {
    return _usernameExists;
  }

  String get referCode {
    return _user['refer_code'] as String;
  }

  Map<String, dynamic> get creatorPreferences {
    return _creatorPreferences;
  }

  List<dynamic> get conversations {
    return _conversations;
  }

  int get selectedConversationId {
    return _selectedConversationId;
  }

  List<dynamic> get messages => _messages;

  int get unreadMessageCount => _unreadMessageCount;

  int get unreadNotificationCount => _unreadNotificationCount;

  Map<String, dynamic> get playerProfile {
    return _playerProfile;
  }

  void setLevelUpCallback(Function(String) callback) {
    _onLevelUpCheck = callback;
  }

  void setPreference(_token, _user) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('userData');
    final userData = json.encode(
      {
        'token': _token,
        'user': _user,
      },
    );
    prefs.setString('userData', userData);
  }

  void authenticate(response) async {
    var responseData = json.decode(utf8.decode((response.bodyBytes)));
    if (responseData['success']) {
      _token = responseData['data']['access_token'];
      _user = responseData['data']['user'];

      // Set loading state immediately after successful authentication
      // This prevents showing login icon in footer during user data fetch
      _isLoadingUser = true;

      setPreference(_token, _user);

      // Set Firebase Analytics user identity
      AnalyticsService.setUserId(_user['id'].toString());
      AnalyticsService.setUserProperties(
        role: _user['role'] ?? 'player',
        subscriptionTier: isSubscribed ? 'subscribed' : 'free',
        isCreator: (_user['role'] == 'creator'),
      );

      // SECURITY: Refresh FCM token for new user to prevent cross-user notifications
      try {
        await FirebaseMessaging.instance.deleteToken();
        DebugLogger.info('🔄 Deleted old FCM token on login');

        String? newToken = await FirebaseMessaging.instance.getToken();
        if (newToken != null) {
          DebugLogger.info(
              '✅ New FCM token obtained: ${newToken.substring(0, 20)}...');
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('fcmToken', newToken);
          DebugLogger.info('💾 New FCM token saved for user ${_user['id']}');
          await saveFCMToken(newToken);
          DebugLogger.info(
              '✅ New FCM token sent to backend for user ${_user['id']}');
        }
      } catch (e) {
        DebugLogger.info('⚠️ Error refreshing FCM token on login: $e');
      }

      notifyListeners();
    } else {
      throw responseData['message'];
    }
  }

  Future<void> _checkLevelUpAfterPointsGain() async {
    try {
      // Trigger level up check through callback if available
      if (_onLevelUpCheck != null) {
        _onLevelUpCheck!(_token);
      }
      notifyListeners();
    } catch (error) {
      DebugLogger.error('Error auto-checking level up: $error');
    }
  }

  Future<void> getAdvertisement() async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/advertisement')),
        headers: Url.baakhapaaHeaders,
      );
      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        _advertisement = responseData['data']['items'];
        notifyListeners();
      } else {
        throw ('Error');
      }
    } catch (error) {
      throw (error);
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/login')),
        headers: Url.baakhapaaHeaders,
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );
      if (response.statusCode == 200) {
        authenticate(response);
        AnalyticsService.logLogin(method: 'email');
        notifyListeners();
      } else {
        throw Exception('Authentication failed: ${response.statusCode}');
      }
    } catch (error) {
      throw error;
    }
  }

  Future<bool> checkGoogleUser(String email) async {
    try {
      // Use GET since your API route for email check is a GET request
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/email/$email/check')),
        headers: Url.baakhapaaHeaders,
      );

      if (response.statusCode != 200) return false;

      final data = json.decode(response.body);
      // Assuming API returns { "exists": true/false }
      return data['exists'] == true;
    } catch (e) {
      DebugLogger.info('Error checking Google user: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> loginGoogle(
    String name,
    String email,
    String photoUrl,
    String? username, // Make username optional for new/existing users
  ) async {
    try {
      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/v2/login/google')),
        headers: Url.baakhapaaHeaders,
        body: json.encode({
          'email': email,
          'name': name,
          'photoUrl': photoUrl,
          if (username != null) 'username': username,
        }),
      );

      final responseData = json.decode(response.body);

      if (!responseData['success']) {
        throw Exception('Google login failed');
      }

      if (responseData['data']['access_token'] != null) {
        authenticate(response);
        AnalyticsService.logLogin(method: 'google');
        await getUser();
      }

      return responseData;
    } catch (e) {
      DebugLogger.error('Error in loginGoogle: $e');
      throw e;
    }
  }

  Future<Map<String, dynamic>> loginApple(
    String identityToken,
    String? name,
    String? email,
    String? username, // Make username optional for new/existing users
  ) async {
    try {
      // Send additional context to help backend extract user info
      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/v2/login/apple')),
        headers: Url.baakhapaaHeaders,
        body: json.encode({
          'identityToken': identityToken,
          if (name != null) 'name': name,
          if (email != null) 'email': email,
          if (username != null) 'username': username,
          // Request backend to decode identity token for user info
          'extract_user_info': true,
        }),
      );

      final responseData = json.decode(response.body);

      if (!responseData['success']) {
        throw Exception(
            'Apple login failed: ${responseData['message'] ?? 'Unknown error'}');
      }

      if (responseData['data']['access_token'] != null) {
        authenticate(response);
        AnalyticsService.logLogin(method: 'apple');
        await getUser();
      }

      return responseData;
    } catch (e) {
      DebugLogger.error('Error in loginApple: $e');
      throw e;
    }
  }

  Future<void> register(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/register')),
        headers: Url.baakhapaaHeaders,
        body: json.encode({
          'username': name,
          'email': email,
          'password': password,
          'role': 'player',
        }),
      );

      // Check response status code
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success - authenticate user
        authenticate(response);
        AnalyticsService.logSignUp(method: 'email');
        notifyListeners();
      } else if (response.statusCode == 422) {
        // Validation errors
        var responseData = json.decode(utf8.decode(response.bodyBytes));
        throw responseData; // Throw the entire response data including errors
      } else {
        // Other errors
        var responseData = json.decode(utf8.decode(response.bodyBytes));
        throw responseData['message'] ??
            'Registration failed. Please try again.';
      }
    } catch (error) {
      throw error;
    }
  }

  Future<bool> tryAutoLogin() async {
    DebugLogger.info("🔐 Auth.tryAutoLogin() - Starting auto login check");
    final prefs = await SharedPreferences.getInstance();

    if (!prefs.containsKey('userData')) {
      DebugLogger.info(
          "🔐 Auth.tryAutoLogin() - No userData found in preferences");
      return false;
    }

    DebugLogger.info("🔐 Auth.tryAutoLogin() - Found userData in preferences");
    final extractedUserData =
        json.decode(prefs.get('userData') as String) as Map<String, dynamic>;
    _token = extractedUserData['token'] as String;
    _user = extractedUserData['user'] as Map<String, dynamic>;
    DebugLogger.info(
        "🔐 Auth.tryAutoLogin() - Token loaded: ${_token.isNotEmpty}");
    DebugLogger.info(
        "🔐 Auth.tryAutoLogin() - User loaded: ${_user['username'] ?? 'unknown'}");
    notifyListeners();
    DebugLogger.info("🔐 Auth.tryAutoLogin() - Auto login successful");

    // Set Firebase Analytics user identity on auto-login
    AnalyticsService.setUserId(_user['id'].toString());
    AnalyticsService.setUserProperties(
      role: _user['role'] ?? 'player',
      subscriptionTier: isSubscribed ? 'subscribed' : 'free',
      isCreator: (_user['role'] == 'creator'),
    );
    AnalyticsService.logLogin(method: 'auto_login');

    // Re-register FCM token with backend on every auto-login (covers server resets, token clears, etc.)
    try {
      final storedToken = prefs.getString('fcmToken');
      if (storedToken != null && storedToken.isNotEmpty) {
        await saveFCMToken(storedToken);
        DebugLogger.info(
            '✅ FCM token re-registered with backend on auto-login');
      }
    } catch (e) {
      DebugLogger.info('⚠️ Error re-registering FCM token on auto-login: $e');
    }

    return true;
  }

  Future<void> getUser() async {
    if (_token.isEmpty) {
      // Ensure loading state is false for guest users
      _isLoadingUser = false;
      notifyListeners();
      return;
    }

    _isLoadingUser = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/v2/user')),
        headers: Url.baakhapaaAuthHeaders(_token),
      );
      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success'] && responseData['data'] != null) {
        _user = responseData['data']; // Changed from data.item to data

        // Extract unread notification count from user data or information
        if (_user['unread_notifications_count'] != null) {
          _unreadNotificationCount = _user['unread_notifications_count'] as int;
        } else if (_user['information'] != null &&
            _user['information']['unread_notifications_count'] != null) {
          _unreadNotificationCount =
              _user['information']['unread_notifications_count'] as int;
        } else {
          _unreadNotificationCount = 0;
        }

        DebugLogger.info(
            '📊 AUTH: Unread notification count from API: $_unreadNotificationCount');
        setPreference(_token, _user);
      } else {
        DebugLogger.auth(
            'Error: User data is null or API response unsuccessful');
        throw Exception('Failed to fetch user data');
      }
    } catch (error) {
      DebugLogger.error('Error fetching user: $error');
    } finally {
      _isLoadingUser = false;
      notifyListeners();
    }
  }

  Future<void> verifyUserEmail() async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/email/resend/${_user['email']}')),
        headers: Url.baakhapaaAuthHeaders(_token),
      );
      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        notifyListeners();
      }
    } catch (error) {
      throw error;
    }
  }

  // Future<void> updateUser(Map<String, String> userData) async {
  //   try {
  //     await http.post(
  //       Uri.parse(Url.baakhapaaApi('/user/${_user['id']}')),
  //       headers: Url.baakhapaaAuthHeaders(_token),
  //       body: json.encode(userData),
  //     );
  //   } catch (error) {
  //     throw error;
  //   }
  // }

  Future<void> updateUser(Map<String, String> userData) async {
    try {
      // Special handling for bio-only updates using the dedicated bio endpoint
      if (userData.keys.length == 1 && userData.containsKey('bio')) {
        final url = Url.baakhapaaApi('/user/${_user['username']}/bio');

        final response = await http.post(
          Uri.parse(url),
          headers: Url.baakhapaaAuthHeaders(_token),
          body: json.encode(userData),
        );

        var responseData = json.decode(utf8.decode(response.bodyBytes));

        if (responseData['success'] == true) {
          // Update local bio from response
          _user['bio'] = responseData['bio'] ?? userData['bio'];

          // Also update creatorsRankings if it exists (for creator profile page display)
          // The structure is flat: { bio: "value", user_id: ..., username: ... }
          if (_creatorsRankings.isNotEmpty) {
            _creatorsRankings['bio'] = _user['bio'];
          }

          // Update shared preferences
          final prefs = await SharedPreferences.getInstance();
          final userDataString = json.encode({
            'token': _token,
            'user': _user,
          });
          await prefs.setString('userData', userDataString);

          notifyListeners();
        } else {
          throw Exception(responseData['message'] ?? 'Failed to update bio');
        }
      } else {
        // Original endpoint for other user data updates
        final url = Url.baakhapaaApi('/user/${_user['id']}');

        final response = await http.post(
          Uri.parse(url),
          headers: Url.baakhapaaAuthHeaders(_token),
          body: json.encode(userData),
        );

        var responseData = json.decode(utf8.decode(response.bodyBytes));

        if (responseData['success'] == true) {
          // Update local user data with the sent data since API returns null for data
          userData.forEach((key, value) {
            _user[key] = value;
          });

          // Update shared preferences
          final prefs = await SharedPreferences.getInstance();
          final userDataString = json.encode({
            'token': _token,
            'user': _user,
          });
          await prefs.setString('userData', userDataString);

          notifyListeners();
        } else {
          throw Exception(responseData['message'] ?? 'Failed to update user');
        }
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> updateUserImage(File image) async {
    try {
      final url =
          Uri.parse(Url.baakhapaaApi('/user/${_user['username']}/image'));

      var request = http.MultipartRequest('POST', url);

      var multipartFile = http.MultipartFile.fromBytes(
        'image',
        image.readAsBytesSync(),
        filename: image.path,
      );

      request.files.add(multipartFile);
      request.headers.addAll(Url.baakhapaaAuthHeadersWithFiles(_token));

      var res = await request.send();
      if (res.statusCode == 200) {
        notifyListeners();
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/forget-password/$email')),
        headers: Url.baakhapaaAuthHeaders(_token),
      );
      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        notifyListeners();
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> changePassword(String email, String otp, String password) async {
    try {
      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/change-password')),
        headers: Url.baakhapaaAuthHeaders(_token),
        body: json.encode({
          'email': email,
          'otp': otp,
          'password': password,
        }),
      );
      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        notifyListeners();
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> signout() async {
    _token = '';
    _isLoadingUser = false; // Reset loading state on signout

    // Clear Firebase Analytics user identity
    AnalyticsService.clearUserId();
    AnalyticsService.logCustomEvent('logout');

    // Delete FCM token to prevent cross-user notifications
    try {
      await FirebaseMessaging.instance.deleteToken();
      DebugLogger.info('🔔 FCM token deleted on logout');
    } catch (e) {
      DebugLogger.info('⚠️ Error deleting FCM token: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userData');
    await prefs.remove('errorMessage');
    await prefs.remove('fcmToken'); // Remove stored FCM token
    notifyListeners();
  }

  Future<void> fetchCreators() async {
    try {
      final response = await http
          .get(
              Uri.parse(
                Url.baakhapaaApi('/user/creators'),
              ),
              headers: Url.baakhapaaAuthHeaders(_token))
          .timeout(const Duration(seconds: 15));

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        _creators = responseData['data']['items'];
        notifyListeners();
      } else {
        throw ('Error');
      }
    } catch (error) {
      DebugLogger.error('Error fetching creators: $error');
    }
  }

  Future<void> fetchAllCreators() async {
    try {
      final response = await http
          .get(
              Uri.parse(
                Url.baakhapaaApi('/user/creators/all'),
              ),
              headers: Url.baakhapaaAuthHeaders(_token))
          .timeout(const Duration(seconds: 15));

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        _creators = responseData['data']['items'];
        notifyListeners();
      } else {
        throw ('Error');
      }
    } catch (error) {
      DebugLogger.error('Error fetching all creators: $error');
    }
  }

  Future<void> checkUsername(String username) async {
    DebugLogger.info("👤 Auth.checkUsername() - Checking username: $username");
    try {
      final response = await http.get(
        Uri.parse(
          Url.baakhapaaApi('/username/$username/check'),
        ),
      );
      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      DebugLogger.info(
          "👤 Auth.checkUsername() - API response: ${responseData['success']}");
      if (responseData['success']) {
        if (responseData['message'] == "USER_EXISTS") {
          _usernameExists = true;
          DebugLogger.info("✅ Auth.checkUsername() - User exists");
        } else {
          _usernameExists = false;
          DebugLogger.info("❌ Auth.checkUsername() - User does not exist");
        }
      } else {
        _usernameExists = true;
        DebugLogger.info(
            "⚠️ Auth.checkUsername() - API error, assuming user exists");
      }
      notifyListeners();
    } catch (error) {
      DebugLogger.info("💥 Auth.checkUsername() - Exception: $error");
      throw error;
    }
  }

  Future<void> setReferCode(String username) async {
    DebugLogger.info(
        "🎯 Auth.setReferCode() - Setting referral code for username: $username");
    try {
      final response = await http.get(
        Uri.parse(
          Url.baakhapaaApi('/user/refercode/$username'),
        ),
        headers: Url.baakhapaaAuthHeaders(_token),
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      DebugLogger.info(
          "🎯 Auth.setReferCode() - API response: ${responseData['success']}");
      if (responseData['success']) {
        DebugLogger.info(
            "✅ Auth.setReferCode() - Referral code set successfully");
        notifyListeners();
      } else {
        DebugLogger.info("❌ Auth.setReferCode() - API returned error");
        throw ('Error');
      }
    } catch (error) {
      DebugLogger.info("💥 Auth.setReferCode() - Exception: $error");
      throw error;
    }
  }

  /// Claim the 40-coin onboarding completion reward (idempotent — safe to call
  /// even if already claimed; backend will simply return a success message).
  Future<void> claimOnboardingReward() async {
    try {
      await http.post(
        Uri.parse(Url.baakhapaaApi('/claim-onboarding-reward')),
        headers: Url.baakhapaaAuthHeaders(_token),
      );
      // Refresh coin balance so UI reflects the new coins
      await getUser();
    } catch (_) {
      // Silently ignore — reward claim should never disrupt normal auth flow
    }
  }

  Future<void> storeOnboardingSelections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('onboarding_role');
      final timeEngagement = prefs.getString('onboarding_time_engagement');
      if (role == null && timeEngagement == null) return;

      final body = <String, dynamic>{};
      if (role != null) body['onboarding_role'] = role;
      if (timeEngagement != null) {
        body['onboarding_time_engagement'] = timeEngagement;
      }

      await http.post(
        Uri.parse(Url.baakhapaaApi('/store-onboarding-selections')),
        headers: Url.baakhapaaAuthHeaders(_token),
        body: json.encode(body),
      );
    } catch (_) {
      // Silently ignore — should not disrupt login flow
    }
  }

  Future<void> donation(
      int points, int id, String comment, String platform) async {
    try {
      await http.post(
        Uri.parse(Url.baakhapaaApi('/v2/donation')),
        headers: Url.baakhapaaAuthHeaders(_token),
        body: json.encode({
          'points': points,
          'id': id,
          'platform': platform,
          'comment': comment,
        }),
      );
    } catch (error) {
      throw error;
    }
  }

  Future<void> fetchCreatorPreferences() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              Url.baakhapaaApi('/creator-preferences'),
            ),
            headers: Url.baakhapaaAuthHeaders(_token),
          )
          .timeout(const Duration(seconds: 15));

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        _creatorPreferences = responseData['data'];
        notifyListeners();
      } else {
        throw ('Error');
      }
    } catch (error) {
      DebugLogger.error('Error fetching creator preferences: $error');
    }
  }

  Future<void> creatorRequest() async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/creator-role-request')),
        headers: Url.baakhapaaAuthHeaders(_token),
      );
      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        notifyListeners();
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> showUser(String username) async {
    try {
      final response = await http
          .get(
            Uri.parse(Url.baakhapaaApi('/user/$username/show')),
            headers: Url.baakhapaaAuthHeaders(_token),
          )
          .timeout(const Duration(seconds: 15));
      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        _teamMember = responseData['data'];
        notifyListeners();
      }
    } catch (error) {
      DebugLogger.error('Error showing user: $error');
    }
  }

  Future<void> checkMlbbRegistered() async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/mlbb-registration/has-registered')),
        headers: Url.baakhapaaAuthHeaders(_token),
      );
      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        _mlbbRegistered =
            responseData['message'] == 'REGISTERED' ? true : false;
        notifyListeners();
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> popupViewed(int popopId) async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/popup/$popopId')),
        headers: Url.baakhapaaAuthHeaders(_token),
      );
      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        notifyListeners();
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> coinTransaction(int coins, String status, String remarks) async {
    try {
      DebugLogger.info(
          '💰 CoinTransaction: Starting - Status: $status, Coins: $coins');

      final transactionResponse = await http.post(
        Uri.parse(
          Url.baakhapaaApi('/coin-transaction'),
        ),
        headers: Url.baakhapaaAuthHeaders(_token),
        body: json.encode({
          'user_id': userId,
          'status': status,
          'coin': coins,
          'remarks': remarks,
        }),
      );

      var responseData = json.decode(transactionResponse.body);
      DebugLogger.info('💰 CoinTransaction Response: ${responseData}');

      // Check for HTTP errors
      if (responseData['code'] != null && responseData['code'] >= 400) {
        DebugLogger.error(
            '❌ CoinTransaction failed with code: ${responseData['code']}');
        throw responseData['message'] ?? 'Transaction failed';
      }

      // Check if transaction was successful
      if (responseData['success'] == true) {
        DebugLogger.info('✅ CoinTransaction: Success');

        // Update local coin balance immediately
        if (status == 'debited') {
          _user['available_coins'] = (_user['available_coins'] ?? 0) - coins;
          DebugLogger.info(
              '💰 Coins debited: New balance = ${_user['available_coins']}');
        } else if (status == 'credited') {
          _user['available_coins'] = (_user['available_coins'] ?? 0) + coins;
          DebugLogger.info(
              '💰 Coins credited: New balance = ${_user['available_coins']}');
        }

        // Notify listeners to update UI
        notifyListeners();

        // Auto-check level up when user gains points
        if (status == 'credited') {
          _checkLevelUpAfterPointsGain();
        }
      } else {
        DebugLogger.error('❌ CoinTransaction: API returned success=false');
        throw responseData['message'] ?? 'Transaction failed';
      }
    } catch (error) {
      DebugLogger.error('❌ CoinTransaction Error: $error');
      throw error;
    }
  }

  // Update user balances from API response (e.g., daily rewards, pusher events)
  // This ensures UI reflects the latest balance immediately
  void updateUserBalances({
    int? availableCoins,
    int? earnedCoins,
    int? totalUsedCoins,
  }) {
    try {
      if (availableCoins != null) {
        _user['available_coins'] = availableCoins;
        DebugLogger.info(
            '💰 Balance updated: available_coins = $availableCoins');
      }
      if (earnedCoins != null) {
        _user['earned_coins'] = earnedCoins;
        DebugLogger.info('💰 Balance updated: earned_coins = $earnedCoins');
      }
      if (totalUsedCoins != null) {
        _user['total_used_coins'] = totalUsedCoins;
        DebugLogger.info(
            '💰 Balance updated: total_used_coins = $totalUsedCoins');
      }

      // Notify listeners to update UI
      notifyListeners();
      DebugLogger.info('✅ User balances updated and UI notified');
    } catch (error) {
      DebugLogger.error('❌ Error updating user balances: $error');
    }
  }

  Future<void> checkMlbbTicketPurchased() async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/mlbb-registration/can-access')),
        headers: Url.baakhapaaAuthHeaders(_token),
      );
      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        _mlbbTicketPurchased =
            responseData['message'] == 'PURCHASED' ? true : false;
        notifyListeners();
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> mlbbRegistration(
      Map<String, dynamic> data, File teamLogo) async {
    try {
      final url = Uri.parse(Url.baakhapaaApi('/mlbb-registration'));

      var request = http.MultipartRequest('POST', url);

      request.files
          .add(await http.MultipartFile.fromPath('team_logo', teamLogo.path));
      request.fields['name'] = data['name'];
      request.fields['contact_number'] = data['contact_number'];
      request.fields['ign'] = data['ign'];
      request.fields['id_number'] = data['id_number'];
      request.fields['discord_id'] = data['discord_id'];
      request.fields['number_of_players'] = data['number_of_players'];
      request.fields['team_players'] = json.encode(data['team_players']);
      request.fields['game_id'] = data['game_id'];
      request.fields['server_id'] = data['server_id'];
      request.headers.addAll(Url.baakhapaaAuthHeadersWithFiles(_token));

      final response = await request.send();
      if (response.statusCode == 200) {
        notifyListeners();
      } else {
        String errorMessage = await utf8.decodeStream(response.stream);
        throw 'Could not register. $errorMessage';
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> cooldownReset(
      {String? platform, String? dateTime, int? cooldownTime}) async {
    try {
      await http.post(
        Uri.parse(
          Url.baakhapaaApi('/cooldown'),
        ),
        headers: Url.baakhapaaAuthHeaders(_token),
        body: json.encode({
          'platform': platform,
          'dateTime': dateTime,
          'cooldownTime': cooldownTime
        }),
      );
    } catch (error) {
      throw error;
    }
  }

  Future<void> getAchievements() async {
    try {
      final response = await http
          .get(
            Uri.parse(Url.baakhapaaApi('/v2/user/achievements')),
            headers: Url.baakhapaaAuthHeaders(_token),
          )
          .timeout(const Duration(seconds: 15));
      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        _achievements = responseData['data']['items'];
        notifyListeners();
      }
      DebugLogger.info('Loaded ${_achievements.length} achievements');
    } catch (error) {
      DebugLogger.error('Error fetching achievements: $error');
    }
  }

  Future<Map<String, dynamic>> fetchCreatorAchievements(int creatorId) async {
    try {
      final response = await http
          .get(
            Uri.parse(Url.baakhapaaApi('/creator/$creatorId/achievements')),
            headers: Url.baakhapaaAuthHeaders(_token),
          )
          .timeout(const Duration(seconds: 15));

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success'] == true) {
        final normalized =
            _normalizeCreatorAchievementsResponse(responseData['data']);
        return normalized;
      } else {
        final msg = responseData['message']?.toString() ??
            'Failed to fetch achievements';
        // For rate-limit (429) or server errors, return empty gracefully instead of crashing.
        if (response.statusCode == 429 ||
            msg.toLowerCase().contains('too many')) {
          DebugLogger.info(
              'fetchCreatorAchievements: rate limited, returning empty');
          return {'items': <dynamic>[], 'completed': 0, 'total': 0};
        }
        throw msg;
      }
    } catch (error) {
      DebugLogger.error('Error fetching creator achievements: $error');
      rethrow;
    }
  }

  Map<String, dynamic> _normalizeCreatorAchievementsResponse(dynamic data) {
    List<dynamic> items = [];
    int completed = 0;
    int total = 0;

    if (data == null) {
      return {'items': items, 'completed': completed, 'total': total};
    }

    if (data is List) {
      items = List<dynamic>.from(data);
    } else if (data is Map) {
      final map = Map<String, dynamic>.from(data);

      if (map['items'] is List) {
        items = List<dynamic>.from(map['items'] as List);
      } else if (map['achievements'] is List) {
        items = List<dynamic>.from(map['achievements'] as List);
      } else if (map['data'] is List) {
        items = List<dynamic>.from(map['data'] as List);
      } else {
        final fallbackEntry = map.entries.firstWhere(
          (entry) => entry.value is List,
          orElse: () => const MapEntry<String, dynamic>('', []),
        );
        if (fallbackEntry.value is List) {
          items = List<dynamic>.from(fallbackEntry.value as List);
        }
      }

      total = _parseToInt(map['total'] ??
          map['count'] ??
          map['achievements_count'] ??
          map['total_achievements'] ??
          0);

      completed = _parseToInt(map['completed'] ??
          map['obtained'] ??
          map['unlocked'] ??
          map['claimed_count'] ??
          map['achievements_completed'] ??
          0);
    }

    if (total == 0) {
      total = items.length;
    }

    if (completed == 0 && items.isNotEmpty) {
      completed = items.where((item) {
        if (item is Map) {
          final itemMap = Map<String, dynamic>.from(item);
          final claimed = itemMap['claimed'];
          final obtained = itemMap['obtained'];
          final done = itemMap['completed'];
          return claimed == 1 ||
              claimed == true ||
              obtained == 1 ||
              obtained == true ||
              done == true;
        }
        return false;
      }).length;
    }

    return {
      'items': items,
      'completed': completed,
      'total': total,
    };
  }

  List<dynamic> _extractChallengeItems(dynamic payload) {
    if (payload == null) {
      return [];
    }

    if (payload is List) {
      return payload.where((item) => item != null).toList();
    }

    if (payload is Map<String, dynamic>) {
      if (payload['items'] is List) {
        return (payload['items'] as List)
            .where((item) => item != null)
            .toList();
      }
      if (payload['data'] is List) {
        return (payload['data'] as List).where((item) => item != null).toList();
      }
      if (payload['challenges'] is List) {
        return (payload['challenges'] as List)
            .where((item) => item != null)
            .toList();
      }
    }

    return [];
  }

  int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  Future<void> getChallenges() async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/challenges')),
        headers: Url.baakhapaaAuthHeaders(_token),
      );
      var responseData = json.decode(utf8.decode((response.bodyBytes)));

      if (responseData['success']) {
        // Handle the correct API response structure: data.items
        var data = responseData['data'];

        if (data is Map && data.containsKey('items')) {
          // The challenges are in data.items
          _challenges = data['items'] ?? [];
        } else if (data is List) {
          _challenges = data;
        } else if (data is Map && data.containsKey('data')) {
          // If data is a map with a 'data' key containing the list
          _challenges = data['data'] ?? [];
        } else if (data is Map && data.containsKey('challenges')) {
          // If data is a map with a 'challenges' key containing the list
          _challenges = data['challenges'] ?? [];
        } else {
          // If data is a map, convert it to a list with single item
          _challenges = data != null ? [data] : [];
        }
        notifyListeners();
      } else {
        _challenges = [];
      }
    } catch (error) {
      DebugLogger.api('Error fetching challenges: $error');
      _challenges = [];
    }
  }

  Future<void> fetchCreatorEnrolledChallenges(int creatorId) async {
    if (creatorId <= 0) {
      _creatorEnrolledChallenges.remove(creatorId);
      notifyListeners();
      return;
    }

    try {
      final response = await http
          .get(
            Uri.parse(Url.baakhapaaApi('/challenges/$creatorId/enrolled')),
            headers: Url.baakhapaaAuthHeaders(_token),
          )
          .timeout(const Duration(seconds: 15));

      final responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success'] == true) {
        _creatorEnrolledChallenges[creatorId] =
            _extractChallengeItems(responseData['data']);
        notifyListeners();
      } else {
        throw responseData['message'] ??
            'Failed to fetch enrolled challenges for creator';
      }
    } catch (error) {
      DebugLogger.error(
          'Auth: Error fetching creator enrolled challenges: $error');
    }
  }

  // New method to fetch coin logs separately
  Future<Map<String, dynamic>> getCoinLogs({int page = 1}) async {
    try {
      final response = await http
          .get(
            Uri.parse(Url.baakhapaaApi('/v2/user/coin-logs?page=$page')),
            headers: Url.baakhapaaAuthHeaders(_token),
          )
          .timeout(const Duration(seconds: 15));
      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        return responseData['data'];
      } else {
        throw responseData['message'] ?? 'Failed to fetch coin logs';
      }
    } catch (error) {
      throw error;
    }
  }

  Future<List<int>> getClaimedAchievements() async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/user-achievements')),
        headers: Url.baakhapaaAuthHeaders(_token),
      );

      var responseData = json.decode(response.body);
      if (responseData['success']) {
        return responseData['data']['items']
            .where((achievement) => achievement['claimed'] == 1)
            .map<int>((achievement) => achievement['id'] as int)
            .toList();
      } else {
        throw responseData['message'];
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> claimAchievements({List<int>? achievementIds}) async {
    try {
      await http.post(
        Uri.parse(
          Url.baakhapaaApi('/claim-achievements'),
        ),
        headers: Url.baakhapaaAuthHeaders(_token),
        body: json.encode({
          'achievements': achievementIds,
        }),
      );
    } catch (error) {
      throw error;
    }
  }

  Future<void> claimAchievementDiscount(int achievement) async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/claim-achievement/$achievement/discount')),
        headers: Url.baakhapaaAuthHeaders(_token),
      );
      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        notifyListeners();
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> changeFirstLoginStatus() async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/user/skip-tutorial')),
        headers: Url.baakhapaaAuthHeaders(_token),
      );
      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        notifyListeners();
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> checkScriptTicketPurchased() async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/challenge/can-access')),
        headers: Url.baakhapaaAuthHeaders(_token),
      );
      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        _challengeTicketPurchased =
            responseData['message'] == 'PURCHASED' ? true : false;
        notifyListeners();
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> submitChallengeRequest(
    String script,
    File? image,
  ) async {
    try {
      var url = Uri.parse(Url.baakhapaaApi('/request-for-challenge'));
      var request = http.MultipartRequest('POST', url);

      if (image != null) {
        final multipartFile = await http.MultipartFile.fromPath(
          'image',
          image.path,
        );
        request.files.add(multipartFile);
      }

      request.fields['script'] = script;
      request.headers.addAll(Url.baakhapaaAuthHeaders(_token));

      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to submit challenge request: ${response.statusCode}');
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> checkChallangeSubmission() async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/challenge/request-status')),
        headers: Url.baakhapaaAuthHeaders(_token),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load data');
      } else {
        var responseData = json.decode(utf8.decode(response.bodyBytes));

        if (responseData['success'] == true && responseData['data'] != null) {
          _checkScriptStatus = responseData['message'];
          _checkScriptRemarks = responseData['data'];
        } else {
          _checkScriptStatus = responseData['message'];
        }
        notifyListeners();
      }
    } catch (error) {
      DebugLogger.error('Error in checkChallangeSubmission: $error');
      throw error;
    }
  }

  Future<void> fetchCreatorsRankings(int userId) async {
    // Clear stale data immediately so UI doesn't show previous creator's info
    _creatorsRankings = {};
    notifyListeners();
    try {
      final response = await http
          .get(
              Uri.parse(
                Url.baakhapaaApi('/creator/$userId/rankings'),
              ),
              headers: Url.baakhapaaAuthHeaders(_token))
          .timeout(const Duration(seconds: 15));

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success'] == true) {
        _creatorsRankings = responseData['data'] ?? {};
        notifyListeners();
      } else {
        throw ('Error');
      }
    } catch (error) {
      DebugLogger.error('Error fetching creator rankings: $error');
    }
  }

  Future<void> fetchConversations() async {
    try {
      final response = await http
          .get(
              Uri.parse(
                Url.baakhapaaApi('/chat-rooms'),
              ),
              headers: Url.baakhapaaAuthHeaders(_token))
          .timeout(const Duration(seconds: 15));

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        _conversations = responseData['data']['items'];
      } else {
        throw ('Error');
      }
    } catch (error) {
      DebugLogger.error('Error fetching conversations: $error');
    }
  }

  Future<void> startConversations(List<int> userIds) async {
    try {
      final response = await http.post(
        Uri.parse(
          Url.baakhapaaApi('/conversations'),
        ),
        headers: Url.baakhapaaAuthHeaders(_token),
        body: json.encode({
          'user_ids': userIds,
        }),
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        _selectedConversationId = responseData['data']['value'];
      } else {
        throw ('Error');
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> fetchMessages(int conversationId) async {
    try {
      final response = await http
          .get(
              Uri.parse(
                Url.baakhapaaApi('/chat-rooms/$conversationId'),
              ),
              headers: Url.baakhapaaAuthHeaders(_token))
          .timeout(const Duration(seconds: 15));

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        _messages = responseData['data']['items'];
      } else {
        throw ('Error');
      }
    } catch (error) {
      DebugLogger.error('Error fetching messages: $error');
    }
  }

  Future<void> sendMessages(
    int conversationId,
    String content,
    String type,
    String? mediaUrl,
    File? imageFile,
  ) async {
    try {
      // Create the multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(Url.baakhapaaApi('/send-message')),
      );

      // Add headers (Authorization, etc.)
      request.headers.addAll(Url.baakhapaaAuthHeaders(_token));

      // Add fields (conversation_id, content, type, media_url)
      request.fields['conversation_id'] = conversationId.toString();
      request.fields['content'] = content;
      request.fields['type'] = type;

      // Add media_url if it exists
      if (mediaUrl != null) {
        request.fields['media_url'] = mediaUrl;
      }

      // If there's an image file, add it as a multipart file
      if (imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'image', // The name of the form field for the file
            imageFile.path,
          ),
        );
      }

      // Send the request and get the response
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      // Check for successful response (status code 200-299)
      if (response.statusCode < 200 || response.statusCode >= 300) {
        // Try to parse error message from response
        String errorMessage = 'Failed to send message';
        try {
          final responseData = json.decode(utf8.decode(response.bodyBytes));
          if (responseData['message'] != null) {
            errorMessage = responseData['message'];
          }
        } catch (_) {
          // If parsing fails, use generic message with status code
          errorMessage =
              'Failed to send message (Error ${response.statusCode})';
        }
        throw Exception(errorMessage);
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> fetchSettingPopup() async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/setting-popup')),
        headers: Url.baakhapaaAuthHeaders(_token),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success']) {
        _settingPopups = responseData['data']['items'];
      } else {
        throw ('Error fetching story popup: ${responseData['message']}');
      }
    } catch (error) {
      throw ('Error fetching story popup: $error');
    }
  }

  Future<void> saveFCMToken(String token) async {
    try {
      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/user/save-fcm-token')),
        headers: Url.baakhapaaAuthHeaders(_token),
        body: json.encode({
          'fcm_token': token,
        }),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));
      if (!responseData['success']) {
        throw ('Error saving fcm token: ${responseData['message']}');
      }
    } catch (error) {
      throw ('Error saving fcm token: $error');
    }
  }

  Future<void> markMessagesAsRead(int conversationId) async {
    try {
      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/messages/mark-as-read')),
        headers: Url.baakhapaaAuthHeaders(_token),
        body: json.encode({
          'conversation_id': conversationId,
        }),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));
      if (!responseData['success']) {
        throw ('Error marking messages as read: ${responseData['message']}');
      }
    } catch (error) {
      throw ('Error marking messages as read: $error');
    }
  }

  Future<void> deleteConversation(int conversationId) async {
    await http.delete(
      Uri.parse(Url.baakhapaaApi('/conversations/$conversationId')),
      headers: Url.baakhapaaAuthHeaders(_token),
    );
    _conversations.removeWhere((c) => c['conversation_id'] == conversationId);
    notifyListeners();
  }

  Future<void> getUnreadMessageCount() async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/messages/unread-count')),
        headers: Url.baakhapaaAuthHeaders(_token),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final newCount = responseData['data']['unread_count'] ?? 0;

        if (newCount != _unreadMessageCount) {
          _unreadMessageCount = newCount;
          notifyListeners();
        }
      }
    } catch (e) {
      DebugLogger.error('Auth: API error getting unread count: $e');
    }
  }

  Future<void> updateUnreadCount() async {
    try {
      _unreadMessageCount++;
      notifyListeners();
    } catch (error) {
      DebugLogger.error('Auth: Error updating unread count: $error');
      notifyListeners();
    }
  }

  void clearUnreadMessageCount() {
    _unreadMessageCount = 0;
    notifyListeners();
    Future.delayed(Duration(milliseconds: 200), notifyListeners);
  }

  // Increment notification count when new notification arrives
  void incrementNotificationCount() {
    _unreadNotificationCount++;
    DebugLogger.info(
        '➕ AUTH: Notification count incremented to: $_unreadNotificationCount');
    notifyListeners();
  }

  // Decrement notification count when notification is read
  void decrementNotificationCount() {
    if (_unreadNotificationCount > 0) {
      _unreadNotificationCount--;
      DebugLogger.info(
          '➖ AUTH: Notification count decremented to: $_unreadNotificationCount');
      notifyListeners();
    }
  }

  // Clear all notification count (when marking all as read)
  void clearNotificationCount() {
    _unreadNotificationCount = 0;
    DebugLogger.info('🗑️ AUTH: Notification count cleared');
    notifyListeners();
  }

  // Sync notification count to a known-accurate value derived from the DB
  void syncNotificationCount(int count) {
    _unreadNotificationCount = count < 0 ? 0 : count;
    DebugLogger.info(
        '🔄 AUTH: Notification count synced to: $_unreadNotificationCount');
    notifyListeners();
  }

  // Fetch daily rewards status from the server
  Future<void> fetchDailyRewardsStatus() async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/daily-rewards/status')),
        headers: Url.baakhapaaAuthHeaders(token),
      );

      // Check if response is successful before decoding
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Check if response body starts with expected JSON format
        if (response.body.trim().startsWith('{')) {
          final responseData = json.decode(utf8.decode(response.bodyBytes));
          if (responseData['success']) {
            _dailyRewardsData = responseData['data'];
            notifyListeners();
          } else {
            throw responseData['message'] ??
                'Failed to fetch daily rewards status';
          }
        } else {
          DebugLogger.api(
              'Invalid JSON response: ${response.body.substring(0, min(100, response.body.length))}');
          throw 'Server returned an invalid response format';
        }
      } else {
        DebugLogger.api(
            'API error: ${response.statusCode} - ${response.body.substring(0, min(100, response.body.length))}');
        throw 'API error: ${response.statusCode}';
      }
    } catch (error) {
      DebugLogger.api('Error fetching daily rewards status: $error');

      // Set default values rather than failing
      _dailyRewardsData = {
        'current_day': 1,
        'can_claim_today': true, // Allow claiming by default if API fails
        'last_claim_date': null,
        'reward_points': [10, 15, 20, 25, 30, 40, 50],
      };

      notifyListeners();
      // Don't rethrow - default values are set above
    }
  }

  // Claim daily reward
  Future<Map<String, dynamic>> claimDailyReward() async {
    try {
      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/daily-rewards/claim')),
        headers: Url.baakhapaaAuthHeaders(token),
      );

      // Check if response is successful before decoding
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Check if response body starts with expected JSON format
        if (response.body.trim().startsWith('{')) {
          final responseData = json.decode(utf8.decode(response.bodyBytes));

          if (responseData['success']) {
            final data = responseData['data'];

            // Update local rewards data with new information
            if (data != null) {
              _dailyRewardsData = {
                'current_day': data['current_day'] ?? 1,
                'can_claim_today': data['can_claim_today'] ?? false,
                'last_claim_date': data['next_claim_available']?['item'],
                'rewards': data['rewards'] ?? [],
                'reward': data['reward'],
              };

              // Update user data since coin balance might have changed
              await getUser();

              // Return data about the claimed reward
              return {
                'message':
                    data['message'] ?? 'Daily reward claimed successfully!',
                'reward': data['reward'],
              };
            } else {
              throw 'Missing data in response';
            }
          } else {
            throw responseData['message'] ?? 'Failed to claim daily reward';
          }
        } else {
          DebugLogger.api(
              'Invalid JSON response: ${response.body.substring(0, min(100, response.body.length))}');
          throw 'Server returned an invalid response format';
        }
      } else {
        DebugLogger.api(
            'API error: ${response.statusCode} - ${response.body.substring(0, min(100, response.body.length))}');
        throw 'API error: ${response.statusCode}';
      }
    } catch (error) {
      DebugLogger.error('Error claiming daily reward: $error');
      throw error;
    }
  }

  // This method fetches withdrawal history
  Future<void> getWithdrawals() async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/withdrawals')),
        headers: Url.baakhapaaAuthHeaders(_token),
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['withdrawals'] != null) {
        _withdrawals = responseData['withdrawals'] ?? [];
        notifyListeners();
      } else {
        throw Exception(
            responseData['message'] ?? 'Failed to load withdrawals');
      }
    } catch (error) {
      _withdrawals = [];
      if (kDebugMode) {
        DebugLogger.api('Error fetching withdrawals: $error');
      }
    }
  }

  Future<void> requestWithdrawal(double amount, int points,
      String paymentMethod, String paymentDetails) async {
    try {
      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/withdrawals')),
        headers: Url.baakhapaaAuthHeaders(_token),
        body: json.encode({
          'amount': amount,
          'points_converted': points,
          'payment_method': paymentMethod,
          'payment_details': paymentDetails,
        }),
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (response.statusCode == 201) {
        // Refresh withdrawals list after successful request
        await getWithdrawals();
        // Refresh user data to get updated coin balance
        await getUser();
        notifyListeners();
      } else {
        throw Exception(
            responseData['message'] ?? 'Failed to request withdrawal');
      }
    } catch (error) {
      if (kDebugMode) {
        DebugLogger.api('Error requesting withdrawal: $error');
      }
      rethrow;
    }
  }

  Future<void> fetchPlayerProfile(String username) async {
    try {
      DebugLogger.info('👤 Fetching player profile for username: $username');
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/user/$username/show')),
        headers: Url.baakhapaaAuthHeaders(_token),
      );

      DebugLogger.info(
          '👤 Player profile response status: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        DebugLogger.info(
            '👤 Player profile response: ${responseData.toString().substring(0, responseData.toString().length > 200 ? 200 : responseData.toString().length)}');

        if (responseData['success'] == true && responseData['data'] != null) {
          _playerProfile = responseData['data'] as Map<String, dynamic>;
          DebugLogger.success(
              '👤 Player profile loaded successfully for $username');
        } else {
          _playerProfile = {};
          DebugLogger.warning(
              '👤 Player profile response success=false or data=null');
        }
      } else if (response.statusCode == 429) {
        _playerProfile = {
          'error': 'rate_limit',
          'message': 'Too many requests. Please wait a moment and try again.'
        };
        DebugLogger.warning('👤 Rate limit exceeded for user profile request');
      } else if (response.statusCode == 404) {
        _playerProfile = {'error': 'not_found', 'message': 'User not found'};
        DebugLogger.warning('👤 User profile not found: $username');
      } else {
        _playerProfile = {};
        DebugLogger.api(
            '👤 fetchPlayerProfile HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _playerProfile = {};
      DebugLogger.error('👤 Error fetching player profile: $e');
    } finally {
      notifyListeners();
    }
  }

  /// Follow a user by username
  Future<Map<String, dynamic>> followUser(String username) async {
    try {
      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/users/$username/follow')),
        headers: Url.baakhapaaAuthHeaders(_token),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && responseData['success']) {
        // Update local follow state
        _followData['is_following'] = responseData['following'] ?? true;
        _followData['followers_count'] = responseData['followers_count'];
        notifyListeners();

        return {
          'success': true,
          'message': responseData['message'] ?? 'Successfully followed user',
        };
      } else {
        throw responseData['message'] ?? 'Failed to follow user';
      }
    } catch (error) {
      DebugLogger.error('Error following user: $error');
      rethrow;
    }
  }

  /// Unfollow a user by username
  Future<Map<String, dynamic>> unfollowUser(String username) async {
    try {
      final response = await http.delete(
        Uri.parse(Url.baakhapaaApi('/users/$username/unfollow')),
        headers: Url.baakhapaaAuthHeaders(_token),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && responseData['success']) {
        // Update local follow state
        _followData['is_following'] = responseData['following'] ?? false;
        _followData['followers_count'] = responseData['followers_count'];
        notifyListeners();

        return {
          'success': true,
          'message': responseData['message'] ?? 'Successfully unfollowed user',
        };
      } else {
        throw responseData['message'] ?? 'Failed to unfollow user';
      }
    } catch (error) {
      DebugLogger.error('Error unfollowing user: $error');
      rethrow;
    }
  }

  /// Toggle follow status (follow if not following, unfollow if following)
  Future<Map<String, dynamic>> toggleFollowUser(String username) async {
    try {
      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/users/$username/toggle-follow')),
        headers: Url.baakhapaaAuthHeaders(_token),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && responseData['success']) {
        // Update local follow state
        _followData['is_following'] = responseData['following'];
        _followData['followers_count'] = responseData['followers_count'];
        notifyListeners();

        return {
          'success': true,
          'message': responseData['message'],
          'following': responseData['following'],
        };
      } else {
        throw responseData['message'] ?? 'Failed to toggle follow';
      }
    } catch (error) {
      DebugLogger.error('Error toggling follow: $error');
      rethrow;
    }
  }

  /// Get followers list for a user
  Future<void> fetchFollowers(String username,
      {int page = 1, int perPage = 20}) async {
    try {
      final response = await http
          .get(
            Uri.parse(Url.baakhapaaApi(
                '/users/$username/followers?per_page=$perPage&page=$page')),
            headers: Url.baakhapaaAuthHeaders(_token),
          )
          .timeout(const Duration(seconds: 15));

      var responseData = json.decode(utf8.decode(response.bodyBytes));

      if (responseData['success']) {
        _followers = responseData['followers'] ?? [];
        _followData['followers_count'] = responseData['total_count'] ?? 0;
        notifyListeners();
      } else {
        throw responseData['message'] ?? 'Failed to fetch followers';
      }
    } catch (error) {
      DebugLogger.error('Error fetching followers: $error');
    }
  }

  /// Get following list for a user
  Future<void> fetchFollowing(String username,
      {int page = 1, int perPage = 20}) async {
    try {
      final response = await http
          .get(
            Uri.parse(Url.baakhapaaApi(
                '/users/$username/following?per_page=$perPage&page=$page')),
            headers: Url.baakhapaaAuthHeaders(_token),
          )
          .timeout(const Duration(seconds: 15));

      var responseData = json.decode(utf8.decode(response.bodyBytes));

      if (responseData['success']) {
        _following = responseData['following'] ?? [];
        _followData['following_count'] = responseData['total_count'] ?? 0;
        notifyListeners();
      } else {
        throw responseData['message'] ?? 'Failed to fetch following';
      }
    } catch (error) {
      DebugLogger.error('Error fetching following: $error');
    }
  }

  /// Check relationship between current user and another user
  Future<void> checkUserRelationship(String username) async {
    try {
      final response = await http
          .get(
            Uri.parse(Url.baakhapaaApi('/users/$username/relationship')),
            headers: Url.baakhapaaAuthHeaders(_token),
          )
          .timeout(const Duration(seconds: 15));

      var responseData = json.decode(utf8.decode(response.bodyBytes));

      if (responseData['success'] == true) {
        _followData = {
          'is_following': responseData['is_following'] ?? false,
          'is_followed_by': responseData['is_followed_by'] ?? false,
          'is_mutual': responseData['is_mutual'] ?? false,
          'followers_count': responseData['followers_count'] ?? 0,
          'following_count': responseData['following_count'] ?? 0,
        };
        notifyListeners();
      } else {
        // Log but do not throw — callers should not crash on relationship failure
        DebugLogger.info(
            'checkUserRelationship: non-success response: ${responseData['message']}');
      }
    } catch (error) {
      DebugLogger.error('Error checking relationship: $error');
    }
  }

  /// Search followers
  Future<List<dynamic>> searchFollowers(String username, String query) async {
    try {
      final response = await http.get(
        Uri.parse(
            Url.baakhapaaApi('/users/$username/followers/search?q=$query')),
        headers: Url.baakhapaaAuthHeaders(_token),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));

      if (responseData['success'] == true) {
        return responseData['results'] ?? [];
      } else {
        throw responseData['message'] ?? 'Failed to search followers';
      }
    } catch (error) {
      DebugLogger.error('Error searching followers: $error');
      return []; // Return empty list on error instead of rethrowing
    }
  }

  /// Search following
  Future<List<dynamic>> searchFollowing(String username, String query) async {
    try {
      final response = await http.get(
        Uri.parse(
            Url.baakhapaaApi('/users/$username/following/search?q=$query')),
        headers: Url.baakhapaaAuthHeaders(_token),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));

      if (responseData['success'] == true) {
        return responseData['results'] ?? [];
      } else {
        throw responseData['message'] ?? 'Failed to search following';
      }
    } catch (error) {
      DebugLogger.error('Error searching following: $error');
      return []; // Return empty list on error instead of rethrowing
    }
  }

  /// Search all users (general search for collaborators, mentions, etc.)
  /// Returns users matching the query by username or name
  Future<List<dynamic>> searchUsers(String query, {String? role}) async {
    try {
      // URL encode the query to handle special characters
      final encodedQuery = Uri.encodeComponent(query);
      final roleParam = (role != null && role.isNotEmpty)
          ? '&role=${Uri.encodeComponent(role)}'
          : '';

      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/users/search?q=$encodedQuery$roleParam')),
        headers: Url.baakhapaaAuthHeaders(_token),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));

      if (responseData['success'] == true) {
        // Handle nested response structure: data.results
        if (responseData['data'] != null &&
            responseData['data']['results'] is List) {
          return responseData['data']['results'];
        }
        // Fallback to direct results or data
        return responseData['results'] ?? responseData['data'] ?? [];
      } else {
        // If general search endpoint doesn't exist, fall back to empty list
        DebugLogger.warning(
            'User search API returned: ${responseData['message']}');
        return [];
      }
    } catch (error) {
      DebugLogger.error('Error searching users: $error');
      return []; // Return empty list on error
    }
  }

  // Wallet OTP Security Methods
  String? _walletSessionToken;
  DateTime? _walletSessionExpiry;

  bool get hasValidWalletSession {
    if (_walletSessionToken == null || _walletSessionExpiry == null) {
      return false;
    }
    return DateTime.now().isBefore(_walletSessionExpiry!);
  }

  /// Request OTP for wallet access
  Future<Map<String, dynamic>> requestWalletOtp() async {
    try {
      DebugLogger.info('Requesting wallet OTP for user: ${_user['id']}');
      DebugLogger.info('Token: ${_token.substring(0, 20)}...');

      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/wallet/request-otp')),
        headers: Url.baakhapaaAuthHeaders(_token),
        body: json.encode({
          'user_id': _user['id'],
        }),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));

      DebugLogger.info('Wallet OTP Response Status: ${response.statusCode}');
      DebugLogger.info('Wallet OTP Response: $responseData');

      if (response.statusCode == 200 && responseData['success']) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'OTP sent to your email',
          'expires_in': responseData['data']?['expires_in'] ?? 300,
        };
      } else {
        // Include error code if available
        String errorMsg = responseData['message'] ?? 'Failed to send OTP';
        if (responseData['error_code'] != null) {
          errorMsg += ' (Error #${responseData['error_code']})';
        }
        throw errorMsg;
      }
    } catch (error) {
      DebugLogger.error('Error requesting wallet OTP: $error');
      rethrow;
    }
  }

  /// Verify OTP and get wallet session token
  Future<Map<String, dynamic>> verifyWalletOtp(String otp) async {
    try {
      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/wallet/verify-otp')),
        headers: Url.baakhapaaAuthHeaders(_token),
        body: json.encode({
          'user_id': _user['id'],
          'otp': otp,
        }),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && responseData['success']) {
        // Backend returns 'access_token', not 'session_token'
        _walletSessionToken = responseData['data']['access_token'];

        // Parse expires_at as absolute datetime from backend
        String expiresAt = responseData['data']['expires_at'];
        _walletSessionExpiry = DateTime.parse(expiresAt);

        // Store session token in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('wallet_session_token', _walletSessionToken!);
        await prefs.setString(
            'wallet_session_expiry', _walletSessionExpiry!.toIso8601String());

        notifyListeners();

        return {
          'success': true,
          'message': responseData['message'] ?? 'Wallet access granted',
        };
      } else {
        throw responseData['message'] ?? 'Invalid OTP';
      }
    } catch (error) {
      DebugLogger.error('Error verifying wallet OTP: $error');
      rethrow;
    }
  }

  /// Load wallet session from storage
  Future<void> loadWalletSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _walletSessionToken = prefs.getString('wallet_session_token');
      String? expiryString = prefs.getString('wallet_session_expiry');

      if (expiryString != null) {
        _walletSessionExpiry = DateTime.parse(expiryString);

        // Clear if expired
        if (!hasValidWalletSession) {
          await clearWalletSession();
        }
      }
    } catch (error) {
      DebugLogger.error('Error loading wallet session: $error');
    }
  }

  /// Clear wallet session
  Future<void> clearWalletSession() async {
    _walletSessionToken = null;
    _walletSessionExpiry = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('wallet_session_token');
    await prefs.remove('wallet_session_expiry');

    notifyListeners();
  }

  // Fetch gifts for you from API
  Future<Map<String, dynamic>> getGiftsForYou() async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/gift/forYou')),
        headers: Url.baakhapaaAuthHeaders(_token),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        if (responseData['success'] == true) {
          return responseData['data'];
        }
      }

      throw Exception('Failed to fetch gifts for you');
    } catch (error) {
      DebugLogger.error('Error fetching gifts for you: $error');
      rethrow;
    }
  }

  /// Buy achievement with bypass cost (coins)
  /// Returns updated user coin balance and achievement purchase status
  Future<Map<String, dynamic>> buyAchievement(int achievementId) async {
    try {
      final url = Url.baakhapaaApi('/buy-achievement/$achievementId');

      final response = await http.post(
        Uri.parse(url),
        headers: Url.baakhapaaAuthHeaders(_token),
      );

      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && responseData['success'] == true) {
        // Update local user information with new coin balance
        if (responseData['data'] != null &&
            responseData['data']['new_coin_balance'] != null) {
          // Update user's available coins locally
          final userInfo = _user['user_information'];
          if (userInfo != null) {
            userInfo['available_coins'] =
                responseData['data']['new_coin_balance'];
          }
          notifyListeners();
        }

        return responseData;
      } else {
        // Handle API errors
        final errorMessage =
            responseData['message'] ?? 'Failed to purchase achievement';
        throw Exception(errorMessage);
      }
    } catch (error) {
      DebugLogger.error('Error buying achievement: $error');
      rethrow;
    }
  }
}
