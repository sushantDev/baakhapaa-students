import 'dart:ui';

import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/providers/story.dart';
import 'package:baakhapaa/screens/story/creator_story_screen.dart';
import 'package:baakhapaa/screens/story/episode_screen.dart';
import 'package:baakhapaa/screens/shorts/single_shorts_screen.dart';
import 'package:baakhapaa/utils/guest_auth_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/challenges/challenge_detail_screen.dart';
import '../screens/story/video_screen.dart';

class ShortsDetail extends StatefulWidget {
  final String title;
  final String description;
  final int user_id;
  final String username;
  final String shortsTitle;
  final String created_at;
  final List<dynamic> challenge_details;
  final VoidCallback onPlayPause;
  final Map<String, dynamic>? linkedContent;
  final List<dynamic>? collaborators; // NEW: Collaborators list

  ShortsDetail(
    this.title,
    this.description,
    this.user_id,
    this.username,
    this.shortsTitle,
    this.created_at,
    this.challenge_details,
    this.onPlayPause, {
    this.linkedContent,
    this.collaborators, // NEW: Optional collaborators
  });

  @override
  _ShortsDetailState createState() => _ShortsDetailState();
}

class _ShortsDetailState extends State<ShortsDetail>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Color?> _colorAnimation;
  bool isExpanded = false;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat(reverse: true);

    _opacityAnimation =
        Tween<double>(begin: 0.9, end: 1.0).animate(_controller);
    _colorAnimation =
        ColorTween(begin: Colors.amber, end: Colors.red).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildSeasonChip(dynamic season, {bool isSeries = false}) {
    if (season == null || season['title'] == null) {
      return const SizedBox.shrink();
    }
    return InkWell(
      onTap: () async {
        widget.onPlayPause();
        try {
          final story = Provider.of<Story>(context, listen: false);
          final seasonId = season['id'];
          if (seasonId != null) {
            final seasonData = await story.fetchSeasonDetails(seasonId);
            if (seasonData != null) {
              await story.setSelectedSeason({
                ...seasonData,
                'isCreatorSeason': false,
              });
              Navigator.of(context).pushNamed(EpisodeScreen.routeName);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to load season details.')),
              );
            }
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading season: $e')),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.folder_outlined,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                isSeries
                    ? 'Related Series: ${season['title']}'
                    : 'Related S. Story: ${season['title']}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Challenge Winner/Enter logic
          if (widget.challenge_details.isNotEmpty &&
              widget.challenge_details[0] != null) ...[
            if (DateTime.tryParse(
                        widget.challenge_details[0]['deadline'] ?? '') !=
                    null &&
                DateTime.parse(widget.challenge_details[0]['deadline'])
                    .isAfter(DateTime.now()))
              TextButton(
                onPressed: () {
                  widget.onPlayPause();
                  Navigator.of(context).pushNamed(
                    ChallengeDetailScreen.routeName,
                    arguments: widget.challenge_details[0]['challenge_id'],
                  );
                },
                child: const Text(
                  'ENTER NOW!!',
                  style: TextStyle(
                    color: Color(0xFFFFC107),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else if (widget.challenge_details[0]['is_winner'] == 1)
              AnimatedBuilder(
                animation: _colorAnimation,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _opacityAnimation,
                    child: Row(
                      children: [
                        Icon(
                          Icons.emoji_events,
                          color: _colorAnimation.value,
                          size: 25,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'WINNER',
                          style: TextStyle(
                            color: _colorAnimation.value,
                            fontWeight: FontWeight.bold,
                            fontSize: 25,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final authProvider = Provider.of<Auth>(context, listen: false);
                if (!authProvider.isAuth) {
                  bool shouldLogin = await GuestAuthHelper.showGuestLoginDialog(
                      context, 'filters');
                  if (!shouldLogin) return;
                }
                widget.onPlayPause();
                Navigator.of(context).pushNamed(
                  ChallengeDetailScreen.routeName,
                  arguments: widget.challenge_details[0]['challenge_id'],
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    color: const Color.fromARGB(255, 188, 161, 25)
                        .withValues(alpha: 0.3),
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Text(
                      '${widget.challenge_details[0]['title'] ?? 'Challenge'}',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),
          // Username and Shorts Title
          InkWell(
            onTap: () async {
              var auth = Provider.of<Auth>(context, listen: false);
              widget.onPlayPause();
              if (auth.isAuth) {
                Navigator.of(context).pushNamed(
                  CreatorStoryScreen.routeName,
                  arguments: [widget.user_id, widget.username],
                );
              } else {
                await GuestAuthHelper.showGuestLoginDialog(
                    context, 'user profiles');
              }
            },
            child: Text(
              '@${widget.username} [${widget.shortsTitle}]',
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    offset: Offset(1.0, 1.0),
                    blurRadius: 3.0,
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          // NEW: Collaborators display
          if (widget.collaborators != null && widget.collaborators!.isNotEmpty)
            _buildCollaboratorsDisplay(),
          const SizedBox(height: 4),
          // Short Title
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black,
                  offset: Offset(1.0, 1.0),
                  blurRadius: 3.0,
                ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          // Description
          isExpanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(1.0, 1.0),
                            blurRadius: 3.0,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      ' [${widget.created_at}]',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(1.0, 1.0),
                            blurRadius: 3.0,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Container(
                  constraints: const BoxConstraints(maxHeight: 60),
                  child: SingleChildScrollView(
                    child: Text(
                      widget.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(1.0, 1.0),
                            blurRadius: 1.0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          const SizedBox(height: 4),
          // More/Less toggle
          GestureDetector(
            onTap: () {
              setState(() {
                isExpanded = !isExpanded;
              });
            },
            child: Text(
              isExpanded ? 'less' : 'more',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
            ),
          ),

          // Linked Content Sections
          if (widget.linkedContent != null) ...[
            // 1. Featured Series (the Season)
            if (widget.linkedContent!['season'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: _buildSeasonChip(widget.linkedContent!['season'],
                    isSeries: true),
              ),

            // 2. Related Episodes
            if (widget.linkedContent!['related_episodes'] != null &&
                (widget.linkedContent!['related_episodes'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: (widget.linkedContent!['related_episodes'] as List)
                      .where((e) => e != null)
                      .map((episode) {
                        if (episode == null || episode['title'] == null) {
                          return const SizedBox.shrink();
                        }
                        return InkWell(
                          onTap: () async {
                            widget.onPlayPause();
                            try {
                              final story =
                                  Provider.of<Story>(context, listen: false);
                              final seasonId = episode['season_id'];
                              if (seasonId != null) {
                                final seasonData =
                                    await story.fetchSeasonDetails(seasonId);
                                if (seasonData != null) {
                                  await story.setSelectedSeason({
                                    ...seasonData,
                                    'isCreatorSeason': false,
                                  });

                                  // Check if season is unlocked
                                  bool isLocked =
                                      seasonData['is_locked'] == true;

                                  if (!isLocked) {
                                    // If unlocked, go directly to video player
                                    Navigator.of(context).pushNamed(
                                        VideoScreen.routeName,
                                        arguments: episode['id']);
                                  } else {
                                    // If locked, go to episode screen to unlock
                                    Navigator.of(context)
                                        .pushNamed(EpisodeScreen.routeName);
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Failed to load season details.')),
                                  );
                                }
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Error loading episode: $e')),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.movie_outlined,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Related Episode: ${episode['title']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      })
                      .whereType<Widget>()
                      .toList(),
                ),
              ),

            // 3. Related Shorts (Stories)
            if (widget.linkedContent!['related_shorts'] != null &&
                (widget.linkedContent!['related_shorts'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: (widget.linkedContent!['related_shorts'] as List)
                      .where((e) => e != null)
                      .map((short) {
                        if (short == null || short['title'] == null) {
                          return const SizedBox.shrink();
                        }
                        return InkWell(
                          onTap: () {
                            widget.onPlayPause();
                            Navigator.of(context).pushNamed(
                              SingleShortsScreen.routeName,
                              arguments: short['id'],
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.play_circle_outline,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Related S. Story: ${short['title']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      })
                      .whereType<Widget>()
                      .toList(),
                ),
              ),

            // 4. Legacy Related Seasons (just in case)
            if (widget.linkedContent!['related_seasons'] != null &&
                (widget.linkedContent!['related_seasons'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: (widget.linkedContent!['related_seasons'] as List)
                      .where((e) => e != null)
                      .map((season) => _buildSeasonChip(season))
                      .whereType<Widget>()
                      .toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Build collaborators display widget
  /// Shows: 1 collab = "@user & @collab", 2+ collabs = "@user & N others" with modal
  Widget _buildCollaboratorsDisplay() {
    final collaborators = widget.collaborators!;

    if (collaborators.isEmpty) return SizedBox.shrink();

    // Case 1: Only 1 collaborator (2 total including main user)
    if (collaborators.length == 1) {
      final collab = collaborators[0];
      final collabUsername = collab['username'] ?? '';

      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          'with @$collabUsername',
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(
                color: Colors.black,
                offset: Offset(1.0, 1.0),
                blurRadius: 2.0,
              ),
            ],
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      );
    }

    // Case 2: 2+ collaborators (3+ total) - show "+N others" with tap to expand
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: InkWell(
        onTap: _showAllCollaborators,
        child: Row(
          children: [
            Text(
              'with ${collaborators.length} others',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.amber,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    offset: Offset(1.0, 1.0),
                    blurRadius: 2.0,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.group,
              size: 14,
              color: Colors.amber,
              shadows: [
                Shadow(
                  color: Colors.black,
                  offset: Offset(1.0, 1.0),
                  blurRadius: 2.0,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Show modal bottom sheet with all collaborators
  void _showAllCollaborators() {
    widget.onPlayPause(); // Pause video when opening modal

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[900]
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.group, color: Colors.amber),
                    SizedBox(width: 8),
                    Text(
                      'Collaborators',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(),
              // Main creator
              _buildCollaboratorTile(
                {
                  'id': widget.user_id,
                  'username': widget.username,
                  'role': 'Main Creator',
                },
                isDark,
                isMainCreator: true,
              ),
              // Collaborators list
              ...widget.collaborators!
                  .map((collab) => _buildCollaboratorTile(collab, isDark)),
            ],
          ),
        );
      },
    );
  }

  /// Build individual collaborator tile in modal
  Widget _buildCollaboratorTile(
    Map<String, dynamic> collaborator,
    bool isDark, {
    bool isMainCreator = false,
  }) {
    final username = collaborator['username'] ?? '';
    final name = collaborator['name'];
    final avatar = collaborator['avatar'];
    final role =
        collaborator['role'] ?? (isMainCreator ? 'Primary' : 'Collaborator');

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: avatar != null ? NetworkImage(avatar) : null,
        child: avatar == null ? Icon(Icons.person, color: Colors.white) : null,
        backgroundColor: isMainCreator ? Colors.amber : Colors.purple,
      ),
      title: Text(
        '@$username',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (name != null)
            Text(
              name,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          Container(
            margin: EdgeInsets.only(top: 4),
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isMainCreator
                  ? Colors.amber.withOpacity(0.2)
                  : Colors.purple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              role,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isMainCreator ? Colors.amber[700] : Colors.purple[700],
              ),
            ),
          ),
        ],
      ),
      onTap: () {
        Navigator.of(context).pop(); // Close modal
        final auth = Provider.of<Auth>(context, listen: false);
        if (auth.isAuth) {
          Navigator.of(context).pushNamed(
            CreatorStoryScreen.routeName,
            arguments: [collaborator['id'], username],
          );
        } else {
          GuestAuthHelper.showGuestLoginDialog(context, 'user profiles');
        }
      },
    );
  }
}
