import 'dart:convert';
import 'dart:developer';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:khalti_checkout_flutter/khalti_checkout_flutter.dart';

import '../config/app_credentials.dart';

class KhaltiService {
  // Store the payment completion callback for the current transaction
  static Function(PaymentPayload)? onPaymentCompletedCallback;
  static bool isPaymentInProgress = false;
  static Timer? statusCheckTimer;

  // Server-side payment initiation
  static Future<String> initiatePaymentServer({
    required double amount,
    required String orderName,
    required String orderId,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
  }) async {
    try {
      final url = Uri.parse(AppCredentials.isProduction
          ? 'https://khalti.com/api/v2/epayment/initiate/'
          : 'https://dev.khalti.com/api/v2/epayment/initiate/');

      // Create the request payload
      final payload = {
        "return_url": "https://baakhapaa.com/",
        "website_url": "https://baakhapaa.com/",
        'amount': (amount * 100).toInt(), // Convert to paisa
        'purchase_order_id': orderId,
        'purchase_order_name': orderName,
        'customer_info': {
          'name': customerName ?? 'Customer',
          'email': customerEmail ?? '',
          'phone': customerPhone ?? '',
        },
      };

      log('Initiating payment with payload: ${json.encode(payload)}');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              "Key ${AppCredentials.isProduction ? AppCredentials.khaltiSecretKey : AppCredentials.khaltiTestSecretKey}"
        },
        body: json.encode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = json.decode(response.body);
        final pidx = responseData['pidx'];
        log('Payment initiated successfully with PIDX: $pidx');
        return pidx;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
            'Failed to initiate payment: ${errorData['error_key'] ?? response.statusCode}');
      }
    } catch (e) {
      log('Error initiating payment: $e');
      throw e;
    }
  }

  static Future<Khalti> initializeKhalti({String? pidx}) async {
    final payConfig = KhaltiPayConfig(
      publicKey: AppCredentials.isProduction
          ? AppCredentials.khaltiPublicKey
          : AppCredentials.khaltiTestPublicKey,
      pidx: pidx ?? '',
      environment:
          AppCredentials.isProduction ? Environment.prod : Environment.test,
    );

    return Khalti.init(
      enableDebugging: true,
      payConfig: payConfig,
      onPaymentResult: (paymentResult, khalti) {
        log('Payment Result: ${paymentResult.toString()}');

        // You can add custom business logic here
        if (paymentResult.payload?.status == 'Completed') {
          log('Payment was successful!');
        }
      },
      onMessage: (
        khalti, {
        description,
        statusCode,
        event,
        needsPaymentConfirmation,
      }) async {
        log('Khalti Message - Description: $description, Status Code: $statusCode, Event: $event');

        // Add special handling for the return URL load failure
        if (event == KhaltiEvent.returnUrlLoadFailure) {
          // This is normal when using http URLs with iOS, we'll handle the success elsewhere
          log('Return URL failed to load, checking payment status...');

          // We can still verify the payment
          if (needsPaymentConfirmation == true) {
            try {
              await khalti.verify();
            } catch (e) {
              log('Payment verification failed: $e');
            }
          }
        }

        // Verify payment if needed
        if (needsPaymentConfirmation == true) {
          try {
            await khalti.verify();
          } catch (e) {
            log('Payment verification failed: $e');
          }
        }
      },
      onReturn: () => log('Successfully redirected to return_url.'),
    );
  }

  // Method to make a payment
  static Future<void> makePayment(BuildContext context, String pidx,
      Function(PaymentPayload)? onPaymentCompleted) async {
    try {
      // Cancel any existing timer
      statusCheckTimer?.cancel();

      // Store the callback for use when payment is completed
      onPaymentCompletedCallback = onPaymentCompleted;
      isPaymentInProgress = true;

      // Validate PIDX
      if (pidx.isEmpty) {
        throw Exception('Invalid PIDX: PIDX cannot be empty');
      }

      log('Starting payment with PIDX: $pidx');

      // Always initialize a new instance with the correct PIDX directly
      final khalti = await initializeKhalti(pidx: pidx);

      // Open the payment page
      khalti.open(context);
      log('Khalti payment page opened');

      // Start checking payment status immediately and more frequently
      statusCheckTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
        if (!isPaymentInProgress) {
          timer.cancel();
          return;
        }

        try {
          // Check payment status
          final status = await checkPaymentStatus(pidx);
          log('Checking payment status: ${status?["status"]}');

          if (status != null && status['status'] == 'Completed') {
            // Payment is complete - close webview and call completion handler
            timer.cancel();
            isPaymentInProgress = false;

            try {
              // Attempt to close the webview
              Navigator.of(context, rootNavigator: true).pop();
              log('Closed payment webview');
            } catch (e) {
              log('Error closing webview: $e');
              // Continue with processing even if closing fails
            }

            // Call the callback with payment data
            if (onPaymentCompletedCallback != null) {
              final payload = PaymentPayload(
                pidx: pidx,
                totalAmount: status['total_amount'] ?? 0,
                status: 'Completed',
                transactionId: status['transaction_id'] ?? '',
                refunded: false,
                purchaseOrderId: status['purchase_order_id'] ?? '',
                purchaseOrderName: status['purchase_order_name'] ?? '',
              );

              // Ensure the callback is called on the main thread
              WidgetsBinding.instance.addPostFrameCallback((_) {
                onPaymentCompletedCallback!(payload);
              });
            }
          }
        } catch (e) {
          log('Error in payment status check: $e');
        }
      });
    } catch (e) {
      isPaymentInProgress = false;
      log('Error processing Khalti payment: $e');
      // Show an error message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment processing failed: $e')),
      );
    }
  }

  // Method to verify a payment manually
  static Future<bool> verifyPayment(Khalti khalti) async {
    try {
      await khalti.verify();
      return true;
    } catch (e) {
      log('Manual payment verification failed: $e');
      return false;
    }
  }

  // Method to manually check payment status with better error handling
  static Future<Map<String, dynamic>?> checkPaymentStatus(String pidx) async {
    try {
      final url = Uri.parse(AppCredentials.isProduction
          ? 'https://khalti.com/api/v2/epayment/lookup/'
          : 'https://dev.khalti.com/api/v2/epayment/lookup/');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              "Key ${AppCredentials.isProduction ? AppCredentials.khaltiSecretKey : AppCredentials.khaltiTestSecretKey}"
        },
        body: json.encode({
          'pidx': pidx,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        log('Payment status manual check: $responseData');
        return responseData;
      } else {
        // log('Error checking payment status: Status code ${response.statusCode}');
        // log('Response body: ${response.body}');

        // Try to parse the error response
        try {
          final errorData = json.decode(response.body);
          log('Error details: $errorData');
        } catch (e) {
          // Couldn't parse JSON, just log the raw response
        }

        return null;
      }
    } catch (e) {
      log('Exception checking payment status: $e');
      return null;
    }
  }

  // Method to generate a PIDX from the server
  // This is a placeholder - in a real app, you would make an API call to your server
  static Future<String> generatePidx(
      double amount, String productIdentity, String productName) async {
    // Here you would make an API call to your server
    // Your server would make a request to Khalti's API to get a PIDX

    // For demonstration purposes, we're returning a placeholder
    log('Generating PIDX for amount: $amount, product: $productName');
    await Future.delayed(Duration(seconds: 1)); // Simulate network delay

    // In a real scenario, you would return the PIDX from your server response
    return "test_pidx_${DateTime.now().millisecondsSinceEpoch}";
  }

  // Clear the payment state when the payment flow is completed or cancelled
  static void clearPaymentState() {
    statusCheckTimer?.cancel();
    isPaymentInProgress = false;
    onPaymentCompletedCallback = null;
  }
}
