import 'dart:convert';
import 'dart:io';
import 'package:baakhapaa/models/subscription.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../models/url.dart'; // Import your existing url.dart file
import '../providers/auth.dart'; // Import your Auth class
import '../../../utils/debug_logger.dart';

class SubscriptionService {
  final BuildContext? context;
  final String? authToken;

  SubscriptionService({this.context, this.authToken});

  // Get authentication token from Auth provider
  String? _getAuthToken() {
    if (authToken != null && authToken!.isNotEmpty) {
      return authToken;
    }

    if (context != null) {
      try {
        final auth = Provider.of<Auth>(context!, listen: false);
        return auth.isAuth ? auth.token : null;
      } catch (e) {
        DebugLogger.info('Error getting auth token from provider: $e');
        return null;
      }
    }
    return null;
  }

  // Fetch all subscription packages (V2 API)
  Future<SubscriptionResponse> getSubscriptionPackages() async {
    try {
      final token = _getAuthToken();

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }

      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/subscription/v2/index')),
        headers: Url.baakhapaaAuthHeaders(token),
      );

      DebugLogger.info(
          'Subscription V2 API Response Status: ${response.statusCode}');
      DebugLogger.info('Subscription V2 API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return SubscriptionResponse.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception(
            'Failed to load subscription packages: ${response.statusCode}');
      }
    } catch (e) {
      DebugLogger.info('Error fetching subscription packages: $e');
      if (e is SocketException) {
        throw Exception(
            'Network error. Please check your internet connection.');
      }
      rethrow;
    }
  }

  // NEW: Khalti payment processing for subscriptions (similar to orders)
  Future<void> khaltiSubscriptionPayment(
    Map<String, dynamic> txn,
    int subscriptionId,
    String duration,
    String paymentMethod,
  ) async {
    try {
      final token = _getAuthToken();

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }

      // Step 1: Process Khalti payment similar to orders
      final response = await http.post(
        // Uri.parse(Url.baakhapaaApi(
        //     '/subscription/payment')),
        Uri.parse(Url.baakhapaaApi('/products/payment')),
        headers: Url.baakhapaaAuthHeaders(token),
        body: json.encode(txn),
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));

      DebugLogger.info('Khalti subscription payment response: $responseData');

      if (responseData['message'] == 'OK') {
        // Step 2: Purchase subscription with the payment ID
        await this.purchaseSubscription(
          subscriptionId: subscriptionId,
          paymentMethod: paymentMethod,
          duration: duration,
          paymentId: responseData['data']['item']['id'],
        );
      } else {
        throw Exception('Khalti payment failed: ${responseData.toString()}');
      }
    } catch (error) {
      DebugLogger.info('Khalti subscription payment error: $error');
      throw (error);
    }
  }

  // Updated purchase subscription method
  Future<PurchaseResponse> purchaseSubscription({
    required int subscriptionId,
    required String duration,
    int? paymentId,
    required String paymentMethod,
  }) async {
    try {
      final token = _getAuthToken();

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }

      // Create the payload with the required fields
      final purchaseRequest = {
        'subscription_id': subscriptionId,
        'duration_days': _getDurationInDays(duration),
        'auto_renew': false,
        'payment_id': paymentId,
        "payment_method": paymentMethod,
      };

      DebugLogger.info(
          'Subscription purchase request: ${json.encode(purchaseRequest)}');

      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/subscription/purchase')),
        headers: Url.baakhapaaAuthHeaders(token),
        body: json.encode(purchaseRequest),
      );

      DebugLogger.info('Purchase API Response Status: ${response.statusCode}');
      DebugLogger.info('Purchase API Response Body: ${response.body}');

      // Check if response is HTML (error page)
      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        throw Exception(
            'Server returned HTML error page. Status: ${response.statusCode}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return PurchaseResponse.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 409) {
        // Conflict - usually means active subscription exists
        final Map<String, dynamic> jsonData = json.decode(response.body);
        final message = jsonData['message'] ??
            'You already have an active subscription. Please wait for it to expire before purchasing a new package.';
        throw Exception(message);
      } else if (response.statusCode == 422) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        final message = jsonData['message'] ?? 'Validation error occurred';
        throw Exception(message);
      } else {
        // Try to extract message from error response
        try {
          final Map<String, dynamic> jsonData = json.decode(response.body);
          final message = jsonData['message'] ??
              'Failed to purchase subscription: ${response.statusCode}';
          throw Exception(message);
        } catch (_) {
          throw Exception(
              'Failed to purchase subscription: ${response.statusCode}');
        }
      }
    } catch (e) {
      DebugLogger.info('Error purchasing subscription: $e');
      if (e is SocketException) {
        throw Exception(
            'Network error. Please check your internet connection.');
      }
      rethrow;
    }
  }

  // Helper function to convert duration strings to days
  int _getDurationInDays(String duration) {
    return getDurationInDays(duration);
  }

  // Public helper to convert duration strings to days
  int getDurationInDays(String duration) {
    switch (duration.toLowerCase()) {
      case 'monthly':
      case '1_month':
        return 30;
      case '3-month':
      case '3_months':
        return 90;
      case '6-month':
      case '6_months':
        return 180;
      case 'annual':
      case '12_months':
        return 365;
      default:
        return 30; // Default to monthly
    }
  }

  // Helper method to calculate pricing for different durations
  Map<String, double> calculatePricing(int pricePerDay) {
    return {
      'Monthly': pricePerDay * 30.0,
      '3-Month': pricePerDay * 90.0 * 1, // 10% discount
      '6-Month': pricePerDay * 180.0 * 1, // 15% discount
      'Annual': pricePerDay * 365.0 * 1, // 20% discount
    };
  }

  // Helper method to get package color based on title
  Color getPackageColor(String packageTitle) {
    switch (packageTitle.toLowerCase()) {
      case 'silver':
      case 'silver package':
        return const Color(0xFF9E9E9E); // Silver metallic
      case 'gold':
      case 'gold package':
        return Colors.amber;
      case 'platinum':
      case 'platinum package':
        return const Color(0xFF8C9EAF); // Platinum
      default:
        return Colors.blue;
    }
  }

  // Helper method to get package icon based on title
  IconData getPackageIcon(String packageTitle) {
    switch (packageTitle.toLowerCase()) {
      case 'silver':
      case 'silver package':
        return FontAwesomeIcons.medal.data;
      case 'gold':
      case 'gold package':
        return FontAwesomeIcons.crown.data;
      case 'platinum':
      case 'platinum package':
        return FontAwesomeIcons.gem.data;
      default:
        return FontAwesomeIcons.star.data;
    }
  }

  // Helper method to check if package is popular (can be customized based on your logic)
  bool isPopularPackage(String packageTitle) {
    return packageTitle.toLowerCase().contains('gold');
  }

  // Helper method to check if package is the recommended one (Basic)
  bool isRecommendedPackage(String packageTitle) {
    return packageTitle.toLowerCase().contains('basic');
  }

  // Helper method to generate features list based on package benefits (V2)
  List<String> generateFeatures(SubscriptionPackage package,
      [String? duration]) {
    List<String> features = [];

    String selectedDuration =
        duration ?? 'monthly'; // Default to monthly if not provided
    int durationDays = _getDurationInDays(selectedDuration);
    int totalPoints = package.pointsPerDay * durationDays;

    String durationDisplay = _formatDurationDisplay(selectedDuration);

    features.add('$totalPoints points for $durationDisplay');

    // Add benefits dynamically from V2 API
    if (package.benefits.isNotEmpty) {
      for (var benefit in package.benefits) {
        String benefitText = '${benefit.name}';
        if (benefit.quantity > 0) {
          benefitText += ' (${benefit.quantity}x)';
        }
        features.add(benefitText);
      }
    }

    return features.take(12).toList();
  }

  String _formatDurationDisplay(String duration) {
    switch (duration.toLowerCase()) {
      case 'monthly':
      case '1_month':
        return '1 month';
      case '3-month':
      case '3_months':
        return '3 months';
      case '6-month':
      case '6_months':
        return '6 months';
      case 'annual':
      case '12_months':
        return '1 year';
      default:
        return '1 month';
    }
  }

  // Fetch remaining benefits for a subscribed user
  Future<UserBenefitStatusResponse> getUserBenefitStatus() async {
    try {
      final token = _getAuthToken();

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }

      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/subscription/user-benefit-status')),
        headers: Url.baakhapaaAuthHeaders(token),
      );

      DebugLogger.info(
          'User Benefit Status API Response Status: ${response.statusCode}');
      DebugLogger.info(
          'User Benefit Status API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return UserBenefitStatusResponse.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception(
            'Failed to load user benefit status: ${response.statusCode}');
      }
    } catch (e) {
      DebugLogger.info('Error fetching user benefit status: $e');
      if (e is SocketException) {
        throw Exception(
            'Network error. Please check your internet connection.');
      }
      rethrow;
    }
  }

  // Update benefit usage counters after use (V2 API)
  Future<UpdateUsageResponse> updateUserBenefitUsage({
    required int userBenefitUsageId,
    int? usedCount, // Keep for backward compatibility if needed locally
    int? availableCount,
    int? remaining,
    int? levelId,
    int? seasonId,
    int? achievementId,
    int? challengeId,
    int? episodeId, // Added for skip timer if needed
  }) async {
    try {
      final token = _getAuthToken();

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }

      // V2 API Body format
      final body = {
        'use_benefit': true,
        if (levelId != null) 'level_id': levelId,
        if (seasonId != null) 'season_id': seasonId,
        if (achievementId != null) 'achievement_id': achievementId,
        if (challengeId != null) 'challenge_id': challengeId,
        if (episodeId != null) 'episode_id': episodeId,
      };

      DebugLogger.info(
          'Update Benefit Usage V2 API Request Body: ${json.encode(body)}');

      final response = await http.put(
        Uri.parse(Url.baakhapaaApi(
            '/subscription/user-benefit-usage/$userBenefitUsageId')),
        headers: Url.baakhapaaAuthHeaders(token),
        body: json.encode(body),
      );

      DebugLogger.info(
          'Update Benefit Usage API Response Status: ${response.statusCode}');
      DebugLogger.info(
          'Update Benefit Usage API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return UpdateUsageResponse.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        // Try to extract message from error response
        String errorMessage = 'Failed to update benefit usage';
        try {
          final errorData = json.decode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } catch (e) {
      DebugLogger.info('Error updating benefit usage: $e');
      if (e is SocketException) {
        throw Exception(
            'Network error. Please check your internet connection.');
      }
      rethrow;
    }
  }
}
