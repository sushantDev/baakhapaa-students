import 'package:flutter/material.dart';
import 'package:bubble/bubble.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:baakhapaa/deep_link_handler.dart';
import '../utils/debug_logger.dart';

// Helper methods to determine content type and get appropriate icons/text
enum BaakhapaaContentType { shorts, episode, product, gift }

class ContentDimensions {
  final double width;
  final double height;

  const ContentDimensions({
    required this.width,
    required this.height,
  });
}

class MessagesBubble extends StatelessWidget {
  final types.TextMessage message;
  final types.User currentUser;
  final bool nextMessageInGroup;

  const MessagesBubble({
    Key? key,
    required this.message,
    required this.currentUser,
    required this.nextMessageInGroup,
  }) : super(key: key);

  void _handleBaakhapaaLink(BuildContext context, String message) async {
    try {
      var url = message.split(' ')[2];
      if (url == 'Gift') url = message.split(' ')[3];
      DeepLinkHandler.handleDeepLink(Uri.parse(url));
    } catch (e) {
      DebugLogger.error('Error launching URL: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error opening the link'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildContentBubble(BuildContext context, types.TextMessage message) {
    final contentType = _getContentType(message.text);

    // Get dimensions based on content type
    final dimensions = _getContentDimensions(contentType);

    return Bubble(
      child: InkWell(
        onTap: () => _handleBaakhapaaLink(context, message.text),
        child: Container(
          width: dimensions.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: dimensions.height,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(
                        'https://picsum.photos/${dimensions.width.toInt()}/${dimensions.height.toInt()}?random=${message.id}'),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(11),
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(11),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      _getContentIcon(contentType),
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: currentUser.id != message.author.id
                      ? Colors.white
                      : const Color(0xff6f61e8),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(11),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getContentTypeIcon(contentType),
                          size: 16,
                          color: currentUser.id != message.author.id
                              ? Colors.black87
                              : Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getContentTitle(contentType),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: currentUser.id != message.author.id
                                ? Colors.black87
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getContentDescription(contentType),
                      style: TextStyle(
                        fontSize: 12,
                        color: currentUser.id != message.author.id
                            ? Colors.grey[600]
                            : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      color: Colors.transparent,
      margin: nextMessageInGroup
          ? const BubbleEdges.symmetric(horizontal: 6)
          : null,
      nip: nextMessageInGroup
          ? BubbleNip.no
          : currentUser.id != message.author.id
              ? BubbleNip.leftBottom
              : BubbleNip.rightBottom,
    );
  }

  BaakhapaaContentType _getContentType(String url) {
    if (url.contains('/shorts/')) return BaakhapaaContentType.shorts;
    if (url.contains('/episode/')) return BaakhapaaContentType.episode;
    if (url.contains('/product/')) return BaakhapaaContentType.product;
    if (url.contains('/gift/')) return BaakhapaaContentType.gift;
    return BaakhapaaContentType.shorts; // default
  }

  IconData _getContentIcon(BaakhapaaContentType type) {
    switch (type) {
      case BaakhapaaContentType.shorts:
        return Icons.play_circle_fill_rounded;
      case BaakhapaaContentType.episode:
        return Icons.movie_outlined;
      case BaakhapaaContentType.product:
        return Icons.shopping_bag_outlined;
      case BaakhapaaContentType.gift:
        return Icons.card_giftcard;
    }
  }

  IconData _getContentTypeIcon(BaakhapaaContentType type) {
    switch (type) {
      case BaakhapaaContentType.shorts:
        return Icons.video_library_rounded;
      case BaakhapaaContentType.episode:
        return Icons.movie;
      case BaakhapaaContentType.product:
        return Icons.shopping_cart;
      case BaakhapaaContentType.gift:
        return Icons.redeem;
    }
  }

  String _getContentTitle(BaakhapaaContentType type) {
    switch (type) {
      case BaakhapaaContentType.shorts:
        return 'Baakhapaa Shorts';
      case BaakhapaaContentType.episode:
        return 'Baakhapaa Episode';
      case BaakhapaaContentType.product:
        return 'Baakhapaa Store';
      case BaakhapaaContentType.gift:
        return 'Baakhapaa Gifts';
    }
  }

  String _getContentDescription(BaakhapaaContentType type) {
    switch (type) {
      case BaakhapaaContentType.shorts:
        return 'Tap to watch video';
      case BaakhapaaContentType.episode:
        return 'Tap to watch episode';
      case BaakhapaaContentType.product:
        return 'Tap to view product';
      case BaakhapaaContentType.gift:
        return 'Tap to view gift';
    }
  }

  ContentDimensions _getContentDimensions(BaakhapaaContentType type) {
    switch (type) {
      case BaakhapaaContentType.shorts:
        return const ContentDimensions(width: 200, height: 300);
      case BaakhapaaContentType.episode:
        return const ContentDimensions(width: 400, height: 200);
      case BaakhapaaContentType.product:
        return const ContentDimensions(width: 300, height: 300);
      case BaakhapaaContentType.gift:
        return const ContentDimensions(width: 300, height: 300);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildContentBubble(context, message);
  }
}
