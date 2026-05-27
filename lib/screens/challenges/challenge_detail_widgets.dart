import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/svg.dart';
import 'package:baakhapaa/theme/theme_constants.dart';

// ==================== SEASON CHALLENGE MODELS ====================
class SeasonChallenge {
  final int challengeId;
  final int seasonId;
  final String seasonTitle;
  final String seasonImage;
  final String seasonDescription;
  final int totalEpisodes;
  final int uploadedEpisodes;
  final bool unlocked;
  final bool isCompleted;
  SeasonChallenge({
    required this.challengeId,
    required this.seasonId,
    required this.seasonTitle,
    required this.seasonImage,
    required this.seasonDescription,
    required this.totalEpisodes,
    required this.uploadedEpisodes,
    required this.unlocked,
    required this.isCompleted,
  });
}

class SeasonProgressState {
  final ChallengeStepStatus step1;
  final ChallengeStepStatus step2;
  final ChallengeStepStatus step3;
  SeasonProgressState({
    required this.step1,
    required this.step2,
    required this.step3,
  });
}

class SeasonReport {
  final String seasonImage;
  final String seasonTitle;
  final int totalEpisodes;
  final int uploadedEpisodes;
  final int totalLikes;
  final int rank;
  final bool rewardEarned;
  SeasonReport({
    required this.seasonImage,
    required this.seasonTitle,
    required this.totalEpisodes,
    required this.uploadedEpisodes,
    required this.totalLikes,
    required this.rank,
    required this.rewardEarned,
  });
}

class SeasonLeaderboardItem {
  final int rank;
  final String username;
  final int totalUsersWatched;
  final int totalUsersUnlocked;
  final int totalDonations;
  final int totalPoints;
  SeasonLeaderboardItem({
    required this.rank,
    required this.username,
    required this.totalUsersWatched,
    required this.totalUsersUnlocked,
    required this.totalDonations,
    required this.totalPoints,
  });
}

// ==================== CLEAN UI COMPONENTS ====================

// Points Pill Widget (Red / Gold)
Widget pointsPill(String text, {Color? color, bool showIcon = true}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: color != null
            ? [color, color.withOpacity(0.8)]
            : [const Color(0xFFFFCB0C), const Color(0xFFDC9903)],
      ),
      borderRadius: BorderRadius.circular(28),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showIcon) ...[
          const Image(
            image: AssetImage('assets/images/coins.png'),
            width: 16,
            height: 16,
          ),
          const SizedBox(width: 4),
        ],
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    ),
  );
}

// Badge Row Widget (Matches screenshot)
Widget badgeItemWidget({
  required String imageUrl,
  required String title,
  required bool earned,
  required bool claimed,
  required double progress,
  VoidCallback? onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        Stack(
          children: [
            Container(
              width: 92,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: earned
                      ? const Color(0xFFD4AF37).withOpacity(0.5)
                      : Colors.white24,
                  width: 2,
                ),
                image: imageUrl.isNotEmpty
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: imageUrl.isEmpty ? Colors.grey.shade700 : null,
              ),
              child: imageUrl.isEmpty
                  ? const Icon(Icons.emoji_events, color: Colors.white54)
                  : null,
            ),
            if (claimed)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 10, color: Colors.white),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        // Progress bar
        Container(
          width: 92,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(6),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// Gift/Product Icon Widget
Widget giftIconWidget({
  required String imageUrl,
  required bool unlocked,
  VoidCallback? onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Stack(
      children: [
        Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: unlocked ? Colors.green.withOpacity(0.5) : Colors.white24,
              width: 2,
            ),
            image: imageUrl.isNotEmpty
                ? DecorationImage(
                    image: CachedNetworkImageProvider(imageUrl),
                    fit: BoxFit.cover,
                  )
                : null,
            color: imageUrl.isEmpty ? const Color(0xFF1C1C1C) : null,
          ),
          child: imageUrl.isEmpty
              ? const Icon(Icons.card_giftcard, color: Colors.white54)
              : null,
        ),
        if (unlocked)
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 8, color: Colors.white),
            ),
          ),
      ],
    ),
  );
}

// ==================== CHALLENGE PROGRESS UI COMPONENTS ====================

// Step Status Enum (clean & scalable)
enum ChallengeStepStatus {
  locked,
  active,
  completed,
  waiting,
}

// Single Step Tile (matches pill UI)
class ChallengeStepTile extends StatelessWidget {
  final int step;
  final String title;
  final ChallengeStepStatus status;

  const ChallengeStepTile({
    super.key,
    required this.step,
    required this.title,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case ChallengeStepStatus.completed:
        borderColor = const Color(0xFF3DDC84);
        bgColor = Colors.transparent;
        textColor = const Color(0xFF3DDC84);
        icon = Icons.check_circle;
        break;

      case ChallengeStepStatus.active:
        borderColor = const Color(0xFF3DDC84);
        bgColor = Colors.transparent;
        textColor = Colors.white;
        icon = Icons.radio_button_checked;
        break;

      case ChallengeStepStatus.locked:
      default:
        borderColor = Colors.white12;
        bgColor = Colors.transparent;
        textColor = Colors.white38;
        icon = Icons.lock;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: borderColor, width: 1.2),
        color: bgColor,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 10),
          Text(
            'Step $step',
            style: AppTextStyles.interMedium(
              color: textColor.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.interSemiBold(
                color: textColor,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Challenge Progress Card (the container)
class ChallengeProgressCard extends StatelessWidget {
  final ChallengeStepStatus step1;
  final ChallengeStepStatus step2;
  final ChallengeStepStatus step3;

  final String step2Title;

  final VoidCallback? primaryAction;
  final String primaryButtonText;
  final Color primaryButtonColor;
  final IconData primaryIcon;

  const ChallengeProgressCard({
    super.key,
    required this.step1,
    required this.step2,
    required this.step3,
    this.step2Title = 'Upload your video',
    this.primaryAction,
    required this.primaryButtonText,
    required this.primaryButtonColor,
    required this.primaryIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Challenge Progression',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ChallengeStepTile(
            step: 1,
            title: 'Unlock the Challenge',
            status: step1,
          ),
          ChallengeStepTile(
            step: 2,
            title: step2Title,
            status: step2,
          ),
          ChallengeStepTile(
            step: 3,
            title: 'Result of the challenge',
            status: step3,
          ),
          if (primaryAction != null) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: primaryAction,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: primaryButtonColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(primaryIcon, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      primaryButtonText,
                      style: AppTextStyles.interBold(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Single unlock CTA for challenge detail screens (placed at bottom of scroll).
class ChallengeBottomUnlockButton extends StatelessWidget {
  final Map<String, dynamic>? challenge;
  final VoidCallback? onUnlock;

  const ChallengeBottomUnlockButton({
    super.key,
    required this.challenge,
    this.onUnlock,
  });

  static int unlockPoints(Map<String, dynamic>? data) {
    if (data == null) return 0;
    final dynamic raw = data['unlock_points'] ?? data['coin_to_unlock'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? 0;
    if (raw is num) return raw.toInt();
    return 0;
  }

  static bool isUnlocked(Map<String, dynamic>? data) {
    if (data == null) return false;
    return data['has_unlocked'] == true ||
        data['has_unlocked'] == 1 ||
        data['unlocked'] == true;
  }

  @override
  Widget build(BuildContext context) {
    if (challenge == null || isUnlocked(challenge)) {
      return const SizedBox.shrink();
    }

    final points = unlockPoints(challenge);
    final text = points > 0
        ? 'Unlock Challenge for $points points'
        : 'Unlock Challenge for FREE';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: unlockChallengeButton(onTap: onUnlock, text: text),
    );
  }
}

// ==================== EXISTING UI COMPONENTS ====================

// Premium CTA Button (Gold)
Widget premiumButton({
  VoidCallback? onTap,
  String text = 'Free Unlock with PREMIUM',
  IconData? icon,
}) {
  const LinearGradient _goldGradient = LinearGradient(
    colors: [
      Color.fromARGB(255, 145, 118, 52),
      Color.fromARGB(255, 238, 208, 131),
      Color.fromARGB(255, 226, 185, 83),
      Color.fromARGB(255, 207, 178, 108),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        gradient: _goldGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null)
            Icon(icon, color: Colors.black, size: 20)
          else
            SvgPicture.asset(
              'assets/svgs/Crown.svg',
              width: 20,
              height: 20,
            ),
          const SizedBox(width: 10),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ],
      ),
    ),
  );
}

// Unlock Challenge Button (Red)
Widget unlockChallengeButton({VoidCallback? onTap, required String text}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE50914),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_open, color: Colors.white),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    ),
  );
}

// ==================== END CLEAN UI COMPONENTS ====================
