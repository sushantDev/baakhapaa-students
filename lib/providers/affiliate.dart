import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import '../models/url.dart';
import '../utils/debug_logger.dart';

import '../models/affiliate_product.dart';

class AffiliateProvider with ChangeNotifier {
  String? authToken;

  Map<String, dynamic>? _affiliateStatus;
  List<AffiliateProduct> _availableProducts = [];
  List<dynamic> _creatorRequests = [];

  AffiliateProvider(this.authToken);

  /// Synchronize affiliate status from Auth provider
  void updateFromAuth(dynamic auth) {
    if (auth.user != null && auth.user['affiliation'] != null) {
      _affiliateStatus = auth.user['affiliation'];
      notifyListeners();
    }
  }

  Map<String, dynamic>? get affiliateStatus => _affiliateStatus;
  List<AffiliateProduct> get availableProducts => _availableProducts;
  List<dynamic> get creatorRequests => _creatorRequests;

  bool get isAffiliate =>
      _affiliateStatus != null &&
      (_affiliateStatus!['program_status']?['status'] == 'approved' ||
          _affiliateStatus!['program_status']?['is_approved'] == true);
  bool get isPending =>
      _affiliateStatus != null &&
      _affiliateStatus!['program_status']?['status'] == 'pending';
  bool get isRejected =>
      _affiliateStatus != null &&
      _affiliateStatus!['program_status']?['status'] == 'rejected';

  String? get affiliateRemarks =>
      _affiliateStatus?['program_status']?['remarks'];
  Map<String, dynamic>? get affiliateCooldown => _affiliateStatus?['cooldown'];

  /// Get affiliate status
  Future<void> fetchAffiliateStatus() async {
    if (authToken == null) return;
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/affiliate/status')),
        headers: Url.baakhapaaAuthHeaders(authToken!),
      );

      final responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success'] == true) {
        _affiliateStatus = responseData['data'];
        notifyListeners();
      }
    } catch (error) {
      DebugLogger.error('Error fetching affiliate status: $error');
      rethrow;
    }
  }

  /// Join affiliate program
  Future<Map<String, dynamic>> joinAffiliateProgram() async {
    if (authToken == null) throw 'Authentication required';
    try {
      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/affiliate/program/join')),
        headers: Url.baakhapaaAuthHeaders(authToken!),
      );

      final responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success'] == true) {
        _affiliateStatus = responseData['data'];
        notifyListeners();
        return responseData;
      } else {
        throw responseData['message'] ?? 'Failed to join program';
      }
    } catch (error) {
      DebugLogger.error('Error joining affiliate program: $error');
      rethrow;
    }
  }

  /// Fetch available products for linking
  Future<void> fetchAvailableProducts({String? search, int page = 1}) async {
    if (authToken == null) return;
    try {
      String url = Url.baakhapaaApi('/affiliate/available-products?page=$page');
      if (search != null && search.isNotEmpty) {
        url += '&search=${Uri.encodeComponent(search)}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: Url.baakhapaaAuthHeaders(authToken!),
      );

      final responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['status'] == 'success' ||
          responseData['success'] == true) {
        final List<dynamic> items = responseData['data'] is List
            ? responseData['data']
            : (responseData['data']['items'] ?? []);

        final List<AffiliateProduct> loadedProducts =
            items.map((item) => AffiliateProduct.fromJson(item)).toList();

        if (page == 1) {
          _availableProducts = loadedProducts;
        } else {
          _availableProducts.addAll(loadedProducts);
        }
        notifyListeners();
      }
    } catch (error) {
      DebugLogger.error('Error fetching available products: $error');
      rethrow;
    }
  }

  /// Fetch creator's affiliate requests/links
  Future<void> fetchCreatorRequests() async {
    if (authToken == null) return;
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/affiliate/creator-requests')),
        headers: Url.baakhapaaAuthHeaders(authToken!),
      );

      final responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success'] == true) {
        _creatorRequests = responseData['data']['items'] ?? [];
        notifyListeners();
      }
    } catch (error) {
      DebugLogger.error('Error fetching creator requests: $error');
      rethrow;
    }
  }

  /// Link products to existing content (short or episode)
  Future<void> linkToContent({
    required String contentType, // 'short' or 'episode'
    required int contentId,
    required List<int> productIds,
  }) async {
    if (authToken == null) throw 'Authentication required';
    try {
      final endpoint = contentType == 'short'
          ? '/affiliate/link-to-short'
          : '/affiliate/link-to-episode';
      final response = await http.post(
        Uri.parse(Url.baakhapaaApi(endpoint)),
        headers: Url.baakhapaaAuthHeaders(authToken!),
        body: json.encode({
          contentType == 'short' ? 'short_id' : 'episode_id': contentId,
          'product_ids': productIds,
        }),
      );

      final responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success'] != true) {
        throw responseData['message'] ?? 'Failed to link products';
      }

      // Refresh requests if needed
      await fetchCreatorRequests();
    } catch (error) {
      DebugLogger.error('Error linking products to $contentType: $error');
      rethrow;
    }
  }
}
