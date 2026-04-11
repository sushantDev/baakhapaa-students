import 'dart:io';

import 'package:baakhapaa/models/url.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../widgets/app_button.dart';
import '../../widgets/loading.dart';
import 'package:flick_video_player/flick_video_player.dart';
import 'package:flutter/material.dart';
import '../../utils/puppet_screen_mapping.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upgrader/upgrader.dart';
import '../../widgets/simple_youtube_player.dart';
import 'package:video_player/video_player.dart';

import '../../providers/auth.dart';
import '../../widgets/my_upgrader_messages.dart';
import '../shorts/shorts_screen.dart';
import '../../utils/debug_logger.dart';

class AdsScreen extends StatefulWidget {
  static const routeName = '/ads-screen';
  const AdsScreen({Key? key}) : super(key: key);

  @override
  State<AdsScreen> createState() => _AdsScreenState();
}

class _AdsScreenState extends State<AdsScreen> with PuppetInteractionMixin {
  var _isInit = true;
  List<dynamic> _advertisement = [];
  late FlickManager flickManager;
  late SharedPreferences prefs;
  late bool hasRun;


  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() async {
    prefs = await SharedPreferences.getInstance();
    hasRun = prefs.getBool('hasRunAds') ?? false;

    if (hasRun) Navigator.pushReplacementNamed(context, ShortsScreen.routeName);

    if (_isInit && !hasRun) {
      var auth = Provider.of<Auth>(context, listen: false);
      auth.getAdvertisement().then((_) {
        setState(() {
          _advertisement = auth.advertisement;
        });

        if (_advertisement.isNotEmpty) {
          if (_advertisement.first['video_source'] != 'youtube') {
            flickManager = FlickManager(
              videoPlayerController: VideoPlayerController.networkUrl(Uri.parse(
                  '${Url.mediaUrl}/${_advertisement.first['video_url']}')),
            );
          }
          // No need to initialize YouTube player here as it's handled by the SimpleYouTubePlayer
        }
      });

      // Check the last time the app was opened
      DateTime lastOpenTime = DateTime.parse(
          prefs.getString('lastOpenTime') ?? DateTime.now().toString());

      // Check if one week has passed since the last open
      if (DateTime.now().difference(lastOpenTime).inDays >= 7) {
        // Update hasRun to true
        prefs.setBool('hasRunAds', true);

        // Update lastOpenTime to the current time
        prefs.setString('lastOpenTime', DateTime.now().toString());
      }
    }
    _isInit = false;
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    try {
      if (_advertisement.isNotEmpty) {
        if (_advertisement.first['video_source'] != 'youtube') {
          flickManager.dispose();
        }
      }
    } catch (e) {
      DebugLogger.error("Error disposing controllers: $e");
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: UpgradeAlert(
        showLater: false,
        barrierDismissible: false,
        showIgnore: false,
        dialogStyle: Platform.isIOS
            ? UpgradeDialogStyle.cupertino
            : UpgradeDialogStyle.material,
        upgrader: Upgrader(
          debugDisplayAlways: false,
          messages: MyUpgraderMessages(),
        ),
        child: SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                  opacity: 0.2,
                  image: CachedNetworkImageProvider(
                      "${Url.mediaUrl}/assets/doodle.jpg"),
                  fit: BoxFit.fill),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 40,
                ),
                Container(
                  margin: const EdgeInsets.all(8.0),
                  child: Text(
                    'Play, Learn & Earn',
                    style: TextStyle(
                      fontSize: 25,
                    ),
                  ),
                ),
                SizedBox(
                  height: 10,
                ),
                _advertisement.length > 0
                    ? _advertisement.first['video_source'] == 'youtube'
                        ? AspectRatio(
                            aspectRatio: 16 / 9,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SimpleYouTubePlayer(
                                videoId: _advertisement.first['video_url']
                                    .toString(),
                                autoPlay: true,
                              ),
                            ),
                          )
                        : Container(
                            height: 550,
                            width: double.infinity,
                            child: FlickVideoPlayer(
                              flickManager: flickManager,
                            ),
                          )
                    : Loading(),
                SizedBox(
                  height: 40,
                ),
                InkWell(
                  onTap: () {
                    prefs.setBool('hasRunAds', true);
                    Navigator.pushReplacementNamed(
                        context, ShortsScreen.routeName);
                    if (_advertisement.isNotEmpty &&
                        _advertisement.first['video_source'] != 'youtube') {
                      flickManager.dispose();
                    }
                  },
                  child: AppButttons(
                      textColor: Colors.white,
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.light
                              ? Color(0xff24b7c1)
                              : Colors.black,
                      borderColor:
                          Theme.of(context).brightness == Brightness.light
                              ? Colors.black
                              : Colors.amber.shade500,
                      text: "SKIP ADS",
                      size: 300),
                ),
                SizedBox(
                  height: 40,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
