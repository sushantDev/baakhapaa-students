import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth.dart';
import '../../widgets/skeleton_loading.dart';
import '../story/creator_story_screen.dart';

class FollowersListScreen extends StatefulWidget {
  static const routeName = '/followers-list';

  final String listType; // 'followers', 'following', or 'mutual'
  final String username;

  const FollowersListScreen({
    Key? key,
    required this.listType,
    required this.username,
  }) : super(key: key);

  @override
  State<FollowersListScreen> createState() => _FollowersListScreenState();
}

class _FollowersListScreenState extends State<FollowersListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _allUsers = [];
  List<dynamic> _filteredUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final auth = Provider.of<Auth>(context, listen: false);

      if (widget.listType == 'followers') {
        await auth.fetchFollowers(widget.username, perPage: 100);
        _allUsers = auth.followers;
      } else if (widget.listType == 'following') {
        await auth.fetchFollowing(widget.username, perPage: 100);
        _allUsers = auth.following;
      } else if (widget.listType == 'mutual') {
        // Fetch both followers and following
        await auth.fetchFollowers(widget.username, perPage: 100);
        await auth.fetchFollowing(widget.username, perPage: 100);

        final followers = auth.followers;
        final following = auth.following;

        // Get IDs of people we follow
        final followingIds = following.map((user) => user['id']).toSet();

        // Filter followers to only include those we also follow (mutual)
        _allUsers = followers.where((user) {
          return followingIds.contains(user['id']);
        }).toList();
      }

      _filterUsers();
    } catch (e) {
      debugPrint('Error loading ${widget.listType}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load ${widget.listType}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshUsers() async {
    await _loadUsers();
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _filteredUsers = List.from(_allUsers);
      } else {
        _filteredUsers = _allUsers.where((user) {
          final name = (user['name'] ?? '').toString().toLowerCase();
          final username = (user['username'] ?? '').toString().toLowerCase();
          return name.contains(query) || username.contains(query);
        }).toList();
      }
    });
  }

  void _openProfile(dynamic user) {
    try {
      final int? userId = (user['id'] is int) ? user['id'] as int : null;
      final String? username = user['username']?.toString();

      if (userId != null && username != null && username.isNotEmpty) {
        Navigator.of(context).pushNamed(
          CreatorStoryScreen.routeName,
          arguments: [userId, username],
        );
      }
    } catch (e) {
      debugPrint('Error opening profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.listType == 'followers'
        ? 'Followers'
        : widget.listType == 'following'
            ? 'Following'
            : 'Mutual';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by name or username...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // User List
          Expanded(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: UserListSkeleton(itemCount: 6),
                  )
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              color: Colors.grey[600],
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No users found'
                                  : 'No $title yet',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refreshUsers,
                        color: Colors.amber,
                        backgroundColor: Colors.grey[900],
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
                            return _UserListItem(
                              user: user,
                              onTap: () => _openProfile(user),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _UserListItem extends StatefulWidget {
  final dynamic user;
  final VoidCallback onTap;

  const _UserListItem({
    Key? key,
    required this.user,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_UserListItem> createState() => _UserListItemState();
}

class _UserListItemState extends State<_UserListItem> {
  bool _isFollowing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.user['is_following'] == true;
  }

  Future<void> _handleFollowToggle() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final auth = Provider.of<Auth>(context, listen: false);
      final username = widget.user['username']?.toString();

      if (username == null || username.isEmpty) {
        throw Exception('Invalid username');
      }

      await auth.toggleFollowUser(username);

      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFollowing
                  ? 'Now following ${widget.user['name']}'
                  : 'Unfollowed ${widget.user['name']}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling follow: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to ${_isFollowing ? 'unfollow' : 'follow'} user'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Profile Image
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey[800],
              backgroundImage: widget.user['image'] != null &&
                      (widget.user['image'] as String).isNotEmpty
                  ? CachedNetworkImageProvider(widget.user['image'])
                  : null,
              child: (widget.user['image'] == null ||
                      (widget.user['image'] as String).isEmpty)
                  ? const CircleAvatar(
                      radius: 24,
                      backgroundImage: AssetImage('assets/images/logo.png'),
                      backgroundColor: Colors.transparent,
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.user['name'] ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '@${widget.user['username'] ?? 'unknown'}',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Follow Back Button or Following Badge
            if (_isFollowing)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue),
                ),
                child: const Text(
                  'Following',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.amber,
                      ),
                    )
                  : OutlinedButton(
                      onPressed: _handleFollowToggle,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amber,
                        side: const BorderSide(color: Colors.amber),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Follow Back',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

            const SizedBox(width: 8),

            // Chevron Icon
            Icon(
              Icons.chevron_right,
              color: Colors.grey[600],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
