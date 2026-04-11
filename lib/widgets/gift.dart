import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/gift/single_gift_screen.dart';
import '../providers/auth.dart';
import '../utils/guest_auth_helper.dart';
import '../../../utils/debug_logger.dart';

class Gift extends StatelessWidget {
  final List<dynamic> _gifts;

  Gift(this._gifts);

  @override
  Widget build(BuildContext context) {
    if (_gifts.isEmpty) {
      return Container(
        padding: EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.card_giftcard_rounded,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No gifts available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Check back later for amazing rewards',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: _gifts.length,
      itemBuilder: (context, index) {
        return GiftItem(_gifts[index]);
      },
    );
  }
}

class GiftItem extends StatelessWidget {
  final Map<String, dynamic> _item;

  GiftItem(this._item);

  String get productImageUrl {
    try {
      final images = _item['images'];
      if (images == null || images is! List || images.isEmpty) {
        return 'https://baakhapaa.com/images/logo.png';
      }

      final firstImage = images[0];
      if (firstImage == null) {
        return 'https://baakhapaa.com/images/logo.png';
      }

      // Handle different image formats from API
      String? imagePath;

      if (firstImage is Map) {
        // Try 'full' field first, then 'url'
        imagePath =
            firstImage['full']?.toString() ?? firstImage['url']?.toString();
      } else if (firstImage is String) {
        imagePath = firstImage;
      }

      if (imagePath == null || imagePath.isEmpty) {
        return 'https://baakhapaa.com/images/logo.png';
      }

      // If already a full URL, return as-is
      if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
        return imagePath;
      }

      // Normalize the path - remove duplicate 'storage/' prefixes
      var normalizedPath = imagePath.trim();
      normalizedPath = normalizedPath.replaceFirst(RegExp(r'^/+'), '');
      normalizedPath = normalizedPath.replaceFirst(
          RegExp(r'^(storage/storage/)+'), 'storage/');
      normalizedPath = normalizedPath.replaceFirst(RegExp(r'^storage/'), '');

      return 'https://app.baakhapaa.com/storage/storage/$normalizedPath';
    } catch (e) {
      DebugLogger.info('Error parsing gift image URL: $e');
      return 'https://baakhapaa.com/images/logo.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final rewardPoints = _item['coin'] ?? 0;

    return InkWell(
      onTap: () {
        // Check if user is guest before navigating
        final auth = Provider.of<Auth>(context, listen: false);
        if (auth.isGuest) {
          GuestAuthHelper.showGuestLoginDialog(context, 'view gift details');
          return;
        }

        Navigator.of(context).pushNamed(
          SingleGiftScreen.routeName,
          arguments: _item['id'],
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Color(0xFFFFF9E6), // Light yellow/cream
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.15),
              blurRadius: 15,
              spreadRadius: 0,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Full Image Background
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CachedNetworkImage(
                imageUrl: productImageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white,
                        Color(0xFFFFF9E6),
                      ],
                    ),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white,
                        Color(0xFFFFF9E6),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.card_giftcard_rounded,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                  ),
                ),
              ),
            ),

            // Gradient overlay at bottom for text readability
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.4),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
              ),
            ),

            // Points Chip (Top Right)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color.fromARGB(255, 251, 218, 121),
                      Colors.amber.shade600,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/coins.png',
                      width: 14,
                      height: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '$rewardPoints points',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content at Bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Gift Title
                    Text(
                      _item['title'].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),

                    // Redeem Now Button
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color.fromARGB(255, 251, 218, 121),
                            Colors.amber.shade600,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Redeem',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
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
}
