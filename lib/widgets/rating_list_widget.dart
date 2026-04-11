import 'package:baakhapaa/models/rating_model.dart';
import 'package:baakhapaa/widgets/star_rating_widget.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class RatingListWidget extends StatelessWidget {
  final List<RatingModel> ratings;
  final RatingStats stats;
  final Function(RatingModel)? onEdit;
  final Function(RatingModel)? onDelete;
  final int? currentUserId;

  const RatingListWidget({
    Key? key,
    required this.ratings,
    required this.stats,
    this.onEdit,
    this.onDelete,
    this.currentUserId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Reviews',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          if (ratings.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No reviews yet',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ratings.length,
              itemBuilder: (context, index) {
                final rating = ratings[index];
                final isCurrentUser =
                    currentUserId != null && rating.userId == currentUserId;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage: rating.user.image != null &&
                                          rating.user.image!.isNotEmpty
                                      ? CachedNetworkImageProvider(
                                          rating.user.image!)
                                      : null,
                                  backgroundColor: Colors.grey.shade300,
                                  child: rating.user.image == null ||
                                          rating.user.image!.isEmpty
                                      ? CircleAvatar(
                                          radius: 16,
                                          backgroundImage: AssetImage(
                                              'assets/images/logo.png'))
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rating.user.name.isNotEmpty
                                          ? rating.user.name
                                          : rating.user.username,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _formatDate(rating.createdAt),
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (isCurrentUser)
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: onEdit != null
                                        ? () => onEdit!(rating)
                                        : null,
                                    icon: const Icon(Icons.edit, size: 20),
                                  ),
                                  IconButton(
                                    onPressed: onDelete != null
                                        ? () => onDelete!(rating)
                                        : null,
                                    icon: Icon(
                                      Icons.delete,
                                      size: 20,
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        StarRatingWidget(rating: rating.stars.toDouble()),
                        const SizedBox(height: 8),
                        if (rating.description.isNotEmpty)
                          Text(rating.description),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
