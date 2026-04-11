import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Base shimmer wrapper — wraps any child with the blinking shimmer effect.
class ShimmerLoading extends StatelessWidget {
  final Widget child;
  final bool isLoading;

  const ShimmerLoading({
    Key? key,
    required this.child,
    this.isLoading = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return child;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Color(0xFF2A2A2A) : Colors.grey[300]!,
      highlightColor: isDark ? Color(0xFF3D3D3D) : Colors.grey[100]!,
      child: child,
    );
  }
}

/// A single rounded rectangle placeholder box.
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    Key? key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// A circular placeholder (for avatars).
class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({Key? key, required this.size}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Composite skeleton widgets for specific sections
// ─────────────────────────────────────────────

/// Full-screen loading skeleton — generic layout for screens
/// that don't have a specific skeleton. Shows a card + list pattern
/// that works as a neutral placeholder for most content screens.
class FullScreenSkeleton extends StatelessWidget {
  const FullScreenSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header area
            ShimmerLoading(
              child: Row(
                children: [
                  SkeletonCircle(size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 140, height: 16, borderRadius: 4),
                        const SizedBox(height: 6),
                        SkeletonBox(width: 100, height: 12, borderRadius: 4),
                      ],
                    ),
                  ),
                  SkeletonBox(width: 80, height: 32, borderRadius: 16),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Featured card
            ShimmerLoading(
              child: SkeletonBox(
                  width: double.infinity, height: 180, borderRadius: 16),
            ),
            const SizedBox(height: 20),
            // Section header
            ShimmerLoading(
              child: SkeletonBox(width: 120, height: 16, borderRadius: 4),
            ),
            const SizedBox(height: 12),
            // List items
            ShimmerLoading(
              child: Column(
                children: List.generate(
                    4,
                    (_) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              SkeletonBox(
                                  width: 80, height: 60, borderRadius: 12),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SkeletonBox(
                                        width: double.infinity,
                                        height: 14,
                                        borderRadius: 4),
                                    const SizedBox(height: 6),
                                    SkeletonBox(
                                        width: 150,
                                        height: 12,
                                        borderRadius: 4),
                                    const SizedBox(height: 4),
                                    SkeletonBox(
                                        width: 80, height: 10, borderRadius: 4),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
              ),
            ),
            const SizedBox(height: 16),
            // Another section
            ShimmerLoading(
              child: SkeletonBox(width: 100, height: 16, borderRadius: 4),
            ),
            const SizedBox(height: 12),
            // Horizontal cards
            ShimmerLoading(
              child: SizedBox(
                height: 120,
                child: Row(
                  children: List.generate(
                      3,
                      (_) => Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: SkeletonBox(
                                width: 100, height: 120, borderRadius: 12),
                          )),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for a single featured story card (the big horizontal card).
class StoryCardSkeleton extends StatelessWidget {
  const StoryCardSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardWidth = MediaQuery.of(context).size.width - 20;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerLoading(
      child: Container(
        width: cardWidth,
        height: 380,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [Color(0xFF2A2A2A), Color(0xFF1E1E1E)]
                : [Colors.white, Colors.grey.shade50],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: 0,
              offset: Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SkeletonBox(width: (cardWidth - 16) * 0.6, height: 16),
            ),
            const SizedBox(height: 8),
            // Bottom action row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SkeletonBox(width: 70, height: 28, borderRadius: 14),
                  const SizedBox(width: 8),
                  SkeletonBox(width: 70, height: 28, borderRadius: 14),
                  const SizedBox(width: 8),
                  SkeletonBox(width: 70, height: 28, borderRadius: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for the storytellers horizontal row (circular avatars).
class StorytellersSkeleton extends StatelessWidget {
  final int count;
  const StorytellersSkeleton({Key? key, this.count = 6}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final avatarSize = (screenWidth - 44) / 5.5 - 3;

    return ShimmerLoading(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              children: [
                SkeletonBox(width: 100, height: 16),
                Spacer(),
                SkeletonBox(width: 60, height: 12),
              ],
            ),
            const SizedBox(height: 12),
            // Avatar row
            SizedBox(
              height: avatarSize + 4,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: NeverScrollableScrollPhysics(),
                itemCount: count,
                itemBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: SkeletonCircle(size: avatarSize),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for a horizontal season row (e.g., Continue Watching, My List, Suggested, etc.).
class SeasonRowSkeleton extends StatelessWidget {
  final int count;
  const SeasonRowSkeleton({Key? key, this.count = 4}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              children: [
                SkeletonBox(width: 140, height: 16),
                Spacer(),
                SkeletonBox(width: 60, height: 12),
              ],
            ),
            const SizedBox(height: 12),
            // Cards row
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: NeverScrollableScrollPhysics(),
                itemCount: count,
                itemBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 120, height: 110, borderRadius: 12),
                      const SizedBox(height: 8),
                      SkeletonBox(width: 100, height: 12),
                      const SizedBox(height: 4),
                      SkeletonBox(width: 70, height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for the rewards/gifts section.
class RewardsSkeleton extends StatelessWidget {
  const RewardsSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonBox(width: 100, height: 16),
                Spacer(),
                SkeletonBox(width: 60, height: 12),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: NeverScrollableScrollPhysics(),
                itemCount: 5,
                itemBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: SkeletonBox(width: 56, height: 56, borderRadius: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for the challenges section.
class ChallengesSkeleton extends StatelessWidget {
  const ChallengesSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonBox(width: 100, height: 16),
                Spacer(),
                SkeletonBox(width: 60, height: 12),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: NeverScrollableScrollPhysics(),
                itemCount: 5,
                itemBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    children: [
                      SkeletonCircle(size: 56),
                      const SizedBox(height: 6),
                      SkeletonBox(width: 50, height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for banner/slider section.
class BannerSkeleton extends StatelessWidget {
  const BannerSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        height: 160,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

/// Generic list skeleton — used for detail screens that show
/// a vertical list of items (episodes, search results, etc.).
class ListSkeleton extends StatelessWidget {
  final int itemCount;
  const ListSkeleton({Key? key, this.itemCount = 5}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: List.generate(
            itemCount,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  SkeletonBox(width: 100, height: 72, borderRadius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: double.infinity, height: 14),
                        const SizedBox(height: 8),
                        SkeletonBox(width: 150, height: 12),
                        const SizedBox(height: 6),
                        SkeletonBox(width: 80, height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Grid skeleton — used for grid-based screens (search, browse, etc.).
class GridSkeleton extends StatelessWidget {
  final int crossAxisCount;
  final int itemCount;
  const GridSkeleton({
    Key? key,
    this.crossAxisCount = 2,
    this.itemCount = 6,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: itemCount,
          itemBuilder: (_, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SkeletonBox(width: double.infinity, height: 14),
              const SizedBox(height: 4),
              SkeletonBox(width: 80, height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for shorts video tile (full-screen vertical).
/// Mirrors the real shorts layout precisely:
///   - Top: tab bar (For You / Challenges) + filter button
///   - Center: subtle play icon
///   - Bottom: Row with ShortsDetail (left flex:3) + ShortsSideBar (right 100px)
class ShortsVideoSkeleton extends StatefulWidget {
  const ShortsVideoSkeleton({Key? key}) : super(key: key);

  @override
  State<ShortsVideoSkeleton> createState() => _ShortsVideoSkeletonState();
}

class _ShortsVideoSkeletonState extends State<ShortsVideoSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      color: Colors.black,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final o = _pulseAnimation.value;
          return Stack(
            children: [
              // Subtle gradient background
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black,
                      Color(0xFF0A0A0A),
                      Color(0xFF111111).withOpacity(o * 0.4),
                      Colors.black,
                    ],
                    stops: const [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
              ),

              // Center play icon
              Center(
                child: Opacity(
                  opacity: o,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.10),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white.withOpacity(0.15),
                      size: 30,
                    ),
                  ),
                ),
              ),

              // ── Bottom area: matches the real Row layout ──
              // Real layout: Positioned(bottom:0) → Column → Row[Expanded(flex:3) ShortsDetail, SizedBox(100) ShortsSideBar]
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Left side — ShortsDetail placeholder (flex: 3)
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 13, bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // @username [topic]
                            Container(
                              width: 160,
                              height: 15,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(o * 0.10),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Title
                            Container(
                              width: 200,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(o * 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Description line 1
                            Container(
                              width: 170,
                              height: 13,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(o * 0.06),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 6),
                            // "more" link placeholder
                            Container(
                              width: 36,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(o * 0.10),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Right side — ShortsSideBar placeholder (width: 100)
                    SizedBox(
                      width: 100,
                      child: Container(
                        width: 70,
                        margin: const EdgeInsets.only(right: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Profile avatar
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(o * 0.10),
                                border: Border.all(
                                  color: Colors.white.withOpacity(o * 0.06),
                                  width: 2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Quiz icon
                            _sidebarIconPlaceholder(o, 0),
                            const SizedBox(height: 14),
                            // Coins icon (amber tint)
                            _sidebarIconPlaceholder(o, 1, isCoins: true),
                            const SizedBox(height: 12),
                            // Like icon
                            _sidebarIconPlaceholder(o, 2),
                            const SizedBox(height: 14),
                            // Comment icon
                            _sidebarIconPlaceholder(o, 3),
                            const SizedBox(height: 14),
                            // Donate icon
                            _sidebarIconPlaceholder(o, 4),
                            const SizedBox(height: 14),
                            // Share icon
                            _sidebarIconPlaceholder(o, 5),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Top: tab bar (matches _buildHeader exactly) ──
              // Real: height 50, top: padding.top+10, left: 20, right: 80
              Positioned(
                top: topPadding + 10,
                left: 20,
                right: 80,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.white.withOpacity(o * 0.12),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Active tab — "For You"
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            color: Colors.white.withOpacity(o * 0.12),
                            border: Border.all(
                              color: Colors.white.withOpacity(o * 0.08),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 55,
                              height: 13,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(o * 0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Inactive tab — "Challenges"
                      Expanded(
                        child: Center(
                          child: Container(
                            width: 70,
                            height: 13,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(o * 0.06),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Top-right: filter button (matches real: top: padding.top+16, right: 8) ──
              Positioned(
                top: topPadding + 16,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.tune,
                    color: Colors.white.withOpacity(o * 0.12),
                    size: 24,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Single sidebar icon + label placeholder matching ShortsSideBar's 32px icons.
  Widget _sidebarIconPlaceholder(double o, int index, {bool isCoins = false}) {
    // Fade slightly per-index for visual depth
    final fade = (0.09 - index * 0.008).clamp(0.03, 0.09);
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                (isCoins ? Colors.amber : Colors.white).withOpacity(o * fade),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: 20,
          height: 7,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(o * (fade * 0.6)),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    );
  }
}

/// Skeleton for comments section.
class CommentsSkeleton extends StatelessWidget {
  final int count;
  const CommentsSkeleton({Key? key, this.count = 5}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Column(
        children: List.generate(
          count,
          (_) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonCircle(size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 90, height: 12),
                      const SizedBox(height: 6),
                      SkeletonBox(width: double.infinity, height: 12),
                      const SizedBox(height: 4),
                      SkeletonBox(width: 180, height: 12),
                    ],
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

/// Skeleton for the story screen's complete initial loading state.
/// Mirrors the actual layout structure of the story screen.
class StoryScreenSkeleton extends StatelessWidget {
  const StoryScreenSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // For You header skeleton
          _ForYouHeaderSkeleton(),
          const SizedBox(height: 8),
          // Featured story card
          StoryCardSkeleton(),
          const SizedBox(height: 8),
          // Storytellers
          StorytellersSkeleton(),
          const SizedBox(height: 8),
          // Continue Watching
          SeasonRowSkeleton(),
          const SizedBox(height: 8),
          // My List
          SeasonRowSkeleton(count: 3),
          const SizedBox(height: 8),
          // Challenges
          ChallengesSkeleton(),
          const SizedBox(height: 8),
          // Rewards/Gifts
          RewardsSkeleton(),
          const SizedBox(height: 8),
          // Suggested
          SeasonRowSkeleton(),
          const SizedBox(height: 8),
          // Banner
          BannerSkeleton(),
        ],
      ),
    );
  }
}

/// Matches the actual "For You" header: "For you" text + search bar + coins chip.
class _ForYouHeaderSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            // "For you" text placeholder
            SkeletonBox(width: 80, height: 20, borderRadius: 4),
            Spacer(),
            // Search bar placeholder
            SkeletonBox(width: 120, height: 32, borderRadius: 18),
            const SizedBox(width: 12),
            // Coins chip placeholder
            SkeletonBox(width: 70, height: 30, borderRadius: 25),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Screen-specific skeleton widgets
// ─────────────────────────────────────────────

/// Skeleton for the Video Screen (episode playback page).
/// Shows: title row + video rectangle + navigation buttons + actions + comments.
class VideoScreenSkeleton extends StatelessWidget {
  const VideoScreenSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            ShimmerLoading(
              child: Row(
                children: [
                  SkeletonBox(width: 180, height: 18, borderRadius: 4),
                  const SizedBox(width: 12),
                  SkeletonBox(width: 50, height: 14, borderRadius: 4),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Video player area
            ShimmerLoading(
              child: Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1), width: 4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Navigation card (prev / questions / next)
            ShimmerLoading(
              child: Row(
                children: [
                  Expanded(
                      flex: 2,
                      child: SkeletonBox(
                          width: double.infinity,
                          height: 44,
                          borderRadius: 50)),
                  const SizedBox(width: 8),
                  Expanded(
                      flex: 5,
                      child: SkeletonBox(
                          width: double.infinity,
                          height: 48,
                          borderRadius: 50)),
                  const SizedBox(width: 8),
                  Expanded(
                      flex: 2,
                      child: SkeletonBox(
                          width: double.infinity,
                          height: 44,
                          borderRadius: 50)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Review / Vote / Share bar
            ShimmerLoading(
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        SkeletonBox(width: 30, height: 30, borderRadius: 6),
                        const SizedBox(width: 8),
                        SkeletonBox(width: 80, height: 14, borderRadius: 4),
                      ],
                    ),
                  ),
                  SkeletonBox(width: 24, height: 24, borderRadius: 4),
                  const SizedBox(width: 20),
                  SkeletonBox(width: 24, height: 24, borderRadius: 4),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Creator info row
            ShimmerLoading(
              child: Row(
                children: [
                  SkeletonCircle(size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 120, height: 14, borderRadius: 4),
                        const SizedBox(height: 4),
                        SkeletonBox(width: 80, height: 12, borderRadius: 4),
                      ],
                    ),
                  ),
                  SkeletonBox(width: 80, height: 32, borderRadius: 16),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Description lines
            ShimmerLoading(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(
                      width: double.infinity, height: 12, borderRadius: 4),
                  const SizedBox(height: 6),
                  SkeletonBox(
                      width: double.infinity, height: 12, borderRadius: 4),
                  const SizedBox(height: 6),
                  SkeletonBox(width: 200, height: 12, borderRadius: 4),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Comments section
            ShimmerLoading(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        SkeletonBox(width: 90, height: 16, borderRadius: 4),
                        const SizedBox(width: 8),
                        SkeletonBox(width: 30, height: 14, borderRadius: 4),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Comment input placeholder
                    Row(
                      children: [
                        SkeletonCircle(size: 36),
                        const SizedBox(width: 10),
                        Expanded(
                            child: SkeletonBox(
                                width: double.infinity,
                                height: 44,
                                borderRadius: 20)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Comment items
                    ...List.generate(
                        2,
                        (_) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SkeletonCircle(size: 30),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SkeletonBox(
                                            width: 80,
                                            height: 12,
                                            borderRadius: 4),
                                        const SizedBox(height: 6),
                                        SkeletonBox(
                                            width: double.infinity,
                                            height: 12,
                                            borderRadius: 4),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Linked content section
            ShimmerLoading(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 130, height: 16, borderRadius: 4),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 140,
                    child: Row(
                      children: List.generate(
                          3,
                          (_) => Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: SkeletonBox(
                                    width: 100, height: 140, borderRadius: 12),
                              )),
                    ),
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

/// Skeleton for the Episode Detail Screen.
/// Shows: trailer thumbnail + season details + episode grid.
class EpisodeDetailSkeleton extends StatelessWidget {
  const EpisodeDetailSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trailer thumbnail (16:9 aspect)
            ShimmerLoading(
              child: Container(
                width: double.infinity,
                height: (screenWidth - 20) * 9 / 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(21),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Lock/Unlock section
            ShimmerLoading(
              child: SkeletonBox(
                  width: double.infinity, height: 48, borderRadius: 12),
            ),
            const SizedBox(height: 12),
            // Season details card
            ShimmerLoading(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rating row
                    Row(
                      children: [
                        ...List.generate(
                            5,
                            (_) => Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: SkeletonBox(
                                      width: 16, height: 16, borderRadius: 2),
                                )),
                        const SizedBox(width: 8),
                        SkeletonBox(width: 30, height: 14, borderRadius: 4),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Title
                    SkeletonBox(
                        width: screenWidth * 0.6, height: 18, borderRadius: 4),
                    const SizedBox(height: 8),
                    // Metadata chips
                    Row(
                      children: [
                        SkeletonBox(width: 60, height: 20, borderRadius: 10),
                        const SizedBox(width: 8),
                        SkeletonBox(width: 80, height: 20, borderRadius: 10),
                        const SizedBox(width: 8),
                        SkeletonBox(width: 50, height: 20, borderRadius: 10),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Description lines
                    SkeletonBox(
                        width: double.infinity, height: 12, borderRadius: 4),
                    const SizedBox(height: 5),
                    SkeletonBox(
                        width: double.infinity, height: 12, borderRadius: 4),
                    const SizedBox(height: 5),
                    SkeletonBox(
                        width: screenWidth * 0.5, height: 12, borderRadius: 4),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Episodes section
            ShimmerLoading(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section header
                    Row(
                      children: [
                        SkeletonBox(width: 32, height: 32, borderRadius: 12),
                        const SizedBox(width: 10),
                        SkeletonBox(width: 80, height: 16, borderRadius: 4),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 2x2 episode grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 16 / 11,
                      ),
                      itemCount: 4,
                      itemBuilder: (_, __) => Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Suggested seasons
            ShimmerLoading(
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 140, height: 14, borderRadius: 4),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: Row(
                        children: List.generate(
                            3,
                            (i) => Expanded(
                                  child: Padding(
                                    padding:
                                        EdgeInsets.only(right: i < 2 ? 10 : 0),
                                    child: SkeletonBox(
                                      width: double.infinity,
                                      height: 180,
                                      borderRadius: 8,
                                    ),
                                  ),
                                )),
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

/// Skeleton for the User Profile Screen.
/// Shows: avatar + stats + profile info + content tabs.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          // Profile header
          ShimmerLoading(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar with level badge
                  Column(
                    children: [
                      const SizedBox(height: 20),
                      SkeletonCircle(size: 120),
                      const SizedBox(height: 8),
                      SkeletonBox(width: 60, height: 20, borderRadius: 25),
                    ],
                  ),
                  const SizedBox(width: 20),
                  // User info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Role + action buttons
                        Row(
                          children: [
                            SkeletonBox(width: 40, height: 12, borderRadius: 4),
                            Spacer(),
                            SkeletonBox(
                                width: 28, height: 28, borderRadius: 10),
                            const SizedBox(width: 6),
                            SkeletonBox(
                                width: 28, height: 28, borderRadius: 10),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Username
                        SkeletonBox(width: 140, height: 16, borderRadius: 4),
                        const SizedBox(height: 6),
                        // Bio lines
                        SkeletonBox(
                            width: double.infinity,
                            height: 12,
                            borderRadius: 4),
                        const SizedBox(height: 4),
                        SkeletonBox(width: 120, height: 12, borderRadius: 4),
                        const SizedBox(height: 12),
                        // Stats row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                              3,
                              (_) => Column(
                                    children: [
                                      SkeletonBox(
                                          width: 30,
                                          height: 16,
                                          borderRadius: 4),
                                      const SizedBox(height: 4),
                                      SkeletonBox(
                                          width: 50,
                                          height: 10,
                                          borderRadius: 4),
                                    ],
                                  )),
                        ),
                        const SizedBox(height: 12),
                        // Action buttons (Follow / Edit)
                        Row(
                          children: [
                            Expanded(
                                child: SkeletonBox(
                                    width: double.infinity,
                                    height: 36,
                                    borderRadius: 18)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: SkeletonBox(
                                    width: double.infinity,
                                    height: 36,
                                    borderRadius: 18)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Monetization card
          ShimmerLoading(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: SkeletonBox(
                  width: double.infinity, height: 80, borderRadius: 16),
            ),
          ),
          const SizedBox(height: 12),
          // Tab bar placeholder
          ShimmerLoading(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                      child: SkeletonBox(
                          width: double.infinity, height: 36, borderRadius: 8)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: SkeletonBox(
                          width: double.infinity, height: 36, borderRadius: 8)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Content grid
          GridSkeleton(crossAxisCount: 2, itemCount: 4),
        ],
      ),
    );
  }
}

/// Skeleton for Creator Story Screen (creator profile).
/// Shows: large profile header with avatar + stats + actions + content sections.
class CreatorProfileSkeleton extends StatelessWidget {
  const CreatorProfileSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          // Creator profile header card
          ShimmerLoading(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(8, 16, 16, 0),
              padding: const EdgeInsets.fromLTRB(12, 20, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar area
                      Column(
                        children: [
                          SkeletonCircle(size: 132),
                          const SizedBox(height: 8),
                          SkeletonBox(width: 70, height: 22, borderRadius: 12),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Creator info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // "Creator" label + name
                            SkeletonBox(width: 50, height: 12, borderRadius: 4),
                            const SizedBox(height: 6),
                            SkeletonBox(
                                width: 150, height: 19, borderRadius: 4),
                            const SizedBox(height: 8),
                            // Location
                            SkeletonBox(
                                width: 100, height: 12, borderRadius: 4),
                            const SizedBox(height: 10),
                            // Bio lines
                            SkeletonBox(
                                width: double.infinity,
                                height: 12,
                                borderRadius: 4),
                            const SizedBox(height: 4),
                            SkeletonBox(
                                width: 140, height: 12, borderRadius: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Stats row (followers, likes, views)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(
                        3,
                        (_) => Column(
                              children: [
                                SkeletonBox(
                                    width: 40, height: 18, borderRadius: 4),
                                const SizedBox(height: 4),
                                SkeletonBox(
                                    width: 60, height: 12, borderRadius: 4),
                              ],
                            )),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Action buttons (Follow / Message / Donate)
          ShimmerLoading(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                      child: SkeletonBox(
                          width: double.infinity,
                          height: 44,
                          borderRadius: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: SkeletonBox(
                          width: double.infinity,
                          height: 44,
                          borderRadius: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: SkeletonBox(
                          width: double.infinity,
                          height: 44,
                          borderRadius: 22)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Achievement chips row
          ShimmerLoading(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 120, height: 16, borderRadius: 4),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 72,
                    child: Row(
                      children: List.generate(
                          4,
                          (_) => Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: SkeletonBox(
                                    width: 72, height: 72, borderRadius: 16),
                              )),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Content tabs + grid
          ShimmerLoading(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                      child: SkeletonBox(
                          width: double.infinity, height: 36, borderRadius: 8)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: SkeletonBox(
                          width: double.infinity, height: 36, borderRadius: 8)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GridSkeleton(crossAxisCount: 2, itemCount: 4),
        ],
      ),
    );
  }
}

/// Skeleton for the Gift/Rewards Screen.
/// Shows: quick actions + for-you horizontal cards + category tabs + gift grid.
class GiftScreenSkeleton extends StatelessWidget {
  const GiftScreenSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick actions header (title + search)
          ShimmerLoading(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  SkeletonBox(width: 100, height: 22, borderRadius: 4),
                  Spacer(),
                  SkeletonBox(width: 100, height: 32, borderRadius: 16),
                  const SizedBox(width: 10),
                  SkeletonBox(width: 70, height: 30, borderRadius: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // "For you" section
          ShimmerLoading(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 80, height: 22, borderRadius: 4),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: Row(
                      children: List.generate(
                          3,
                          (_) => Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Column(
                                  children: [
                                    SkeletonBox(
                                        width: 120,
                                        height: 120,
                                        borderRadius: 16),
                                    const SizedBox(height: 8),
                                    SkeletonBox(
                                        width: 100,
                                        height: 12,
                                        borderRadius: 4),
                                    const SizedBox(height: 4),
                                    SkeletonBox(
                                        width: 60, height: 10, borderRadius: 4),
                                  ],
                                ),
                              )),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Category gifts section
          ShimmerLoading(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header
                  Row(
                    children: [
                      SkeletonBox(width: 32, height: 32, borderRadius: 12),
                      const SizedBox(width: 10),
                      SkeletonBox(width: 140, height: 18, borderRadius: 4),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Category chips
                  Row(
                    children: List.generate(
                        4,
                        (_) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: SkeletonBox(
                                  width: 70, height: 36, borderRadius: 20),
                            )),
                  ),
                  const SizedBox(height: 12),
                  // Gift cards row
                  SizedBox(
                    height: 260,
                    child: Row(
                      children: List.generate(
                          2,
                          (_) => Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: SkeletonBox(
                                    width: 160, height: 260, borderRadius: 16),
                              )),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Hero banner
          ShimmerLoading(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: SkeletonBox(
                  width: double.infinity, height: 140, borderRadius: 20),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for the Points/Wallet Screen.
/// Shows: monetization card + action buttons + chart + daily rewards.
class WalletScreenSkeleton extends StatelessWidget {
  const WalletScreenSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          // Monetization card
          ShimmerLoading(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SkeletonBox(
                  width: double.infinity, height: 80, borderRadius: 16),
            ),
          ),
          const SizedBox(height: 4),
          // Available points card
          ShimmerLoading(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SkeletonBox(
                  width: double.infinity, height: 100, borderRadius: 16),
            ),
          ),
          const SizedBox(height: 4),
          // Action buttons row (Withdraw / Transfer / Convert)
          ShimmerLoading(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: List.generate(
                    3,
                    (i) => Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(left: i > 0 ? 12 : 0),
                            child: SkeletonBox(
                                width: double.infinity,
                                height: 98,
                                borderRadius: 12),
                          ),
                        )),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Points chart
          ShimmerLoading(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 140, height: 18, borderRadius: 4),
                  const SizedBox(height: 16),
                  // Summary cards (credited / debited)
                  Row(
                    children: [
                      Expanded(
                          child: SkeletonBox(
                              width: double.infinity,
                              height: 60,
                              borderRadius: 12)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: SkeletonBox(
                              width: double.infinity,
                              height: 60,
                              borderRadius: 12)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Chart placeholder
                  SkeletonBox(
                      width: double.infinity, height: 200, borderRadius: 8),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Daily rewards card
          ShimmerLoading(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SkeletonBox(
                  width: double.infinity, height: 72, borderRadius: 16),
            ),
          ),
          const SizedBox(height: 4),
          // Watch ads card
          ShimmerLoading(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SkeletonBox(
                  width: double.infinity, height: 72, borderRadius: 16),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for the Discover Screen.
/// Shows: section header + storyteller cards + section header + challenge cards.
class DiscoverScreenSkeleton extends StatelessWidget {
  const DiscoverScreenSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // Subscription banner placeholder
          ShimmerLoading(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: SkeletonBox(
                  width: double.infinity, height: 60, borderRadius: 16),
            ),
          ),
          const SizedBox(height: 16),
          // Storytellers section header
          _DiscoverSectionHeaderSkeleton(),
          const SizedBox(height: 16),
          // Storyteller cards
          StorytellerCardsSkeleton(),
          const SizedBox(height: 32),
          // Challenges section header
          _DiscoverSectionHeaderSkeleton(),
          const SizedBox(height: 16),
          // Challenge cards
          ChallengeCardsSkeleton(),
        ],
      ),
    );
  }
}

class _DiscoverSectionHeaderSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            SkeletonBox(width: 44, height: 44, borderRadius: 12),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 120, height: 18, borderRadius: 4),
                const SizedBox(height: 4),
                SkeletonBox(width: 80, height: 14, borderRadius: 4),
              ],
            ),
            Spacer(),
            SkeletonBox(width: 16, height: 16, borderRadius: 4),
          ],
        ),
      ),
    );
  }
}

/// Storyteller cards skeleton — tall rectangular cards (matching the actual
/// discover screen storyteller cards: 160×160 with avatar + text).
class StorytellerCardsSkeleton extends StatelessWidget {
  final int count;
  const StorytellerCardsSkeleton({Key? key, this.count = 4}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: SizedBox(
        height: 160,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: count,
          itemBuilder: (_, __) => Container(
            width: 160,
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SkeletonCircle(size: 72),
                const SizedBox(height: 12),
                SkeletonBox(width: 100, height: 14, borderRadius: 4),
                const SizedBox(height: 4),
                SkeletonBox(width: 70, height: 12, borderRadius: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Challenge cards skeleton — horizontal cards matching the actual challenge
/// layout: 280×height with image + title + description + status.
class ChallengeCardsSkeleton extends StatelessWidget {
  final int count;
  const ChallengeCardsSkeleton({Key? key, this.count = 3}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: count,
          itemBuilder: (_, __) => Container(
            width: 280,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                SkeletonBox(width: 60, height: 60, borderRadius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SkeletonBox(width: 130, height: 14, borderRadius: 4),
                      const SizedBox(height: 6),
                      SkeletonBox(
                          width: double.infinity, height: 12, borderRadius: 4),
                      const SizedBox(height: 4),
                      SkeletonBox(width: 100, height: 12, borderRadius: 4),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          SkeletonBox(width: 60, height: 22, borderRadius: 8),
                          const SizedBox(width: 8),
                          SkeletonBox(width: 50, height: 22, borderRadius: 8),
                        ],
                      ),
                    ],
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

/// Skeleton for user list screens (followers, following, etc.)
/// Uses circles for avatars + text + trailing action button.
class UserListSkeleton extends StatelessWidget {
  final int itemCount;
  const UserListSkeleton({Key? key, this.itemCount = 6}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SkeletonBox(
                  width: double.infinity, height: 48, borderRadius: 12),
            ),
            // User list items
            ...List.generate(
              itemCount,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      SkeletonCircle(size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(
                                width: 120, height: 15, borderRadius: 4),
                            const SizedBox(height: 4),
                            SkeletonBox(width: 90, height: 13, borderRadius: 4),
                          ],
                        ),
                      ),
                      SkeletonBox(width: 80, height: 32, borderRadius: 12),
                      const SizedBox(width: 8),
                      SkeletonBox(width: 20, height: 20, borderRadius: 4),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for search results screen — search bar + 2-column grid.
class SearchResultsSkeleton extends StatelessWidget {
  const SearchResultsSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        ShimmerLoading(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SkeletonBox(
                width: double.infinity, height: 48, borderRadius: 24),
          ),
        ),
        // Grid results
        Expanded(
          child: GridSkeleton(crossAxisCount: 2, itemCount: 6),
        ),
      ],
    );
  }
}

/// Skeleton for the Shop/Store screen.
/// Mirrors the real layout: quick actions header → For You horizontal section
/// → hero banner → vendor product cards.
class ShopScreenSkeleton extends StatefulWidget {
  const ShopScreenSkeleton({Key? key}) : super(key: key);

  @override
  State<ShopScreenSkeleton> createState() => _ShopScreenSkeletonState();
}

class _ShopScreenSkeletonState extends State<ShopScreenSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, _) {
          final o = _pulseAnimation.value;
          return SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQuickActionsPlaceholder(o),
                _buildForYouPlaceholder(o),
                _buildHeroBannerPlaceholder(o),
                _buildVendorSectionPlaceholder(o),
                _buildVendorSectionPlaceholder(o, shorter: true),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }

  /// "All Vendors" title + search bar row
  Widget _buildQuickActionsPlaceholder(double o) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Title placeholder
          Container(
            width: 120,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(o * 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 12),
          // Search bar placeholder
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(o * 0.06),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(o * 0.10),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 60,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(o * 0.08),
                      borderRadius: BorderRadius.circular(6),
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

  /// "For you" horizontal card scroll placeholder
  Widget _buildForYouPlaceholder(double o) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: "For you" title + arrow
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 80,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(o * 0.25),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(o * 0.06),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Horizontal scrolling cards
          SizedBox(
            height: 135,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                return Container(
                  width: 110,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(o * 0.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      // Product image placeholder
                      Container(
                        height: 85,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(o * 0.07),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Title placeholder
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Container(
                          width: double.infinity,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(o * 0.08),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      // Price placeholder
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Container(
                          width: 50,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(o * 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Hero banner / image slideshow placeholder
  Widget _buildHeroBannerPlaceholder(double o) {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A2A2A).withOpacity(o + 0.3),
            Color(0xFF1E1E1E).withOpacity(o + 0.2),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(o * 0.06),
          width: 1,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber.withOpacity(o * 0.12),
              ),
              child: Icon(
                Icons.shopping_bag_rounded,
                color: Colors.amber.withOpacity(o * 0.25),
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: 140,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(o * 0.08),
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 200,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(o * 0.05),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Vendor card placeholder — avatar + name + product grid
  Widget _buildVendorSectionPlaceholder(double o, {bool shorter = false}) {
    final productCount = shorter ? 2 : 4;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A2A2A).withOpacity(o + 0.3),
            Color(0xFF1E1E1E).withOpacity(o + 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(o * 0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vendor header: avatar + name + chevron
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(o * 0.08),
                  border: Border.all(
                    color: Colors.white.withOpacity(o * 0.04),
                    width: 1,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 100,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(o * 0.10),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 160,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(o * 0.06),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(o * 0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Product grid: 2-column
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            itemCount: productCount,
            itemBuilder: (_, __) => _buildProductCardPlaceholder(o),
          ),
        ],
      ),
    );
  }

  /// Single product card placeholder
  Widget _buildProductCardPlaceholder(double o) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(o * 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(o * 0.03),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image area
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(o * 0.06),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
            ),
          ),
          // Details area
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: double.infinity,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(o * 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 60,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(o * 0.15),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 40,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(o * 0.05),
                      borderRadius: BorderRadius.circular(4),
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
