import 'package:baakhapaa/screens/leaderboard/leaderboard_screen.dart';
import 'package:baakhapaa/screens/challenges/challenge_detail_screen.dart';
import 'package:baakhapaa/screens/story/story_screen.dart';
import 'package:baakhapaa/screens/subscription/subscription_screen.dart';
import 'package:baakhapaa/screens/user/user_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../helpers/helpers.dart';
import '../../providers/auth.dart';
import '../../screens/shop/single_product_screen.dart';
import '../../screens/shorts/single_shorts_screen.dart';
import '../../screens/story/video_screen.dart';
import '../../widgets/app_button.dart';

class Popup extends StatefulWidget {
  final List popupArr;
  final Widget child;

  const Popup({
    Key? key,
    required this.popupArr,
    required this.child,
  }) : super(key: key);

  @override
  State<Popup> createState() => _PopupState();
}

class _PopupState extends State<Popup> {
  late List<bool> _popupVisibility;
  bool _popupTapped = false;

  @override
  void initState() {
    super.initState();
    if (widget.popupArr.isNotEmpty) {
      _popupVisibility =
          List.generate(widget.popupArr.length, (index) => false);
      _popupVisibility[0] = true;
    } else {
      _popupVisibility = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.popupArr != [] || widget.popupArr.isNotEmpty) {
      return Stack(
        children: [
          // ignore: unnecessary_null_comparison
          (widget.child != null) ? widget.child : Container(),
          for (int i = 0; i < widget.popupArr.length; i++)
            Visibility(
              visible: _popupVisibility[i],
              child: GestureDetector(
                onTap: () {
                  dismisPopup(i);
                },
                child: Container(
                  color: Color.fromRGBO(1, 1, 2, 0.495),
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.8,
                      child: Stack(
                        children: [
                          Card(
                            elevation: 8.0,
                            margin: EdgeInsets.all(20.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                            child: Container(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  widget.popupArr[i]['images'] != null &&
                                          widget
                                              .popupArr[i]['images'].isNotEmpty
                                      ? Column(
                                          children: [
                                            CachedNetworkImage(
                                              imageUrl: widget.popupArr[i]
                                                  ['images'][0]['url'],
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                            ),
                                            SizedBox(height: 10),
                                          ],
                                        )
                                      : Container(height: 0),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9),
                                    child: Text(
                                      widget.popupArr[i]['title'],
                                      style: TextStyle(
                                          fontSize: 16.0,
                                          fontWeight: FontWeight.w800),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Container(
                                      height: 60,
                                      width: 260,
                                      child: Text(
                                        widget.popupArr[i]['description'],
                                        style: TextStyle(fontSize: 14.0),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: InkWell(
                                      onTap: () async {
                                        var gotoUrl =
                                            widget.popupArr[i]['goto'];
                                        if (gotoUrl == null) {
                                          var gotoPlatformId = widget
                                              .popupArr[i]['goto_platform_id'];
                                          var gotoPlatformType =
                                              widget.popupArr[i]
                                                  ['goto_platform_type'];

                                          if (gotoPlatformType ==
                                              'App\\Product') {
                                            Navigator.of(context).pushNamed(
                                              SingleProductScreen.routeName,
                                              arguments: gotoPlatformId,
                                            );
                                          } else if (gotoPlatformType ==
                                              'App\\Episode') {
                                            Navigator.of(context).pushNamed(
                                              VideoScreen.routeName,
                                              arguments: gotoPlatformId,
                                            );
                                          } else if (gotoPlatformType ==
                                              'App\\Leaderboard') {
                                            Navigator.pushNamed(context,
                                                LeaderboardScreen.routeName);
                                          } else if (gotoPlatformType ==
                                              'App\\Story') {
                                            Navigator.pushNamed(
                                                context, StoryScreen.routeName);
                                          } else if (gotoPlatformType ==
                                              'App\\Setting') {
                                            Navigator.pushNamed(
                                                context, UserScreen.routeName);
                                          } else if (gotoPlatformType ==
                                              'App\\Challenge') {
                                            Navigator.of(context).pushNamed(
                                              ChallengeDetailScreen.routeName,
                                              arguments: gotoPlatformId,
                                            );
                                          } else if (gotoPlatformType ==
                                              'App\\Shorts') {
                                            Navigator.of(context).pushNamed(
                                              SingleShortsScreen.routeName,
                                              arguments: gotoPlatformId,
                                            );
                                          } else if (gotoPlatformType ==
                                              'App\\Subscription') {
                                            Navigator.pushNamed(context,
                                                SubscriptionScreen.routeName);
                                          }
                                        } else {
                                          final Uri _url = Uri.parse(gotoUrl);
                                          if (!await launchUrl(_url)) {
                                            throw Exception(
                                                'Could not launch $_url');
                                          }
                                        }
                                        Provider.of<Auth>(context,
                                                listen: false)
                                            .popupViewed(
                                                widget.popupArr[i]['id'])
                                            .then((_) {
                                          dismisPopup(i);
                                          showScaffoldMessenger(context,
                                              'Please refresh the page for permanently dismiss.');
                                        });
                                        dismisPopup(i);
                                      },
                                      child: AppButttons(
                                        textColor: Colors.black,
                                        backgroundColor: Colors.white,
                                        borderColor: Colors.black,
                                        text: "Let's Go!",
                                        size: 100,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            right: 20.0,
                            top: 25.0,
                            child: GestureDetector(
                              onTap: () {
                                Provider.of<Auth>(context, listen: false)
                                    .popupViewed(widget.popupArr[i]['id'])
                                    .then((_) {
                                  dismisPopup(i);
                                  showScaffoldMessenger(context,
                                      'Please refresh the page for permanently dismiss.');
                                });
                              },
                              child: Icon(
                                Icons.close,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }
    return Container();
  }

  void dismisPopup(int i) {
    setState(() {
      if (!_popupTapped) {
        // If no popup has been tapped yet, set visibility of all popups except the current one to true
        for (int j = 0; j < widget.popupArr.length; j++) {
          if (j != i) {
            _popupVisibility[j] = true;
          }
        }
        _popupTapped = true;
      }
      _popupVisibility[i] = false;
    });
  }
}
