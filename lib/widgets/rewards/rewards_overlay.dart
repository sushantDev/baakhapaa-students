import 'package:flutter/material.dart';
import 'package:baakhapaa/providers/rewards_provider.dart';
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/widgets/rewards/progress_ring_painter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:baakhapaa/models/url.dart';
import 'package:baakhapaa/services/pusher_service.dart';
import 'package:provider/provider.dart';

class RewardsOverlay extends StatelessWidget {
  final VoidCallback onClose;
  final Map<String, dynamic>? notificationData;
  final PusherEventData? pusherEventData;

  const RewardsOverlay({
    Key? key,
    required this.onClose,
    this.notificationData,
    this.pusherEventData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final rewardsProvider = Provider.of<RewardsProvider>(context);
    final screenHeight = MediaQuery.of(context).size.height;

    // Determine notification type from either source
    String? notificationType;
    if (pusherEventData != null) {
      notificationType = pusherEventData!.type;
    } else if (notificationData != null) {
      notificationType = notificationData!['type'];
    }

    // Check notification type
    final isLevelUpgrade = notificationType == 'level_upgraded';
    final isRewardEarned = notificationType == 'reward_earned';
    final isGiftAvailable = notificationType == 'gift_available';
    final isProgressUpdate = notificationType == 'progress_updated';

    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Stack(
          children: [
            // Main popup card positioned at center
            Center(
              child: GestureDetector(
                onTap: () {}, // Prevent closing when tapping the card
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 32),
                  constraints: BoxConstraints(
                    maxHeight: screenHeight * 0.6,
                    maxWidth: 400,
                  ),
                  decoration: BoxDecoration(
                    color: Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.amber.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(context, rewardsProvider),
                        // Show reward earned section for coin notifications
                        if (isRewardEarned) _buildRewardEarnedSection(context),
                        // Show progress update section
                        if (isProgressUpdate)
                          _buildProgressUpdateSection(context),
                        // Show gift available section for gift notifications
                        if (isGiftAvailable)
                          _buildGiftAvailableSection(context),
                        // Show new level section only for level upgrade notifications
                        if (isLevelUpgrade) _buildLevelUpSection(context),
                        _buildHintsSection(),
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, RewardsProvider rewardsProvider) {
    // Get user data from Auth provider
    final authProvider = Provider.of<Auth>(context);
    String? userImageUrl;
    try {
      if (authProvider.image != null && authProvider.image!.isNotEmpty) {
        userImageUrl = authProvider.image!.first['thumbnail'];
      }
    } catch (e) {
      userImageUrl = null;
    }

    // Get pending action from actionDescription
    final pendingAction =
        rewardsProvider.actionDescription ?? 'Complete challenges';

    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile image with progress ring and level below
              Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Progress ring
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CustomPaint(
                          painter: ProgressRingPainter(
                            progress: rewardsProvider.progressPercentage,
                            progressColor: Colors.amber,
                            backgroundColor: Colors.grey.shade800,
                            strokeWidth: 5.0,
                          ),
                        ),
                      ),
                      // User avatar
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: userImageUrl != null && userImageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: "${Url.mediaUrl}/$userImageUrl",
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) => Icon(
                                    Icons.person,
                                    color: Colors.amber,
                                    size: 32,
                                  ),
                                )
                              : Icon(
                                  Icons.person,
                                  color: Colors.amber,
                                  size: 32,
                                ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  // Level name below profile
                  Text(
                    rewardsProvider.levelName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(width: 16),
              // Pending action and horizontal progress bar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            pendingAction,
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon:
                              Icon(Icons.close, color: Colors.white, size: 20),
                          onPressed: onClose,
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    // Horizontal progress bar
                    Container(
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Stack(
                        children: [
                          FractionallySizedBox(
                            widthFactor: rewardsProvider.requiredValue > 0
                                ? rewardsProvider.currentProgress /
                                    rewardsProvider.requiredValue
                                : 0.0,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.amber,
                                    Colors.orange.shade700
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          Center(
                            child: Text(
                              rewardsProvider.requiredValue > 0
                                  ? '${rewardsProvider.currentProgress}/${rewardsProvider.requiredValue}'
                                  : '${rewardsProvider.progressPercentage.toInt()}%',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      rewardsProvider.actionDescription ??
                          'You would get more exposure in\nBaakhapaa community.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.3,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRewardEarnedSection(BuildContext context) {
    // Get data from either Pusher or FCM
    final amount = pusherEventData?.amount ?? notificationData?['amount'] ?? 0;
    final source =
        pusherEventData?.source ?? notificationData?['source'] ?? 'reward';

    String sourceEmoji = '💰';
    String sourceName = source.toString();

    switch (source.toString().toLowerCase()) {
      case 'qna':
      case 'q&a':
        sourceEmoji = '❓';
        sourceName = 'Q&A';
        break;
      case 'ads':
        sourceEmoji = '📺';
        sourceName = 'Watching Ads';
        break;
      case 'product':
        sourceEmoji = '🛍️';
        sourceName = 'Product Interaction';
        break;
      case 'referral':
        sourceEmoji = '👥';
        sourceName = 'Referrals';
        break;
      case 'donation':
        sourceEmoji = '💝';
        sourceName = 'Donation';
        break;
      case 'achievement':
        sourceEmoji = '🏆';
        sourceName = 'Achievement';
        break;
      case 'daily_reward':
        sourceEmoji = '🎁';
        sourceName = 'Daily Reward';
        break;
      case 'challenge':
        sourceEmoji = '🎯';
        sourceName = 'Challenge Complete';
        break;
      case 'order_completed':
        sourceEmoji = '✅';
        sourceName = 'Order Completed';
        break;
      case 'level_up':
        sourceEmoji = '⭐';
        sourceName = 'Level Up';
        break;
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade900.withOpacity(0.5),
            Colors.green.shade700.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Reward icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.green, Colors.green.shade700],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Text(
                sourceEmoji,
                style: TextStyle(fontSize: 40),
              ),
            ),
          ),
          SizedBox(height: 16),
          // Reward amount
          Text(
            '+$amount Coins',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          // Source text
          Text(
            'Earned from $sourceName',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          // Encouragement text
          Text(
            'Keep up the great work!',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          // Continue button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onClose,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Awesome!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressUpdateSection(BuildContext context) {
    final progressType = pusherEventData?.progressType ??
        notificationData?['progress_type'] ??
        'general';
    final progressData = pusherEventData?.progressData ??
        notificationData?['progress_data'] ??
        {};

    String progressEmoji = '📊';
    String progressTitle = 'Progress Update';
    String progressDescription = 'Keep going!';

    // Parse progress data
    final unlocked = progressData['unlocked'];
    final total = progressData['total'];
    final questionsAnswered = progressData['questions_answered'];
    final correct = progressData['correct'];

    switch (progressType.toString().toLowerCase()) {
      case 'achievement':
        progressEmoji = '🏆';
        progressTitle = 'Achievement Progress';
        if (unlocked != null && total != null) {
          progressDescription =
              'You\'ve unlocked $unlocked of $total achievements!';
        }
        break;
      case 'quiz_completion':
        progressEmoji = '📝';
        progressTitle = 'Quiz Progress';
        if (questionsAnswered != null && correct != null) {
          progressDescription =
              'You answered $questionsAnswered questions with $correct correct!';
        }
        break;
      case 'daily_streak':
        progressEmoji = '🔥';
        progressTitle = 'Daily Streak';
        progressDescription = 'Your streak is growing!';
        break;
      case 'challenge':
        progressEmoji = '🎯';
        progressTitle = 'Challenge Progress';
        progressDescription = 'You\'re making great progress!';
        break;
      case 'watching':
        progressEmoji = '📺';
        progressTitle = 'Watching Progress';
        progressDescription = 'Keep watching to unlock more rewards!';
        break;
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.shade900.withOpacity(0.5),
            Colors.deepPurple.shade900.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.purpleAccent.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Progress icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.purple.shade700,
                  Colors.deepPurple.shade700,
                ],
              ),
            ),
            child: Center(
              child: Text(
                progressEmoji,
                style: TextStyle(fontSize: 40),
              ),
            ),
          ),
          SizedBox(height: 16),
          // Progress title
          Text(
            progressTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          // Progress description
          Text(
            progressDescription,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          // Show progress bar if data available
          if (unlocked != null && total != null) ...[
            SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: unlocked / total,
                minHeight: 8,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
              ),
            ),
            SizedBox(height: 8),
            Text(
              '$unlocked / $total',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.purpleAccent,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGiftAvailableSection(BuildContext context) {
    final giftType = pusherEventData?.giftType ??
        notificationData?['gift_type'] ??
        'achievement_unlock';
    final giftData =
        pusherEventData?.giftDetails ?? notificationData?['gift_data'];

    String giftEmoji = '🎁';
    String giftName = 'Gift';
    String giftDescription = 'You have a new gift waiting!';

    switch (giftType.toString().toLowerCase()) {
      case 'achievement_unlock':
        giftEmoji = '🏆';
        giftName = 'Achievement Unlock';
        giftDescription = 'You\'ve unlocked a new achievement!';
        break;
      case 'challenge_reward':
        giftEmoji = '🎯';
        giftName = 'Challenge Reward';
        giftDescription = 'Challenge completed! Collect your reward!';
        break;
      case 'level_reward':
        giftEmoji = '⭐';
        giftName = 'Level Reward';
        giftDescription = 'You\'ve reached a new level!';
        break;
      case 'milestone':
        giftEmoji = '🎯';
        giftName = 'Milestone Reached';
        giftDescription = 'Great progress! Collect your reward!';
        break;
      case 'seasonal':
        giftEmoji = '🎄';
        giftName = 'Seasonal Gift';
        giftDescription = 'Special seasonal reward for you!';
        break;
      case 'bonus':
        giftEmoji = '⭐';
        giftName = 'Bonus Gift';
        giftDescription = 'You earned a bonus reward!';
        break;
      case 'referral_bonus':
        giftEmoji = '👥';
        giftName = 'Referral Bonus';
        giftDescription = 'Someone joined using your referral!';
        break;
      case 'special_offer':
        giftEmoji = '🎉';
        giftName = 'Special Offer';
        giftDescription = 'Exclusive offer just for you!';
        break;
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade900.withOpacity(0.5),
            Colors.cyan.shade900.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Gift icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.blue, Colors.cyan],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Text(
                giftEmoji,
                style: TextStyle(fontSize: 40),
              ),
            ),
          ),
          SizedBox(height: 16),
          // Gift name
          Text(
            giftName,
            style: TextStyle(
              color: Colors.amber,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          // Gift description
          Text(
            giftDescription,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          // Additional info
          if (giftData != null)
            Text(
              'Tap to claim your reward!',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          SizedBox(height: 16),
          // Claim button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onClose,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan,
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Claim Gift',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelUpSection(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.shade900.withOpacity(0.5),
            Colors.deepPurple.shade900.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.purple.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Celebration icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.amber, Colors.orange],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '🎉',
                style: TextStyle(fontSize: 40),
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'New Level Reached!',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Congratulations! You\'ve reached new Level. Please check your new tasks to upgrade further.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onClose,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Awesome!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHintsSection() {
    return Consumer<RewardsProvider>(
      builder: (context, rewardsProvider, _) {
        final hint = rewardsProvider.levelHint;

        // Don't show hints section if no hint available
        if (hint == null || hint.isEmpty) {
          return SizedBox.shrink();
        }

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 20),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade900.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.amber.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Hints',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hint,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.card_giftcard, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Daily Rewards',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.3)),
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timeline, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'My Journey',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
