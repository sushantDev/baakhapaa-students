import 'package:baakhapaa/models/url.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../utils/puppet_screen_mapping.dart';
import 'package:provider/provider.dart';
import 'package:flick_video_player/flick_video_player.dart';
import 'package:video_player/video_player.dart';

import '../../widgets/loading.dart';
import '../../providers/auth.dart';
import '../story/story_screen.dart';
import '../../widgets/simple_youtube_player.dart';
import '../../utils/debug_logger.dart';

class IntroScreen extends StatefulWidget {
  static const routeName = '/intro-screen';
  const IntroScreen({Key? key}) : super(key: key);

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> with PuppetInteractionMixin {
  var _isInit = true;
  List<dynamic> _advertisement = [];
  late FlickManager flickManager;

  @override
  void didChangeDependencies() {
    if (_isInit) {
      var auth = Provider.of<Auth>(context, listen: false);
      auth.getAdvertisement().then((_) {
        setState(() {
          _advertisement = auth.advertisement;
        });

        if (_advertisement.length > 0) {
          if (_advertisement.last['video_source'] != 'youtube') {
            flickManager = FlickManager(
              videoPlayerController: VideoPlayerController.networkUrl(Uri.parse(
                  '${Url.mediaUrl}/${_advertisement.last['video_url']}')),
            );
          }
          // No need to initialize YouTube player here as it's handled by SimpleYouTubePlayer
        }
      });
    }
    _isInit = false;
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    try {
      if (_advertisement.isNotEmpty) {
        if (_advertisement.last['video_source'] != 'youtube') {
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
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
              opacity: 0.1,
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
                'How To Play',
                style: TextStyle(
                  fontSize: 25,
                ),
              ),
            ),
            SizedBox(
              height: 10,
            ),
            _advertisement.length > 0
                ? _advertisement.last['video_source'] == 'youtube'
                    ? AspectRatio(
                        aspectRatio: 16 / 9,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SimpleYouTubePlayer(
                            videoId:
                                _advertisement.last['video_url'].toString(),
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
                Navigator.pushReplacementNamed(context, StoryScreen.routeName);
                if (_advertisement.isNotEmpty &&
                    _advertisement.last['video_source'] != 'youtube') {
                  flickManager.dispose();
                }
              },
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  width: double.infinity,
                  height: 70,
                  child: Stack(clipBehavior: Clip.none, children: [
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          width: screenWidth <= 400
                              ? (0.9 * MediaQuery.of(context).size.width)
                              : screenWidth <= 500
                                  ? (0.9 * MediaQuery.of(context).size.width)
                                  : screenWidth >= 600 && screenWidth < 1000
                                      ? (0.97 *
                                          MediaQuery.of(context).size.width)
                                      : (0.2 *
                                          MediaQuery.of(context).size.width),
                          height: 60,
                          padding: const EdgeInsets.only(right: 5, bottom: 10),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.amber
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(width: 2),
                          ),
                          child: Stack(clipBehavior: Clip.none, children: [
                            Positioned(
                              top: -20,
                              child: Container(
                                width: screenWidth <= 400
                                    ? (0.9 * MediaQuery.of(context).size.width)
                                    : screenWidth <= 500
                                        ? (0.9 *
                                            MediaQuery.of(context).size.width)
                                        : screenWidth >= 600 &&
                                                screenWidth < 1000
                                            ? (0.97 *
                                                MediaQuery.of(context)
                                                    .size
                                                    .width)
                                            : (0.2 *
                                                MediaQuery.of(context)
                                                    .size
                                                    .width),
                                height: 70,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.amber
                                        : Colors.black,
                                    width: 2,
                                  ),
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.black
                                      : Color(0xff24b7c1),
                                ),
                                child: Center(child: Text('Skip Intro')),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
