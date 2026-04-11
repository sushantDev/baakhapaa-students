import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/providers/story.dart';
import 'package:baakhapaa/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AchievementPurchaseDialog extends StatefulWidget {
  final Map<String, dynamic> achievement;
  final VoidCallback onSuccess;

  const AchievementPurchaseDialog({
    Key? key,
    required this.achievement,
    required this.onSuccess,
  }) : super(key: key);

  @override
  State<AchievementPurchaseDialog> createState() =>
      _AchievementPurchaseDialogState();
}

class _AchievementPurchaseDialogState extends State<AchievementPurchaseDialog> {
  bool _isPurchasing = false;
  String? _purchaseError;

  Future<void> _buyAchievement() async {
    if (_isPurchasing) return;

    setState(() {
      _isPurchasing = true;
      _purchaseError = null;
    });

    try {
      final storyProvider = Provider.of<Story>(context, listen: false);
      final authProvider = Provider.of<Auth>(context, listen: false);
      final achievementId = widget.achievement['id'];

      // Step 1: Purchase the achievement
      final result = await storyProvider.buyAchievement(achievementId);

      if (mounted) {
        // Step 2: Immediately claim the purchased achievement
        try {
          await authProvider.claimAchievements(achievementIds: [achievementId]);

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.emoji_events, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Achievement purchased & claimed! Level: ${result['level']}',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // Close dialog and trigger callback
          Navigator.of(context).pop();
          widget.onSuccess();
        } catch (claimError) {
          DebugLogger.error(
              '❌ Failed to claim achievement after purchase: $claimError');

          // Even if claim fails, show purchase was successful
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.emoji_events, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Achievement purchased! Level: ${result['level']} - Please try claiming manually',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );

          if (mounted) {
            setState(() => _isPurchasing = false);
          }
        }
      }
    } catch (error) {
      DebugLogger.error('❌ Failed to buy achievement: $error');

      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _purchaseError = error.toString();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to purchase achievement: ${error.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<Auth>(context, listen: false);
    final baseCost = (widget.achievement['bypass_cost'] ?? 0) as int;
    final currentLevel = (widget.achievement['level'] ?? 1) as int;
    final nextLevel = currentLevel + 1;
    final actualCost = baseCost * nextLevel;
    final hasEnoughCoins = authProvider.userAvailableCoins >= actualCost;
    final claimablePoints =
        (widget.achievement['claimable_points'] ?? 0) as int;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Icon(Icons.emoji_events, color: Colors.amber, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Buy Achievement',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Achievement name
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.achievement['title'] ?? 'Unknown Achievement',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber[800],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    widget.achievement['description'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.amber[700],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),

            // Level info
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Current Level: $currentLevel',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '→ Level $nextLevel',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),

            // Cost breakdown
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Base Cost:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '$baseCost',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.attach_money,
                            size: 14,
                            color: Colors.red[700],
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Level Multiplier:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '× $nextLevel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Cost:',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.attach_money,
                            size: 16,
                            color: Colors.red[700],
                          ),
                          Text(
                            '$actualCost',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),

            // Your balance
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: Colors.amber[800],
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Your Balance: ${authProvider.userAvailableCoins}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.amber[800],
                    ),
                  ),
                ],
              ),
            ),

            // Insufficient coins warning
            if (!hasEnoughCoins) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Insufficient coins. You need ${actualCost - authProvider.userAvailableCoins} more coins.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Claimable points info
            if (claimablePoints > 0) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.card_giftcard, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Claim reward: +$claimablePoints coins',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Error message
            if (_purchaseError != null) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _purchaseError!,
                  style: TextStyle(color: Colors.red[700], fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isPurchasing ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ),
        ElevatedButton(
          onPressed:
              (hasEnoughCoins && !_isPurchasing) ? _buyAchievement : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: _isPurchasing
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'Buy Achievement',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),
      ],
    );
  }
}
