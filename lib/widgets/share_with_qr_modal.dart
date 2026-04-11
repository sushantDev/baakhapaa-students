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
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
              size: 260, // Increased size for clarity
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
          SizedBox(height: 20),
          SelectableText(data, textAlign: TextAlign.center),
          SizedBox(height: 16),
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
