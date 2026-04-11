import 'package:baakhapaa/models/url.dart';

import '../../widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:flick_video_player/flick_video_player.dart';

import '../../providers/auth.dart';
import './login_screen.dart';
import './register_screen.dart';

class WelcomeScreen extends StatefulWidget {
  static const routeName = '/welcome-screen';

  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  var _isInit = true;
  FlickManager? flickManager;
  var _isLoading = true;

  @override
  void didChangeDependencies() {
    if (_isInit) {
      var auth = Provider.of<Auth>(context, listen: false);
      auth.getAdvertisement().then((_) {
        if (!mounted) return;
        try {
          Map<String, dynamic> _intro;

          _intro = auth.advertisement[1];

          flickManager = FlickManager(
            videoPlayerController: VideoPlayerController.networkUrl(
                Uri.parse('${Url.mediaUrl}/${_intro['video_url']}')),
          );

          setState(() {
            _isLoading = false;
          });
        } catch (e) {
          // If advertisement data is missing or invalid, stay in loading state
        }
      }).catchError((_) {
        // Network error - stay in loading state
      });
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    flickManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Loading()
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  children: <Widget>[
                    Flexible(
                      flex: 2,
                      child: FlickVideoPlayer(
                        flickManager: flickManager!,
                      ),
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    Center(
                      child: Flexible(
                        flex: 1,
                        child: Column(
                          children: [
                            Text(
                              'Let\'s get started',
                              style: TextStyle(
                                fontSize: 22,
                              ),
                            ),
                            SizedBox(
                              height: 10,
                            ),
                            Text(
                              'Login to your account below or signup for an amazing experience',
                              style: TextStyle(
                                fontSize: 18,
                              ),
                            ),
                            SizedBox(
                              height: 10,
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pushReplacementNamed(
                                    LoginScreen.routeName);
                              },
                              child: Text('Have An Account? Login'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pushReplacementNamed(
                                    RegisterScreen.routeName);
                              },
                              child: Text('Join Us, It\'s free'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
