import 'package:baakhapaa/models/subscription.dart';
import 'package:baakhapaa/services/khalti_service.dart' as app_khalti;
import 'package:baakhapaa/services/subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:khalti_checkout_flutter/khalti_checkout_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/auth.dart';

class SubscriptionProvider extends ChangeNotifier {
  SubscriptionService? _subscriptionService;
  List<SubscriptionPackage> _packages = [];
  bool _isLoading = false;
  bool _isPurchasing = false;
  String? _error;
  SubscriptionPackage? _selectedPackage;
  String? _currentPidx;

  // Getters
  List<SubscriptionPackage> get packages => _packages;
  bool get isLoading => _isLoading;
  bool get isPurchasing => _isPurchasing;
  String? get error => _error;
  SubscriptionPackage? get selectedPackage => _selectedPackage;

  // Initialize the service with context
  void initializeServices(BuildContext context) {
    _subscriptionService = SubscriptionService(context: context);
  }

  @override
  void dispose() {
    // Clear any active payment state when provider is disposed
    app_khalti.KhaltiService.clearPaymentState();
    super.dispose();
  }

  // Fetch subscription packages
  Future<void> fetchPackages() async {
    if (_subscriptionService == null) {
      _error = 'Service not initialized. Please try again.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _subscriptionService!.getSubscriptionPackages();

      if (response.success) {
        _packages = response.data;
        // Auto-select recommended package if available
        if (_packages.isNotEmpty) {
          try {
            _selectedPackage = _packages.firstWhere(
              (package) =>
                  _subscriptionService!.isRecommendedPackage(package.title),
            );
          } catch (e) {
            // If no recommended package found, select the first one
            _selectedPackage = _packages.first;
          }
        }
      } else {
        _error = 'No packages available';
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching packages: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Select a package
  void selectPackage(SubscriptionPackage package) {
    _selectedPackage = package;
    notifyListeners();
  }

  // Khalti payment success handler (similar to cart screen)
  void khaltiPaymentSuccess(PaymentPayload payload, BuildContext context,
      int subscriptionId, String duration) async {
    if (_currentPidx != null && _currentPidx != payload.pidx) {
      debugPrint(
          "Ignoring payment for different PIDX: ${payload.pidx} (current: $_currentPidx)");
      return;
    }

    _isPurchasing = true;
    notifyListeners();

    try {
      // Create payment data similar to cart screensu
      Map<String, dynamic> paymentData = {
        'idx': payload.pidx,
        'token': payload.transactionId,
        'amount': payload.totalAmount,
        'mobile': '', // The new SDK doesn't provide mobile number directly
        'source': 'Khalti',
      };

      debugPrint(
          "Subscription payment data being sent to server: $paymentData");

      // Process the subscription payment using the new khaltiSubscriptionPayment method
      await _subscriptionService!.khaltiSubscriptionPayment(
          paymentData, subscriptionId, duration, "khalti");

      // Clear PIDX reference and refresh packages
      _currentPidx = null;
      await fetchPackages();

      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint("Error processing Khalti subscription payment: $e");
    } finally {
      _isPurchasing = false;
      app_khalti.KhaltiService.clearPaymentState();
      notifyListeners();
    }
  }

  // Purchase subscription with Khalti payment (updated to follow cart screen pattern)
  Future<bool> purchaseSubscriptionWithKhalti({
    required BuildContext context,
    required int subscriptionId,
    required String duration,
    required double amount,
    required String subscriptionName,
  }) async {
    _isPurchasing = true;
    _error = null;
    notifyListeners();

    try {
      // Generate a unique orderId and a descriptive orderName for the transaction
      final String orderId =
          'subscription_${subscriptionId}_${DateTime.now().millisecondsSinceEpoch}';
      final String orderName = 'Subscription - $subscriptionName ($duration)';

      // Get user information from Auth provider
      final auth = Provider.of<Auth>(context, listen: false);
      String? customerName = auth.userName;
      String? customerEmail = auth.user['email'];
      String? customerPhone = auth.user['phone_number'];

      // Clear any previous payment state
      app_khalti.KhaltiService.clearPaymentState();

      // Step 1: Call the server-side payment initiation to get the PIDX.
      final String pidx = await app_khalti.KhaltiService.initiatePaymentServer(
        amount: amount,
        orderId: orderId,
        orderName: orderName,
        customerName: customerName,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
      );

      if (pidx.isEmpty) {
        throw Exception("Failed to get valid PIDX from server");
      }

      // Store current PIDX to track payment session
      _currentPidx = pidx;
      debugPrint("Received PIDX for subscription: $pidx");

      // Step 2: Use the received PIDX to start the client-side payment with Khalti.
      await app_khalti.KhaltiService.makePayment(
        context,
        pidx,
        (paymentPayload) => khaltiPaymentSuccess(
            paymentPayload, context, subscriptionId, duration),
      );

      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error during subscription payment flow: $e');
      _currentPidx = null;
      _isPurchasing = false;
      app_khalti.KhaltiService.clearPaymentState();
      notifyListeners();
      return false;
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Clear payment state
  void clearPaymentState() {
    _currentPidx = null;
    _isPurchasing = false;
    app_khalti.KhaltiService.clearPaymentState();
    notifyListeners();
  }

  // Get package pricing
  Map<String, double> getPackagePricing(int pricePerDay) {
    if (_subscriptionService == null) return {};
    return _subscriptionService!.calculatePricing(pricePerDay);
  }

  // Helper methods
  bool isPopularPackage(String packageTitle) {
    if (_subscriptionService == null) return false;
    return _subscriptionService!.isPopularPackage(packageTitle);
  }

  bool isRecommendedPackage(String packageTitle) {
    if (_subscriptionService == null) return false;
    return _subscriptionService!.isRecommendedPackage(packageTitle);
  }

  Color getPackageColor(String packageTitle) {
    if (_subscriptionService == null) return Colors.blue;
    return _subscriptionService!.getPackageColor(packageTitle);
  }

  IconData getPackageIcon(String packageTitle) {
    if (_subscriptionService == null) return Icons.star;
    return _subscriptionService!.getPackageIcon(packageTitle);
  }

  List<String> getPackageFeatures(SubscriptionPackage package) {
    if (_subscriptionService == null) return [];
    return _subscriptionService!.generateFeatures(package);
  }
}
