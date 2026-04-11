import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'skeleton_loading.dart';

import 'package:cached_network_image/cached_network_image.dart';
import '../providers/shorts.dart';
import '../providers/story.dart';
import '../providers/auth.dart';
import '../providers/affiliate.dart';
import '../models/affiliate_product.dart';
import '../utils/debug_logger.dart';

class CreatorContentSelector extends StatefulWidget {
  final List<dynamic> initialSelectedShorts;
  final List<dynamic> initialSelectedEpisodes;
  final List<dynamic> initialSelectedSeasons;
  final List<AffiliateProduct> initialSelectedAffiliateProducts;
  final bool showProducts;
  final Function({
    required List<dynamic> shorts,
    required List<dynamic> episodes,
    required List<dynamic> seasons,
    required List<AffiliateProduct> affiliateProducts,
  }) onSelected;

  const CreatorContentSelector({
    super.key,
    required this.initialSelectedShorts,
    required this.initialSelectedEpisodes,
    required this.initialSelectedSeasons,
    this.initialSelectedAffiliateProducts = const [],
    this.showProducts = true,
    required this.onSelected,
  });

  @override
  State<CreatorContentSelector> createState() => _CreatorContentSelectorState();
}

class _CreatorContentSelectorState extends State<CreatorContentSelector> {
  // Selection state
  List<dynamic> _selectedShorts = [];
  List<dynamic> _selectedEpisodes = [];
  List<dynamic> _selectedSeasons = [];
  List<AffiliateProduct> _selectedAffiliateProducts = [];

  // Data state
  bool _isLoadingShorts = false;
  bool _isLoadingSeasons = false;
  bool _isLoadingProducts = false;
  bool _isInit = true;

  // Product Search
  final TextEditingController _searchController = TextEditingController();

  @override
  void didChangeDependencies() {
    if (_isInit) {
      _selectedShorts = List<dynamic>.from(widget.initialSelectedShorts);
      _selectedEpisodes = List<dynamic>.from(widget.initialSelectedEpisodes);
      _selectedSeasons = List<dynamic>.from(widget.initialSelectedSeasons);
      _selectedAffiliateProducts =
          List<AffiliateProduct>.from(widget.initialSelectedAffiliateProducts);
      _fetchData();
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  Future<void> _fetchData() async {
    final auth = Provider.of<Auth>(context, listen: false);
    final userId = auth.userId;
    // Check affiliation status from provider if needed, or assume caller handled permissions.
    // However, we'll fetch products if the user is an affiliate.
    final affiliateProvider =
        Provider.of<AffiliateProvider>(context, listen: false);

    setState(() {
      _isLoadingShorts = true;
      _isLoadingSeasons = true;
      if (affiliateProvider.isAffiliate) {
        _isLoadingProducts = true;
      }
    });

    try {
      // Fetch shorts
      final shortsProvider = Provider.of<Shorts>(context, listen: false);
      await shortsProvider.fetchCreatorShorts(userId);
    } catch (e) {
      DebugLogger.error('Error fetching creator shorts: $e');
    } finally {
      if (mounted) setState(() => _isLoadingShorts = false);
    }

    try {
      // Fetch seasons
      final storyProvider = Provider.of<Story>(context, listen: false);
      await storyProvider.fetchCreatorSeasons(userId);
    } catch (e) {
      DebugLogger.error('Error fetching creator seasons: $e');
    } finally {
      if (mounted) setState(() => _isLoadingSeasons = false);
    }

    if (affiliateProvider.isAffiliate && widget.showProducts) {
      _fetchProducts();
    }
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final provider = Provider.of<AffiliateProvider>(context, listen: false);
      await provider.fetchAvailableProducts(search: _searchController.text);
    } catch (e) {
      DebugLogger.error('Error fetching affiliate products: $e');
    } finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  void _toggleShortSelection(dynamic short) {
    setState(() {
      final id = short['id'];
      final index = _selectedShorts.indexWhere((s) => s['id'] == id);
      if (index >= 0) {
        _selectedShorts.removeAt(index);
      } else {
        _selectedShorts.add(short);
      }
    });
  }

  void _toggleEpisodeSelection(dynamic episode) {
    setState(() {
      final id = episode['id'];
      final index = _selectedEpisodes.indexWhere((e) => e['id'] == id);
      if (index >= 0) {
        _selectedEpisodes.removeAt(index);
      } else {
        _selectedEpisodes.add(episode);
      }
    });
  }

  void _toggleSeasonSelection(dynamic season) {
    setState(() {
      final id = season['id'];
      final index = _selectedSeasons.indexWhere((s) => s['id'] == id);
      if (index >= 0) {
        _selectedSeasons.removeAt(index);
      } else {
        _selectedSeasons.add(season);
      }
    });
  }

  void _toggleProductSelection(AffiliateProduct product) {
    setState(() {
      final id = product.id;
      final index = _selectedAffiliateProducts.indexWhere((p) => p.id == id);
      if (index >= 0) {
        _selectedAffiliateProducts.removeAt(index);
      } else {
        _selectedAffiliateProducts.add(product);
      }
    });
  }

  String _getImageUrl(AffiliateProduct product) {
    String imagePath = product.image ?? '';
    if (imagePath.isEmpty) {
      return 'https://baakhapaa.com/images/logo.png';
    }

    // If it's already a full URL, return it
    if (imagePath.startsWith('http')) {
      return imagePath;
    }

    // Normalize path similar to product.dart
    var normalizedPath = imagePath.trim();
    normalizedPath = normalizedPath.replaceFirst(RegExp(r'^/+'), '');
    normalizedPath = normalizedPath.replaceFirst(
        RegExp(r'^(storage/storage/)+'), 'storage/');
    normalizedPath = normalizedPath.replaceFirst(RegExp(r'^storage/'), '');

    return 'https://app.baakhapaa.com/storage/storage/$normalizedPath';
  }

  @override
  Widget build(BuildContext context) {
    final isAffiliate =
        context.select<AffiliateProvider, bool>((p) => p.isAffiliate);

    return DefaultTabController(
      length: (isAffiliate && widget.showProducts) ? 3 : 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Select Content'),
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Shorts', icon: Icon(Icons.video_library)),
              const Tab(text: 'Episodes', icon: Icon(Icons.movie_filter)),
              if (isAffiliate && widget.showProducts)
                const Tab(text: 'Products', icon: Icon(Icons.shopping_bag)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                widget.onSelected(
                  shorts: _selectedShorts,
                  episodes: _selectedEpisodes,
                  seasons: _selectedSeasons,
                  affiliateProducts: _selectedAffiliateProducts,
                );
                Navigator.of(context).pop();
              },
              child: const Text('DONE',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildShortsTab(),
            _buildEpisodesTab(),
            if (isAffiliate && widget.showProducts) _buildProductsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildShortsTab() {
    return Consumer<Shorts>(
      builder: (ctx, shortsProvider, _) {
        final shorts = shortsProvider.creatorShorts;

        if (_isLoadingShorts && shorts.isEmpty) {
          return const ListSkeleton(itemCount: 3);
        }

        if (shorts.isEmpty) {
          return const Center(
              child: Text(
                  'No shorts found. Post your first short to link it here!'));
        }

        return ListView.builder(
          itemCount: shorts.length,
          padding: const EdgeInsets.all(12),
          itemBuilder: (ctx, i) {
            final short = shorts[i];
            final isSelected =
                _selectedShorts.any((s) => s['id'] == short['id']);
            return _buildContentItem(
              title: short['title'] ?? 'Untitled',
              subtitle:
                  '${short['views'] ?? 0} views • ${short['likes'] ?? 0} likes',
              thumbnail: short['thumbnail'],
              isSelected: isSelected,
              onTap: () => _toggleShortSelection(short),
            );
          },
        );
      },
    );
  }

  Widget _buildEpisodesTab() {
    return Consumer<Story>(
      builder: (ctx, storyProvider, _) {
        final seasons = storyProvider.creatorSeasons;

        if (_isLoadingSeasons && seasons.isEmpty) {
          return const ListSkeleton(itemCount: 3);
        }

        if (seasons.isEmpty) {
          return const Center(
              child: Text(
                  'No seasons found. Create a season and episodes to link them here!'));
        }

        return ListView.builder(
          itemCount: seasons.length,
          padding: const EdgeInsets.all(12),
          itemBuilder: (ctx, i) {
            final season = seasons[i];
            final isSeasonSelected =
                _selectedSeasons.any((s) => s['id'] == season['id']);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSeasonSelected ? Colors.amber : Colors.transparent,
                    width: 2,
                  )),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                title: Text(season['title'] ?? 'Untitled',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                leading: const Icon(Icons.folder, color: Colors.amber),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: isSeasonSelected,
                      onChanged: (_) => _toggleSeasonSelection(season),
                      activeColor: Colors.amber,
                    ),
                    const Icon(Icons.expand_more),
                  ],
                ),
                children: [
                  _SeasonEpisodesList(
                    seasonId: season['id'],
                    selectedEpisodes: _selectedEpisodes,
                    onToggle: _toggleEpisodeSelection,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProductsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search products...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _fetchProducts();
                },
              ),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onSubmitted: (_) => _fetchProducts(),
          ),
        ),
        Expanded(
          child: Consumer<AffiliateProvider>(
            builder: (ctx, provider, _) {
              final products = provider.availableProducts;

              if (_isLoadingProducts && products.isEmpty) {
                return const ListSkeleton(itemCount: 3);
              }

              if (products.isEmpty) {
                return const Center(child: Text('No products found'));
              }

              return ListView.builder(
                itemCount: products.length,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemBuilder: (ctx, i) {
                  final product = products[i];
                  final isSelected =
                      _selectedAffiliateProducts.any((p) => p.id == product.id);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? Colors.amber : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: _getImageUrl(product),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: (ctx, url) => Container(
                            color: Colors.grey[800],
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (ctx, url, error) =>
                              const Icon(Icons.image),
                        ),
                      ),
                      title: Text(
                        product.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (product.brand != null)
                            Text(
                              product.brand!.title,
                              style: TextStyle(
                                color: Colors.amber[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                'Rs. ${product.price}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${product.affiliateCommission} Points',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleProductSelection(product),
                        activeColor: Colors.amber,
                      ),
                      onTap: () => _toggleProductSelection(product),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContentItem({
    required String title,
    required String subtitle,
    String? thumbnail,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.amber : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: thumbnail != null && thumbnail.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: thumbnail,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  placeholder: (ctx, url) => Container(color: Colors.grey[800]),
                  errorWidget: (ctx, url, error) => const Icon(Icons.image),
                )
              : Container(
                  width: 50,
                  height: 50,
                  color: Colors.grey[800],
                  child: const Icon(Icons.image)),
        ),
        title: Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: Checkbox(
          value: isSelected,
          onChanged: (_) => onTap(),
          activeColor: Colors.amber,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _SeasonEpisodesList extends StatefulWidget {
  final int seasonId;
  final List<dynamic> selectedEpisodes;
  final Function(dynamic) onToggle;

  const _SeasonEpisodesList({
    required this.seasonId,
    required this.selectedEpisodes,
    required this.onToggle,
  });

  @override
  State<_SeasonEpisodesList> createState() => _SeasonEpisodesListState();
}

class _SeasonEpisodesListState extends State<_SeasonEpisodesList> {
  List<dynamic> _episodes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchEpisodes();
  }

  Future<void> _fetchEpisodes() async {
    setState(() => _isLoading = true);
    try {
      final storyProvider = Provider.of<Story>(context, listen: false);
      final episodes = await storyProvider.fetchSeasonEpisodes(widget.seasonId);
      if (mounted) setState(() => _episodes = episodes);
    } catch (e) {
      DebugLogger.error(
          'Error fetching episodes for season ${widget.seasonId}: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: ListSkeleton(itemCount: 2),
      );
    }

    if (_episodes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No episodes in this season.'),
      );
    }

    return Column(
      children: [
        const Divider(height: 1),
        ..._episodes.map((episode) {
          final isSelected =
              widget.selectedEpisodes.any((e) => e['id'] == episode['id']);
          return ListTile(
            dense: true,
            leading: const Icon(Icons.play_circle_outline,
                size: 20, color: Colors.grey),
            title: Text(episode['title'] ?? 'Untitled'),
            trailing: Checkbox(
              value: isSelected,
              onChanged: (_) => widget.onToggle(episode),
              activeColor: Colors.amber,
            ),
            onTap: () => widget.onToggle(episode),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }
}
