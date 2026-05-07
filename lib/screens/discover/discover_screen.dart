import 'package:baakhapaa/helpers/helpers.dart';
import 'package:baakhapaa/widgets/header.dart';
import 'package:baakhapaa/widgets/subscriptionBanner.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../providers/auth.dart';
import '../../providers/challenge.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/footer.dart';
import '../../utils/exit_confirmation_dialog.dart';
import '../story/creator_story_screen.dart';
import '../story/creators_screen.dart';
import '../challenges/all_challenges_screen.dart';
import '../challenges/challenge_detail_screen.dart';
import '../../providers/puppet_interaction_provider.dart';
import '../../utils/puppet_screen_mapping.dart';
import '../../utils/debug_logger.dart';
import '../../utils/guest_auth_helper.dart';

class DiscoverScreen extends StatefulWidget {
  static const routeName = '/discover-screen';

  const DiscoverScreen({Key? key}) : super(key: key);

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with PuppetInteractionMixin {
  bool _isLoading = false;
  bool _isDisposed = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    DebugLogger.info('DiscoverScreen: initState called');
    // Add a small delay to ensure providers are fully initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) {
        DebugLogger.info(
            'DiscoverScreen: Starting to load data in postFrameCallback');

        // Initialize puppet provider
        try {
          context.read<PuppetInteractionProvider>().initState();
        } catch (e) {
          DebugLogger.puppet('Puppet provider not available: $e');
        }

        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;

    // Clear puppet interactions when leaving screen
    clearPuppetInteractions();

    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted || _isDisposed) return;

    DebugLogger.info('DiscoverScreen: _loadData called');

    if (mounted && !_isDisposed) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Perform operations with mounted checks between each step
      if (!mounted || _isDisposed) return;

      // Execute both API calls in parallel for better performance
      final List<Future> futures = [];

      // Add fetchCreators to futures
      try {
        final authProvider = Provider.of<Auth>(context, listen: false);
        if (!mounted || _isDisposed) return;
        DebugLogger.api('DiscoverScreen: Adding fetchCreators to futures');
        futures.add(authProvider.fetchCreators());
      } catch (e) {
        DebugLogger.auth('DiscoverScreen: Error setting up Auth provider: $e');
      }

      // Add fetchChallenges to futures
      try {
        final challengeProvider =
            Provider.of<Challenge>(context, listen: false);
        if (!mounted || _isDisposed) return;
        DebugLogger.api('DiscoverScreen: Adding fetchChallenges to futures');
        futures.add(challengeProvider.fetchChallenges());
      } catch (e) {
        DebugLogger.error(
            'DiscoverScreen: Error setting up Challenge provider: $e');
      }

      // Execute all API calls in parallel
      if (futures.isNotEmpty) {
        try {
          DebugLogger.api(
              'DiscoverScreen: Executing ${futures.length} API calls in parallel');
          await Future.wait(futures);
          DebugLogger.api(
              'DiscoverScreen: All API calls completed successfully');
        } catch (error) {
          DebugLogger.api(
              'DiscoverScreen: Error in parallel API calls: $error');
        }
      }

      if (!mounted || _isDisposed) return;
    } catch (error) {
      DebugLogger.error(
          'DiscoverScreen: Failed to load discover content: $error');
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load content. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted && !_isDisposed) {
        DebugLogger.info('DiscoverScreen: Setting loading state to false');
        setState(() {
          _isLoading = false;
        });

        // Refresh puppet suggestions when content loads
        refreshPuppetSuggestions();
      }
    }
  }

  Widget _buildSectionHeader(
      String title, String subtitle, IconData icon, VoidCallback onViewAll) {
    return InkWell(
      onTap: onViewAll,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(20),
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
              color: Colors.grey.withValues(alpha: 0.2),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber, Colors.orange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onViewAll,
              icon: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.amber,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorytellerCard(Map<String, dynamic> creator) {
    return Container(
      width: 160, // Increased width for better proportions
      margin: const EdgeInsets.only(right: 16),
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
            offset: Offset(0, 8),
          ),
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.8),
            blurRadius: 1,
            spreadRadius: 0,
            offset: Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () async {
          try {
            final auth = Provider.of<Auth>(context, listen: false);
            if (auth.isGuest) {
              await GuestAuthHelper.showGuestLoginDialog(
                context,
                'view storyteller profile',
              );
              return;
            }
            // Ensure we have the creator data
            if (creator['id'] != null) {
              await Navigator.of(context).pushNamed(
                CreatorStoryScreen.routeName,
                arguments: [
                  creator['id'],
                  creator['name'] ?? creator['username']
                ],
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Creator information not available'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          } catch (e) {
            DebugLogger.error('Error navigating to creator story: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Unable to open creator profile'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16), // Better padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Profile image section with enhanced design
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    width: 72, // Much larger profile image
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.amber.shade400,
                          Colors.orange.shade600,
                          Colors.deepOrange.shade400,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 0,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(3),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: creator['images'][0]['thumbnail'],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.amber.withValues(alpha: 0.1),
                                  Colors.orange.withValues(alpha: 0.1),
                                ],
                              ),
                            ),
                            child: Icon(
                              Icons.person,
                              size: 32,
                              color: Colors.amber.shade600,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.amber.withValues(alpha: 0.1),
                                  Colors.orange.withValues(alpha: 0.1),
                                ],
                              ),
                            ),
                            child: Icon(
                              Icons.person,
                              size: 32,
                              color: Colors.amber.shade600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Enhanced video badge
                  AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade500,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Color(0xFF2A2A2A)
                            : Colors.white,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 0,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      FontAwesomeIcons.video,
                      color: Colors.white,
                      size: 8,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12), // Proper spacing

              // Text section with better typography
              Column(
                children: [
                  Text(
                    '@${creator['username']}',
                    style: TextStyle(
                      fontSize: 14, // Larger, more readable text
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.grey[800],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4), // Better spacing
                  Text(
                    creator['name'] ?? 'Creator',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeCard(Map<String, dynamic> challenge) {
    final isLocked = challenge['is_locked'] == 1;
    final statusColor = isLocked ? Colors.red : Colors.green;

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
          try {
            if (!isLocked && challenge['id'] != null) {
              await Navigator.of(context).pushNamed(
                ChallengeDetailScreen.routeName,
                arguments: challenge['id'],
              );
            } else if (isLocked) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('This challenge is locked'),
                  backgroundColor: Colors.red,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Challenge information not available'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          } catch (e) {
            DebugLogger.error('Error navigating to challenge: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Unable to open challenge'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Challenge Image
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.amber, Colors.orange],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                padding: EdgeInsets.all(3),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: challenge['image_url'] != null
                      ? CachedNetworkImage(
                          imageUrl: challenge['image_url'],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.amber.withValues(alpha: 0.1),
                            child: const Icon(
                              FontAwesomeIcons.trophy,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.amber.withValues(alpha: 0.1),
                            child: const Icon(
                              FontAwesomeIcons.trophy,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.amber.withValues(alpha: 0.1),
                          child: const Icon(
                            FontAwesomeIcons.trophy,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Challenge Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isLocked ? Icons.lock : Icons.lock_open,
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            challenge['title'],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      challenge['description'] ?? 'No description',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (isLocked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'LOCKED',
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        if (challenge['point_reward'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.amber, Colors.orange],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${challenge['point_reward']}pts',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ExitConfirmationDialog.wrapWithExitConfirmation(
      context: context,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: header(
          context: context,
          titleText: context.l10n.discover,
        ),
        drawer: NavBar(),
        body: RefreshIndicator(
          onRefresh: _loadData,
          child: Container(
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
            child: _isLoading
                ? const DiscoverScreenSkeleton()
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        SubscriptionBanner(
                          bannerType: 'container',
                        ),
                        // Storytellers Section
                        _buildSectionHeader(
                          context.l10n.teachers,
                          context.l10n.creators,
                          FontAwesomeIcons.video,
                          () {
                            Navigator.pushNamed(
                                context, CreatorsScreen.routeName);
                          },
                        ),
                        const SizedBox(height: 16),
                        Consumer<Auth>(
                          builder: (_, auth, __) {
                            // Add safety check for disposed state
                            if (_isDisposed || !mounted) {
                              return const SizedBox(height: 50);
                            }

                            // Show loading indicator if we're still loading and no data
                            if (_isLoading && auth.creators.isEmpty) {
                              return const StorytellerCardsSkeleton(count: 3);
                            }

                            // Show message if no creators available
                            if (auth.creators.isEmpty) {
                              return Container(
                                height: 160,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.person_search,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'No teachers available',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      ElevatedButton.icon(
                                        onPressed: _loadData,
                                        icon: Icon(Icons.refresh),
                                        label: Text('Retry'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.amber,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return Container(
                              height:
                                  160, // Increased height for the improved design
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: auth.creators.length > 5
                                    ? 5
                                    : auth.creators.length,
                                itemBuilder: (_, index) {
                                  return _buildStorytellerCard(
                                      auth.creators[index]);
                                },
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 32),

                        // Challenges Section
                        _buildSectionHeader(
                          '${context.l10n.available} ${context.l10n.challenge}',
                          '${context.l10n.challengesDescription}',
                          FontAwesomeIcons.trophy,
                          () {
                            Navigator.pushNamed(
                                context, AllChallengesScreen.routeName);
                          },
                        ),

                        const SizedBox(height: 16),
                        Consumer<Challenge>(
                          builder: (context, challengeProvider, _) {
                            // Add safety check for disposed state
                            if (_isDisposed || !mounted) {
                              return const SizedBox(height: 50);
                            }

                            // Show loading indicator if we're still loading and no data
                            if (_isLoading &&
                                challengeProvider.challenges.isEmpty) {
                              return const ChallengeCardsSkeleton(count: 2);
                            }

                            // Show message if no challenges available
                            if (challengeProvider.challenges.isEmpty) {
                              return Container(
                                height: 120,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        FontAwesomeIcons.trophy,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'No challenges available',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      ElevatedButton.icon(
                                        onPressed: _loadData,
                                        icon: Icon(Icons.refresh),
                                        label: Text('Retry'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.amber,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return Container(
                              height: 120,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                itemCount:
                                    challengeProvider.challenges.length > 3
                                        ? 3
                                        : challengeProvider.challenges.length,
                                itemBuilder: (context, index) {
                                  return _buildChallengeCard(
                                      challengeProvider.challenges[index]);
                                },
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 200),
                      ],
                    ),
                  ),
          ),
        ),
        bottomNavigationBar: Footer(0),
      ),
    );
  }
}
