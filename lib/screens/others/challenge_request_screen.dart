import 'dart:io';
import 'package:baakhapaa/screens/shop/single_product_screen.dart';
import 'package:baakhapaa/screens/user/user_screen.dart';
import 'package:baakhapaa/widgets/text_input_word_count.dart';
import 'package:baakhapaa/widgets/upload_widget.dart';
import 'package:flutter/material.dart';
import '../../utils/puppet_screen_mapping.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth.dart';
import '../../widgets/app_button.dart';
import '../../widgets/header.dart';
import '../../widgets/loading.dart';

class ChallengeRequestScreen extends StatefulWidget {
  static const routeName = '/challenge-request-screen';

  const ChallengeRequestScreen({Key? key}) : super(key: key);

  @override
  State<ChallengeRequestScreen> createState() => _ChallengeRequestScreenState();
}

class _ChallengeRequestScreenState extends State<ChallengeRequestScreen>
    with PuppetInteractionMixin {
  final _formKey = GlobalKey<FormState>();
  var _isInit = true;
  var _isLoading = true;
  late bool _challengeTicketPurchased = false;
  final TextEditingController _scriptController = TextEditingController();
  File? _selectedImage;

  @override
  void didChangeDependencies() {
    if (_isInit) {
      final auth = Provider.of<Auth>(context, listen: false);

      auth.checkScriptTicketPurchased().then(
        (_) {
          _challengeTicketPurchased = auth.challengeTicketPurchased;
          _isLoading = false;
        },
      );

      _isInit = false;
    }
    super.didChangeDependencies();
  }

  void _pasteFromClipboard() async {
    ClipboardData? clipboardData = await Clipboard.getData('text/plain');
    if (clipboardData != null) {
      _scriptController.text = clipboardData.text ?? '';
    }
  }

  Future<void> submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      showScaffoldMessenger(context, 'Please correct the errors in the form.');
      return;
    }

    final script = _scriptController.text.trim();
    if (script.isEmpty) {
      showScaffoldMessenger(context, 'Please write something.');
      return;
    }

    // Count the number of words by splitting the text by whitespace
    final wordCount = script.split(RegExp(r'\s+')).length;
    final int minWords = 100;

    if (wordCount < minWords) {
      showScaffoldMessenger(context, 'Word count is below $minWords.');
      return;
    }

    try {
      await Provider.of<Auth>(context, listen: false)
          .submitChallengeRequest(script, _selectedImage);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Congratulations'),
          content: Text('The script has been submitted successfully.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, UserScreen.routeName);
              },
              child: Text('Okay'),
            ),
          ],
        ),
      );
    } catch (error) {
      showScaffoldMessenger(context, 'Opps! something went wrong');
    }
  }

  void showScaffoldMessenger(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _onImageSelected(File image) {
    setState(
      () {
        _selectedImage = image;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: header(context: context, titleText: "Script Writing Challenge"),
      body: _isLoading
          ? Loading()
          : SingleChildScrollView(
              child: Container(
                constraints: BoxConstraints(
                  minHeight: 900,
                ),
                padding: const EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).brightness == Brightness.dark
                          ? Color.fromARGB(255, 9, 9, 9)
                          : Colors.white,
                      Theme.of(context).brightness == Brightness.dark
                          ? Color(0xFF082032)
                          : Color.fromARGB(255, 188, 186, 186),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: !_challengeTicketPurchased
                    ? Column(
                        children: [
                          SizedBox(height: 20),
                          Text(
                            'As a creator on Baakhapaa, you have the power to share your unique voice and creativity with the art of storytelling.',
                            style: TextStyle(fontSize: 16),
                          ),
                          SizedBox(height: 20),
                          Text(
                            'This challenge will enhance your art of story writing by our judge and reviewed by our expert team of writers. Renowned judges will evaluate your work, offering invaluable feedback from a panel of established writing professionals.',
                            style: TextStyle(fontSize: 16),
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Share a story that close to your heart under 1000 words. A well written story will get a chance to participate in our Creator challenge to compete for a grand prize of Iphone 15 and along with many other gifts.',
                            style: TextStyle(fontSize: 16),
                          ),
                          SizedBox(height: 20),
                          Column(
                            // crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 10,
                              ),
                              Row(
                                children: [
                                  Text(
                                    '1. Purchased ticket to challenge. ',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  _challengeTicketPurchased
                                      ? Icon(
                                          Icons.check_circle,
                                          color: Colors.amber,
                                        )
                                      : Icon(
                                          Icons.cancel,
                                          color: Colors.red,
                                        ),
                                ],
                              ),
                              _challengeTicketPurchased
                                  ? Container()
                                  : Center(
                                      child: Column(
                                        children: [
                                          SizedBox(
                                            height: 20,
                                          ),
                                          InkWell(
                                            onTap: () {
                                              Navigator.of(context).pushNamed(
                                                SingleProductScreen.routeName,
                                                arguments: 234,
                                              );
                                            },
                                            child: AppButttons(
                                              textColor: Colors.white,
                                              backgroundColor: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.light
                                                  ? Colors.amber
                                                  : Colors.black,
                                              borderColor: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.light
                                                  ? Colors.black
                                                  : Colors.amber.shade500,
                                              text: "Buy Ticket",
                                              size: 250,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ],
                          ),
                        ],
                      )
                    : Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            SizedBox(height: 60),
                            TextButton(
                              onPressed: _pasteFromClipboard,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.paste,
                                    color: Colors.amber,
                                  ),
                                  Text(
                                    'CLICK HERE TO PASTE',
                                    style: TextStyle(color: Colors.amber),
                                  ),
                                ],
                              ),
                            ),
                            TextInputWordCount(
                              controller: _scriptController,
                              labelText: 'Script Writing',
                              hintText: 'Start Writing here ..',
                              onWordCountChanged: (int count) {},
                              maxWords: 1000,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your script';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 60),
                            UploadWidget(onImageSelected: _onImageSelected),
                            Text(
                                'NOTE: Image is optional. Please feel free to choose any image that potrays your script.'),
                            SizedBox(height: 60),
                            Center(
                              child: InkWell(
                                onTap: submitRequest,
                                child: AppButttons(
                                  textColor: Colors.white,
                                  backgroundColor:
                                      Theme.of(context).brightness ==
                                              Brightness.light
                                          ? Colors.amber
                                          : Colors.black,
                                  borderColor: Theme.of(context).brightness ==
                                          Brightness.light
                                      ? Colors.black
                                      : Colors.amber.shade500,
                                  text: "APPLY NOW",
                                  size: 250,
                                ),
                              ),
                            ),
                            SizedBox(height: 60),
                          ],
                        ),
                      ),
              ),
            ),
    );
  }
}
