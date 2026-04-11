import 'package:baakhapaa/widgets/header.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../providers/collaboration_provider.dart';
import '../../providers/auth.dart';
import '../../models/collaboration.dart';
import '../../helpers/helpers.dart';
import '../../widgets/skeleton_loading.dart';
import '../../utils/guest_auth_helper.dart';
import '../story/creator_story_screen.dart';
import '../shorts/create/create_shorts_screen.dart';
import '../create/story/create_season_screen.dart';

/// Collaboration Detail Screen - Professional UI/UX
/// Shows full details of a single collaboration with all participants
/// Allows accept/decline/cancel actions based on user role and status
class CollaborationDetailScreen extends StatefulWidget {
  static const routeName = '/collaboration-detail';

  @override
  _CollaborationDetailScreenState createState() =>
      _CollaborationDetailScreenState();
}

class _CollaborationDetailScreenState extends State<CollaborationDetailScreen> {
  var _isInit = true;
  var _isLoading = false;
  Collaboration? _collaboration;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final collaborationId = ModalRoute.of(context)!.settings.arguments as int;
      _fetchCollaboration(collaborationId);
      _isInit = false;
    }
  }

  Future<void> _fetchCollaboration(int id) async {
    setState(() => _isLoading = true);

    try {
      final provider =
          Provider.of<CollaborationProvider>(context, listen: false);

      // First try the in-memory cache
      Collaboration? collab = provider.getCollaborationById(id);

      if (collab != null) {
        setState(() {
          _collaboration = collab;
          _isLoading = false;
        });
      } else {
        // Cache miss — fetch directly from API
        final fetched = await provider.fetchCollaborationById(id);
        if (fetched != null) {
          setState(() {
            _collaboration = fetched;
            _isLoading = false;
          });
        } else {
          if (mounted) {
            showTopSnackBar(context, 'Collaboration not found');
            Navigator.of(context).pop();
          }
        }
      }
    } catch (error) {
      if (mounted) {
        showTopSnackBar(context, 'Failed to load collaboration details');
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _respondToCollaboration(String status) async {
    if (_collaboration == null) return;

    try {
      final provider =
          Provider.of<CollaborationProvider>(context, listen: false);
      await provider.respondToCollaboration(_collaboration!.id, status);

      if (status == 'accept') {
        showTopSnackBar(
          context,
          'Collaboration accepted! Tap the button below to create content.',
          backgroundColor: Colors.green,
        );
        // Stay on this screen and re-fetch so Create button becomes visible
        await _fetchCollaboration(_collaboration!.id);
      } else {
        showTopSnackBar(
          context,
          'Collaboration declined',
          backgroundColor: Colors.red,
        );
        Navigator.of(context).pop();
      }
    } catch (error) {
      showTopSnackBar(context, 'Failed to respond to collaboration');
    }
  }

  Future<void> _cancelCollaboration() async {
    if (_collaboration == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? Color(0xFF2A2A2A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Cancel Collaboration?'),
          ],
        ),
        content: Text(
          'This will cancel the collaboration for all participants. This action cannot be undone.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'No, Keep It',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final provider =
          Provider.of<CollaborationProvider>(context, listen: false);
      await provider.cancelCollaboration(_collaboration!.id);

      showTopSnackBar(context, 'Collaboration cancelled');
      Navigator.of(context).pop();
    } catch (error) {
      showTopSnackBar(context, 'Failed to cancel collaboration');
    }
  }

  void _navigateToCreateShorts() {
    if (_collaboration == null) return;
    final int collabId = _collaboration!.id;

    Navigator.of(context).pushNamed(
      CreateShortsScreen.routeName,
      arguments: {'collaboration_id': collabId},
    ).then((_) async {
      // Force a fresh API fetch — bypass cache so contentId/status reflects
      // the newly created short and "Create Short" button disappears.
      if (!mounted) return;
      final provider =
          Provider.of<CollaborationProvider>(context, listen: false);
      final updated = await provider.fetchCollaborationById(collabId);
      if (mounted && updated != null) {
        setState(() => _collaboration = updated);
      }
    });
  }

  void _navigateToCreateSeason() {
    if (_collaboration == null) return;
    final int collabId = _collaboration!.id;

    Navigator.of(context).pushNamed(
      CreateSeasonScreen.routeName,
      arguments: {'collaboration_id': collabId},
    ).then((_) async {
      // Force a fresh API fetch — bypass cache so contentId/status reflects
      // the newly created season and "Create Season" button disappears.
      if (!mounted) return;
      final provider =
          Provider.of<CollaborationProvider>(context, listen: false);
      final updated = await provider.fetchCollaborationById(collabId);
      if (mounted && updated != null) {
        setState(() => _collaboration = updated);
      }
    });
  }

  void _navigateToUserProfile(int userId, String username) {
    final auth = Provider.of<Auth>(context, listen: false);
    if (auth.isAuth) {
      Navigator.of(context).pushNamed(
        CreatorStoryScreen.routeName,
        arguments: [userId, username],
      );
    } else {
      GuestAuthHelper.showGuestLoginDialog(context, 'user profiles');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<Auth>(context, listen: false);

    return Scaffold(
      backgroundColor: isDark ? Color(0xFF121212) : Color(0xFFF5F5F5),
      appBar: header(
        context: context,
        titleText: "Collaboration Details",
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(24.0),
              child: ListSkeleton(itemCount: 5),
            )
          : _collaboration == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Collaboration not found',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card with gradient
                      _buildHeaderCard(isDark),
                      SizedBox(height: 20),

                      // Description section
                      if (_collaboration!.description != null) ...[
                        _buildSectionTitle('Description', isDark),
                        SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? Color(0xFF2A2A2A) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            _collaboration!.description!,
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark ? Colors.white70 : Colors.black87,
                              height: 1.5,
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                      ],

                      // Participants section
                      _buildSectionTitle('Participants', isDark),
                      SizedBox(height: 12),
                      ..._buildParticipantsList(isDark, auth),

                      SizedBox(height: 20),

                      // Stats section
                      _buildSectionTitle('Statistics', isDark),
                      SizedBox(height: 12),
                      _buildStatsCard(isDark),

                      SizedBox(height: 24),

                      // Action Buttons
                      _buildActionButtons(auth, isDark),

                      SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeaderCard(bool isDark) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.withOpacity(0.8),
            Colors.blue.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _collaboration!.title ?? 'Collaboration',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              _buildStatusBadge(_collaboration!.status, true),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.video_library_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text(
                _collaboration!.collaborationType == 'short'
                    ? 'Short Story Collaboration'
                    : 'Story Collaboration',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (_collaboration!.contentId != null) ...[
            SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.link_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Linked to Content #${_collaboration!.contentId}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple, Colors.blue],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildParticipantsList(bool isDark, Auth auth) {
    List<Widget> participantWidgets = [];

    // Add initiator first
    final initiatorId = _collaboration!.initiatorId;
    final initiatorUsername = _collaboration!.initiatorUsername;
    final initiatorName = _collaboration!.initiatorName;
    final initiatorAvatar = _collaboration!.initiatorImage;
    final isInitiatorMe = auth.userId == initiatorId;

    participantWidgets.add(
      Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [Color(0xFF2A2A2A), Color(0xFF1E1E1E)]
                : [Colors.white, Colors.grey.shade50],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _navigateToUserProfile(initiatorId, initiatorUsername),
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Colors.amber, Colors.orange],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(2),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor:
                              isDark ? Color(0xFF2A2A2A) : Colors.white,
                          child: CircleAvatar(
                            radius: 26,
                            backgroundImage: initiatorAvatar != null
                                ? CachedNetworkImageProvider(initiatorAvatar)
                                : null,
                            child: initiatorAvatar == null
                                ? Icon(Icons.person, size: 28)
                                : null,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? Color(0xFF2A2A2A) : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '@$initiatorUsername',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (isInitiatorMe) ...[
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.blue, Colors.purple],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'You',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (initiatorName.isNotEmpty) ...[
                          SizedBox(height: 4),
                          Text(
                            initiatorName,
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                        SizedBox(height: 6),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.amber.withOpacity(0.2),
                                Colors.orange.withOpacity(0.2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amber.withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Initiator',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Add other participants
    for (var participant in _collaboration!.participants) {
      final myParticipation = _collaboration!.myParticipation;
      final isMe = myParticipation != null &&
          participant.userId == myParticipation.userId;

      participantWidgets.add(
        Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [Color(0xFF2A2A2A), Color(0xFF1E1E1E)]
                  : [Colors.white, Colors.grey.shade50],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _navigateToUserProfile(
                  participant.userId, participant.username),
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Colors.purple, Colors.blue],
                            ),
                          ),
                          padding: EdgeInsets.all(2),
                          child: CircleAvatar(
                            radius: 26,
                            backgroundColor:
                                isDark ? Color(0xFF2A2A2A) : Colors.white,
                            child: CircleAvatar(
                              radius: 24,
                              backgroundImage: participant.avatar != null
                                  ? CachedNetworkImageProvider(
                                      participant.avatar!)
                                  : null,
                              child: participant.avatar == null
                                  ? Icon(Icons.person, size: 24)
                                  : null,
                            ),
                          ),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '@${participant.username}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (isMe) ...[
                                    SizedBox(width: 8),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Colors.blue, Colors.purple],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'You',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (participant.userName.isNotEmpty) ...[
                                SizedBox(height: 4),
                                Text(
                                  participant.userName,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black54,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.purple.withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            participant.role,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[700],
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        _buildStatusBadge(participant.status, isDark),
                      ],
                    ),
                    // Show offer if participant has one
                    if (participant.offerType != 'none') ...[
                      SizedBox(height: 12),
                      _buildOfferDisplay(participant, isDark),
                    ],
                    // Show message if exists
                    if (participant.message != null &&
                        participant.message!.isNotEmpty) ...[
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.format_quote_rounded,
                              size: 16,
                              color: Colors.purple.withOpacity(0.6),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                participant.message!,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  color:
                                      isDark ? Colors.white70 : Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return participantWidgets;
  }

  Widget _buildStatsCard(bool isDark) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [Color(0xFF2A2A2A), Color(0xFF1E1E1E)]
              : [Colors.white, Colors.grey.shade50],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildStatRow(
            Icons.people_rounded,
            'Total Participants',
            '${_collaboration!.participants.length}',
            Colors.purple,
            isDark,
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          _buildStatRow(
            Icons.check_circle_rounded,
            'Accepted',
            '${_collaboration!.acceptedParticipants.length}',
            Colors.green,
            isDark,
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          _buildStatRow(
            Icons.access_time_rounded,
            'Pending',
            '${_collaboration!.pendingParticipants.length}',
            Colors.orange,
            isDark,
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          _buildStatRow(
            Icons.calendar_today_rounded,
            'Created',
            _formatDate(_collaboration!.createdAt),
            Colors.blue,
            isDark,
          ),
          if (_collaboration!.expiresAt != null) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            _buildStatRow(
              Icons.event_busy_rounded,
              'Expires',
              _formatDate(_collaboration!.expiresAt!),
              Colors.red,
              isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow(
    IconData icon,
    String label,
    String value,
    Color color,
    bool isDark,
  ) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: color),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Auth auth, bool isDark) {
    final myParticipation = _collaboration!.myParticipation;
    final isInitiator = auth.userId == _collaboration!.initiatorId;

    Widget? actionWidget;

    // Content already exists — posted via the "shorts first, invite later" flow.
    // In this case no one needs to "create" anything; the short is already live.
    final contentAlreadyPosted = _collaboration!.contentId != null;

    if (contentAlreadyPosted) {
      // Show an informational badge instead of a create button
      actionWidget = _buildContentAlreadyPostedBadge(isDark);
    }
    // If user is initiator
    else if (isInitiator) {
      if (_collaboration!.status == 'active' ||
          _collaboration!.status == 'completed') {
        // Determine button text and action based on collaboration type
        final isShort = _collaboration!.contentType == 'short';
        final buttonText = isShort ? 'Create Short' : 'Create Season';
        final buttonAction =
            isShort ? _navigateToCreateShorts : _navigateToCreateSeason;

        actionWidget = _buildPrimaryButton(
          buttonText,
          Icons.video_call_rounded,
          buttonAction,
          Colors.purple,
        );
      } else if (_collaboration!.status == 'pending') {
        actionWidget = _buildSecondaryButton(
          'Cancel Collaboration',
          Icons.cancel_rounded,
          _cancelCollaboration,
          Colors.red,
          isDark,
        );
      }
    }
    // If user is participant and status is pending
    else if (myParticipation != null && _collaboration!.status == 'pending') {
      if (myParticipation.status == 'pending') {
        actionWidget = Row(
          children: [
            Expanded(
              child: _buildPrimaryButton(
                'Accept',
                Icons.check_circle_rounded,
                () => _respondToCollaboration('accept'),
                Colors.green,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _respondToCollaboration('decline'),
                icon: Icon(Icons.cancel_rounded, size: 20),
                label: Text(
                  'Decline',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ],
        );
      }
    }
    // If user is participant and collaboration is active (content not yet posted)
    else if (myParticipation != null && _collaboration!.status == 'active') {
      // Determine button text and action based on collaboration type
      final isShort = _collaboration!.contentType == 'short';
      final buttonText = isShort ? 'Create Short' : 'Create Season';
      final buttonAction =
          isShort ? _navigateToCreateShorts : _navigateToCreateSeason;

      actionWidget = _buildPrimaryButton(
        buttonText,
        Icons.video_call_rounded,
        buttonAction,
        Colors.purple,
      );
    }

    return actionWidget ?? SizedBox.shrink();
  }

  Widget _buildPrimaryButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
    Color color,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 4,
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
    Color color,
    bool isDark,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  /// Informational badge shown when the content was already posted
  /// (short/season created before all collaborators responded).
  Widget _buildContentAlreadyPostedBadge(bool isDark) {
    final isShort = _collaboration!.contentType == 'short';
    final contentLabel = isShort ? 'Short' : 'Season';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withOpacity(0.15),
            Colors.teal.withOpacity(0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.green, size: 40),
          SizedBox(height: 12),
          Text(
            '$contentLabel Already Live',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'The $contentLabel has been posted and you are credited as a collaborator.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black54,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        icon = Icons.access_time_rounded;
        label = 'Pending';
        break;
      case 'accepted':
      case 'active':
        color = Colors.green;
        icon = Icons.check_circle_rounded;
        label = 'Active';
        break;
      case 'declined':
        color = Colors.red;
        icon = Icons.cancel_rounded;
        label = 'Declined';
        break;
      case 'cancelled':
        color = Colors.grey;
        icon = Icons.block_rounded;
        label = 'Cancelled';
        break;
      case 'completed':
        color = Colors.blue;
        icon = Icons.done_all_rounded;
        label = 'Completed';
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_rounded;
        label = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? color.withOpacity(0.25)
            : (status == 'pending' || status == 'accepted' || status == 'active'
                ? color.withOpacity(0.15)
                : Colors.white.withOpacity(0.95)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.6),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferDisplay(CollaborationParticipant participant, bool isDark) {
    if (participant.offerType == 'none') return SizedBox.shrink();

    IconData icon = Icons.card_giftcard_rounded;
    String label;
    Color color;
    List<Color> gradientColors;

    if (participant.offerType == 'points') {
      label = '${participant.offerAmount} Points';
      color = Colors.amber;
      gradientColors = [Colors.amber, Colors.orange];
    } else if (participant.offerType == 'gift') {
      icon = Icons.card_giftcard_rounded;
      label = 'Gift Reward';
      color = Colors.pink;
      gradientColors = [Colors.pink, Colors.purple];
    } else {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors.map((c) => c.withOpacity(0.15)).toList(),
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: participant.offerType == 'points'
                ? Image.asset(
                    'assets/images/walletCoin.png',
                    width: 20,
                    height: 20,
                  )
                : Icon(icon, size: 20, color: Colors.white),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎁 Offer',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();

    // For future dates (expiration), show time remaining
    if (date.isAfter(now)) {
      final difference = date.difference(now);
      if (difference.inDays == 0) {
        final hours = difference.inHours;
        return '$hours hours left';
      } else if (difference.inDays == 1) {
        return '1 day left';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days left';
      } else {
        return DateFormat('MMM dd, yyyy').format(date);
      }
    }

    // For past dates (created), show time ago
    final difference = now.difference(date);
    if (difference.inDays == 0) {
      return 'Today ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }
}
