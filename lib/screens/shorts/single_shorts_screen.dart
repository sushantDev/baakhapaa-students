import 'package:baakhapaa/widgets/skeleton_loading.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/shorts_detail.dart';
import '../../widgets/shorts_side_bar.dart';
import '../../widgets/shorts_video_tile.dart';
import '../../widgets/footer.dart';
import '../../providers/shorts.dart';
import '../../providers/video_state_provider.dart';
import '../../widgets/header.dart';
import '../../utils/puppet_screen_mapping.dart';

class SingleShortsScreen extends StatefulWidget {
  static const routeName = '/single-shorts-screen';

  const SingleShortsScreen({Key? key}) : super(key: key);

  @override
  State<SingleShortsScreen> createState() => _SingleShortsScreenState();
}

class _SingleShortsScreenState extends State<SingleShortsScreen>
    with PuppetInteractionMixin {
  bool _isInit = false;
  bool _isLoading = true;
  late Map _shorts = {};
  late int _navId;
  bool _isVideoPlaying = true;
  // Notifier used to trigger 2x fast-forward from the edge overlays
  // (the sidebar intercepts right-edge touches, so we handle it here)
  final ValueNotifier<bool> _fastForwardNotifier = ValueNotifier(false);

  @override
  void didChangeDependencies() {
    if (!_isInit) {
      // Safely handle arguments that might be either int or String
      final arguments = ModalRoute.of(context)!.settings.arguments;
      if (arguments is int) {
        _navId = arguments;
      } else if (arguments is String) {
        _navId = int.tryParse(arguments) ?? 0;
      } else {
        _navId = 0; // Default fallback
      }

      var shortsProvider = Provider.of<Shorts>(context, listen: false);
      shortsProvider.fetchSingleShorts(_navId).then((value) {
        if (mounted) {
          setState(() {
            _shorts = shortsProvider.singleShorts;
            _isLoading = false;
            _isVideoPlaying = true; // Ensure video is set to play
          });

          // Explicitly clear any existing active video to ensure this single video plays
          final videoStateProvider =
              Provider.of<VideoStateProvider>(context, listen: false);
          videoStateProvider.clearAllActiveVideos();

          // Set puppet context for this specific shorts video
          setPuppetShortsContext(_navId);
        }
      });
      _isInit = true;
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _fastForwardNotifier.dispose();
    super.dispose();
  }

  void _pauseVideo() {
    setState(() {
      _isVideoPlaying = false;
    });
  }

  void _playPauseVideo() {
    setState(() {
      _isVideoPlaying = !_isVideoPlaying;
    });
  }

  void likeAndUnlike(int shortsId) {
    setState(() {
      if (_shorts['id'] == shortsId) {
        _shorts['liked'] = !(_shorts['liked'] ?? false);
        _shorts['likes'] = _shorts['liked']
            ? (_shorts['likes'] ?? 0) + 1
            : (_shorts['likes'] ?? 0) - 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final footerInset = Footer.estimatedHeight(context, fullBleed: true);

    return Scaffold(
      extendBody: true,
      appBar: header(
          context: context,
          titleText: _shorts['title'] != null ? _shorts['title'] : ''),
      body: _isLoading
          ? const ShortsVideoSkeleton()
          : Container(
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  ShortsVideoTile(
                    video: _shorts['video_url'],
                    currentIndex: 0,
                    snappedPageIndex: 0,
                    isVideoPlaying: _isVideoPlaying,
                    onPlayPause: _playPauseVideo,
                    shortsId: _shorts['id'],
                    likeAndUnlikeCallback: likeAndUnlike,
                    isLiked: _shorts['liked'] ?? false,
                    fastForwardNotifier: _fastForwardNotifier,
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: footerInset,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            constraints: BoxConstraints(
                              maxHeight:
                                  MediaQuery.of(context).size.height / 3,
                            ),
                            child: SingleChildScrollView(
                              child: ShortsDetail(
                                _shorts['title'],
                                _shorts['description'],
                                _shorts['user_id'],
                                _shorts['username'],
                                _shorts['shorts_topic'],
                                _shorts['created_at'],
                                _shorts['challenge_details'],
                                _pauseVideo,
                                linkedContent: _shorts['linked_content'],
                                collaborators: _shorts['collaborators'],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ShortsSideBar(
                            index: 2,
                            shortsId: _shorts['id'],
                            image: _shorts['user_image'] == null
                                ? 'https://baakhapaa.com/images/logo.png'
                                : _shorts['user_image'],
                            questions: _shorts['questions'],
                            likes: _shorts['likes'],
                            liked: _shorts['liked'],
                            lives: _shorts['lives'],
                            title: _shorts['title'],
                            coins: _shorts['coins'],
                            coins_users: _shorts['coins_users'],
                            viewed: _shorts['viewed'],
                            user_id: _shorts['user_id'],
                            username: _shorts['username'],
                            fetchMostLikedShortsCallback: () {},
                            fetchMostPointsShortsCallback: () {},
                            fetchLatestShortsCallback: () {},
                            fetchOldestShortsCallback: () {},
                            fetchRandomShortsCallback: () {},
                            fetchFilteredShortsCallback: () {},
                            likeAndUnlikeCallback: () {},
                            onPlayPause: _pauseVideo,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Transparent edge overlays placed on top of the sidebar so
                  // long-press on the right/left edges always reaches us.
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 0,
                    width: MediaQuery.of(context).size.width * 0.25,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onLongPressStart: (_) =>
                          _fastForwardNotifier.value = true,
                      onLongPressEnd: (_) => _fastForwardNotifier.value = false,
                      onLongPressCancel: () =>
                          _fastForwardNotifier.value = false,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    width: MediaQuery.of(context).size.width * 0.25,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onLongPressStart: (_) =>
                          _fastForwardNotifier.value = true,
                      onLongPressEnd: (_) => _fastForwardNotifier.value = false,
                      onLongPressCancel: () =>
                          _fastForwardNotifier.value = false,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
