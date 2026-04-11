import 'package:baakhapaa/models/url.dart';
import 'package:baakhapaa/screens/auth/login_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth.dart';
import '../../widgets/app_button.dart';

class VerifyOtpScreen extends StatefulWidget {
  static const routeName = '/veify_otp_screen';

  const VerifyOtpScreen({Key? key}) : super(key: key);

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final passwordController = TextEditingController();
  final otpController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    passwordController.dispose();
    otpController.dispose();
    super.dispose();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('An error occurred'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text('Okay'),
          ),
        ],
      ),
    );
  }

  void startOrStopLoading() {
    setState(() {
      _isLoading = !_isLoading;
    });
  }

  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
    ));
  }

  void changePassword() async {
    try {
      startOrStopLoading();
      final String email = ModalRoute.of(context)!.settings.arguments as String;
      await Provider.of<Auth>(context, listen: false)
          .changePassword(email, otpController.text, passwordController.text)
          .then((_) {
        showSnackBar('Your password has been changed successfully.');
        Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
      });
      startOrStopLoading();
    } catch (error) {
      var errorMessage = 'Could not change your password.';
      _showErrorDialog(errorMessage);
      startOrStopLoading();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Change Password'),
      ),
      body: _isLoading
          ? Loading()
          : Container(
              decoration: BoxDecoration(
                  image: DecorationImage(
                      opacity: 0.1,
                      image: CachedNetworkImageProvider(
                          "${Url.mediaUrl}/assets/sketch.png"),
                      fit: BoxFit.fill)),
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Amazing gift and rewards are waiting',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                    Container(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextFormField(
                          style: TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            labelText: 'Enter OTP',
                            labelStyle: TextStyle(color: Colors.black),
                            fillColor: Colors.white,
                            filled: true,
                            prefixIcon: Icon(
                              Icons.person,
                              color: Colors.black,
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value!.isEmpty) return 'Please input Otp';
                            return null;
                          },
                          controller: otpController,
                        ),
                      ),
                    ),
                    Container(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: TextFormField(
                              style: TextStyle(color: Colors.black),
                              decoration: InputDecoration(
                                labelText: 'Enter New Password',
                                labelStyle: TextStyle(color: Colors.black),
                                fillColor: Colors.white,
                                filled: true,
                                prefixIcon: Icon(
                                  Icons.person,
                                  color: Colors.black,
                                ),
                              ),
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value!.isEmpty)
                                  return 'Please input password';
                                return null;
                              },
                              controller: passwordController,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: changePassword,
                      child: AppButttons(
                          textColor: Colors.white,
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.black
                                  : Colors.amber.shade500,
                          borderColor:
                              Theme.of(context).brightness == Brightness.light
                                  ? Colors.black
                                  : Colors.amber.shade500,
                          text: "Submit",
                          size: 400),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}
