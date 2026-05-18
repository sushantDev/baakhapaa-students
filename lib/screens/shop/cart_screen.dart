import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/screens/shop/tab_view_product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:khalti_checkout_flutter/khalti_checkout_flutter.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';

import '../../providers/cart.dart' show Cart;
import '../../widgets/cart_item.dart';
import '../../providers/orders.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/header.dart';
import '../../helpers/helpers.dart';
import '../../utils/puppet_screen_mapping.dart';
import '../../widgets/checkout_bottom_sheet.dart';
import '../../utils/order_success_dialog.dart';

// Fix the ambiguous import by using an alias
import '../../services/khalti_service.dart' as app_khalti;
import '../../services/stripe_service.dart';
import '../../utils/debug_logger.dart';
import '../../providers/currency_provider.dart';
import '../../providers/delivery_provider.dart';
import '../../models/shipping.dart';

class CartScreen extends StatelessWidget {
  static const routeName = '/cart';

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<Cart>(context);

    // Show loading indicator if cart is still loading
    if (!cart.isLoaded) {
      return Scaffold(
        appBar: header(context: context, titleText: '${context.l10n.yourCart}'),
        body: const Padding(
          padding: EdgeInsets.all(16.0),
          child: ListSkeleton(itemCount: 3),
        ),
      );
    }

    return Scaffold(
      appBar: header(context: context, titleText: '${context.l10n.yourCart}'),
      body: cart.itemCount == 0
          ? _buildEmptyCart(context)
          : Container(
              // decoration: BoxDecoration(
              //   gradient: LinearGradient(
              //     begin: Alignment.topCenter,
              //     end: Alignment.bottomCenter,
              //     colors: [
              //       Theme.of(context).brightness == Brightness.dark
              //           ? Color.fromARGB(255, 9, 9, 9)
              //           : Colors.white,
              //       Theme.of(context).brightness == Brightness.dark
              //           ? Color(0xFF082032)
              //           : Color.fromARGB(255, 248, 248, 248),
              //     ],
              //   ),
              // ),
              child: Column(
                children: <Widget>[
                  // Cart Items Section
                  Expanded(
                    child: SingleChildScrollView(
                      physics: BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          SizedBox(height: 16),

                          // Cart Items List
                          Container(
                            margin: EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Color(0xFF2A2A2A)
                                      : Colors.white,
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Color(0xFF1E1E1E)
                                      : Colors.grey.shade50,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.black.withValues(alpha: 0.3)
                                      : Colors.grey.withValues(alpha: 0.15),
                                  blurRadius: 15,
                                  spreadRadius: 0,
                                  offset: Offset(0, 5),
                                ),
                              ],
                              border: Border.all(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                // Header
                                Container(
                                  padding: EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.blue.shade400,
                                              Colors.cyan.shade400
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.blue
                                                  .withValues(alpha: 0.4),
                                              blurRadius: 10,
                                              offset: Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.shopping_cart_rounded,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Cart Items',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              '${cart.itemCount} ${cart.itemCount == 1 ? 'item' : 'items'} in your cart',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Cart Items
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  padding: EdgeInsets.only(bottom: 20),
                                  itemCount: cart.itemCount,
                                  separatorBuilder: (context, index) => Divider(
                                    height: 1,
                                    color: Colors.grey.withValues(alpha: 0.2),
                                    indent: 20,
                                    endIndent: 20,
                                  ),
                                  itemBuilder: (ctx, i) {
                                    final cartItem =
                                        cart.items.values.toList()[i];
                                    final productId =
                                        cart.items.keys.toList()[i];
                                    return CartItem(
                                      cartItem.id,
                                      productId,
                                      cartItem.price,
                                      cartItem.quantity,
                                      cartItem.title,
                                      cartItem.image,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // Cart Summary & Checkout Section
                  _buildCartSummary(context, cart),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).brightness == Brightness.dark
                ? Color.fromARGB(255, 9, 9, 9)
                : Colors.white,
            Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF082032)
                : Color.fromARGB(255, 248, 248, 248),
          ],
        ),
      ),
      child: Center(
        child: Container(
          margin: EdgeInsets.all(32),
          padding: EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).brightness == Brightness.dark
                    ? Color(0xFF2A2A2A)
                    : Colors.white,
                Theme.of(context).brightness == Brightness.dark
                    ? Color(0xFF1E1E1E)
                    : Colors.grey.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 0,
                offset: Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.cyan.shade400],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.shopping_cart_outlined,
                  size: 64,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 24),
              Text(
                context.l10n.yourCartIsEmpty,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 12),
              Text(
                context.l10n.yourCartDescription,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  final GlobalKey<ScaffoldState> scaffoldKeyProduct =
                      GlobalKey<ScaffoldState>();
                  Navigator.pushReplacement(
                    context,
                    PageTransition(
                      child: TabViewProduct(scaffoldKey: scaffoldKeyProduct),
                      type: PageTransitionType.fade,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shopping_bag_rounded, size: 20),
                    SizedBox(width: 8),
                    Text(
                      context.l10n.continueShopping,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartSummary(BuildContext context, Cart cart) {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF2A2A2A)
                : Colors.white,
            Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF1E1E1E)
                : Colors.grey.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.15),
            blurRadius: 15,
            spreadRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Summary Header
          Container(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade400, Colors.teal.shade400],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.receipt_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cart Summary',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Review your order details',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Total Amount
          Consumer<CurrencyProvider>(
            builder: (context, currency, _) => Container(
              margin: EdgeInsets.symmetric(horizontal: 20),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.withValues(alpha: 0.1),
                    Colors.red.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Amount',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Rs. ${cart.totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        '~${currency.formatNprAsUsd(cart.totalAmount)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Checkout Button
          Padding(
            padding: EdgeInsets.all(20),
            child: OrderButton(cart: cart),
          ),
        ],
      ),
    );
  }
}

class OrderButton extends StatefulWidget {
  const OrderButton({
    Key? key,
    required this.cart,
  }) : super(key: key);

  final Cart cart;

  @override
  State<OrderButton> createState() => _OrderButtonState();
}

class _OrderButtonState extends State<OrderButton> with PuppetInteractionMixin {
  bool _isLoading = false;

  bool _isProcessingOrder = false;
  // Keep _currentPidx since it's used to track the current payment session
  String? _currentPidx;
  // Shipping address collected before payment; used by the Khalti success callback
  ShippingAddress? _pendingShippingAddress;

  @override
  void dispose() {
    // Clear any active payment state when the cart screen is closed
    app_khalti.KhaltiService.clearPaymentState();

    // Clear puppet interactions when leaving screen
    clearPuppetInteractions();

    super.dispose();
  }

  void khaltiPaymentSuccess(PaymentPayload payload) async {
    // This method might be called from a different context/thread
    if (!mounted) return;

    DebugLogger.success('Processing successful payment: ${payload.pidx}');

    // Check if this payment matches our current payment session
    if (_currentPidx != null && _currentPidx != payload.pidx) {
      DebugLogger.info(
          "Ignoring payment for different PIDX: ${payload.pidx} (current: $_currentPidx));");
      return;
    }

    // Run on UI thread
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        _isLoading = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Payment Completed. Placing Order...'),
        duration: Duration(seconds: 2),
      ));
    });

    try {
      Map<String, dynamic> paymentData = {
        'idx': payload.pidx,
        'token': payload.transactionId,
        'amount': payload.totalAmount,
        'mobile': '', // The new SDK doesn't provide mobile number directly
        'source': 'Khalti',
        if (_pendingShippingAddress != null)
          'shipping_address_id': _pendingShippingAddress!.id,
      };

      DebugLogger.info("Payment data being sent to server: $paymentData");

      // Process the order
      await Provider.of<Orders>(context, listen: false).khaltiPayment(
        paymentData,
        widget.cart.items,
      );

      // Reset cart and clear PIDX reference
      widget.cart.reset();
      _currentPidx = null;

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            // Close any existing processing dialog before showing success
            try {
              Navigator.of(context, rootNavigator: true).popUntil(
                  (route) => route.settings.name != 'ProcessingDialog');
            } catch (e) {
              // If no dialogs to pop, continue
            }
            presentOrderSuccessDialog(
              detailMessage:
                  'Your order has been placed successfully. We will get back to you soon with order details.',
            );
            // Clear payment state when success dialog is shown
            app_khalti.KhaltiService.clearPaymentState();
          }
        });
      }
    } catch (e) {
      DebugLogger.error("Error processing Khalti payment: $e");
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });

            // Show a more helpful error message
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('Payment Verification Issue'),
                content: Text(
                    'Your payment was processed successfully by Khalti, but we couldn\'t verify it with our system. '
                    'Please contact customer support with your transaction ID: ${payload.transactionId}.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                    },
                    child: Text('OK'),
                  ),
                ],
              ),
            );
          }
        });
      }
    } finally {
      app_khalti.KhaltiService.clearPaymentState();

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        });
      }
    }
  }

  Future<void> payWithKhaltiInApp(BuildContext context, double amount) async {
    try {
      // Ensure the context is valid
      if (!mounted) return;

      setState(() {
        _isLoading = true;
      });

      // Generate a unique order ID
      final orderId = 'order_${DateTime.now().millisecondsSinceEpoch}';
      final orderName = 'Baakhapaa Order - ${widget.cart.itemCount} items';

      // Get user information from Auth provider
      final auth = Provider.of<Auth>(context, listen: false);
      String? customerName = auth.userName;
      String? customerEmail = auth.user['email'];
      String? customerPhone = auth.user['phone_number'];

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
      DebugLogger.info("Received PIDX: $pidx");
      DebugLogger.info("Initializing Khalti payment with PIDX: $pidx");

      // Pass the callback that should be executed when payment is completed
      await app_khalti.KhaltiService.makePayment(
        context,
        pidx,
        khaltiPaymentSuccess, // Pass the callback for completed payments
      );

      // Note: The payment process will continue asynchronously from here
      // The makePayment function handles webview opening and status checks
    } catch (e) {
      if (!mounted) return;
      DebugLogger.error("Error initiating payment: $e");
      _showMessage(context, 'Error processing payment: $e');
      // Clear _currentPidx on error
      _currentPidx = null;
      app_khalti.KhaltiService.clearPaymentState();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Don't clear _currentPidx here - we need it to validate the payment completion
        });
      }
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Dispatches the order after the user completes the checkout sheet.
  /// All payment methods now receive a [ShippingAddress] from the result.
  Future<void> _processOrder(CheckoutResult result) async {
    DebugLogger.info(
        '_processOrder called with payment method: ${result.paymentMethod}');

    setState(() {
      _isProcessingOrder = true;
      _isLoading = true;
    });

    try {
      final method = result.paymentMethod;
      final shippingAddr = result.shippingAddress;

      DebugLogger.info('Processing order with method: $method');

      // ── Khalti ──────────────────────────────────────────────────────────
      if (method == 'khalti') {
        DebugLogger.info('Processing Khalti payment...');
        _pendingShippingAddress = shippingAddr;
        await payWithKhaltiInApp(context, widget.cart.totalAmount);

        // ── Cash on Delivery ─────────────────────────────────────────────
      } else if (method == 'cod') {
        DebugLogger.info('Processing COD order...');
        _showProcessingWarningDialog(context);

        await Provider.of<Orders>(context, listen: false).addOrder(
          cartItems: widget.cart.items,
          paymentMethod: 'Cash on Delivery',
          shippingAddressId: shippingAddr?.id,
        );
        DebugLogger.success('COD order placed successfully');

        if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();
        widget.cart.reset();
        presentOrderSuccessDialog(
          detailMessage:
              'Your order has been placed successfully. We will get back to you soon with order details.',
        );

        // ── Stripe ───────────────────────────────────────────────────────
      } else if (method == 'stripe') {
        DebugLogger.info('Processing Stripe payment...');
        if (!widget.cart.hasOnlyDigitalProducts && shippingAddr == null) {
          if (mounted) {
            _showMessage(
                context, 'Shipping address required for Stripe payments.');
          }
          return;
        }
        await _runStripeProductPurchase(
          shippingAddress: shippingAddr,
          shippingProvider: result.shippingProvider,
        );
      }
    } catch (e) {
      DebugLogger.error('Error processing order: $e');
      if (mounted && Navigator.canPop(context)) {
        try {
          Navigator.of(context).pop();
        } catch (_) {}
      }

      String errorMessage = 'Error processing order';
      final msg = e.toString();
      if (msg.contains('HTML error page')) {
        errorMessage = 'Server error. Please try again later.';
      } else if (msg.contains('SocketException') ||
          msg.contains('TimeoutException')) {
        errorMessage = 'Network error. Please check your connection.';
      } else if (msg.contains('not authenticated')) {
        errorMessage = 'Please log in to place an order.';
      } else if (msg.contains('401')) {
        errorMessage = 'Session expired. Please log in again.';
      }
      if (mounted) _showMessage(context, errorMessage);
    } finally {
      DebugLogger.info('_processOrder finally block executed');
      if (mounted) {
        setState(() {
          _isProcessingOrder = false;
          _isLoading = false;
        });
      }
    }
  }

  /// Runs the full Stripe product-purchase flow using the address & provider
  /// already chosen in the checkout sheet.
  Future<void> _runStripeProductPurchase({
    ShippingAddress? shippingAddress,
    ShippingProvider? shippingProvider,
  }) async {
    try {
      final authToken = Provider.of<Auth>(context, listen: false).token;
      if (authToken.isEmpty) {
        _showMessage(context, 'Please log in to make a payment.');
        return;
      }

      final delivery = Provider.of<DeliveryProvider>(context, listen: false);

      // If the sheet didn't load providers yet (edge case), do it now.
      // Skip provider loading for digital-only orders (no shipping needed).
      if (shippingAddress != null &&
          shippingProvider == null &&
          delivery.availableProviders.isEmpty) {
        final weightKg = widget.cart.items.values
            .fold<double>(0.0, (sum, item) => sum + 0.5 * item.quantity);
        await delivery.loadProviders(
          countryCode: shippingAddress.countryCode,
          weightKg: weightKg > 0 ? weightKg : 0.5,
        );
        if (!mounted) return;
        shippingProvider = delivery.selectedProvider;
      }

      // Build qty-expanded product IDs for server-side validation.
      final productIds = widget.cart.items.entries.expand<int>((entry) {
        final id = int.tryParse(entry.key) ?? 0;
        if (id <= 0) return [];
        return List.filled(entry.value.quantity, id);
      }).toList();

      final currency = Provider.of<CurrencyProvider>(context, listen: false);
      final totalNpr = widget.cart.totalAmount;
      int totalUsdCents = currency.nprToCents(totalNpr);
      if (totalUsdCents <= 0) {
        totalUsdCents = (totalNpr * 100 / 135).round();
      }
      if (shippingProvider != null) {
        totalUsdCents += (shippingProvider.costUsd * 100).round();
      }

      // Stripe minimum is $0.50 (50 cents). Warn user to increase quantity.
      if (totalUsdCents < 50) {
        final minNpr = (50 / (currency.nprToUsd * 100)).ceil();
        if (mounted) {
          _showMessage(
              context,
              'Stripe requires a minimum of \$0.50 per transaction (≈Rs.$minNpr). '
              'Please increase the quantity of your items and try again.');
        }
        return;
      }

      _showProcessingWarningDialog(context);

      await StripeService.purchaseProducts(
        authToken: authToken,
        productIds: productIds,
        amountInCents: totalUsdCents,
        shippingAddressId: shippingAddress?.id,
        shippingProviderId: shippingProvider?.id,
      );

      if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();
      widget.cart.reset();
      delivery.resetSelection();
      presentOrderSuccessDialog(
        detailMessage:
            'Your order has been placed successfully. We will get back to you soon with order details.',
      );
    } on StripeException catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();
      if (e.error.code != FailureCode.Canceled) {
        _showMessage(context, e.error.localizedMessage ?? 'Payment failed');
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();
      _showMessage(context, 'Payment error: ${e.toString()}');
    }
  }

  void _showProcessingWarningDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      routeSettings: RouteSettings(name: 'ProcessingDialog'),
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade400, Colors.red.shade400],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Processing Order',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Please do not close this window or navigate away while we process your order. This may take a few moments.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Processing...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      child: (_isLoading || _isProcessingOrder)
          ? Container(
              padding: EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey.shade400, Colors.grey.shade500],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    _isProcessingOrder ? 'PLACING ORDER...' : 'PROCESSING...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          : ElevatedButton(
              onPressed: (widget.cart.totalAmount <= 0 ||
                      _isLoading ||
                      _isProcessingOrder)
                  ? null
                  : () async {
                      setState(() => _isLoading = true);

                      final profileOk =
                          await checkAndShowProfileDialog(context);

                      if (profileOk && mounted) {
                        final currency = Provider.of<CurrencyProvider>(context,
                            listen: false);
                        final isDigitalOnly =
                            widget.cart.hasOnlyDigitalProducts;
                        final result = await showCheckoutSheet(
                          context,
                          totalNpr: widget.cart.totalAmount,
                          totalUsdDisplay:
                              currency.formatNprAsUsd(widget.cart.totalAmount),
                          showShippingProvider: !isDigitalOnly,
                          requiresShipping: !isDigitalOnly,
                        );
                        if (result != null && mounted) {
                          await _processOrder(result);
                        }
                      }

                      if (mounted) setState(() => _isLoading = false);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.cart.totalAmount <= 0
                    ? Colors.grey
                    : Theme.of(context).brightness == Brightness.light
                        ? Color(0xff24b7c1)
                        : Colors.amber.shade600,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.cart.totalAmount <= 0
                        ? Icons.shopping_cart_outlined
                        : Icons.shopping_bag_rounded,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    widget.cart.totalAmount <= 0
                        ? 'CART IS EMPTY'
                        : 'PLACE ORDER',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
