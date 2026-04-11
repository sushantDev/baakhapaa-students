import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/auth.dart';
import '../helpers/helpers.dart';
import 'skeleton_loading.dart';

/// Full-screen collaborator selector for creating collaboration invitations
/// Allows searching users, selecting up to 4 collaborators, and configuring offers
///
/// Pattern: Similar to CreatorContentSelector and AffiliateProductSelector
/// Returns List<Map<String, dynamic>> with collaborator details and offers
class CollaboratorSelector extends StatefulWidget {
  final List<Map<String, dynamic>> initialSelected;
  final Function(List<Map<String, dynamic>>) onSelected;

  const CollaboratorSelector({
    Key? key,
    this.initialSelected = const [],
    required this.onSelected,
  }) : super(key: key);

  @override
  _CollaboratorSelectorState createState() => _CollaboratorSelectorState();
}

class _CollaboratorSelectorState extends State<CollaboratorSelector> {
  final TextEditingController _searchController = TextEditingController();
  final Map<int, TextEditingController> _messageControllers = {};
  final Map<int, TextEditingController> _pointsControllers = {};

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _suggestedUsers =
      []; // Default suggested collaborators
  List<Map<String, dynamic>> _selectedUsers = [];
  bool _isSearching = false;
  bool _isLoadingSuggestions = false;
  Timer? _debounce;

  // Max collaborators: 4 invitations + 1 initiator = 5 total
  static const int MAX_COLLABORATORS = 4;

  @override
  void initState() {
    super.initState();
    _selectedUsers = List.from(widget.initialSelected);

    // Initialize controllers for already selected users
    for (var user in _selectedUsers) {
      final userId = user['user_id'] ?? 0;
      _messageControllers[userId] = TextEditingController(
        text: user['message'] ?? '',
      );
      _pointsControllers[userId] = TextEditingController(
        text: user['offer_amount']?.toString() ?? '',
      );
    }

    // Load suggested collaborators on init
    _loadSuggestedCollaborators();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _messageControllers.values.forEach((c) => c.dispose());
    _pointsControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  /// Load suggested collaborators (followers + following)
  /// Shows a default list of users likely to collaborate with
  Future<void> _loadSuggestedCollaborators() async {
    setState(() => _isLoadingSuggestions = true);

    try {
      final auth = Provider.of<Auth>(context, listen: false);
      final username = auth.username ?? '';

      // Fetch both followers and following (limit to 20 each for performance)
      await auth.fetchFollowers(username, perPage: 20);
      await auth.fetchFollowing(username, perPage: 20);

      final followers = auth.followers;
      final following = auth.following;

      // Combine and deduplicate, filtering to creators only
      // If the API response includes a 'role' field, only include creators
      // Otherwise include all (graceful fallback for APIs that don't return role)
      final Map<int, dynamic> uniqueUsers = {};
      for (var user in [...followers, ...following]) {
        final id = user['id'];
        if (id == null || uniqueUsers.containsKey(id)) continue;
        final role = user['role'];
        if (role == null || role == 'creator') {
          uniqueUsers[id] = user;
        }
      }

      if (mounted) {
        setState(() {
          _suggestedUsers =
              uniqueUsers.values.toList().cast<Map<String, dynamic>>();
          _isLoadingSuggestions = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _suggestedUsers = [];
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  /// Debounced search for users
  /// Time complexity: O(n) where n is search results count
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      await _performSearch(query.trim());
    });
  }

  /// Perform user search using Auth provider
  /// Searches only users with the 'creator' role on the platform
  /// This ensures collaborators are content creators, not regular players
  Future<void> _performSearch(String query) async {
    try {
      final auth = Provider.of<Auth>(context, listen: false);

      // Filter search to only return users with the 'creator' role
      final results = await auth.searchUsers(query, role: 'creator');

      if (mounted) {
        setState(() {
          _searchResults = results.cast<Map<String, dynamic>>();
          _isSearching = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
        showScaffoldMessenger(context, 'Failed to search users: $error');
      }
    }
  }

  /// Toggle user selection
  /// Time complexity: O(n) to check if user exists in selected list
  void _toggleUserSelection(Map<String, dynamic> user) {
    final userId = user['id'];
    final isSelected = _selectedUsers.any((u) => u['user_id'] == userId);

    if (isSelected) {
      setState(() {
        _selectedUsers.removeWhere((u) => u['user_id'] == userId);
        _messageControllers[userId]?.dispose();
        _messageControllers.remove(userId);
        _pointsControllers[userId]?.dispose();
        _pointsControllers.remove(userId);
      });
    } else {
      if (_selectedUsers.length >= MAX_COLLABORATORS) {
        showScaffoldMessenger(
          context,
          'Maximum $MAX_COLLABORATORS collaborators allowed',
        );
        return;
      }

      setState(() {
        _selectedUsers.add({
          'user_id': userId,
          'username': user['username'],
          'name': user['name'],
          'image': user['image'],
          'offer_type': 'none',
          'offer_amount': 0,
          'offer_gift_id': null,
          'message': '',
        });
        _messageControllers[userId] = TextEditingController();
        _pointsControllers[userId] = TextEditingController();
      });

      // Show configuration dialog for the newly selected user
      _showUserConfigDialog(
          userId, user['username'], user['name'], user['image']);
    }
  }

  /// Update offer type for a user
  void _updateOfferType(int userId, String offerType) {
    setState(() {
      final index = _selectedUsers.indexWhere((u) => u['user_id'] == userId);
      if (index != -1) {
        _selectedUsers[index]['offer_type'] = offerType;
        if (offerType != 'points') {
          _selectedUsers[index]['offer_amount'] = 0;
          _pointsControllers[userId]?.clear();
        }
        if (offerType != 'gift') {
          _selectedUsers[index]['offer_gift_id'] = null;
        }
      }
    });
  }

  /// Update offer amount for a user
  void _updateOfferAmount(int userId, String amount) {
    final points = int.tryParse(amount) ?? 0;
    _selectedUsers = _selectedUsers.map((u) {
      if (u['user_id'] == userId) {
        return {...u, 'offer_amount': points};
      }
      return u;
    }).toList();
  }

  /// Update message for a user
  void _updateMessage(int userId, String message) {
    _selectedUsers = _selectedUsers.map((u) {
      if (u['user_id'] == userId) {
        return {...u, 'message': message};
      }
      return u;
    }).toList();
  }

  /// Show configuration dialog for selected user
  /// Allows user to configure offer type, amount, and message
  Future<void> _showUserConfigDialog(
      int userId, String username, String? name, String? image) async {
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final user = _selectedUsers.firstWhere((u) => u['user_id'] == userId);
          final offerType = user['offer_type'] ?? 'none';

          return AlertDialog(
            title: Row(
              children: [
                if (image != null)
                  CircleAvatar(
                    backgroundImage: CachedNetworkImageProvider(image),
                    radius: 20,
                  )
                else
                  CircleAvatar(
                    child: Icon(Icons.person),
                    radius: 20,
                  ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@$username',
                        style: TextStyle(fontSize: 16),
                      ),
                      if (name != null && name.isNotEmpty)
                        Text(
                          name,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Offer Type
                  DropdownButtonFormField<String>(
                    value: offerType,
                    decoration: InputDecoration(
                      labelText: 'Offer Type',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(value: 'none', child: Text('No Offer')),
                      DropdownMenuItem(
                          value: 'points', child: Text('Points Offer')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _updateOfferType(userId, value);
                        setDialogState(() {});
                        setState(() {});
                      }
                    },
                  ),

                  // Points input
                  if (offerType == 'points') ...[
                    SizedBox(height: 16),
                    TextField(
                      controller: _pointsControllers[userId],
                      decoration: InputDecoration(
                        labelText: 'Points Amount',
                        hintText: 'Min: 100 points',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.stars, color: Colors.amber),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        _updateOfferAmount(userId, value);
                      },
                    ),
                  ],

                  // Message
                  SizedBox(height: 16),
                  TextField(
                    controller: _messageControllers[userId],
                    decoration: InputDecoration(
                      labelText: 'Message (Optional)',
                      hintText: 'Personal message',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.message),
                    ),
                    maxLength: 200,
                    maxLines: 3,
                    onChanged: (value) {
                      _updateMessage(userId, value);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Validate points if offer type is points
                  if (offerType == 'points') {
                    final amount =
                        int.tryParse(_pointsControllers[userId]?.text ?? '0') ??
                            0;
                    if (amount < 100) {
                      showScaffoldMessenger(
                          context, 'Points must be at least 100');
                      return;
                    }
                  }
                  Navigator.of(ctx).pop();
                },
                child: Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Build user list tile for suggested/search results
  /// Displays user with selection state indicator
  Widget _buildUserListTile(
      Map<String, dynamic> user, bool isSelected, bool isDark) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isDark ? Colors.grey[850] : Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: user['image'] != null
              ? CachedNetworkImageProvider(user['image'])
              : null,
          child: user['image'] == null
              ? Icon(Icons.person, color: Colors.white)
              : null,
          backgroundColor: Colors.purple,
        ),
        title: Text(
          '@${user['username']}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        subtitle: user['name'] != null && user['name'].toString().isNotEmpty
            ? Text(
                user['name'],
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              )
            : null,
        trailing: isSelected
            ? Icon(Icons.check_circle, color: Colors.purple)
            : Icon(Icons.add_circle_outline,
                color: isDark ? Colors.white54 : Colors.black54),
        onTap: () => _toggleUserSelection(user),
      ),
    );
  }

  /// Build user search result card
  Widget _buildUserCard(Map<String, dynamic> user, bool isDark) {
    final userId = user['id'];
    final isSelected = _selectedUsers.any((u) => u['user_id'] == userId);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isDark ? Colors.grey[850] : Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: user['image'] != null
              ? CachedNetworkImageProvider(user['image'])
              : null,
          child: user['image'] == null
              ? Icon(Icons.person, color: Colors.white)
              : null,
          backgroundColor: Colors.amber,
        ),
        title: Text(
          '@${user['username']}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        subtitle: user['name'] != null
            ? Text(
                user['name'],
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              )
            : null,
        trailing: isSelected
            ? Icon(Icons.check_circle, color: Colors.amber)
            : Icon(Icons.add_circle_outline,
                color: isDark ? Colors.white54 : Colors.black54),
        onTap: () => _toggleUserSelection(user),
      ),
    );
  }

  /// Validate and return selected collaborators
  void _done() {
    // Validate points amounts
    for (var user in _selectedUsers) {
      if (user['offer_type'] == 'points') {
        final amount = user['offer_amount'] ?? 0;
        if (amount < 100) {
          showScaffoldMessenger(
            context,
            'Points offer must be at least 100 for @${user['username']}',
          );
          return;
        }
      }
    }

    widget.onSelected(_selectedUsers);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text('Select Collaborators'),
        backgroundColor: isDark ? Colors.grey[900] : Colors.amber,
        actions: [
          TextButton(
            onPressed: _selectedUsers.isEmpty ? null : _done,
            child: Text(
              'Done',
              style: TextStyle(
                color: _selectedUsers.isEmpty
                    ? Colors.grey
                    : (isDark ? Colors.amber : Colors.white),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by username...',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _isSearching
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : (_searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchResults = []);
                            },
                          )
                        : null),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // Selected count indicator
          if (_selectedUsers.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.amber.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.group, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '${_selectedUsers.length}/$MAX_COLLABORATORS selected',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),

          // Content area
          Expanded(
            child: _searchController.text.isEmpty
                ? _buildSuggestedUsersView(isDark)
                : _buildSearchResultsView(isDark),
          ),
        ],
      ),
    );
  }

  /// Build suggested users view (when search is empty)
  Widget _buildSuggestedUsersView(bool isDark) {
    if (_isLoadingSuggestions) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: ListSkeleton(itemCount: 4),
      );
    }

    if (_suggestedUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_add,
              size: 64,
              color: isDark ? Colors.white38 : Colors.black26,
            ),
            SizedBox(height: 16),
            Text(
              'No suggested collaborators',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Search for users to collaborate with',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header for suggested users
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: isDark ? Colors.grey[900] : Colors.grey[200],
          child: Row(
            children: [
              Icon(Icons.stars, size: 20, color: Colors.amber),
              SizedBox(width: 8),
              Text(
                'Suggested Collaborators',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Spacer(),
              Text(
                '${_suggestedUsers.length} users',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
        // List of suggested users
        Expanded(
          child: ListView.builder(
            itemCount: _suggestedUsers.length,
            itemBuilder: (ctx, index) {
              final user = _suggestedUsers[index];
              final isSelected =
                  _selectedUsers.any((u) => u['user_id'] == user['id']);
              return _buildUserListTile(user, isSelected, isDark);
            },
          ),
        ),
      ],
    );
  }

  /// Build search results view
  Widget _buildSearchResultsView(bool isDark) {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: ListSkeleton(itemCount: 3),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'No users found',
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (ctx, index) =>
          _buildUserCard(_searchResults[index], isDark),
    );
  }
}
