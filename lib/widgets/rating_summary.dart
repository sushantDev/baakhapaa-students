import 'dart:async';
import 'package:flutter/material.dart';
import 'package:baakhapaa/models/rating_model.dart';
import 'package:baakhapaa/services/rating_service.dart';
import '../../../utils/debug_logger.dart';
import 'skeleton_loading.dart';

enum RatingTo { product, episode, season }

class RatingSummery extends StatefulWidget {
  final int ratingId;
  final String authToken;
  final double starSize;
  final bool showText;
  final MainAxisAlignment alignment;
  final VoidCallback? onTap;
  final RatingTo ratingTo;
  final Duration refreshInterval; // New: customizable refresh interval

  const RatingSummery({
    Key? key,
    required this.ratingId,
    required this.authToken,
    required this.ratingTo,
    required this.starSize,
    this.showText = true,
    this.alignment = MainAxisAlignment.start,
    this.onTap,
    this.refreshInterval = const Duration(seconds: 30), // Default: 30 seconds
  }) : super(key: key);

  @override
  _RatingSummeryState createState() => _RatingSummeryState();
}

class _RatingSummeryState extends State<RatingSummery> {
  late final RatingService _ratingService;
  RatingStats? ratingStats;
  bool isLoading = true;
  Timer? _refreshTimer;
  bool _hasRateLimitError = false; // Track if we hit rate limit
  int _consecutiveErrors = 0; // Track consecutive errors
  static const int _maxConsecutiveErrors = 3; // Stop after 3 consecutive errors

  @override
  void initState() {
    super.initState();
    _ratingService = RatingService(authToken: widget.authToken);
    loadRatingStats();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(widget.refreshInterval, (timer) {
      // Stop auto-refresh if we hit rate limit or too many errors
      if (_hasRateLimitError || _consecutiveErrors >= _maxConsecutiveErrors) {
        timer.cancel();
        return;
      }
      if (mounted) {
        loadRatingStats(silent: true);
      }
    });
  }

  Future<void> loadRatingStats({bool silent = false}) async {
    if (!mounted) return;

    if (!silent) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final RatingResponse response;
      switch (widget.ratingTo) {
        case RatingTo.product:
          response = await _ratingService.getProductRatings(widget.ratingId);
          break;
        case RatingTo.episode:
          response = await _ratingService.getEpisodeRatings(widget.ratingId);
          break;
        case RatingTo.season:
          response = await _ratingService.getSeasonsRatings(widget.ratingId);
          break;
      }

      // Success - reset error counters
      _consecutiveErrors = 0;
      _hasRateLimitError = false;

      if (mounted) {
        setState(() {
          ratingStats = response.stats;
          isLoading = false;
        });
      }
    } catch (e) {
      // Check if it's a rate limit error
      if (e.toString().contains('429')) {
        _hasRateLimitError = true;
        _refreshTimer?.cancel(); // Stop the timer immediately
        if (!silent) {
          DebugLogger.info(
              '⚠️ Rating API rate limit reached (429). Stopping auto-refresh.');
        }
      } else {
        _consecutiveErrors++;
        if (_consecutiveErrors >= _maxConsecutiveErrors && !silent) {
          DebugLogger.info(
              '⚠️ Too many consecutive rating errors ($_consecutiveErrors). Stopping auto-refresh.');
        }
      }

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      // Only DebugLogger.info error once, not repeatedly
      if (!silent && _consecutiveErrors <= 1) {
        DebugLogger.info('Error loading rating stats: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Special layout for season page
    if (widget.ratingTo == RatingTo.season) {
      if (isLoading) {
        return Row(
          mainAxisAlignment: widget.alignment,
          children: const [
            ShimmerLoading(
              child: SkeletonBox(width: 60, height: 18),
            ),
          ],
        );
      }

      final content = Row(
        mainAxisAlignment: widget.alignment,
        children: [
          const Icon(Icons.star, color: Colors.amber, size: 18),
          const SizedBox(width: 6),
          Text(
            ratingStats != null
                ? '${(ratingStats!.averageRating).toStringAsFixed(1)}/5'
                : 'Not rated',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      );

      if (widget.onTap != null) {
        return InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: content,
          ),
        );
      }

      return content;
    }

    // Original layout for product and episode
    if (isLoading) {
      return Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: widget.alignment,
        children: [
          SizedBox(
            width: widget.starSize,
            height: widget.starSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          if (widget.showText) ...[
            const SizedBox(width: 8),
            Text(
              'Loading...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      );
    }

    if (ratingStats == null) {
      return Row(
        mainAxisAlignment: widget.alignment,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              return Icon(
                Icons.star_border,
                color: Colors.grey,
                size: widget.starSize,
              );
            }),
          ),
          if (widget.showText) ...[
            const SizedBox(width: 8),
            Text(
              'No reviews',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      );
    }

    final content = Row(
      mainAxisAlignment: widget.alignment,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            5,
            (index) {
              final avgRating = ratingStats!.averageRating;
              return Icon(
                index < avgRating.floor()
                    ? Icons.star
                    : (index < avgRating ? Icons.star_half : Icons.star_border),
                color: Colors.amber,
                size: widget.starSize,
              );
            },
          ),
        ),
        if (widget.showText && widget.ratingTo != RatingTo.product) ...[
          const SizedBox(width: 8),
          Text(
            '${ratingStats!.averageRating.toStringAsFixed(1)} / 5',
          ),
        ],
      ],
    );

    if (widget.onTap != null) {
      return InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: content,
        ),
      );
    }

    return content;
  }
}
