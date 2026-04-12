// ignore_for_file: duplicate_ignore, unused_element

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:baakhapaa/helpers/helpers.dart';
import './creator_story_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/auth.dart';
import '../../providers/story.dart';
import '../../providers/shorts.dart';
import '../../widgets/header.dart';
import '../../widgets/loading.dart';
import '../../utils/debug_logger.dart';
import '../../utils/guest_auth_helper.dart';

class CreatorsScreen extends StatefulWidget {
  static const routeName = '/creators-screen';

  const CreatorsScreen({Key? key}) : super(key: key);

  @override
  State<CreatorsScreen> createState() => _CreatorsScreenState();
}

class _CreatorsScreenState extends State<CreatorsScreen> {
  bool _isLoading = true;
  bool _isLoadingCounts = false;
  Map<int, Map<String, int>> _counts = {};

  List<dynamic> _creators = [];
  List<dynamic> _filtered = [];

  String _searchQuery = "";
  String _filter = "All";

  Timer? _debounce;

  bool get _isActiveRoute =>
      mounted && (ModalRoute.of(context)?.isCurrent ?? true);

  @override
  void initState() {
    super.initState();
    _loadCreators();
  }

  Future<void> _loadCreators() async {
    try {
      setState(() => _isLoading = true);

      final auth = Provider.of<Auth>(context, listen: false);
      await auth.fetchAllCreators();

      _creators = auth.creators;
      _filtered = _creators;
    } catch (e) {
      DebugLogger.error("Failed loading creators: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed loading creators")),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ignore: unused_element
  void _loadCreatorCountsBatched() async {
    if (_isLoadingCounts) return;
    _isLoadingCounts = true;

    final story = Provider.of<Story>(context, listen: false);
    final shorts = Provider.of<Shorts>(context, listen: false);

    final ids = _creators.map((c) => c['id'] as int).toList();

    for (int i = 0; i < ids.length; i++) {
      if (!mounted) break;
      while (!_isActiveRoute && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      if (!mounted) break;
      await _fetchCount(ids[i], story, shorts);
      if (mounted && (i % 3 == 2 || i == ids.length - 1)) setState(() {});
      if (i < ids.length - 1) {
        await Future.delayed(const Duration(milliseconds: 1200));
      }
    }

    _isLoadingCounts = false;
  }

  Future<void> _fetchCount(int id, Story story, Shorts shorts,
      {int retryCount = 0}) async {
    if (_counts.containsKey(id)) return;

    try {
      // Sequential calls to avoid doubling concurrent request load
      final storyList = await story.fetchCreatorSeasons(id, returnList: true);
      await Future.delayed(const Duration(milliseconds: 100));
      final shortsList = await shorts.fetchCreatorShorts(id, returnList: true);

      _counts[id] = {
        "story": (storyList as dynamic).length as int,
        "shorts": (shortsList as dynamic).length as int,
      };
    } catch (e) {
      final is429 = e.toString().contains('429') ||
          e.toString().toLowerCase().contains('rate limit');

      if (is429 && retryCount < 3) {
        // Exponential backoff with jitter to avoid thundering herd
        final baseDelay = 2000 * (retryCount + 1);
        final jitter = (baseDelay * 0.3).round();
        final delayMs = baseDelay + (DateTime.now().millisecond % jitter);
        await Future.delayed(Duration(milliseconds: delayMs));
        return _fetchCount(id, story, shorts, retryCount: retryCount + 1);
      }

      _counts[id] = {"story": 0, "shorts": 0};
    }
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _searchQuery = q.toLowerCase();
      _applyFilters();
    });
  }

  void _onFilterChanged(String f) {
    _filter = f;
    _fetchFilteredCreators(f);
  }

  String _mapFilterToBackend(String uiFilter) {
    switch (uiFilter) {
      case "Most Popular":
        return "most_popular";
      case "Trending":
        return "trending";
      case "Following":
        return "following";
      default:
        return "most_popular";
    }
  }

  Future<void> _fetchFilteredCreators(String filter) async {
    if (filter == "All") {
      setState(() {
        _filtered = _creators;
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() => _isLoading = true);

      final auth = Provider.of<Auth>(context, listen: false);
      final response = await http.get(
        Uri.parse(
            'https://student.baakhapaa.com/api/creators/filter?filter=${_mapFilterToBackend(filter)}'),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _filtered = List<dynamic>.from(data['data']['values'] ?? []);
          _isLoading = false;
        });

        DebugLogger.info(
          '✅ Filtered creators loaded: ${_filtered.length} creators for filter "$filter"',
        );

        // Debug: Log first creator structure
        if (_filtered.isNotEmpty) {
          final firstCreator = _filtered.first;
          DebugLogger.info(
              '👤 First creator keys: ${firstCreator.keys.toString()}');
          DebugLogger.info(
              '👤 First creator has images: ${firstCreator['images'] != null}');
          if (firstCreator['images'] is List) {
            DebugLogger.info(
                '👤 First creator images count: ${(firstCreator['images'] as List).length}');
            if ((firstCreator['images'] as List).isNotEmpty) {
              final firstImage = (firstCreator['images'] as List).first;
              DebugLogger.info('👤 First creator image structure: $firstImage');
            }
          }
        }

        // Load counts for filtered creators
        _loadCreatorCountsBatchedForFiltered();
      } else {
        throw Exception('Filter failed: ${response.statusCode}');
      }
    } catch (e) {
      DebugLogger.error("Filter failed: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Load counts for filtered creators
  void _loadCreatorCountsBatchedForFiltered() async {
    if (_isLoadingCounts) return;
    _isLoadingCounts = true;

    final story = Provider.of<Story>(context, listen: false);
    final shorts = Provider.of<Shorts>(context, listen: false);

    final ids = _filtered.map((c) => c['id'] as int).toList();

    // Clear previous counts for this batch
    for (var id in ids) {
      _counts.remove(id);
    }

    for (int i = 0; i < ids.length; i++) {
      if (!mounted) break;
      while (!_isActiveRoute && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      if (!mounted) break;
      await _fetchCount(ids[i], story, shorts);
      if (mounted && (i % 3 == 2 || i == ids.length - 1)) setState(() {});
      if (i < ids.length - 1) {
        await Future.delayed(const Duration(milliseconds: 1200));
      }
    }

    _isLoadingCounts = false;
  }

  void _applyFilters() {
    setState(() {
      _filtered = _creators.where((c) {
        final u = c['username'].toString().toLowerCase();
        final matchesSearch = u.contains(_searchQuery);

        bool matchesFilter = true;
        switch (_filter) {
          case "Most Popular":
            matchesFilter =
                (int.tryParse(c['total_points']?.toString() ?? '0') ?? 0) > 200;
            break;
          case "Trending":
            matchesFilter =
                (int.tryParse(c['total_points']?.toString() ?? '0') ?? 0) >
                    1000;
            break;
          case "Following":
            matchesFilter = c['is_following'] == true;
            break;
          default:
            matchesFilter = true;
        }

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  int _countStory(int id) {
    final creator =
        _filtered.firstWhere((c) => c['id'] == id, orElse: () => null);
    return creator != null ? (creator['seasons_count'] ?? 0) as int : 0;
  }

  int _countShort(int id) {
    final creator =
        _filtered.firstWhere((c) => c['id'] == id, orElse: () => null);
    return creator != null ? (creator['shorts_count'] ?? 0) as int : 0;
  }

  bool _countLoading(int id) => false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F5F7),
      appBar: header(
        context: context,
        titleText: 'Teachers',
      ),
      body: RefreshIndicator(
        onRefresh: _loadCreators,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF090909), const Color(0xFF082032)]
                  : [Colors.white, Colors.grey.shade300],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              const _SubHeader(),
              _SearchSection(onSearch: _onSearchChanged),
              _FilterSection(onFilter: _onFilterChanged),
              Expanded(
                child: _isLoading
                    ? const Center(child: Loading())
                    : _filtered.isEmpty
                        ? const _EmptyState()
                        : _CreatorsList(
                            creators: _filtered,
                            storyCount: _countStory,
                            shortsCount: _countShort,
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Sub Header — clean minimal stats bar
// =====================================================================
class _SubHeader extends StatelessWidget {
  const _SubHeader();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coins = Provider.of<Auth>(context).userAvailableCoins;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Discover Teachers',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Find teachers you\'ll love',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pushNamed('/points-screen'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.amber.withValues(alpha: 0.12)
                    : Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/coins.png', width: 18, height: 18),
                  const SizedBox(width: 6),
                  Text(
                    coins.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.amber.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Search Bar — clean rounded input
// =====================================================================
class _SearchSection extends StatelessWidget {
  final Function(String) onSearch;

  const _SearchSection({required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: TextField(
          onChanged: onSearch,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: '${context.l10n.search} teachers...',
            hintStyle: TextStyle(
              color: isDark ? Colors.white30 : Colors.black26,
              fontSize: 15,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: isDark ? Colors.white30 : Colors.black26,
              size: 22,
            ),
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Filter Pills — modern chip style
// =====================================================================
class _FilterSection extends StatefulWidget {
  final Function(String) onFilter;

  const _FilterSection({required this.onFilter});

  @override
  State<_FilterSection> createState() => _FilterSectionState();
}

class _FilterSectionState extends State<_FilterSection> {
  String _selected = "All";

  final List<_FilterItem> _filters = [
    _FilterItem("All", Icons.grid_view_rounded),
    _FilterItem("Most Popular", Icons.local_fire_department_rounded),
    _FilterItem("Trending", Icons.trending_up_rounded),
    _FilterItem("Following", Icons.people_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final f = _filters[i];
          final isSelected = _selected == f.label;

          return GestureDetector(
            onTap: () {
              setState(() => _selected = f.label);
              widget.onFilter(f.label);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.shade500
                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    f.icon,
                    size: 16,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.grey.shade700),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    f.label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

//
// -----------------------------
// Count Badge
// -----------------------------
class CountBadge extends StatelessWidget {
  final List<Color> colors;
  final String? assetIcon;
  final IconData? iconData;
  final bool loading;
  final int count;

  const CountBadge({
    super.key,
    required this.colors,
    required this.count,
    this.loading = false,
    this.assetIcon,
    this.iconData,
  });

  String _format(int n) {
    if (n >= 1000000) return "${(n / 1000000).toStringAsFixed(1)}M";
    if (n >= 1000) return "${(n / 1000).toStringAsFixed(1)}K";
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          else if (assetIcon != null)
            Image.asset(assetIcon!, width: 12, height: 12)
          else if (iconData != null)
            Icon(iconData, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          if (!loading)
            Text(
              _format(count),
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterItem {
  final String label;
  final IconData icon;
  const _FilterItem(this.label, this.icon);
}

// =====================================================================
// Creators List — modern card-based list layout
// =====================================================================
class _CreatorsList extends StatelessWidget {
  final List<dynamic> creators;
  final int Function(int id) storyCount;
  final int Function(int id) shortsCount;
  final bool Function(int id) isLoading;

  const _CreatorsList({
    required this.creators,
    required this.storyCount,
    required this.shortsCount,
    // ignore: unused_element_parameter
    this.isLoading = _defaultIsLoading,
  });

  static bool _defaultIsLoading(int id) => false;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: creators.length,
      itemBuilder: (_, i) {
        final c = creators[i];
        return _CreatorCard(
          creator: c,
          storyCount: storyCount,
          shortsCount: shortsCount,
          isLoading: isLoading,
        );
      },
    );
  }
}

// =====================================================================
// Creator Card — horizontal card with avatar, info, and stats
// =====================================================================
class _CreatorCard extends StatelessWidget {
  final Map<String, dynamic> creator;
  final int Function(int id) storyCount;
  final int Function(int id) shortsCount;
  final bool Function(int id) isLoading;

  const _CreatorCard({
    required this.creator,
    required this.storyCount,
    required this.shortsCount,
    required this.isLoading,
  });

  String _image(Map c) {
    if (c['image'] is String && (c['image'] as String).isNotEmpty) {
      return c['image'] as String;
    }
    final imgs = c['images'];
    if (imgs is List && imgs.isNotEmpty) {
      final first = imgs[0];
      if (first is Map) {
        for (final key in ['full', 'thumbnail', 'url', 'image']) {
          if (first[key] is String && (first[key] as String).isNotEmpty) {
            return first[key] as String;
          }
        }
      }
    }
    return "https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg";
  }

  String _formatCount(int n) {
    if (n >= 1000000) return "${(n / 1000000).toStringAsFixed(1)}M";
    if (n >= 1000) return "${(n / 1000).toStringAsFixed(1)}K";
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final id = creator['id'];
    final imageUrl = _image(creator);
    final name = (creator['name'] ?? creator['username'] ?? '').toString();
    final username = (creator['username'] ?? '').toString();
    // ignore: unused_local_variable
    final totalPoints =
        int.tryParse(creator['total_points']?.toString() ?? '0') ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () async {
          if (creator['id'] == null) return;
          final auth = Provider.of<Auth>(context, listen: false);
          if (auth.isGuest) {
            await GuestAuthHelper.showGuestLoginDialog(
                context, 'view storyteller profile');
            return;
          }
          Navigator.of(context).pushNamed(
            CreatorStoryScreen.routeName,
            arguments: [creator['id'], name],
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar with ring
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade400, Colors.orange.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(2.5),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: isDark
                          ? const Color(0xFF2A2A2A)
                          : Colors.grey.shade100,
                      child: const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: isDark
                          ? const Color(0xFF2A2A2A)
                          : Colors.grey.shade100,
                      child: Icon(
                        Icons.person_rounded,
                        color: isDark ? Colors.white24 : Colors.black12,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Name & Username
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (username.isNotEmpty)
                      Text(
                        '@$username',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        CountBadge(
                          colors: const [Color(0xFFF9F5FF), Color(0xFF9191FD)],
                          assetIcon: "assets/images/story-playlist.png",
                          count: storyCount(id),
                          loading: isLoading(id),
                        ),
                        const Spacer(),
                        CountBadge(
                          colors: const [Color(0xFF990000), Color(0xFFFF0000)],
                          iconData: Icons.play_circle,
                          count: shortsCount(id),
                          loading: isLoading(id),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Stat Chip — tiny inline stat badge
// =====================================================================
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool loading;
  final bool isDark;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.loading,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                color: color,
                strokeWidth: 1.5,
              ),
            )
          else
            Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          if (!loading)
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}

// =====================================================================
// Empty State
// =====================================================================
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_outline_rounded,
            color:
                isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black12,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No teachers found',
            style: GoogleFonts.inter(
              color: isDark ? Colors.white38 : Colors.black38,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try a different search or filter',
            style: GoogleFonts.inter(
              color: isDark ? Colors.white24 : Colors.black26,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
