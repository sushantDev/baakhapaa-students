import 'package:flutter/material.dart';

class StarRatingWidget extends StatelessWidget {
  final double rating;
  final int starCount;
  final double size;
  final Color color;
  final bool allowHalfRating;

  const StarRatingWidget({
    Key? key,
    required this.rating,
    this.starCount = 5,
    this.size = 20,
    this.color = Colors.amber,
    this.allowHalfRating = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(starCount, (index) {
        double starValue = index + 1.0;
        IconData icon;

        if (rating >= starValue) {
          // Full star
          icon = Icons.star;
        } else if (allowHalfRating && rating >= starValue - 0.5) {
          // Half star
          icon = Icons.star_half;
        } else {
          // Empty star
          icon = Icons.star_border;
        }

        return Icon(
          icon,
          size: size,
          color: color,
        );
      }),
    );
  }
}

class InteractiveStarRating extends StatefulWidget {
  final double initialRating;
  final Function(double) onRatingChanged;
  final int starCount;
  final double size;
  final Color selectedColor;
  final Color unselectedColor;

  const InteractiveStarRating({
    Key? key,
    required this.onRatingChanged,
    this.initialRating = 0,
    this.starCount = 5,
    this.size = 30,
    this.selectedColor = Colors.amber,
    this.unselectedColor = Colors.grey,
  }) : super(key: key);

  @override
  _InteractiveStarRatingState createState() => _InteractiveStarRatingState();
}

class _InteractiveStarRatingState extends State<InteractiveStarRating> {
  late double currentRating;

  @override
  void initState() {
    super.initState();
    currentRating = widget.initialRating;
  }

  void _setRating(double newRating) {
    setState(() => currentRating = newRating);
    widget.onRatingChanged(newRating);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.starCount, (index) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox;
            final localPos = box.globalToLocal(details.globalPosition);

            double starWidth = widget.size;
            bool isHalf = localPos.dx % starWidth < starWidth / 2;

            double newRating = index + (isHalf ? 0.5 : 1.0);
            _setRating(newRating);
          },
          child: Icon(
            currentRating >= index + 1
                ? Icons.star
                : (currentRating >= index + 0.5
                    ? Icons.star_half
                    : Icons.star_border),
            size: widget.size,
            color: currentRating >= index + 0.5
                ? widget.selectedColor
                : widget.unselectedColor,
          ),
        );
      }),
    );
  }
}
