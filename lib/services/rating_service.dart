import 'dart:convert';
import 'package:baakhapaa/models/rating_model.dart';
import 'package:baakhapaa/models/url.dart';
import 'package:http/http.dart' as http;
import '../../../utils/debug_logger.dart';

class RatingService {
  final String? authToken;
  final String? authProvider;

  RatingService({this.authToken, this.authProvider});

  // Get headers based on whether auth token is provided
  Map<String, String> get headers {
    if (authToken != null) {
      return Url.baakhapaaAuthHeaders(authToken!);
    }
    return Url.baakhapaaHeaders;
  }

  // Get ratings for a product
  Future<RatingResponse> getProductRatings(int productId) async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/rating/products/$productId')),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        DebugLogger.info(
            'Product $productId ratings response: ${jsonData.keys.toList()}');
        return RatingResponse.fromJson(jsonData);
      } else if (response.statusCode == 429) {
        // Rate limit - throw specific error without DebugLogger.infoing
        throw Exception('Failed to load ratings: 429');
      } else {
        throw Exception('Failed to load ratings: ${response.statusCode}');
      }
    } catch (e) {
      // Only DebugLogger.info non-429 errors
      if (!e.toString().contains('429')) {
        DebugLogger.error('Error getting product ratings: $e');
      }
      rethrow; // Rethrow to maintain error flow
    }
  }

// Get ratings for a episode
  Future<RatingResponse> getEpisodeRatings(int episodeId) async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/rating/episodes/$episodeId')),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        DebugLogger.info(
            'Episode $episodeId ratings response: ${jsonData.keys.toList()}');
        return RatingResponse.fromJson(jsonData);
      } else if (response.statusCode == 429) {
        // Rate limit - throw specific error without DebugLogger.infoing
        throw Exception('Failed to load ratings: 429');
      } else {
        throw Exception('Failed to load ratings: ${response.statusCode}');
      }
    } catch (e) {
      // Only DebugLogger.info non-429 errors
      if (!e.toString().contains('429')) {
        DebugLogger.error('Error getting episode ratings: $e');
      }
      rethrow; // Rethrow to maintain error flow
    }
  }

// Get ratings for a season
  Future<RatingResponse> getSeasonsRatings(int seasonsId) async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/rating/seasons/$seasonsId')),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        DebugLogger.info(
            'Season $seasonsId ratings response: ${jsonData.keys.toList()}');
        return RatingResponse.fromJson(jsonData);
      } else if (response.statusCode == 429) {
        // Rate limit - throw specific error without DebugLogger.infoing
        throw Exception('Failed to load ratings: 429');
      } else {
        throw Exception('Failed to load ratings: ${response.statusCode}');
      }
    } catch (e) {
      // Only DebugLogger.info non-429 errors
      if (!e.toString().contains('429')) {
        DebugLogger.error('Error getting season ratings: $e');
      }
      rethrow; // Rethrow to maintain error flow
    }
  }

  // Post a new product rating
  Future<bool> postProductRating(int productId, RatingRequest rating) async {
    try {
      DebugLogger.info(
          'Posting rating: ${json.encode(rating.toJson())}'); // Debug log

      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/rating/products/$productId')),
        headers: headers,
        body: json.encode(rating.toJson()),
      );

      DebugLogger.info('Response status: ${response.statusCode}'); // Debug log
      DebugLogger.info('Response body: ${response.body}'); // Debug log

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = json.decode(response.body);
        return jsonData['success'] ?? false;
      } else {
        throw Exception('Failed to post rating: ${response.statusCode}');
      }
    } catch (e) {
      DebugLogger.info('Error posting rating: $e');
      throw Exception('Error posting rating: $e');
    }
  }

  // Post a new rating
  Future<bool> postEpisodeRating(int episodeId, RatingRequest rating) async {
    try {
      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/rating/episodes/$episodeId')),
        headers: headers,
        body: json.encode(rating.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = json.decode(response.body);
        return jsonData['success'] ??
            true; // default to true if success not present
      } else {
        final body = json.decode(response.body);
        throw Exception(body['message'] ??
            'Failed to post episode rating: ${response.statusCode}');
      }
    } catch (e) {
      DebugLogger.info('Error posting episode rating: $e');
      throw Exception('Error posting episode rating: $e');
    }
  }

  // Post a new season
  Future<bool> postSeasonsRating(int seasonsId, RatingRequest rating) async {
    try {
      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/rating/seasons/$seasonsId')),
        headers: headers,
        body: json.encode(rating.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = json.decode(response.body);
        return jsonData['success'] ??
            true; // default to true if success not present
      } else {
        final body = json.decode(response.body);
        throw Exception(body['message'] ??
            'Failed to post episode rating: ${response.statusCode}');
      }
    } catch (e) {
      DebugLogger.info('Error posting episode rating: $e');
      throw Exception('Error posting episode rating: $e');
    }
  }

  // Update an existing rating
  Future<bool> updateRating(int ratingId, RatingRequest rating) async {
    try {
      final response = await http.put(
        Uri.parse(Url.baakhapaaApi('/rating/$ratingId')),
        headers: headers,
        body: json.encode(rating.toJson()),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData['success'] ?? false;
      } else {
        throw Exception('Failed to update rating: ${response.statusCode}');
      }
    } catch (e) {
      DebugLogger.info('Error updating rating: $e');
      throw Exception('Error updating rating: $e');
    }
  }

  // Delete a rating
  Future<bool> deleteRating(int ratingId) async {
    try {
      final response = await http.delete(
        Uri.parse(Url.baakhapaaApi('/rating/$ratingId')),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData['success'] ?? false;
      } else {
        throw Exception('Failed to delete rating: ${response.statusCode}');
      }
    } catch (e) {
      DebugLogger.info('Error deleting rating: $e');
      throw Exception('Error deleting rating: $e');
    }
  }
}
