import 'package:baakhapaa/models/rating_model.dart';
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/services/rating_service.dart';
import 'package:baakhapaa/widgets/rating_dialog.dart';
import 'package:baakhapaa/widgets/rating_list_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'skeleton_loading.dart';

enum RatingType { product, episode, season }

class RatingSheet extends StatefulWidget {
  final int ratingId;
  final String ratingTitle;
  final String authToken;
  final int currentUserId;
  final RatingType ratingType;

  const RatingSheet({
    Key? key,
    required this.ratingId,
    required this.ratingTitle,
    required this.authToken,
    required this.currentUserId,
    required this.ratingType,
  }) : super(key: key);

  @override
  _RatingSheetState createState() => _RatingSheetState();
}

class _RatingSheetState extends State<RatingSheet> {
  late final RatingService _ratingService;
  RatingResponse? ratingResponse;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _ratingService = RatingService(authToken: widget.authToken);
    loadRatings();
  }

  Future<void> loadRatings() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final RatingResponse response;
      switch (widget.ratingType) {
        case RatingType.product:
          response = await _ratingService.getProductRatings(widget.ratingId);
          break;
        case RatingType.episode:
          response = await _ratingService.getEpisodeRatings(widget.ratingId);
          break;
        case RatingType.season:
          response = await _ratingService.getSeasonsRatings(widget.ratingId);
          break;
      }

      setState(() {
        ratingResponse = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> addRating(int stars, String description) async {
    try {
      final request = RatingRequest(stars: stars, description: description);
      final bool success;

      switch (widget.ratingType) {
        case RatingType.product:
          success =
              await _ratingService.postProductRating(widget.ratingId, request);
          break;
        case RatingType.episode:
          success =
              await _ratingService.postEpisodeRating(widget.ratingId, request);
          break;
        case RatingType.season:
          success =
              await _ratingService.postSeasonsRating(widget.ratingId, request);
          break;
      }

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rating added successfully')),
        );
        loadRatings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add rating')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> updateRating(
      RatingModel rating, int stars, String description) async {
    try {
      final request = RatingRequest(stars: stars, description: description);
      final success = await _ratingService.updateRating(rating.id, request);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rating updated successfully')),
        );
        loadRatings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update rating')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> deleteRating(RatingModel rating) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text('Delete Rating', style: theme.textTheme.titleMedium),
          content: Text('Are you sure you want to delete this rating?',
              style: theme.textTheme.bodyMedium),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: theme.textTheme.labelLarge),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
              ),
              child: Text('Delete', style: theme.textTheme.labelLarge),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final success = await _ratingService.deleteRating(rating.id);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rating deleted successfully')),
        );
        loadRatings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete rating')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void showRatingDialog({RatingModel? existingRating}) {
    showDialog(
      context: context,
      builder: (context) => RatingDialog(
        initialRating: existingRating?.stars,
        initialDescription: existingRating?.description,
        isEdit: existingRating != null,
        onSubmit: (stars, description) {
          if (existingRating != null) {
            updateRating(existingRating, stars, description);
          } else {
            addRating(stars, description);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = Provider.of<Auth>(context, listen: false);
    final userId = auth.userId;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.dividerColor, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${widget.ratingTitle} - Reviews',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => showRatingDialog(),
                      icon: Icon(Icons.add, color: theme.iconTheme.color),
                      tooltip: 'Add Rating',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (ratingResponse?.stats != null) ...[
                  Row(
                    children: [
                      Row(
                        children: List.generate(5, (index) {
                          final avgRating = ratingResponse!.stats.averageRating;
                          return Icon(
                            index < avgRating.floor()
                                ? Icons.star
                                : (index < avgRating
                                    ? Icons.star_half
                                    : Icons.star_border),
                            color: Colors.amber,
                            size: 16,
                          );
                        }),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ratingResponse!.stats.averageRating.toStringAsFixed(1),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${ratingResponse!.stats.totalRatings} ${ratingResponse!.stats.totalRatings == 1 ? 'review' : 'reviews'})',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Content
          Expanded(
            child: isLoading
                ? const CommentsSkeleton(count: 4)
                : error != null
                    ? Center(child: Text('Error: $error'))
                    : ratingResponse?.ratings.isEmpty == true
                        ? Center(child: Text('No reviews yet'))
                        : RefreshIndicator(
                            color: theme.colorScheme.primary,
                            onRefresh: loadRatings,
                            child: SingleChildScrollView(
                              padding:
                                  const EdgeInsets.only(top: 8, bottom: 20),
                              child: RatingListWidget(
                                ratings: ratingResponse!.ratings,
                                stats: ratingResponse!.stats,
                                currentUserId: userId,
                                onEdit: (rating) =>
                                    showRatingDialog(existingRating: rating),
                                onDelete: deleteRating,
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
