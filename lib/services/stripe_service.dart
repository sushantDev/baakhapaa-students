import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

import '../config/app_credentials.dart';
import '../models/url.dart';
import '../../utils/debug_logger.dart';

/// Service for handling Stripe payments.
/// Secret keys are kept on the Laravel backend; only the publishable key lives here.
class StripeService {
  /// Initialize Stripe SDK — call once in main.dart before runApp()
  static Future<void> init() async {
    Stripe.publishableKey = AppCredentials.stripePublishableKey;
    // Do NOT set merchantIdentifier here — it triggers an Apple Pay async
    // check inside PaymentSheetLoader.load() which crashes on iOS 17+/macOS 26+
    // via a Swift Concurrency actor-isolation fault (_swift_task_dealloc_specific).
    // Apple Pay is not used in the payment sheet, so no identifier is needed.
    await Stripe.instance.applySettings();
    DebugLogger.info('StripeService: Initialized');
  }

  // ── Payment Intent Flow ────────────────────────────────────────────

  /// Create a PaymentIntent on the backend and return the client secret.
  static Future<Map<String, dynamic>> createPaymentIntent({
    required String authToken,
    required int amountInCents,
    required String type, // 'subscription' or 'product'
    int? subscriptionId,
    int? durationDays,
    List<int>? productIds,
    int? shippingAddressId,
    int? shippingProviderId,
  }) async {
    final body = <String, dynamic>{
      'amount': amountInCents,
      'currency': 'usd',
      'type': type,
    };

    if (type == 'subscription') {
      body['subscription_id'] = subscriptionId;
      body['duration_days'] = durationDays;
    } else if (type == 'product') {
      body['product_ids'] = productIds;
      if (shippingAddressId != null)
        body['shipping_address_id'] = shippingAddressId;
      if (shippingProviderId != null)
        body['shipping_provider_id'] = shippingProviderId;
    }

    DebugLogger.info(
        'StripeService: Creating payment intent — amount: $amountInCents cents, type: $type');

    final response = await http.post(
      Uri.parse(Url.baakhapaaApi('/stripe/create-payment-intent')),
      headers: Url.baakhapaaAuthHeaders(authToken),
      body: json.encode(body),
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      DebugLogger.info('StripeService: PaymentIntent created');
      return data['data'];
    }

    final msg = data['message'] ?? 'Failed to create payment intent';
    throw Exception(msg);
  }

  /// Whether we're running inside the iOS Simulator.
  /// Used to guard against a known Swift Concurrency crash in the Stripe SDK's
  /// PaymentSheetLoader.load() on iOS 26.x simulators (SIGABRT in
  /// _swift_task_dealloc_specific). Real devices are unaffected.
  static bool get _isIOSSimulator {
    if (!Platform.isIOS) return false;
    // On iOS Simulator the temp directory lives under a CoreSimulator path,
    // e.g. .../Library/Developer/CoreSimulator/Devices/<UUID>/data/tmp.
    // But /tmp may be a symlink, so we resolve it first.
    // On real devices it's /private/var/mobile/... — never contains "CoreSimulator".
    try {
      final resolved = Directory.systemTemp.resolveSymbolicLinksSync();
      return resolved.contains('CoreSimulator');
    } catch (_) {
      return Directory.systemTemp.path.contains('CoreSimulator');
    }
  }

  /// Show the Stripe payment sheet and return when payment completes.
  static Future<void> presentPaymentSheet({
    required String clientSecret,
    String? merchantDisplayName,
  }) async {
    // On iOS Simulator (especially iOS 26.x), Stripe PaymentSheet crashes
    // with a SIGABRT in libswift_Concurrency.dylib during
    // PaymentSheetLoader.load(). This is an Apple Swift runtime bug.
    // Skip the native sheet and throw a catchable exception instead.
    if (_isIOSSimulator) {
      DebugLogger.warning(
        'StripeService: Skipping PaymentSheet on iOS Simulator — '
        'known Swift Concurrency crash (async let task deallocation). '
        'Test payments on a real device.',
      );
      throw Exception(
        'Stripe PaymentSheet is unavailable on the iOS Simulator due to '
        'an Apple Swift Concurrency runtime bug (iOS 26.x). '
        'Please test payments on a real device.',
      );
    }

    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: merchantDisplayName ?? 'Baakhapaa',
          style: ThemeMode.system,
          // returnURL is required on iOS to prevent a SIGABRT crash (freed
          // pointer) in Stripe SDK ≥25.x when the backend enables payment
          // methods that need redirect handling (Cash App Pay, Crypto, etc.).
          // Without it, the SDK logs warnings and corrupts memory on load.
          returnURL: 'baakhapaa://stripe-redirect',
          googlePay: const PaymentSheetGooglePay(
            merchantCountryCode: 'US',
            testEnv: !AppCredentials.isProduction,
          ),
        ),
      );
      DebugLogger.info('StripeService: Payment sheet initialized');

      await Stripe.instance.presentPaymentSheet();
      DebugLogger.info('StripeService: Payment sheet completed');
    } on StripeException catch (e) {
      DebugLogger.info(
          'StripeService: StripeException — code: ${e.error.code}, message: ${e.error.message}');
      throw Exception(
          'StripeException: ${e.error.localizedMessage ?? e.error.message ?? 'Payment cancelled'}');
    } catch (e) {
      DebugLogger.info('StripeService: Payment sheet error — $e');
      rethrow;
    }
  }

  /// Confirm a payment on the backend after the client has paid.
  static Future<Map<String, dynamic>> confirmPaymentOnBackend({
    required String authToken,
    required String paymentIntentId,
    required String type,
    int? subscriptionId,
    int? durationDays,
    List<int>? productIds,
    int? shippingAddressId,
    int? shippingProviderId,
  }) async {
    final body = <String, dynamic>{
      'payment_intent_id': paymentIntentId,
      'type': type,
    };

    if (type == 'subscription') {
      body['subscription_id'] = subscriptionId;
      body['duration_days'] = durationDays;
    } else if (type == 'product') {
      body['product_ids'] = productIds;
      if (shippingAddressId != null)
        body['shipping_address_id'] = shippingAddressId;
      if (shippingProviderId != null)
        body['shipping_provider_id'] = shippingProviderId;
    }

    DebugLogger.info(
        'StripeService: Confirming payment on backend — PI: $paymentIntentId');

    final response = await http.post(
      Uri.parse(Url.baakhapaaApi('/stripe/confirm-payment')),
      headers: Url.baakhapaaAuthHeaders(authToken),
      body: json.encode(body),
    );

    final data = json.decode(response.body);

    if ((response.statusCode == 200 || response.statusCode == 201) &&
        data['success'] == true) {
      DebugLogger.info('StripeService: Payment confirmed on backend');
      return data['data'] ?? data;
    }

    final msg = data['message'] ?? 'Payment confirmation failed';
    throw Exception(msg);
  }

  // ── Full Purchase Flows ─────────────────────────────────────────────

  /// Complete end-to-end Stripe subscription purchase.
  /// 1. Create PaymentIntent on backend
  /// 2. Show Stripe payment sheet
  /// 3. Confirm payment on backend (activate subscription)
  static Future<Map<String, dynamic>> purchaseSubscription({
    required String authToken,
    required int subscriptionId,
    required int durationDays,
    required int amountInCents,
  }) async {
    // Step 1: Create PaymentIntent
    final intentData = await createPaymentIntent(
      authToken: authToken,
      amountInCents: amountInCents,
      type: 'subscription',
      subscriptionId: subscriptionId,
      durationDays: durationDays,
    );

    final clientSecret = intentData['client_secret'] as String;
    final paymentIntentId = intentData['payment_intent_id'] as String;

    // Re-sync the Stripe publishable key if the backend returned one.
    // IMPORTANT: Do NOT call applySettings() here — calling it mid-flow
    // reinitializes the native SDK and crashes the app ("Lost connection").
    // The new key will take effect on the next payment flow.
    final publishableKey = intentData['publishable_key'] as String?;
    if (publishableKey != null &&
        publishableKey.isNotEmpty &&
        publishableKey != Stripe.publishableKey) {
      DebugLogger.info(
          'StripeService: Backend key differs, updating for next flow');
      Stripe.publishableKey = publishableKey;
    }

    // Step 2: Present payment sheet
    await presentPaymentSheet(clientSecret: clientSecret);

    // Step 3: Confirm on backend
    return await confirmPaymentOnBackend(
      authToken: authToken,
      paymentIntentId: paymentIntentId,
      type: 'subscription',
      subscriptionId: subscriptionId,
      durationDays: durationDays,
    );
  }

  /// Complete end-to-end Stripe product purchase with optional international shipping.
  static Future<Map<String, dynamic>> purchaseProducts({
    required String authToken,
    required List<int> productIds,
    required int amountInCents,
    int? shippingAddressId,
    int? shippingProviderId,
  }) async {
    final intentData = await createPaymentIntent(
      authToken: authToken,
      amountInCents: amountInCents,
      type: 'product',
      productIds: productIds,
      shippingAddressId: shippingAddressId,
      shippingProviderId: shippingProviderId,
    );

    final clientSecret = intentData['client_secret'] as String;
    final paymentIntentId = intentData['payment_intent_id'] as String;

    // Re-sync Stripe SDK publishable key with the one the backend actually used.
    // IMPORTANT: Do NOT call applySettings() here — calling it mid-flow
    // reinitializes the native SDK and crashes the app.
    final publishableKey = intentData['publishable_key'] as String?;
    if (publishableKey != null &&
        publishableKey.isNotEmpty &&
        publishableKey != Stripe.publishableKey) {
      DebugLogger.info(
          'StripeService: Backend key differs, updating for next flow');
      Stripe.publishableKey = publishableKey;
    }

    await presentPaymentSheet(clientSecret: clientSecret);

    return await confirmPaymentOnBackend(
      authToken: authToken,
      paymentIntentId: paymentIntentId,
      type: 'product',
      productIds: productIds,
      shippingAddressId: shippingAddressId,
      shippingProviderId: shippingProviderId,
    );
  }

  // ── Saved Cards ─────────────────────────────────────────────────────

  /// Fetch saved payment methods for the authenticated user.
  static Future<List<Map<String, dynamic>>> getPaymentMethods({
    required String authToken,
  }) async {
    final response = await http.get(
      Uri.parse(Url.baakhapaaApi('/stripe/payment-methods')),
      headers: Url.baakhapaaAuthHeaders(authToken),
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return List<Map<String, dynamic>>.from(data['data']);
    }
    return [];
  }

  /// Remove a saved payment method.
  static Future<void> deletePaymentMethod({
    required String authToken,
    required String paymentMethodId,
  }) async {
    await http.delete(
      Uri.parse(Url.baakhapaaApi('/stripe/payment-methods/$paymentMethodId')),
      headers: Url.baakhapaaAuthHeaders(authToken),
    );
  }
}
