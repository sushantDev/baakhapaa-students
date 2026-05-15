import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/url.dart';
import '../utils/debug_logger.dart';

class PaymentRouteResult {
  final String paymentRoute; // khalti | stripe
  final bool isNepal;
  final String countryCode;
  final String countryName;

  const PaymentRouteResult({
    required this.paymentRoute,
    required this.isNepal,
    required this.countryCode,
    required this.countryName,
  });
}

class PaymentRouteService {
  static Future<PaymentRouteResult> resolve(String authToken) async {
    final response = await http.get(
      Uri.parse(Url.baakhapaaApi('/payment/route')),
      headers: Url.baakhapaaAuthHeaders(authToken),
    );

    final body = json.decode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200) {
      final message = body['message'] ?? 'Unable to resolve payment route';
      throw Exception(message);
    }

    final item =
        (body['data']?['item'] ?? <String, dynamic>{}) as Map<String, dynamic>;
    final route = (item['payment_route'] ?? '').toString();

    final result = PaymentRouteResult(
      paymentRoute: route.isNotEmpty ? route : 'stripe',
      isNepal: item['is_nepal'] == true,
      countryCode: (item['country_code'] ?? '').toString(),
      countryName: (item['country_name'] ?? '').toString(),
    );

    DebugLogger.info(
        'PaymentRouteService: route=${result.paymentRoute}, country=${result.countryCode}');
    return result;
  }
}
