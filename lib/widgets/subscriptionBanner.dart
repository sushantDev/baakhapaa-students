import 'package:baakhapaa/screens/subscription/subscription_screen.dart';
import 'package:flutter/material.dart';

class SubscriptionBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonText;
  final String bannerType;
  final List<Color> gradientColors;

  const SubscriptionBanner({
    super.key,
    this.title = 'BAAKHAPAA PREMIUM',
    this.subtitle =
        'Upgrade and get instant level , content, point boost and many more....',
    this.gradientColors = const [Color(0xFFFFE082), Color(0xFFFF7043)],
    this.buttonText = 'Upgrade',
    this.bannerType = '',
  });

  @override
  Widget build(BuildContext context) {
    if (bannerType == 'png') {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: GestureDetector(
          onTap: () => Navigator.pushNamed(
            context,
            SubscriptionScreen.routeName,
          ),
          child: Image.asset(
            'assets/images/ads2.png',
            fit: BoxFit.cover,
            width: double.infinity,
          ),
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.amber.shade600,
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.pushNamed(
              context,
              SubscriptionScreen.routeName,
            ),
            borderRadius: BorderRadius.circular(50),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.normal,
                            fontSize: 14,
                            color: Color(0xFFFFC107),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.normal,
                            fontSize: 10,
                            height: 1.2,
                            letterSpacing: 0,
                            color: null, // Let color fallback if not provided
                          ).copyWith(
                            color: Colors.grey.shade400,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade600,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      buttonText,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }
}
