import 'package:baakhapaa/models/subscription.dart';
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/providers/currency_provider.dart';
import 'package:baakhapaa/services/subscription_service.dart';
import 'package:baakhapaa/services/stripe_service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:khalti_checkout_flutter/khalti_checkout_flutter.dart';
import 'package:provider/provider.dart';
import '../../widgets/loading.dart';
import '../../services/khalti_service.dart' as app_khalti;
import '../../../utils/debug_logger.dart';
import '../../widgets/checkout_bottom_sheet.dart';

class SubscriptionScreen extends StatefulWidget {
  static const routeName = '/subscription-screen';

  const SubscriptionScreen({Key? key}) : super(key: key);

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = false;
  bool _isPurchasing = false;
  String _selectedDuration = 'Monthly';
  SubscriptionPackage? _selectedPackage;
  List<SubscriptionPackage> _packages = [];
  late final SubscriptionService _subscriptionService;
  // Keep track of current payment session
  String? _currentPidx;

  // UI display → API value
  static const Map<String, String> _durationApiValue = {
    'Monthly': '1_month',
    '3-Month': '3_months',
    '6-Month': '6_months',
    'Annual': '12_months',
  };

  final List<String> _durationOptions = [
    'Monthly',
    '3-Month',
    '6-Month',
    'Annual'
  ];

  @override
  void initState() {
    super.initState();
    DebugLogger.info('SubscriptionScreen: Initializing screen');
    _subscriptionService = SubscriptionService(context: context);
    _loadPackages();
  }

  @override
  void dispose() {
    DebugLogger.info(
        'SubscriptionScreen: Disposing screen and clearing payment state');
    // Clear any active payment state when the screen is closed
    app_khalti.KhaltiService.clearPaymentState();
    super.dispose();
  }

  Future<void> _loadPackages() async {
    DebugLogger.info('SubscriptionScreen: Loading recurring packages');
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _subscriptionService.getSubscriptionPackages();
      DebugLogger.info(
          'SubscriptionScreen: Received ${response.data.length} packages');

      if (response.success && response.data.isNotEmpty) {
        setState(() {
          _packages = response.data;
          // Auto-select recommended (Basic) or first
          try {
            _selectedPackage = response.data.firstWhere(
              (p) => _subscriptionService.isRecommendedPackage(p.title),
            );
            DebugLogger.info(
                'SubscriptionScreen: Auto-selected recommended package: ${_selectedPackage!.title}');
          } catch (_) {
            _selectedPackage = response.data.first;
            DebugLogger.info(
                'SubscriptionScreen: Auto-selected first package: ${_selectedPackage!.title}');
          }
        });
      } else {
        DebugLogger.info(
            'SubscriptionScreen: No subscription packages available');
        _showErrorSnackBar('No subscription packages available');
      }
    } catch (error) {
      DebugLogger.info('SubscriptionScreen: Error loading packages: $error');
      _showErrorSnackBar('Failed to load packages: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        DebugLogger.info('SubscriptionScreen: Finished loading packages');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    DebugLogger.info('SubscriptionScreen: Showing error: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFBA1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    DebugLogger.info('SubscriptionScreen: Showing success: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF7ED321),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Khalti payment success handler - similar to cart screen
  void khaltiPaymentSuccess(PaymentPayload payload) async {
    if (!mounted) return;

    DebugLogger.info(
        'SubscriptionScreen: Processing successful subscription payment: ${payload.pidx}');

    // Check if this payment matches our current payment session
    if (_currentPidx != null && _currentPidx != payload.pidx) {
      DebugLogger.info(
          "SubscriptionScreen: Ignoring payment for different PIDX: ${payload.pidx} (current: $_currentPidx)");
      return;
    }

    // Run on UI thread
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        _isPurchasing = true;
      });

      _showSuccessSnackBar('Payment Completed. Processing Recurring Orders...');
    });

    try {
      // Create payment data similar to cart screen
      Map<String, dynamic> paymentData = {
        'idx': payload.pidx,
        'token': payload.transactionId,
        'amount': payload.totalAmount,
        'mobile': '',
        'source': 'Khalti',
      };

      DebugLogger.info(
          "SubscriptionScreen: Subscription payment data being sent to server: $paymentData");

      // Get API duration value
      final apiDuration =
          _durationApiValue[_selectedDuration] ?? _selectedDuration;
      DebugLogger.info("SubscriptionScreen: API duration: $apiDuration");

      // Process the subscription payment - similar to khaltiPayment in orders
      await _subscriptionService.khaltiSubscriptionPayment(
        paymentData,
        _selectedPackage!.id,
        apiDuration,
        "khalti",
      );

      // Clear PIDX reference
      _currentPidx = null;
      DebugLogger.info(
          'SubscriptionScreen: Subscription payment processed successfully');

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isPurchasing = false;
            });

            _subscriptionSuccessDialog();
            // Clear payment state when success dialog is shown
            app_khalti.KhaltiService.clearPaymentState();
            DebugLogger.info(
                'SubscriptionScreen: Payment state cleared after success');
          }
        });
      }
    } catch (e) {
      DebugLogger.info(
          "SubscriptionScreen: Error processing Khalti subscription payment: $e");
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isPurchasing = false;
            });

            // Extract error message from exception
            String errorMessage = e.toString().replaceFirst('Exception: ', '');

            // Show error dialog with actual message
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text('Payment Processing Failed'),
                content: Text(
                  errorMessage.isEmpty
                      ? 'An error occurred while processing your payment. Please try again.'
                      : errorMessage,
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        });
      }
    } finally {
      app_khalti.KhaltiService.clearPaymentState();
      DebugLogger.info(
          'SubscriptionScreen: Payment state cleared in finally block');

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isPurchasing = false;
            });
          }
        });
      }
    }
  }

  // Khalti payment handler - similar to cart screen
  Future<void> payWithKhaltiInApp(BuildContext context, double amount) async {
    try {
      if (!mounted) return;

      DebugLogger.info(
          'SubscriptionScreen: Initiating Khalti payment for amount: $amount');

      setState(() {
        _isPurchasing = true;
      });

      // Generate a unique order ID
      final orderId =
          'subscription_${_selectedPackage!.id}_${DateTime.now().millisecondsSinceEpoch}';
      final orderName =
          'Subscription - ${_selectedPackage!.title} ($_selectedDuration)';

      DebugLogger.info('SubscriptionScreen: Generated order ID: $orderId');
      DebugLogger.info('SubscriptionScreen: Order name: $orderName');

      // Get user information from Auth provider
      final auth = Provider.of<Auth>(context, listen: false);
      String? customerName = auth.userName;
      String? customerEmail = auth.user['email'];
      String? customerPhone = auth.user['phone_number'] as String;

      DebugLogger.info(
          'SubscriptionScreen: Customer info - Name: $customerName, Email: $customerEmail, Phone: $customerPhone');

      // Clear any previous payment state
      app_khalti.KhaltiService.clearPaymentState();

      String pidx = await app_khalti.KhaltiService.initiatePaymentServer(
        amount: amount,
        orderName: orderName,
        orderId: orderId,
        customerName: customerName,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
      );

      if (pidx.isEmpty) {
        throw Exception("Failed to get valid PIDX from server");
      }

      // Store current PIDX to track payment session
      _currentPidx = pidx;
      DebugLogger.info(
          "SubscriptionScreen: Received PIDX for subscription: $pidx");
      DebugLogger.info(
          "SubscriptionScreen: Initializing Khalti subscription payment with PIDX: $pidx");

      // Pass the callback that should be executed when payment is completed
      await app_khalti.KhaltiService.makePayment(
        context,
        pidx,
        khaltiPaymentSuccess, // Pass the callback for completed payments
      );
    } catch (e) {
      if (!mounted) return;
      DebugLogger.info(
          "SubscriptionScreen: Error initiating subscription payment: $e");
      _showErrorSnackBar('Error processing payment: $e');
      // Clear _currentPidx on error
      _currentPidx = null;
      app_khalti.KhaltiService.clearPaymentState();
      DebugLogger.info('SubscriptionScreen: Payment state cleared after error');
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
        DebugLogger.info('SubscriptionScreen: Payment processing finished');
      }
    }
  }

  void _subscriptionSuccessDialog() {
    DebugLogger.info('SubscriptionScreen: Showing subscription success dialog');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B7355), Color(0xFF6B5B47)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B7355).withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                FontAwesomeIcons.crown,
                size: 44,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Success!',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${_selectedPackage!.title} ($_selectedDuration)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF8B7355),
              ),
            ),
            const SizedBox(height: 12),
            /** 
             * 
            Application Todo: Unlock Challenges Using Subscription Benefit
            1: Use Message from API in Success Dialog of Subscription Purchase
            2: Add life only after life is 0 since its is creating issue with reloading the lose screen infinity resolved by rujal
            3: Resolve the ongoing issue during story unlock in @episode screen completed 
            Api Changes:
            1. When Subscribed user should get points reward as mentioned in the subscription plan as soon as the order is completed 
            2. User ID should be registered to Achievement_user table
            3. 
             */
            Text(
              'Your recurring subscription order is send for confirmation. !',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade400
                    : Colors.grey.shade600,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  DebugLogger.info(
                      'SubscriptionScreen: User confirmed success dialog');
                  Navigator.of(ctx).pop();
                  _loadPackages();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B7355),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processPurchase() async {
    if (_selectedPackage == null) {
      DebugLogger.info('SubscriptionScreen: Error - No package selected');
      return;
    }

    DebugLogger.info(
        'SubscriptionScreen: _processPurchase called for subscription with payment method: khalti');
    DebugLogger.info(
        'SubscriptionScreen: Selected package: ${_selectedPackage!.title}');
    DebugLogger.info(
        'SubscriptionScreen: Selected duration: $_selectedDuration');

    setState(() {
      _isPurchasing = true;
    });

    try {
      final pricing =
          _subscriptionService.calculatePricing(_selectedPackage!.pricePerDay);
      final double amount = (pricing[_selectedDuration] ?? 0).toDouble();

      DebugLogger.info('SubscriptionScreen: Calculated amount: $amount');
      DebugLogger.info(
          'SubscriptionScreen: Processing Khalti subscription payment...');

      // Process Khalti payment
      await payWithKhaltiInApp(context, amount);
    } catch (e) {
      DebugLogger.info('SubscriptionScreen: Error processing subscription: $e');
      DebugLogger.info(
          'SubscriptionScreen: Error stack trace: ${StackTrace.current}');

      // Show error message
      String errorMessage = 'Error processing subscription';
      if (e.toString().contains('HTML error page')) {
        errorMessage = 'Server error. Please try again later.';
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        errorMessage = 'Network error. Please check your connection.';
      } else if (e.toString().contains('not authenticated')) {
        errorMessage = 'Please log in to purchase subscription.';
      } else if (e.toString().contains('401')) {
        errorMessage = 'Session expired. Please log in again.';
      }
      _showErrorSnackBar(errorMessage);
    } finally {
      DebugLogger.info(
          'SubscriptionScreen: _processPurchase finally block executed');
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  /// Process subscription purchase via Stripe (credit/debit card in USD).
  Future<void> _processStripePurchase() async {
    if (_selectedPackage == null) return;

    DebugLogger.info(
        'SubscriptionScreen: Starting Stripe payment for ${_selectedPackage!.title}');

    setState(() => _isPurchasing = true);

    try {
      final auth = Provider.of<Auth>(context, listen: false);
      final token = auth.token;
      if (token.isEmpty) {
        throw Exception('Not authenticated. Please login again.');
      }

      // Calculate USD amount
      final apiDuration =
          _durationApiValue[_selectedDuration] ?? _selectedDuration;
      final durationDays = _subscriptionService.getDurationInDays(apiDuration);

      // Use USD pricing from package
      final priceUsdPerDay = _selectedPackage!.priceUsdPerDay;
      DebugLogger.info(
          'SubscriptionScreen: priceUsdPerDay=${_selectedPackage!.priceUsdPerDay}, '
          'id=${_selectedPackage!.id}, durationDays=$durationDays');
      if (priceUsdPerDay == null || priceUsdPerDay <= 0) {
        throw Exception(
            'USD pricing is not configured for the "${_selectedPackage!.title}" package. '
            'Please run: php artisan db:seed --class=SubscriptionUsdPriceSeeder on the server.');
      }
      final amountUsd = priceUsdPerDay * durationDays;
      final amountInCents = (amountUsd * 100).round();

      DebugLogger.info(
          'SubscriptionScreen: Stripe amount — \$$amountUsd ($amountInCents cents) for $durationDays days');

      // Full Stripe flow: create intent → show sheet → confirm on backend
      await StripeService.purchaseSubscription(
        authToken: token,
        subscriptionId: _selectedPackage!.id,
        durationDays: durationDays,
        amountInCents: amountInCents,
      );

      DebugLogger.info('SubscriptionScreen: Stripe payment successful');

      if (mounted) {
        _subscriptionSuccessDialog();
      }
    } catch (e, stackTrace) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      DebugLogger.info('SubscriptionScreen: Stripe payment error — $msg');
      DebugLogger.info('SubscriptionScreen: Stripe stack trace — $stackTrace');

      if (!mounted) return;

      // StripeException from SDK means user cancelled or card declined
      if (msg.contains('StripeException') ||
          msg.contains('Cancelled') ||
          msg.contains('canceled') ||
          msg.contains('StripeError')) {
        _showErrorSnackBar('Payment cancelled.');
      } else if (msg.contains('No such payment_intent') ||
          msg.contains('key mismatch')) {
        _showErrorSnackBar(
            'Payment configuration error. Please contact support.');
      } else if (msg.contains('SocketException') ||
          msg.contains('TimeoutException') ||
          msg.contains('Connection')) {
        _showErrorSnackBar(
            'Network error. Please check your connection and try again.');
      } else {
        _showErrorSnackBar(msg.isNotEmpty ? msg : 'Payment failed. Try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  double _getDiscountPercentage(SubscriptionPackage package, String duration) {
    final pricing = _subscriptionService.calculatePricing(package.pricePerDay);
    final monthlyPrice = pricing['Monthly'] ?? 0;
    final selectedPrice = pricing[duration] ?? monthlyPrice;

    int months = 1;
    switch (duration) {
      case '3-Month':
        months = 3;
        break;
      case '6-Month':
        months = 6;
        break;
      case 'Annual':
        months = 12;
        break;
    }
    if (months == 1 || monthlyPrice == 0) return 0;

    final totalMonthlyPrice = monthlyPrice * months;
    final discount =
        ((totalMonthlyPrice - selectedPrice) / totalMonthlyPrice) * 100;
    return discount.clamp(0, 100);
  }

  Widget _buildDurationSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: _durationOptions.map((duration) {
          final isSelected = _selectedDuration == duration;
          final isBestValue = duration == 'Annual';
          return Expanded(
            child: GestureDetector(
              onTap: () {
                DebugLogger.info(
                    'SubscriptionScreen: Duration selected: $duration');
                setState(() => _selectedDuration = duration);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF1A1A1A))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    if (isBestValue)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        margin: const EdgeInsets.only(bottom: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'SAVE',
                          style: GoogleFonts.inter(
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    Text(
                      duration,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? (isDark ? const Color(0xFF1A1A1A) : Colors.white)
                            : (isDark ? Colors.white54 : Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  int _getTotalPoints(SubscriptionPackage package, String duration) {
    int days = 30; // default monthly
    switch (duration) {
      case '3-Month':
        days = 90;
        break;
      case '6-Month':
        days = 180;
        break;
      case 'Annual':
        days = 365;
        break;
      case 'Monthly':
      default:
        days = 30;
    }
    return package.pointsPerDay * days;
  }

  Widget _buildPackageCard(SubscriptionPackage package) {
    final color = _subscriptionService.getPackageColor(package.title);
    final icon = _subscriptionService.getPackageIcon(package.title);
    final features = _subscriptionService.generateFeatures(
        package, _durationApiValue[_selectedDuration]);
    final pricing = _subscriptionService.calculatePricing(package.pricePerDay);
    final price = (pricing[_selectedDuration] ?? 0).toDouble();
    final discount = _getDiscountPercentage(package, _selectedDuration);
    final isSelected = _selectedPackage?.id == package.id;
    final isRecommended =
        _subscriptionService.isRecommendedPackage(package.title);
    final totalPoints = _getTotalPoints(package, _selectedDuration);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        DebugLogger.info(
            'SubscriptionScreen: Package selected: ${package.title}');
        setState(() => _selectedPackage = package);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: isDark
                      ? [
                          color.withValues(alpha: 0.2),
                          color.withValues(alpha: 0.08)
                        ]
                      : [
                          color.withValues(alpha: 0.08),
                          color.withValues(alpha: 0.02)
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected
              ? null
              : (isDark ? const Color(0xFF141414) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.6)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey.withValues(alpha: 0.12)),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recommended strip
            if (isRecommended)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.7)],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(19),
                    topRight: Radius.circular(19),
                  ),
                ),
                child: Text(
                  '⭐  RECOMMENDED',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
              ),

            Padding(
              padding: EdgeInsets.fromLTRB(18, isRecommended ? 14 : 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: icon + title + price inline
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color, color.withValues(alpha: 0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              package.title,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              '${package.pointsPerDay} pts/day  •  ${package.benefits.length + 1} benefits',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.white38
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Price column
                      Consumer<CurrencyProvider>(
                        builder: (_, currency, __) {
                          final int days;
                          switch (_selectedDuration) {
                            case '3-Month':
                              days = 90;
                              break;
                            case '6-Month':
                              days = 180;
                              break;
                            case 'Annual':
                              days = 365;
                              break;
                            default:
                              days = 30;
                          }
                          final priceUsd = (package.priceUsdPerDay != null &&
                                  package.priceUsdPerDay! > 0)
                              ? package.priceUsdPerDay! * days
                              : currency.convertNprToUsd(price);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Rs ${price.toInt()}',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                              Text(
                                '/${_selectedDuration.toLowerCase().replaceAll('-', ' ')}',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.grey.shade500,
                                ),
                              ),
                              Text(
                                '~\$${priceUsd.toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),

                  if (discount > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_offer_rounded,
                              color: Color(0xFF4CAF50), size: 13),
                          const SizedBox(width: 4),
                          Text(
                            'Save ${discount.toInt()}% compared to monthly',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF4CAF50),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Compact benefits row
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildBenefitChip(
                        Icons.block_rounded,
                        'No Ads',
                        color,
                        isDark,
                        isPremium: true,
                      ),
                      if (package.benefits.isNotEmpty)
                        ...package.benefits.take(3).map(
                              (benefit) => _buildBenefitChip(
                                Icons.check_circle_outline_rounded,
                                benefit.quantity > 0
                                    ? '${benefit.name} ×${benefit.quantity}'
                                    : benefit.name,
                                color,
                                isDark,
                              ),
                            )
                      else
                        ...features.take(3).map(
                              (f) => _buildBenefitChip(
                                Icons.check_circle_outline_rounded,
                                f.replaceAll('• ', ''),
                                color,
                                isDark,
                              ),
                            ),
                      _buildBenefitChip(
                        Image.asset('assets/images/coins.png',
                            width: 22, height: 22),
                        '$totalPoints pts',
                        color,
                        isDark,
                      ),
                    ],
                  ),

                  // Selected indicator
                  if (isSelected) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: color, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Selected',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitChip(
    dynamic icon,
    String label,
    Color color,
    bool isDark, {
    bool isPremium = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isPremium
            ? color.withValues(alpha: 0.12)
            : (isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(8),
        border:
            isPremium ? Border.all(color: color.withValues(alpha: 0.3)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon is IconData)
            Icon(icon,
                size: 12,
                color: isPremium
                    ? color
                    : (isDark ? Colors.white54 : Colors.grey.shade600))
          else if (icon is Widget)
            SizedBox(width: 14, height: 14, child: icon),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isPremium ? FontWeight.w700 : FontWeight.w500,
                color: isPremium
                    ? color
                    : (isDark ? Colors.white60 : Colors.grey.shade700),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseButton() {
    if (_selectedPackage == null) return const SizedBox.shrink();

    final color = _subscriptionService.getPackageColor(_selectedPackage!.title);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pricing =
        _subscriptionService.calculatePricing(_selectedPackage!.pricePerDay);
    final price = (pricing[_selectedDuration] ?? 0).toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: _isPurchasing
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Processing...',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            : GestureDetector(
                onTap: _showCheckout,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.8)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Get ${_selectedPackage!.title}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Consumer<CurrencyProvider>(
                        builder: (_, currency, __) {
                          final int days;
                          switch (_selectedDuration) {
                            case '3-Month':
                              days = 90;
                              break;
                            case '6-Month':
                              days = 180;
                              break;
                            case 'Annual':
                              days = 365;
                              break;
                            default:
                              days = 30;
                          }
                          final priceUsd =
                              (_selectedPackage!.priceUsdPerDay != null &&
                                      _selectedPackage!.priceUsdPerDay! > 0)
                                  ? _selectedPackage!.priceUsdPerDay! * days
                                  : currency.convertNprToUsd(price);
                          return Text(
                            '•  Rs ${price.toInt()} (~\$${priceUsd.toStringAsFixed(2)})',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // void _handlePurchase() {
  //   if (_selectedPackage == null) {
  //     DebugLogger.info(
  //         'SubscriptionScreen: Error - Cannot handle purchase, no package selected');
  //     return;
  //   }

  //   DebugLogger.info(
  //       'SubscriptionScreen: Handle purchase called for package: ${_selectedPackage!.title}');

  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       final color =
  //           _subscriptionService.getPackageColor(_selectedPackage!.title);
  //       final pricing = _subscriptionService
  //           .calculatePricing(_selectedPackage!.pricePerDay);
  //       final price = (pricing[_selectedDuration] ?? 0).toDouble();

  //       DebugLogger.info('SubscriptionScreen: Showing purchase confirmation dialog');
  //       DebugLogger.info(
  //           'SubscriptionScreen: Price: $price, Duration: $_selectedDuration');

  //       return AlertDialog(
  //         shape:
  //             RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //         title: Row(
  //           children: [
  //             Icon(_subscriptionService.getPackageIcon(_selectedPackage!.title),
  //                 color: color, size: 24),
  //             const SizedBox(width: 12),
  //             const Text('Confirm Purchase'),
  //           ],
  //         ),
  //         content: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             const Text('You are about to purchase:',
  //                 style: TextStyle(fontWeight: FontWeight.w500)),
  //             const SizedBox(height: 12),
  //             Container(
  //               padding: const EdgeInsets.all(16),
  //               decoration: BoxDecoration(
  //                 color: color.withValues(alpha: 0.1),
  //                 borderRadius: BorderRadius.circular(12),
  //                 border: Border.all(color: color.withValues(alpha: 0.3)),
  //               ),
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   Text(_selectedPackage!.title,
  //                       style: TextStyle(
  //                           fontSize: 18,
  //                           fontWeight: FontWeight.bold,
  //                           color: color)),
  //                   Text('$_selectedDuration Recurring Orders',
  //                       style:
  //                           TextStyle(fontSize: 14, color: Colors.grey[600])),
  //                   const SizedBox(height: 8),
  //                   Text('Rs. ${price.toInt()}',
  //                       style: TextStyle(
  //                           fontSize: 24,
  //                           fontWeight: FontWeight.bold,
  //                           color: color)),
  //                   const SizedBox(height: 4),
  //                   Text('${_selectedPackage!.pointsPerDay} points per day',
  //                       style:
  //                           TextStyle(fontSize: 12, color: Colors.grey[600])),
  //                 ],
  //               ),
  //             ),
  //           ],
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //             },
  //             child: const Text('Cancel'),
  //           ),
  //           ElevatedButton(
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //               _processPurchase();
  //             },
  //             style: ElevatedButton.styleFrom(
  //               backgroundColor: color,
  //               foregroundColor: Colors.white,
  //               shape: RoundedRectangleBorder(
  //                   borderRadius: BorderRadius.circular(8)),
  //             ),
  //             child: const Text('Confirm Purchase'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  Future<void> _processCODPurchase() async {
    if (_selectedPackage == null) {
      DebugLogger.info(
          'SubscriptionScreen: Error - No package selected for COD');
      return;
    }

    DebugLogger.info(
        'SubscriptionScreen: Processing COD subscription purchase');
    DebugLogger.info(
        'SubscriptionScreen: Selected package: ${_selectedPackage!.title}');
    DebugLogger.info(
        'SubscriptionScreen: Selected duration: $_selectedDuration');

    setState(() {
      _isPurchasing = true;
    });

    try {
      // Get API duration value
      final apiDuration =
          _durationApiValue[_selectedDuration] ?? _selectedDuration;
      DebugLogger.info(
          "SubscriptionScreen: API duration for COD: $apiDuration");

      // Call the purchase method with COD parameters
      final response = await _subscriptionService.purchaseSubscription(
        subscriptionId: _selectedPackage!.id,
        duration: apiDuration,
        paymentId: null, // null for COD as specified
        paymentMethod: "Cash on Delivery",
      );

      DebugLogger.info(
          'SubscriptionScreen: COD purchase response: ${response.message}');

      if (response.success) {
        // Show success dialog
        _subscriptionSuccessDialog();
        DebugLogger.info(
            'SubscriptionScreen: COD subscription purchase successful');
      } else {
        // If response has a message, use that instead of generic error
        throw Exception(response.message);
      }
    } catch (e) {
      DebugLogger.info(
          'SubscriptionScreen: Error processing COD subscription: $e');

      // Extract the actual error message from exception
      String errorMessage = 'Error processing subscription';
      final errorStr = e.toString().replaceFirst('Exception: ', '');

      // Use the actual error message from API/exception
      if (errorStr.isNotEmpty && !errorStr.contains('Error')) {
        errorMessage = errorStr;
      } else if (errorStr.contains('already have an active subscription')) {
        // API response for 409 conflict
        errorMessage = errorStr;
      } else if (errorStr.contains('already purchased') ||
          errorStr.contains('already subscribed')) {
        errorMessage = 'You have already purchased this subscription.';
      } else if (errorStr.contains('mobile number') ||
          errorStr.contains('phone')) {
        errorMessage =
            'Please update your profile with a mobile number to purchase.';
      } else if (errorStr.contains('HTML error page')) {
        errorMessage = 'Server error. Please try again later.';
      } else if (errorStr.contains('SocketException') ||
          errorStr.contains('TimeoutException')) {
        errorMessage = 'Network error. Please check your connection.';
      } else if (errorStr.contains('not authenticated')) {
        errorMessage = 'Please log in to purchase subscription.';
      } else if (errorStr.contains('401')) {
        errorMessage = 'Session expired. Please log in again.';
      }

      _showErrorSnackBar(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  /// Opens the premium multi-step checkout sheet and processes the subscription
  /// purchase with the chosen payment method.
  Future<void> _showCheckout() async {
    final auth = Provider.of<Auth>(context, listen: false);
    if (!auth.completedProfile) {
      _showErrorSnackBar(
          'Please update your profile with a mobile number to purchase a subscription.');
      return;
    }
    if (_selectedPackage == null) return;

    final currency = Provider.of<CurrencyProvider>(context, listen: false);
    final pricing =
        _subscriptionService.calculatePricing(_selectedPackage!.pricePerDay);
    final double totalNpr = (pricing[_selectedDuration] ?? 0).toDouble();

    final result = await showCheckoutSheet(
      context,
      totalNpr: totalNpr,
      totalUsdDisplay: currency.formatNprAsUsd(totalNpr),
      showShippingProvider: false, // subscriptions don't need a shipping method
      requiresShipping: false, // digital product — skip address step
    );

    if (result == null || !mounted) return;

    DebugLogger.info(
        'SubscriptionScreen: checkout result — method: ${result.paymentMethod}');

    if (result.paymentMethod == 'khalti') {
      DebugLogger.info('SubscriptionScreen: Processing Khalti payment');
      await _processPurchase();
    } else if (result.paymentMethod == 'cod') {
      DebugLogger.info('SubscriptionScreen: Processing COD payment');
      await _processCODPurchase();
    } else if (result.paymentMethod == 'stripe') {
      DebugLogger.info('SubscriptionScreen: Processing Stripe payment');
      await _processStripePurchase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F8FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Recurring Orders',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadPackages,
        child: Column(
          children: [
            // Hero banner
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1A1400), const Color(0xFF0F0D08)]
                      : [const Color(0xFFFFF8E8), const Color(0xFFFFF1D4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFFD700)
                      .withValues(alpha: isDark ? 0.15 : 0.25),
                ),
              ),
              child: Row(
                children: [
                  // Crown icon with glow
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.receipt_long_rounded,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Creator Plans',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? const Color(0xFFFFD700)
                                : const Color(0xFF3C2F1E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Manage recurring plans and perks',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color:
                                isDark ? Colors.white38 : Colors.brown.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!_isLoading && _packages.isNotEmpty) _buildDurationSelector(),
            Expanded(
              child: _isLoading
                  ? const Center(child: Loading())
                  : _packages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_rounded,
                                size: 56,
                                color: isDark
                                    ? Colors.white24
                                    : Colors.grey.shade300,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'No packages available',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextButton.icon(
                                onPressed: _loadPackages,
                                icon:
                                    const Icon(Icons.refresh_rounded, size: 18),
                                label: Text(
                                  'Retry',
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: const EdgeInsets.only(top: 4, bottom: 120),
                          children: [
                            ..._packages
                                .map((package) => _buildPackageCard(package)),
                          ],
                        ),
            ),
          ],
        ),
      ),
      bottomSheet:
          !_isLoading && _packages.isNotEmpty ? _buildPurchaseButton() : null,
    );
  }
}
