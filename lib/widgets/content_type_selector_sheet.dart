import 'package:baakhapaa/screens/shop/create/vendor_product_type_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../screens/shorts/create/create_shorts_screen.dart';
import '../screens/create/story/create_story_type_screen.dart';
import '../providers/auth.dart';

class ContentTypeSelectorSheet extends StatelessWidget {
  const ContentTypeSelectorSheet({Key? key}) : super(key: key);

  bool _isEmailVerified(Auth auth) {
    return auth.isEmailVerified;
  }

  void _showEmailVerificationRequired(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Email not verified yet. Please verify your email first.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<Auth>(context, listen: false);
    final bool isCreator = auth.role == 'creator';
    final bool isVendor = auth.role == 'vendor';

    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white30 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'What do you want to create?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Choose the type of content you want to share',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 24),

            // Shorts Option
            if (isCreator) ...[
              _buildContentOption(
                context: context,
                icon: Icons.video_library_rounded,
                title: 'Shorts',
                description: 'Quick video content with quiz',
                gradient: [Color(0xFF667eea), Color(0xFF764ba2)],
                isDark: isDark,
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (!_isEmailVerified(auth)) {
                    _showEmailVerificationRequired(context);
                    return;
                  }
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamed(
                    CreateShortsScreen.routeName,
                  );
                },
              ),

              SizedBox(height: 16),

              // Stories Option
              _buildContentOption(
                context: context,
                icon: Icons.auto_stories_rounded,
                title: 'Stories (Seasons & Episodes)',
                description: 'Long-form series with multiple episodes',
                gradient: [Color(0xFFf093fb), Color(0xFFf5576c)],
                isDark: isDark,
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (!_isEmailVerified(auth)) {
                    _showEmailVerificationRequired(context);
                    return;
                  }
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamed(
                    CreateStoryTypeScreen.routeName,
                  );
                },
              ),
            ],

            if (isVendor) ...[
              _buildContentOption(
                context: context,
                icon: Icons.storefront,
                title: 'Products',
                description: 'Create and manage your products',
                gradient: [Color(0xFFf093fb), Color(0xFFf5576c)],
                isDark: isDark,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    VendorProductTypeScreen.routeName,
                  );
                },
              ),
            ],

            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildContentOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required List<Color> gradient,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  gradient[0].withValues(alpha: 0.15),
                  gradient[1].withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: gradient[0].withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: gradient[0].withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: isDark
                      ? Colors.white.withOpacity(0.4)
                      : Colors.black.withOpacity(0.38),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
