import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:convert';
import 'dart:async';

import '../../providers/story.dart';
import '../../providers/auth.dart';
import '../../widgets/header.dart';
import '../../widgets/skeleton_loading.dart';
import '../../models/url.dart';
import '../../utils/debug_logger.dart';
import '../../utils/guest_auth_helper.dart';
import 'episode_screen.dart';
import '../../utils/season_unlock_helper.dart';
import '../../services/analytics_service.dart';

class SearchScreen extends StatefulWidget {
  static const routeName = '/search-screen';
  final String? initialQuery;
  final List<dynamic>? preloadedResults;
  final String? preloadedTitle;

  const SearchScreen(
      {Key? key, this.initialQuery, this.preloadedResults, this.preloadedTitle})
      : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String _lastQuery = '';

  // Pagination
  int _currentPage = 1;
  int _lastPage = 1;
  int _totalResults = 0;
  bool _isLoadingMore = false;
  ScrollController _scrollController = ScrollController();

  // Auto-search debouncing
  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();

    if (widget.preloadedResults != null &&
        widget.preloadedResults!.isNotEmpty) {
      // Pre-loaded results mode (e.g., "All Books")
      _searchResults = List<dynamic>.from(widget.preloadedResults!);
      _hasSearched = true;
      _totalResults = _searchResults.length;
      _lastPage = 1;
    } else if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    }

    // Add scroll listener for pagination
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    // Unfocus and dismiss keyboard before disposing
    FocusManager.instance.primaryFocus?.unfocus();
    _searchFocusNode.unfocus();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore &&
          _currentPage < _lastPage &&
          _searchResults.isNotEmpty) {
        _loadMoreResults();
      }
    }
  }

  Future<void> _performSearch(String query, {bool isNewSearch = true}) async {
    if (query.trim().isEmpty) return;

    // Track search event for new searches
    if (isNewSearch) {
      AnalyticsService.logSearch(query: query.trim());
    }

    setState(() {
      if (isNewSearch) {
        _isLoading = true;
        _searchResults.clear();
        _currentPage = 1;
        _hasSearched = false;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final authProvider = Provider.of<Auth>(context, listen: false);
      final authToken = await authProvider.authToken;
      final String apiUrl =
          '${Url.baakhapaaApi('/search')}?query=${Uri.encodeComponent(query)}&page=$_currentPage';

      DebugLogger.api('🔍 Search API URL: $apiUrl');

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      DebugLogger.api('🔍 Search API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        DebugLogger.api('🔍 Search API Response: $responseData');

        if (responseData['success'] == true) {
          final data = responseData['data'];
          final List<dynamic> newResults = data['data'] ?? [];

          setState(() {
            if (isNewSearch) {
              _searchResults = newResults;
            } else {
              _searchResults.addAll(newResults);
            }
            _lastPage = data['last_page'] ?? 1;
            _totalResults = data['total'] ?? newResults.length;
            _lastQuery = query;
            _hasSearched = true;
            _isLoading = false;
            _isLoadingMore = false;
          });

          DebugLogger.api(
              '🔍 Search results loaded: ${newResults.length} items');
        } else {
          throw Exception(responseData['message'] ?? 'Search failed');
        }
      } else {
        throw Exception('Search API error: ${response.statusCode}');
      }
    } catch (e) {
      DebugLogger.api('🔍 Search error: $e');
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _hasSearched = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMoreResults() async {
    _currentPage++;
    await _performSearch(_lastQuery, isNewSearch: false);
  }

  // Helper method to check if a reward value is valid (handles both numbers and strings)
  bool _hasValidReward(dynamic value) {
    if (value == null) return false;
    if (value is num) return value > 0;
    if (value is String) return value.isNotEmpty && value.trim().isNotEmpty;
    return false;
  }

  // Auto-search with debouncing
  void _onSearchTextChanged(String value) {
    // Cancel previous timer
    _debounceTimer?.cancel();

    // If search field is empty, clear results
    if (value.trim().isEmpty) {
      setState(() {
        _searchResults.clear();
        _hasSearched = false;
        _totalResults = 0;
      });
      return;
    }

    // Set up new timer for auto-search
    _debounceTimer = Timer(_debounceDuration, () {
      if (value.trim().isNotEmpty && mounted) {
        _performSearch(value.trim());
      }
    });
  }

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isDark ? const Color(0xFF2A2A2A) : Colors.white,
              isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.8),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(
              Icons.search,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.7)
                  : Colors.grey.shade600,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  hintText: 'Search for seasons, episodes...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 16,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.grey.shade500,
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                  isDense: false,
                ),
                textInputAction: TextInputAction.search,
                onChanged: _onSearchTextChanged,
                onSubmitted: (value) {
                  // Cancel any pending auto-search and search immediately
                  _debounceTimer?.cancel();
                  if (value.trim().isNotEmpty) {
                    _performSearch(value.trim());
                  }
                },
              ),
            ),
            if (_searchController.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _debounceTimer?.cancel();
                  setState(() {
                    _searchController.clear();
                    _searchResults.clear();
                    _hasSearched = false;
                    _totalResults = 0;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.clear,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.grey.shade600,
                    size: 18,
                  ),
                ),
              ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  void _showBookRequestForm() {
    final auth = Provider.of<Auth>(context, listen: false);
    if (auth.isGuest) {
      GuestAuthHelper.showGuestLoginDialog(context, 'request books');
      return;
    }

    final titleController =
        TextEditingController(text: _searchController.text.trim());
    final authorController = TextEditingController();
    final reasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Request a Book 📚',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Can't find what you're looking for? Request it!",
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Book Title *',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.amber),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: authorController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Author (optional)',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.amber),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Why do you want this book? (optional)',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.amber),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) return;
                    final story = Provider.of<Story>(ctx, listen: false);
                    final success = await story.submitBookRequest(
                      title: titleController.text.trim(),
                      author: authorController.text.trim().isEmpty
                          ? null
                          : authorController.text.trim(),
                      reason: reasonController.text.trim().isEmpty
                          ? null
                          : reasonController.text.trim(),
                    );
                    Navigator.of(ctx).pop();
                    if (success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Book request submitted! 📚')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Submit Request',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return Expanded(
        child: GridSkeleton(crossAxisCount: 2, itemCount: 6),
      );
    }

    if (!_hasSearched) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search,
                size: 80,
                color: Colors.grey.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Search for your favorite seasons',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.grey.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Type in the search box to get started',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 80,
                color: Colors.grey.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No results found',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try searching with different keywords',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _showBookRequestForm(),
                icon: const Icon(Icons.library_add_rounded),
                label: Text(
                  'Request this Book',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber,
                  side: BorderSide(color: Colors.amber.withValues(alpha: 0.5)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Results header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Search Results (${_totalResults} found)',
              //'Showing ${_searchResults.length} of ${_totalResults} results',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.8)
                    : Colors.grey.shade700,
              ),
            ),
          ),

          // Results grid
          Expanded(
            child: GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _searchResults.length +
                  (_isLoadingMore && _currentPage < _lastPage
                      ? 2
                      : 0), // Show 2 loading cards
              itemBuilder: (context, index) {
                if (index >= _searchResults.length) {
                  // Loading indicator for pagination - show as grid cards
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey.shade800.withValues(alpha: 0.5)
                          : Colors.grey.shade200.withValues(alpha: 0.5),
                    ),
                    child: const ShimmerLoading(
                      child: SkeletonBox(
                          width: double.infinity,
                          height: double.infinity,
                          borderRadius: 12),
                    ),
                  );
                }

                final season = _searchResults[index];
                return _buildSearchResultCard(season);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultCard(Map<String, dynamic> season) {
    final String thumbnail = season['thumbnail'] ?? '';
    final String title = season['title'] ?? 'Unknown';
    final dynamic rawRewards = season['rewards'];
    final Map<String, dynamic>? rewards = rawRewards != null
        ? (rawRewards is Map<String, dynamic>
            ? rawRewards
            : Map<String, dynamic>.from(rawRewards as Map))
        : null;
    final double completionPercentage =
        season['completion_percentage']?.toDouble() ?? 0.0;

    // Check if season is unlocked using helper function
    final bool hasUnlocked = isSeasonUnlocked(season);

    return InkWell(
      onTap: () async {
        try {
          final story = Provider.of<Story>(context, listen: false);
          await story.setSelectedSeason({
            'id': season['id'],
            'thumbnail': thumbnail,
            'isCreatorSeason': false,
            ...season,
          });
          Navigator.of(context).pushNamed(EpisodeScreen.routeName);
        } catch (e) {
          DebugLogger.info('Error navigating to search result: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to open season'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              // Thumbnail Image
              Positioned.fill(
                child: thumbnail.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: thumbnail,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[800],
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[800],
                          child: Icon(
                            Icons.movie,
                            color: Colors.grey[400],
                            size: 30,
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: Icon(
                          Icons.movie,
                          color: Colors.grey[400],
                          size: 30,
                        ),
                      ),
              ),

              // Gradient overlay for the specified filter effect
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.2),
                ),
              ),

              // Play icon for continue watching items
              if (completionPercentage > 0)
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Color(0xFFFFE88C),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        color: Color(0xFFFFE88C),
                        size: 14,
                      ),
                    ),
                  ),
                ),

              // Gradient overlay and content
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Season Title
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.8),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Rewards section - Full width
                      if (rewards != null) ...[
                        Container(
                          width: double.infinity,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Product reward
                              if (rewards['product'] != null &&
                                  _hasValidReward(rewards['product'])) ...[
                                Flexible(
                                  flex: 1,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      FaIcon(
                                        FontAwesomeIcons.gift,
                                        color: Color(0xFFF96544),
                                        size: 10,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${rewards['product']}',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w400,
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Reward points
                              if (rewards['reward_points'] != null &&
                                  _hasValidReward(
                                      rewards['reward_points'])) ...[
                                Flexible(
                                  flex: 1,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: Colors.amber,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Image.asset(
                                            'assets/images/coins.png',
                                            width: 9,
                                            height: 10,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${rewards['reward_points']}',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w400,
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Achievement
                              if (rewards['achievement'] != null &&
                                  _hasValidReward(rewards['achievement'])) ...[
                                Flexible(
                                  flex: 1,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SvgPicture.asset(
                                        'assets/svgs/star-badge-solid.svg',
                                        width: 9,
                                        height: 9,
                                        colorFilter: ColorFilter.mode(
                                          Color(0xFFA7DCFF),
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${rewards['achievement']}',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w400,
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      // Completion percentage for continue watching items
                      if (completionPercentage > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          height: 7,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: completionPercentage / 100,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Color(0xFFFFE88C),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Lock indicator (enhanced visibility)
              // Show lock when season is not unlocked (same logic as StoryCard)
              if (!hasUnlocked)
                Positioned(
                  top: 8,
                  left: 8,
                  child: SvgPicture.asset(
                    'assets/svgs/lock.svg',
                    width: 10.5,
                    height: 14,
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
    return WillPopScope(
      onWillPop: () async {
        // Dismiss keyboard and unfocus before popping
        FocusManager.instance.primaryFocus?.unfocus();
        _searchFocusNode.unfocus();

        // Wait a bit for keyboard animation
        await Future.delayed(const Duration(milliseconds: 150));
        return true;
      },
      child: Scaffold(
        appBar: header(
          context: context,
          titleText: 'Search',
        ),
        body: GestureDetector(
          onTap: () {
            // Dismiss keyboard when tapping outside
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: SafeArea(
            child: Column(
              children: [
                _buildSearchBar(),
                _buildSearchResults(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
