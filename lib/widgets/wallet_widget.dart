import 'package:flutter/material.dart';

class DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    // Start from bottom left corner
    path.moveTo(0, size.height);
    // Draw to bottom right corner
    path.lineTo(size.width, size.height);
    // Draw to top right corner
    path.lineTo(size.width, 0);
    // Draw diagonal back to bottom left (this creates the hypotenuse)
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class MonetizationWidget extends StatelessWidget {
  final int availableCoins;
  final double nrsPerPoint;
  final VoidCallback? onTap;
  final String? title;
  final String? currency;
  final String? subtitle;
  final Color? color;
  final String? imageAsset;
  final EdgeInsetsGeometry? margin;
  final bool showTotalValue; // << NEW parameter

  const MonetizationWidget({
    Key? key,
    required this.availableCoins,
    required this.nrsPerPoint,
    this.color,
    this.onTap,
    this.title,
    this.currency,
    this.subtitle,
    this.imageAsset,
    this.margin,
    this.showTotalValue = true, // Default to true to preserve existing behavior
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Compute display value based on showTotalValue flag
    final totalValue = (availableCoins * nrsPerPoint).toStringAsFixed(2);
    final displayValue =
        showTotalValue ? totalValue : availableCoins.toString();

    String valueSuffix = '';
    if (showTotalValue) {
      valueSuffix = (currency != null ? ' $currency' : '');
    } else {
      valueSuffix = ' Bpts';
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        margin:
            margin ?? const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey.shade800,
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            // Green diagonal background accent with straight diagonal line
            Positioned(
              right: -10,
              bottom: -15,
              top: -15,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(55),
                ),
                child: ClipPath(
                  clipper: DiagonalClipper(),
                  child: Container(
                    width: 250,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          (color ?? Colors.green).withOpacity(0.7),
                          (color ?? Colors.green).withOpacity(1.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title ??
                              (showTotalValue
                                  ? 'Monetize your points'
                                  : 'Available Points'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!showTotalValue) ...[
                          // For Available Points card: Show points value with orange number and white Bpts
                          Text.rich(
                            TextSpan(
                              text: displayValue,
                              style: TextStyle(
                                color: color ?? Colors.orange,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                              children: [
                                TextSpan(
                                  text: valueSuffix,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Expires at:',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              Text(
                                subtitle ?? 'Never',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          // For Weekly Reward card: Show subtitle and total value
                          if (subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Text(
                                subtitle!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total value:',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text.rich(
                                TextSpan(
                                  text: displayValue,
                                  style: TextStyle(
                                    color: color ?? Colors.green.shade400,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: valueSuffix,
                                      style: TextStyle(
                                        color: color ?? Colors.green.shade400,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Icons on the right
                  Image.asset(
                    imageAsset ?? 'assets/images/walletCoin.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
