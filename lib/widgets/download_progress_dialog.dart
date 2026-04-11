import 'package:flutter/material.dart';

class DownloadProgressDialog extends StatelessWidget {
  final ValueNotifier<double> progress; // 0.0 - 1.0, use null for indeterminate
  final VoidCallback? onCancel;
  final String? title;

  const DownloadProgressDialog({
    Key? key,
    required this.progress,
    this.onCancel,
    this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title ?? 'Downloading video'),
      content: ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (context, value, child) {
          final isIndeterminate = value < 0;
          final isComplete = value >= 1.0;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              isIndeterminate
                  ? LinearProgressIndicator()
                  : LinearProgressIndicator(value: value.clamp(0.0, 1.0)),
              SizedBox(height: 12),
              Text(
                isIndeterminate
                    ? 'Preparing download...'
                    : isComplete
                        ? '✅ Download complete!'
                        : '📥 Downloading: ${(value.clamp(0.0, 1.0) * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: isComplete ? FontWeight.bold : FontWeight.normal,
                  color: isComplete ? Colors.green : null,
                ),
              ),
              if (!isIndeterminate && !isComplete) ...[
                SizedBox(height: 8),
                Text(
                  'Please keep the app open during download',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          );
        },
      ),
      actions: [
        if (onCancel != null)
          ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (context, value, child) {
              final isComplete = value >= 1.0;
              if (isComplete)
                return SizedBox.shrink(); // Hide cancel when complete

              return TextButton(
                onPressed: () {
                  Navigator.of(context)
                      .pop(); // close the dialog; caller should handle cancellation
                  onCancel!();
                },
                child: Text('Cancel'),
              );
            },
          ),
      ],
    );
  }
}
