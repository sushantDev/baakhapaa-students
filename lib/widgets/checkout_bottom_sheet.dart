import 'dart:io';

import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/shipping.dart';
import '../providers/auth.dart';
import '../providers/delivery_provider.dart';
import '../screens/shop/shipping_address_screen.dart';

/// Result returned after the user completes (or cancels) the checkout sheet.
class CheckoutResult {
  final String paymentMethod; // 'khalti' | 'cod' | 'stripe' | 'apple_iap'
  final ShippingAddress? shippingAddress;
  final ShippingProvider? shippingProvider; // only relevant for Stripe

  const CheckoutResult({
    required this.paymentMethod,
    this.shippingAddress,
    this.shippingProvider,
  });
}

/// Opens the premium multi-step checkout bottom sheet.
/// Returns [CheckoutResult] on success or null if cancelled.
Future<CheckoutResult?> showCheckoutSheet(
  BuildContext context, {
  required double totalNpr,
  required String totalUsdDisplay, // e.g. "$17.85"
  bool showShippingProvider = true, // false for subscriptions
  bool requiresShipping = true, // false for digital products
  bool allowAppleIap = false,
}) {
  return showModalBottomSheet<CheckoutResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CheckoutSheet(
      totalNpr: totalNpr,
      totalUsdDisplay: totalUsdDisplay,
      showShippingProvider: showShippingProvider,
      requiresShipping: requiresShipping,
      allowAppleIap: allowAppleIap,
    ),
  );
}

// ─── Internal sheet widget ────────────────────────────────────────────────────

class _CheckoutSheet extends StatefulWidget {
  final double totalNpr;
  final String totalUsdDisplay;
  final bool showShippingProvider;
  final bool requiresShipping;
  final bool allowAppleIap;

  const _CheckoutSheet({
    required this.totalNpr,
    required this.totalUsdDisplay,
    required this.showShippingProvider,
    this.requiresShipping = true,
    this.allowAppleIap = false,
  });

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet>
    with SingleTickerProviderStateMixin {
  // ── Stepper state ────────────────────────────────────────────────────────
  int _step = 0; // 0 = payment, 1 = shipping
  String? _selectedPayment; // 'khalti' | 'cod' | 'stripe' | 'apple_iap'
  ShippingAddress? _selectedAddress;
  ShippingProvider? _selectedProvider;

  late final AnimationController _anim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnim = CurvedAnimation(parent: _anim, curve: Curves.easeInOut);
    _anim.forward();

    // Pre-fetch addresses
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DeliveryProvider>(context, listen: false).fetchAddresses();
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    _anim.reverse().then((_) {
      setState(() => _step = step);
      _anim.forward();
    });
  }

  bool get _canProceedFromPayment => _selectedPayment != null;

  bool get _isNepalCustomer {
    final auth = Provider.of<Auth>(context, listen: false);
    final country =
        (auth.user['country'] ?? '').toString().trim().toLowerCase();
    final countryCode =
        (auth.user['country_code'] ?? '').toString().trim().toLowerCase();
    return country == 'nepal' || countryCode == 'np';
  }

  bool get _showKhaltiOption {
    if (Platform.isAndroid) return false;
    if (widget.allowAppleIap) return false;
    return _isNepalCustomer;
  }

  bool get _showStripeOption {
    if (Platform.isAndroid) return true;
    if (Platform.isIOS) return !_isNepalCustomer && !widget.allowAppleIap;
    return true;
  }

  bool get _showAppleIapOption {
    if (!Platform.isIOS) return false;
    return widget.allowAppleIap;
  }

  bool get _showCodOption {
    return widget.requiresShipping && !widget.allowAppleIap;
  }

  bool get _canConfirm {
    // Digital products don't need shipping address
    if (!widget.requiresShipping) return _selectedPayment != null;
    if (_selectedAddress == null) return false;
    if (widget.showShippingProvider &&
        _selectedPayment == 'stripe' &&
        _selectedProvider == null) return false;
    return true;
  }

  void _confirm() {
    if (!_canConfirm) return;
    Navigator.of(context).pop(CheckoutResult(
      paymentMethod: _selectedPayment!,
      shippingAddress: _selectedAddress,
      shippingProvider: _selectedProvider,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F1117) : Colors.white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(isDark),
          _buildHeader(isDark),
          _buildStepIndicator(isDark),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 4,
              ),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _step == 0
                    ? _buildPaymentStep(isDark)
                    : _buildShippingStep(isDark),
              ),
            ),
          ),
          _buildActionBar(isDark),
        ],
      ),
    );
  }

  // ── Handle ────────────────────────────────────────────────────────────────

  Widget _buildHandle(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Center(
        child: Container(
          width: 44,
          height: 4,
          decoration: BoxDecoration(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.shopping_bag_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Checkout',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  'Rs. ${widget.totalNpr.toStringAsFixed(2)}  (≈ ${widget.totalUsdDisplay})',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded,
                color: isDark ? Colors.white38 : Colors.grey.shade500),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // ── Step indicator ────────────────────────────────────────────────────────

  Widget _buildStepIndicator(bool isDark) {
    // For digital products, only show the payment step
    if (!widget.requiresShipping) return const SizedBox.shrink();

    final steps = ['Payment Method', 'Shipping Address'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Connector line
            final done = _step > i ~/ 2;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 2,
                color: done
                    ? const Color(0xFF6366F1)
                    : (isDark ? Colors.white12 : Colors.grey.shade200),
              ),
            );
          }

          final idx = i ~/ 2;
          final isCurrent = idx == _step;
          final isDone = idx < _step;

          return GestureDetector(
            onTap: isDone ? () => _goToStep(idx) : null,
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrent
                        ? const Color(0xFF6366F1)
                        : isDone
                            ? const Color(0xFF6366F1).withOpacity(0.15)
                            : (isDark ? Colors.white10 : Colors.grey.shade100),
                    border: Border.all(
                      color: isCurrent || isDone
                          ? const Color(0xFF6366F1)
                          : (isDark ? Colors.white24 : Colors.grey.shade300),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check_rounded,
                            color: Color(0xFF6366F1), size: 14)
                        : Text(
                            '${idx + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isCurrent
                                  ? Colors.white
                                  : (isDark
                                      ? Colors.white38
                                      : Colors.grey.shade500),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  steps[idx],
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                    color: isCurrent
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.white38 : Colors.grey.shade500),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── Step 0: Payment Method ────────────────────────────────────────────────

  Widget _buildPaymentStep(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Choose how you\'d like to pay', isDark),
          const SizedBox(height: 16),
          if (_showKhaltiOption)
            _paymentOption(
              value: 'khalti',
              title: 'Digital Wallet',
              subtitle: 'Pay securely with Khalti',
              icon: Icons.account_balance_wallet_rounded,
              color: const Color(0xFF7C3AED),
              imagePath: 'assets/images/logo-khalti.png',
              isDark: isDark,
            ),
          if (_showKhaltiOption) const SizedBox(height: 12),
          if (_showCodOption)
            _paymentOption(
              value: 'cod',
              title: 'Cash on Delivery',
              subtitle: 'Pay when your order arrives',
              icon: Icons.local_shipping_rounded,
              color: const Color(0xFF059669),
              imagePath: 'assets/images/cod.png',
              isDark: isDark,
            ),
          if (_showCodOption) const SizedBox(height: 12),
          if (_showStripeOption) const SizedBox(height: 12),
          if (_showStripeOption)
            _paymentOption(
              value: 'stripe',
              title: 'Credit / Debit Card',
              subtitle: 'Visa, Mastercard — charged in USD',
              icon: Icons.credit_card_rounded,
              color: const Color(0xFF635BFF),
              isDark: isDark,
            ),
          if (_showAppleIapOption) const SizedBox(height: 12),
          if (_showAppleIapOption)
            _paymentOption(
              value: 'apple_iap',
              title: 'Apple In-App Purchase',
              subtitle: 'Complete this digital purchase through the App Store',
              icon: Icons.apple_rounded,
              color: isDark ? Colors.white : Colors.black,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  Widget _paymentOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    String? imagePath,
    required bool isDark,
  }) {
    final selected = _selectedPayment == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedPayment = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(isDark ? 0.15 : 0.07)
              : (isDark ? const Color(0xFF1A1C23) : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? color
                : (isDark ? Colors.white12 : Colors.grey.shade200),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            _paymentIcon(
                icon: icon, color: color, imagePath: imagePath, isDark: isDark),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? color
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? color : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? color
                      : (isDark ? Colors.white24 : Colors.grey.shade400),
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 13)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentIcon({
    required IconData icon,
    required Color color,
    String? imagePath,
    required bool isDark,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: imagePath != null
          ? Padding(
              padding: const EdgeInsets.all(8),
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    Icon(icon, color: color, size: 24),
              ),
            )
          : Icon(icon, color: color, size: 24),
    );
  }

  // ── Step 1: Shipping Address ──────────────────────────────────────────────

  Widget _buildShippingStep(bool isDark) {
    return Consumer<DeliveryProvider>(
      builder: (ctx, delivery, _) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Where should we deliver?', isDark),
              const SizedBox(height: 16),

              // Loading indicator
              if (delivery.isLoadingAddresses && delivery.addresses.isEmpty)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ))

              // Address list
              else if (delivery.addresses.isNotEmpty) ...[
                ...delivery.addresses.map((addr) {
                  final isSelected = _selectedAddress?.id == addr.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _addressTile(addr, isSelected, isDark, delivery),
                  );
                }),
              ]

              // Empty state
              else
                _emptyAddressState(isDark),

              const SizedBox(height: 8),

              // Add new address button
              OutlinedButton.icon(
                onPressed: () async {
                  final addr =
                      await Navigator.of(context).push<ShippingAddress>(
                    MaterialPageRoute(
                        builder: (_) => const ShippingAddressScreen()),
                  );
                  if (addr != null && mounted) {
                    setState(() => _selectedAddress = addr);
                    delivery.selectAddress(addr);
                  }
                },
                icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                label: const Text('Add New Address'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(
                    color: isDark ? Colors.white24 : const Color(0xFF6366F1),
                  ),
                  foregroundColor: const Color(0xFF6366F1),
                ),
              ),

              // Shipping provider picker (Stripe only, if enabled)
              if (widget.showShippingProvider &&
                  _selectedPayment == 'stripe' &&
                  _selectedAddress != null) ...[
                const SizedBox(height: 20),
                _buildShippingProviderSection(delivery, isDark),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _addressTile(ShippingAddress addr, bool isSelected, bool isDark,
      DeliveryProvider delivery) {
    return GestureDetector(
      onTap: () {
        setState(() => _selectedAddress = addr);
        delivery.selectAddress(addr);
        if (widget.showShippingProvider && _selectedPayment == 'stripe') {
          setState(() => _selectedProvider = null);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1).withOpacity(isDark ? 0.15 : 0.06)
              : (isDark ? const Color(0xFF1A1C23) : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6366F1)
                : (isDark ? Colors.white12 : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Radio dot
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF6366F1)
                      : (isDark ? Colors.white38 : Colors.grey.shade400),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 12)
                  : null,
            ),
            const SizedBox(width: 12),

            // Address details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        addr.recipientName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (addr.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Default',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6366F1),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    addr.phone,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    addr.formattedAddress,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.5,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyAddressState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1C23) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.location_off_outlined,
              size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No shipping address yet',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add an address to continue checkout.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShippingProviderSection(DeliveryProvider delivery, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Shipping Method', isDark),
        const SizedBox(height: 12),
        if (delivery.isLoadingProviders)
          const Center(
              child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ))
        else if (delivery.availableProviders.isEmpty)
          Text(
            'No shipping options available for this destination.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          )
        else
          ...delivery.availableProviders.map((p) {
            final isSelected = _selectedProvider?.id == p.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedProvider = p);
                  delivery.selectProvider(p);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF635BFF)
                            .withOpacity(isDark ? 0.15 : 0.06)
                        : (isDark
                            ? const Color(0xFF1A1C23)
                            : Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF635BFF)
                          : (isDark ? Colors.white12 : Colors.grey.shade200),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? const Color(0xFF635BFF)
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF635BFF)
                                : (isDark
                                    ? Colors.white38
                                    : Colors.grey.shade400),
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 12)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              p.estimatedDelivery.isNotEmpty
                                  ? p.estimatedDelivery
                                  : '${p.estimatedDaysMin}–${p.estimatedDaysMax} business days',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white38
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '\$${p.costUsd.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF635BFF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  // ── Action bar ────────────────────────────────────────────────────────────

  Widget _buildActionBar(bool isDark) {
    final isLastStep = _step == 1 || !widget.requiresShipping;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1117) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade100,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Back / Cancel button
            if (_step > 0)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _goToStep(_step - 1),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(
                        color: isDark ? Colors.white24 : Colors.grey.shade300),
                    foregroundColor:
                        isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              )
            else
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(
                        color: isDark ? Colors.white24 : Colors.grey.shade300),
                    foregroundColor:
                        isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                  child: const Text('Cancel'),
                ),
              ),

            const SizedBox(width: 12),

            // Next / Confirm button
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: isLastStep
                    ? (_canConfirm ? _confirm : null)
                    : (_canProceedFromPayment ? () => _goToStep(1) : null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  disabledBackgroundColor:
                      isDark ? Colors.white12 : Colors.grey.shade200,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isLastStep
                          ? Icons.check_circle_rounded
                          : Icons.arrow_forward_rounded,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isLastStep ? 'Confirm Order' : 'Next',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, bool isDark) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white54 : Colors.grey.shade600,
        letterSpacing: 0.3,
      ),
    );
  }
}
