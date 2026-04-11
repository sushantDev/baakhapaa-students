import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/models/subscription.dart';
import 'level_models.dart';
import 'level_card.dart';
import 'level_connector_painter.dart';

class LevelTimelineItem extends StatelessWidget {
  final LevelData level;
  final bool isFirst;
  final bool isLast;
  final Color railColor;
  final Color connectorColor;
  final bool isAlternateLeft;
  final int index;

  final bool isAboveCompleted;
  final bool isBelowCompleted;

  final UserBenefitUsage? unlockAchievementBenefit;
  final bool isUnlockingAchievement;
  final Function(int) onUnlockAchievement;

  const LevelTimelineItem({
    Key? key,
    required this.level,
    required this.isFirst,
    required this.isLast,
    required this.railColor,
    required this.connectorColor,
    required this.isAlternateLeft,
    required this.index,
    required this.isAboveCompleted,
    required this.isBelowCompleted,
    this.unlockAchievementBenefit,
    this.isUnlockingAchievement = false,
    required this.onUnlockAchievement,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isCurrent = level.isCurrent;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left side progress bar with avatar (width fixed at 58)
              SizedBox(
                width: 58,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Vertical progress rail
                    if (isCurrent) ...[
                      // Split rail for current level: gray above, orange below
                      Positioned(
                        left: 11,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 10,
                          color: const Color(0xFF3A3A3A),
                        ),
                      ),
                      Positioned(
                        left: 11,
                        top: 80,
                        bottom: 0,
                        child: Container(
                          width: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9F1C),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF9F1C).withOpacity(0.4),
                                blurRadius: 10,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else
                      // Single color rail for other levels
                      Positioned(
                        left: 11,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 10,
                          decoration: BoxDecoration(
                            color: railColor,
                            borderRadius: isFirst
                                ? const BorderRadius.only(
                                    topLeft: Radius.circular(3),
                                    topRight: Radius.circular(3),
                                  )
                                : null,
                            boxShadow: (railColor.value ==
                                    const Color(0xFFFF9F1C).value)
                                ? [
                                    BoxShadow(
                                      color: railColor.withOpacity(0.4),
                                      blurRadius: 10,
                                      spreadRadius: 0,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    // User avatar (only for current level)
                    if (isCurrent)
                      Positioned(
                        top: 70.0,
                        left: 0,
                        child: Consumer<Auth>(
                          builder: (context, auth, child) {
                            String imageUrl =
                                'https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg';

                            if (auth.image != null && auth.image!.isNotEmpty) {
                              imageUrl =
                                  auth.image!.first['thumbnail'] ?? imageUrl;
                            }

                            return Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black,
                                border: Border.all(
                                  color: const Color(0xFFFF9F1C),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF9F1C)
                                        .withOpacity(0.5),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                backgroundColor: Colors.black,
                                child: ClipOval(
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    width: 26,
                                    height: 26,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 18,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              // Right side cards with snake pattern
              Expanded(
                child: Stack(
                  children: [
                    // Main card area background lines
                    _buildSnakePatternCards(context),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Connector gap to next item or bottom section
        Row(
          children: [
            SizedBox(
              width: 58,
              height: 160, // Increased height
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(left: 11),
                  width: 10,
                  height: 160,
                  decoration: BoxDecoration(
                    color: connectorColor,
                    boxShadow:
                        (connectorColor.value == const Color(0xFFFF9F1C).value)
                            ? [
                                BoxShadow(
                                  color: connectorColor.withOpacity(0.4),
                                  blurRadius: 10,
                                  spreadRadius: 0,
                                ),
                              ]
                            : null,
                  ),
                ),
              ),
            ),
            Expanded(
              child: SizedBox(
                height: 160,
                child: CustomPaint(
                  painter: LevelConnectorPainter(
                    isCompleted: (level.isCompleted || level.isCurrent) &&
                        (isLast || isBelowCompleted),
                    isFirst: isFirst,
                    isLast: isLast,
                    isAlternateLeft: isAlternateLeft,
                    nextAlternateLeft: (index + 1) % 2 == 0,
                    isCurrent: level.isCurrent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSnakePatternCards(BuildContext context) {
    final bool isCurrent = level.isCurrent;
    final bool isCompleted = level.isCompleted;
    final bool isLocked = !isCompleted && !isCurrent;
    final bool cardOnLeft = isCompleted && isAlternateLeft;

    if (isCurrent) {
      // Current level: center the card with a vibrant glow effect
      return Align(
        alignment: Alignment.center,
        child: FractionallySizedBox(
          widthFactor: 0.95,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF9F1C).withOpacity(0.4),
                  blurRadius: 25,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: const Color(0xFFFF9F1C).withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: LevelCard(
              level: level,
              unlockAchievementBenefit: unlockAchievementBenefit,
              isUnlockingAchievement: isUnlockingAchievement,
              onUnlockAchievement: onUnlockAchievement,
            ),
          ),
        ),
      );
    }

    if (isLocked) {
      // Locked levels: center the card without glow
      return Align(
        alignment: Alignment.center,
        child: FractionallySizedBox(
          widthFactor: 0.95,
          child: LevelCard(
            level: level,
            unlockAchievementBenefit: unlockAchievementBenefit,
            isUnlockingAchievement: isUnlockingAchievement,
            onUnlockAchievement: onUnlockAchievement,
          ),
        ),
      );
    }

    // Snake pattern: alternate left-right for completed cards only
    if (cardOnLeft)
      return Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: 0.85,
          child: LevelCard(
            level: level,
            unlockAchievementBenefit: unlockAchievementBenefit,
            isUnlockingAchievement: isUnlockingAchievement,
            onUnlockAchievement: onUnlockAchievement,
          ),
        ),
      );
    else
      return Align(
        alignment: Alignment.centerRight,
        child: FractionallySizedBox(
          widthFactor: 0.85,
          child: LevelCard(
            level: level,
            unlockAchievementBenefit: unlockAchievementBenefit,
            isUnlockingAchievement: isUnlockingAchievement,
            onUnlockAchievement: onUnlockAchievement,
          ),
        ),
      );
  }
}
