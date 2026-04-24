import 'package:flutter/material.dart';
import 'package:baakhapaa/helpers/helpers.dart';
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/screens/story/video_screen.dart';
import 'package:baakhapaa/widgets/header.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/puppet_screen_mapping.dart';
import 'package:provider/provider.dart';
import '../../utils/debug_logger.dart';
import '../../widgets/skeleton_loading.dart';

class CreatorRequestScreen extends StatefulWidget {
  static const routeName = '/creator-request-screen';

  const CreatorRequestScreen({Key? key}) : super(key: key);

  @override
  State<CreatorRequestScreen> createState() => _CreatorRequestScreenState();
}

class _CreatorRequestScreenState extends State<CreatorRequestScreen>
    with PuppetInteractionMixin {
  var _isInit = true;
  var _isLoading = true;
  var _hasError = false;
  late Map<String, dynamic> _creatorPreferences = {};
  int _userBalance = 0;

  @override
  void didChangeDependencies() {
    if (_isInit) {
      var auth = Provider.of<Auth>(context, listen: false);
      auth.fetchCreatorPreferences().then((_) {
        setState(() {
          _creatorPreferences = auth.creatorPreferences;
          _userBalance = auth.userAvailableCoins;
          _isLoading = false;
        });
      }).catchError((error) {
        DebugLogger.api('Error loading creator preferences: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }
      });
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  // Helper function to parse boolean values from different data types
  bool _parseBoolValue(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == "1" || value.toLowerCase() == "true";
    return false;
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
            child: Text(context.l10n.ok),
          ),
        ],
      ),
    );
  }

  bool get _completedEpisodes {
    final episodes = _creatorPreferences['creators_episode'];
    if (episodes == null || episodes is! List || episodes.isEmpty) {
      return false;
    }
    return episodes.every((episode) => (episode['watched'] == true));
  }

  int get _minCreatorPoints {
    final val = _creatorPreferences['min_creator_points'];
    if (val == null) return 0;
    if (val is int) return val;
    return int.tryParse(val.toString()) ?? 0;
  }

  void submitRequest() {
    if (_parseBoolValue(_creatorPreferences['requested'])) {
      return _showErrorDialog(
          'Your request for the creator role has been received. Please allow some time for Baakhapaa Admin to review and approve your request. You will receive an email notification once a decision has been made.');
    }
    if (!(_userBalance >= _minCreatorPoints)) {
      return _showErrorDialog('You do not have enough points.');
    }
    if (!_completedEpisodes) {
      return _showErrorDialog(
          'You have not completed all the required episodes.');
    }

    setState(() {
      _isLoading = true;
    });

    Provider.of<Auth>(context, listen: false).creatorRequest().then((_) {
      setState(() {
        _isLoading = false;
        // Update the creator preferences to reflect the request was submitted
        _creatorPreferences['requested'] = true;
      });

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Success!!'),
          content: Text(
              'Your request for the creator role has been received. Please allow some time for Baakhapaa Admin to review and approve your request. You will receive an email notification once a decision has been made.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: Text(context.l10n.ok),
            ),
          ],
        ),
      );
    }).catchError((error) {
      setState(() {
        _isLoading = false;
      });

      _showErrorDialog('Oops!! Some error occurred. Please try again.');
      DebugLogger.api('Creator request error: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: header(
          context: context,
          titleText: '${context.l10n.creator} ${context.l10n.request}'),
      body: _isLoading
          ? _buildLoadingState()
          : _hasError
              ? _buildErrorState()
              : Container(
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
                            : Color.fromARGB(255, 248, 248, 248),
                      ],
                    ),
                  ),
                  child: SingleChildScrollView(
                    physics: BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        // Hero Section
                        _buildHeroSection(),

                        // Benefits Section
                        _buildBenefitsSection(),

                        // Requirements Section
                        _buildRequirementsSection(),

                        // Episodes Section
                        _buildEpisodesSection(),

                        // Submit Button
                        _buildSubmitSection(),

                        SizedBox(height: 100), // Bottom padding
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
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
                : Color.fromARGB(255, 248, 248, 248),
          ],
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.all(24.0),
        child: ListSkeleton(itemCount: 5),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load content',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                  _isInit = true;
                });
                didChangeDependencies();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF2A2A2A)
                : Colors.white,
            Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF1E1E1E)
                : Colors.grey.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 0,
            offset: Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.purple.shade400],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: CachedNetworkImage(
              imageUrl: 'https://baakhapaa.com/assets/img/logo/logo3.png',
              height: 80,
              errorWidget: (context, url, error) => Icon(
                Icons.account_circle_rounded,
                size: 80,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(height: 24),
          Text(
            context.l10n.becomeACreator,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 12),
          Text(
            context.l10n.joinCreatorCommunity,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsSection() {
    final benefits = [
      {
        'icon': Icons.video_library_rounded,
        'title': context.l10n.contentCreation,
        'description': context.l10n.createAndShareContent,
        'color': Colors.red,
      },
      {
        'icon': Icons.people_rounded,
        'title': context.l10n.buildFollowing,
        'description': context.l10n.growYourAudience,
        'color': Colors.blue,
      },
      {
        'icon': Icons.monetization_on_rounded,
        'title': context.l10n.monetization,
        'description': context.l10n.earnThroughMonetization,
        'color': Colors.green,
        'showCoin': true,
      },
      {
        'icon': Icons.star_rounded,
        'title': context.l10n.recognition,
        'description': context.l10n.getRewardsForContributions,
        'color': Colors.amber,
      },
    ];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).brightness == Brightness.dark
                      ? Color(0xFF2A2A2A)
                      : Colors.white,
                  Theme.of(context).brightness == Brightness.dark
                      ? Color(0xFF1E1E1E)
                      : Colors.grey.shade50,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.15),
                  blurRadius: 15,
                  spreadRadius: 0,
                  offset: Offset(0, 5),
                ),
              ],
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange.shade400, Colors.red.shade400],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.creatorBenefits,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            context.l10n.whatYouCanAchieve,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                GridView.count(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                  children: benefits.map((benefit) {
                    return Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            (benefit['color'] as Color).withValues(alpha: 0.1),
                            (benefit['color'] as Color).withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (benefit['color'] as Color)
                              .withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (benefit['showCoin'] == true) ...[
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  benefit['icon'] as IconData,
                                  color: benefit['color'] as Color,
                                  size: 32,
                                ),
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Image.asset(
                                    'assets/images/coins.png',
                                    width: 12,
                                    height: 12,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Icon(
                              benefit['icon'] as IconData,
                              color: benefit['color'] as Color,
                              size: 32,
                            ),
                          ],
                          SizedBox(height: 8),
                          Text(
                            benefit['title'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 4),
                          Text(
                            benefit['description'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              height: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementsSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF2A2A2A)
                : Colors.white,
            Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF1E1E1E)
                : Colors.grey.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.15),
            blurRadius: 15,
            spreadRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.cyan.shade400],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.checklist_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Image.asset(
                          'assets/images/coins.png',
                          width: 8,
                          height: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.requirements,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      context.l10n.meetCreatorCriteria,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Points Requirement
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.amber.withValues(alpha: 0.1),
                  Colors.orange.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _userBalance >= _minCreatorPoints
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.amber.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _userBalance >= _minCreatorPoints
                        ? Colors.green
                        : Colors.amber,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _userBalance >= _minCreatorPoints
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 20,
                        )
                      : Image.asset(
                          'assets/images/coins.png',
                          width: 20,
                          height: 20,
                        ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${context.l10n.minimum}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            ' ${context.l10n.points} ${context.l10n.required}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${context.l10n.need} ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Image.asset(
                            'assets/images/coins.png',
                            width: 14,
                            height: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '$_minCreatorPoints points (You have ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Image.asset(
                            'assets/images/coins.png',
                            width: 14,
                            height: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '$_userBalance)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  _userBalance >= _minCreatorPoints
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: _userBalance >= _minCreatorPoints
                      ? Colors.green
                      : Colors.red,
                  size: 28,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodesSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF2A2A2A)
                : Colors.white,
            Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF1E1E1E)
                : Colors.grey.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.15),
            blurRadius: 15,
            spreadRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.pink.shade400],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.play_circle_filled_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.l10n.required} ${context.l10n.episodes}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      // 'Complete these episodes to qualify',
                      context.l10n.completeEpisodesToQualify,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Episodes List
          _buildEpisodesRequired(_creatorPreferences['creators_episode']),
        ],
      ),
    );
  }

  Widget _buildEpisodesRequired(List<dynamic> episodes) {
    return Column(
      children: episodes.map<Widget>((episode) {
        bool isWatched = _parseBoolValue(episode['watched']);
        DebugLogger.api(
            'Creator Request Episode ${episode['title']}: watched value = ${episode['watched']}, isWatched = $isWatched');
        return InkWell(
          onTap: () {
            Navigator.of(context)
                .pushNamed(VideoScreen.routeName, arguments: episode['id']);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  isWatched
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  isWatched
                      ? Colors.green.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isWatched
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isWatched ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isWatched ? Icons.check_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episode['title']?.toString() ?? 'Episode',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (episode['description'] != null) ...[
                        SizedBox(height: 4),
                        Text(
                          episode['description'].toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (episode['points'] != null && episode['points'] != 0) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/coins.png',
                        width: 16,
                        height: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '${episode['points']}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 12),
                ],
                Icon(
                  isWatched ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isWatched ? Colors.green : Colors.grey,
                  size: 28,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubmitSection() {
    bool canSubmit = _userBalance >= _minCreatorPoints &&
        _completedEpisodes &&
        !_parseBoolValue(_creatorPreferences['requested']);

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF2A2A2A)
                : Colors.white,
            Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF1E1E1E)
                : Colors.grey.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.15),
            blurRadius: 15,
            spreadRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          if (_creatorPreferences['requested']) ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withValues(alpha: 0.1),
                    Colors.cyan.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_rounded, color: Colors.blue, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      // 'Your request is under review. You will receive an email notification once a decision has been made.',
                      context.l10n.requestUnderReview,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
          ],
          Container(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canSubmit ? submitRequest : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canSubmit ? Colors.blue : Colors.grey,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _creatorPreferences['requested']
                        ? Icons.pending_rounded
                        : Icons.send_rounded,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    _creatorPreferences['requested']
                        ? '${context.l10n.requestSubmitted}'
                        : '${context.l10n.submitCreatorRequest}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!canSubmit && !_creatorPreferences['requested']) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_rounded, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please meet all requirements before submitting your request.',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
