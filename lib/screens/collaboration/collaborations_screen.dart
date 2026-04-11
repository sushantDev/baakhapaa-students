import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/collaboration_provider.dart';
import '../../providers/auth.dart';
import '../../models/collaboration.dart';
import '../../helpers/helpers.dart';
import '../../widgets/header.dart';
import '../../widgets/skeleton_loading.dart';
import 'collaboration_detail_screen.dart';
import 'create_collaboration_screen.dart';
import '../shorts/create/create_shorts_screen.dart';
import '../create/story/create_season_screen.dart';

/// Collaboration Management Screen - Professional UI/UX
/// Shows received and sent collaboration invitations with tabs
/// Time Complexity: O(n) where n is number of collaborations per fetch
class CollaborationsScreen extends StatefulWidget {
  static const routeName = '/collaborations';

  @override
  _CollaborationsScreenState createState() => _CollaborationsScreenState();
}

class _CollaborationsScreenState extends State<CollaborationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  var _isInit = true;
  var _isLoadingReceived = false;
  var _isLoadingSent = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      _isInit = false;
      // Defer async work to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fetchData();
        }
      });
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoadingReceived = true;
      _isLoadingSent = true;
    });

    final provider = Provider.of<CollaborationProvider>(context, listen: false);

    try {
      await Future.wait([
        provider.fetchReceived(),
        provider.fetchSent(),
      ]);
    } catch (error) {
      showTopSnackBar(context, 'Failed to load collaborations');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingReceived = false;
          _isLoadingSent = false;
        });
      }
    }
  }

  Future<void> _refreshReceived() async {
    final provider = Provider.of<CollaborationProvider>(context, listen: false);
    await provider.fetchReceived();
  }

  Future<void> _refreshSent() async {
    final provider = Provider.of<CollaborationProvider>(context, listen: false);
    await provider.fetchSent();
  }

  Future<void> _loadMoreReceived() async {
    if (_isLoadingReceived) return;

    setState(() => _isLoadingReceived = true);
    final provider = Provider.of<CollaborationProvider>(context, listen: false);
    await provider.loadMoreReceived();
    if (mounted) setState(() => _isLoadingReceived = false);
  }

  Future<void> _loadMoreSent() async {
    if (_isLoadingSent) return;

    setState(() => _isLoadingSent = true);
    final provider = Provider.of<CollaborationProvider>(context, listen: false);
    await provider.loadMoreSent();
    if (mounted) setState(() => _isLoadingSent = false);
  }

  Future<void> _respondToCollaboration(
    int collaborationId,
    String status,
  ) async {
    try {
      final provider =
          Provider.of<CollaborationProvider>(context, listen: false);
      await provider.respondToCollaboration(collaborationId, status);

      if (status == 'accept') {
        showTopSnackBar(
          context,
          'Collaboration accepted! You can now create content.',
          backgroundColor: Colors.green,
        );
        // Navigate to detail screen so user can immediately create content
        Navigator.of(context).pushNamed(
          CollaborationDetailScreen.routeName,
          arguments: collaborationId,
        );
      } else {
        showTopSnackBar(
          context,
          'Collaboration declined',
          backgroundColor: Colors.red,
        );
        _refreshReceived();
      }
    } catch (error) {
      showTopSnackBar(context, 'Failed to respond to collaboration');
    }
  }

  Future<void> _cancelCollaboration(int collaborationId) async {
    try {
      final provider =
          Provider.of<CollaborationProvider>(context, listen: false);
      await provider.cancelCollaboration(collaborationId);

      showTopSnackBar(context, 'Collaboration cancelled');
      _refreshSent();
    } catch (error) {
      showTopSnackBar(context, 'Failed to cancel collaboration');
    }
  }

  void _navigateToCreateShorts(int collaborationId) {
    Navigator.of(context).pushNamed(
      CreateShortsScreen.routeName,
      arguments: {'collaboration_id': collaborationId},
    ).then((_) {
      // Refresh list when returning — collaboration may now be completed
      if (mounted) _fetchData();
    });
  }

  void _navigateToCreateSeason(int collaborationId) {
    Navigator.of(context).pushNamed(
      CreateSeasonScreen.routeName,
      arguments: {'collaboration_id': collaborationId},
    ).then((_) {
      // Refresh list when returning — collaboration may now be completed
      if (mounted) _fetchData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Color(0xFF121212) : Color(0xFFF5F5F5),
      appBar: header(
        context: context,
        titleText: 'Collaborations',
      ),
      body: Column(
        children: [
          // Tabs Section
          Container(
            decoration: BoxDecoration(
              color: Colors.black,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.purple,
              indicatorWeight: 3,
              labelColor: Colors.purple,
              unselectedLabelColor: Colors.white60,
              labelStyle: TextStyle(fontWeight: FontWeight.bold),
              tabs: [
                Tab(
                  icon: Icon(Icons.inbox),
                  text: 'Received',
                ),
                Tab(
                  icon: Icon(Icons.send),
                  text: 'Sent',
                ),
              ],
            ),
          ),
          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildReceivedTab(isDark),
                _buildSentTab(isDark),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pushNamed(
            CreateCollaborationScreen.routeName,
          );
        },
        icon: Icon(Icons.add),
        label: Text('New Collab'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }

  Widget _buildReceivedTab(bool isDark) {
    return Consumer<CollaborationProvider>(
      builder: (ctx, provider, _) {
        if (_isLoadingReceived && provider.receivedCollaborations.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24.0),
            child: ListSkeleton(itemCount: 4),
          );
        }

        if (provider.receivedCollaborations.isEmpty) {
          return _buildEmptyState(
            'No Invitations',
            'You haven\'t received any collaboration invitations yet.',
            Icons.inbox_outlined,
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshReceived,
          color: Colors.purple,
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (!_isLoadingReceived &&
                  provider.hasMoreReceivedPages &&
                  scrollInfo.metrics.pixels >=
                      scrollInfo.metrics.maxScrollExtent - 200) {
                _loadMoreReceived();
              }
              return false;
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: provider.receivedCollaborations.length +
                  (provider.hasMoreReceivedPages ? 1 : 0),
              itemBuilder: (ctx, index) {
                if (index == provider.receivedCollaborations.length) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: Colors.purple),
                    ),
                  );
                }

                final collaboration = provider.receivedCollaborations[index];
                return _buildReceivedCollaborationCard(collaboration, isDark);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSentTab(bool isDark) {
    return Consumer<CollaborationProvider>(
      builder: (ctx, provider, _) {
        if (_isLoadingSent && provider.sentCollaborations.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24.0),
            child: ListSkeleton(itemCount: 4),
          );
        }

        if (provider.sentCollaborations.isEmpty) {
          return _buildEmptyState(
            'No Sent Invitations',
            'You haven\'t sent any collaboration invitations yet.',
            Icons.send_outlined,
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshSent,
          color: Colors.purple,
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (!_isLoadingSent &&
                  provider.hasMoreSentPages &&
                  scrollInfo.metrics.pixels >=
                      scrollInfo.metrics.maxScrollExtent - 200) {
                _loadMoreSent();
              }
              return false;
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: provider.sentCollaborations.length +
                  (provider.hasMoreSentPages ? 1 : 0),
              itemBuilder: (ctx, index) {
                if (index == provider.sentCollaborations.length) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: Colors.purple),
                    ),
                  );
                }

                final collaboration = provider.sentCollaborations[index];
                return _buildSentCollaborationCard(collaboration, isDark);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildReceivedCollaborationCard(
    Collaboration collaboration,
    bool isDark,
  ) {
    final auth = Provider.of<Auth>(context, listen: false);
    final initiatorUsername = collaboration.initiatorUsername;
    final initiatorName = collaboration.initiatorName;
    final initiatorAvatar = collaboration.initiatorImage;

    // Find current user's participation to show offer
    final myParticipation = collaboration.participants.firstWhere(
      (p) => p.userId == auth.userId,
      orElse: () => collaboration.participants.first,
    );

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [Color(0xFF2A2A2A), Color(0xFF1E1E1E)]
              : [Colors.white, Colors.grey.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 0,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).pushNamed(
              CollaborationDetailScreen.routeName,
              arguments: collaboration.id,
            );
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with initiator
                Row(
                  children: [
                    // Avatar with gradient border
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Colors.purple, Colors.blue],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(2),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor:
                            isDark ? Color(0xFF2A2A2A) : Colors.white,
                        child: CircleAvatar(
                          radius: 24,
                          backgroundImage: initiatorAvatar != null
                              ? CachedNetworkImageProvider(initiatorAvatar)
                              : null,
                          child: initiatorAvatar == null
                              ? Icon(Icons.person, size: 28)
                              : null,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@$initiatorUsername',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          if (initiatorName.isNotEmpty)
                            Text(
                              initiatorName,
                              style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.black54,
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(collaboration.status, isDark),
                  ],
                ),
                SizedBox(height: 16),

                // Title with gradient background
                if (collaboration.title != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.purple.withOpacity(0.1),
                          Colors.blue.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      collaboration.title!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                // Description
                if (collaboration.description != null) ...[
                  SizedBox(height: 12),
                  Text(
                    collaboration.description!,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                SizedBox(height: 16),

                // Info chips row
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip(
                      Icons.people_rounded,
                      '${collaboration.participants.length} people',
                      Colors.purple,
                      isDark,
                    ),
                    _buildInfoChip(
                      Icons.video_library_rounded,
                      collaboration.collaborationType == 'short'
                          ? 'Short Stories'
                          : 'Stories',
                      Colors.orange,
                      isDark,
                    ),
                  ],
                ),

                // Offer display - IMPORTANT: Show what initiator is offering
                if (myParticipation.offerType != 'none') ...[
                  SizedBox(height: 16),
                  _buildOfferDisplay(myParticipation, isDark),
                ],

                // Action buttons
                // Pending: show Accept / Decline
                if (collaboration.status == 'pending') ...[
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _respondToCollaboration(
                            collaboration.id,
                            'accept',
                          ),
                          icon: Icon(Icons.check_circle_rounded, size: 20),
                          label: Text(
                            'Accept',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _respondToCollaboration(
                            collaboration.id,
                            'decline',
                          ),
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
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Active: show Create Short / Create Season button
                // Only if content hasn't been created yet (contentId == null)
                if ((collaboration.status == 'active' ||
                        collaboration.status == 'accepted') &&
                    collaboration.contentId == null) ...[
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final isShort = collaboration.contentType == 'short';
                        if (isShort) {
                          _navigateToCreateShorts(collaboration.id);
                        } else {
                          _navigateToCreateSeason(collaboration.id);
                        }
                      },
                      icon: Icon(Icons.video_call_rounded, size: 22),
                      label: Text(
                        collaboration.contentType == 'short'
                            ? 'Create Collaborative Short'
                            : 'Create Collaborative Season',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSentCollaborationCard(
    Collaboration collaboration,
    bool isDark,
  ) {
    final pendingCount = collaboration.pendingParticipants.length;
    final acceptedCount = collaboration.acceptedParticipants.length;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [Color(0xFF2A2A2A), Color(0xFF1E1E1E)]
              : [Colors.white, Colors.grey.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 0,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).pushNamed(
              CollaborationDetailScreen.routeName,
              arguments: collaboration.id,
            );
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        collaboration.title ?? 'Collaboration',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    _buildStatusBadge(collaboration.status, isDark),
                  ],
                ),
                SizedBox(height: 12),

                // Description
                if (collaboration.description != null)
                  Text(
                    collaboration.description!,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                SizedBox(height: 16),

                // Participants avatars stack
                if (collaboration.participants.isNotEmpty)
                  _buildParticipantsAvatars(collaboration.participants, isDark),
                SizedBox(height: 16),

                // Stats row
                Row(
                  children: [
                    _buildStatChip(
                      Icons.check_circle_rounded,
                      '$acceptedCount Accepted',
                      Colors.green,
                      isDark,
                    ),
                    SizedBox(width: 10),
                    _buildStatChip(
                      Icons.access_time_rounded,
                      '$pendingCount Pending',
                      Colors.orange,
                      isDark,
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    // Cancel button (only for pending)
                    if (collaboration.status == 'pending')
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _cancelCollaboration(collaboration.id),
                          icon: Icon(Icons.cancel_rounded, size: 20),
                          label: Text(
                            'Cancel',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    // Create Content button (only for active/accepted without existing content)
                    if ((collaboration.status == 'active' ||
                            collaboration.status == 'accepted') &&
                        collaboration.contentId == null) ...[
                      if (collaboration.status == 'pending')
                        SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Navigate based on collaboration type
                            final isShort =
                                collaboration.contentType == 'short';
                            if (isShort) {
                              _navigateToCreateShorts(collaboration.id);
                            } else {
                              _navigateToCreateSeason(collaboration.id);
                            }
                          },
                          icon: Icon(Icons.video_call_rounded, size: 22),
                          label: Text(
                            collaboration.contentType == 'short'
                                ? 'Create Short Story'
                                : 'Create Story',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantsAvatars(
    List<CollaborationParticipant> participants,
    bool isDark,
  ) {
    final displayCount = participants.length > 5 ? 5 : participants.length;
    final remaining = participants.length - displayCount;

    return SizedBox(
      height: 46,
      child: Stack(
        children: [
          for (int i = 0; i < displayCount; i++)
            Positioned(
              left: i * 32.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Color(0xFF2A2A2A) : Colors.white,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: participants[i].avatar != null
                      ? CachedNetworkImageProvider(participants[i].avatar!)
                      : null,
                  child: participants[i].avatar == null
                      ? Icon(Icons.person, size: 20)
                      : null,
                ),
              ),
            ),
          if (remaining > 0)
            Positioned(
              left: displayCount * 32.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.purple, Colors.blue],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.transparent,
                  child: Text(
                    '+$remaining',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
        color: color.withOpacity(isDark ? 0.25 : 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 1,
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

  Widget _buildInfoChip(
    IconData icon,
    String label,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
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
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
    IconData icon,
    String label,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
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
              color: color,
              fontWeight: FontWeight.bold,
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
      label = '${participant.offerAmount} Points Offered!';
      color = Colors.amber;
      gradientColors = [Colors.amber, Colors.orange];
    } else if (participant.offerType == 'gift') {
      icon = Icons.card_giftcard_rounded;
      label = 'Gift Offered!';
      color = Colors.pink;
      gradientColors = [Colors.pink, Colors.purple];
    } else {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors.map((c) => c.withOpacity(0.15)).toList(),
        ),
        borderRadius: BorderRadius.circular(16),
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
                    'assets/images/coins.png',
                    width: 24,
                    height: 24,
                  )
                : Icon(icon, size: 24, color: Colors.white),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎁 Special Offer',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (participant.message != null &&
                    participant.message!.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    '"${participant.message}"',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String message, IconData icon) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.purple.withOpacity(0.1),
                    Colors.blue.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 80,
                color: Colors.purple.withOpacity(0.6),
              ),
            ),
            SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
