import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
// import 'package:share_plus/share_plus.dart';

class ShareWithQrModal extends StatelessWidget {
  final String data;
  final String? subject;

  const ShareWithQrModal({Key? key, required this.data, this.subject})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxQrSize =
        (mediaQuery.size.width - 80).clamp(180.0, 260.0).toDouble();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + mediaQuery.viewInsets.bottom + mediaQuery.padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: QrImageView(
              data: data,
              version: QrVersions.auto,
              size: maxQrSize,
              gapless: false,
              errorCorrectionLevel: QrErrorCorrectLevel.H,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
              embeddedImage: const AssetImage('assets/images/bkp.png'),
              embeddedImageStyle: const QrEmbeddedImageStyle(
                size: Size(60, 60),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: mediaQuery.size.width - 64),
            child: SelectableText(data, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          // ElevatedButton.icon(
          //   icon: Icon(Icons.share),
          //   label: Text('Share'),
          //   onPressed: () {
          //     SharePlus.instance.share(
          //       ShareParams(text: data, subject: subject),
          //     );
          //     Navigator.pop(context);
          //   },
          // ),
        ],
      ),
    );
  }
}
