import 'package:baakhapaa/widgets/star_rating_widget.dart';
import 'package:flutter/material.dart';
import '../../../utils/debug_logger.dart';

class RatingDialog extends StatefulWidget {
  final Function(int stars, String description) onSubmit;
  final int? initialRating;
  final String? initialDescription;
  final bool isEdit;

  const RatingDialog({
    Key? key,
    required this.onSubmit,
    this.initialRating,
    this.initialDescription,
    this.isEdit = false,
  }) : super(key: key);

  @override
  _RatingDialogState createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  double selectedStars = 0; // use double
  late TextEditingController descriptionController;

  @override
  void initState() {
    super.initState();
    selectedStars = (widget.initialRating ?? 0).toDouble();
    descriptionController =
        TextEditingController(text: widget.initialDescription ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEdit ? 'Edit Rating' : 'Add Rating'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Rate this item:'),
          const SizedBox(height: 10),
          InteractiveStarRating(
            initialRating: selectedStars,
            onRatingChanged: (rating) {
              setState(() {
                selectedStars = rating; // rating is already double
              });
            },
          ),
          const SizedBox(height: 20),
          TextField(
            controller: descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Write your review...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: selectedStars > 0
              ? () {
                  DebugLogger.info(
                      'Stars: ${selectedStars.round()}'); // Add this
                  DebugLogger.info(
                      'Description: "${descriptionController.text}"'); // Add this
                  DebugLogger.info(
                      'Description isEmpty: ${descriptionController.text.isEmpty}'); // Add this

                  widget.onSubmit(
                    selectedStars.round(),
                    descriptionController.text,
                  );
                  Navigator.of(context).pop();
                }
              : null,
          child: Text(widget.isEdit ? 'Update' : 'Submit'),
        ),
      ],
    );
  }
}
