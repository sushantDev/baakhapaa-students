import 'package:flutter/material.dart';
import '../utils/subscription_utils.dart';

/// Premium subscription badge widget that shows a tick mark on profile pictures
class PremiumBadge extends StatefulWidget {
  final Map<String, dynamic> userData;
  final double size;
  final bool showCountdownOnTap;
  final VoidCallback? onTap;

  const PremiumBadge({
    Key? key,
    required this.userData,
    this.size = 24.0,
    this.showCountdownOnTap = false,
    this.onTap,
  }) : super(key: key);

  @override
  State<PremiumBadge> createState() => _PremiumBadgeState();
}

class _PremiumBadgeState extends State<PremiumBadge>
    with TickerProviderStateMixin {
  bool _showCountdown = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.showCountdownOnTap && !_showCountdown) {
      setState(() {
        _showCountdown = true;
      });
      _animationController.forward(from: 0.0);

      // Auto-hide after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _showCountdown = false;
          });
        }
      });
    }

    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!SubscriptionUtils.hasActiveSubscription(widget.userData)) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 0,
      left: 0,
      child: GestureDetector(
        onTap: _handleTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background circle
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFD700), // Gold color
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            // Tick image
            Image.asset(
              'assets/images/tick.png',
              width: widget.size * 0.6,
              height: widget.size * 0.6,
              fit: BoxFit.contain,
            ),
            // Countdown overlay
            if (_showCountdown && widget.showCountdownOnTap)
              AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: _buildCountdownWidget(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownWidget() {
    final remainingTime = SubscriptionUtils.getRemainingTime(widget.userData);
    final formattedTime = SubscriptionUtils.formatRemainingTime(remainingTime);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(top: 30),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFFD700),
          width: 1,
        ),
      ),
      child: Text(
        'Expires in: $formattedTime',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Simple premium badge without countdown functionality
class SimplePremiumBadge extends StatelessWidget {
  final Map<String, dynamic> userData;
  final double size;

  const SimplePremiumBadge({
    Key? key,
    required this.userData,
    this.size = 20.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!SubscriptionUtils.hasActiveSubscription(userData)) {
      return const SizedBox.shrink();
    }

    return Image.asset(
      'assets/images/tick.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
