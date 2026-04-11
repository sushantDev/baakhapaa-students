import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/shorts.dart';
import '../providers/auth.dart';
import '../utils/debug_logger.dart';
import 'skeleton_loading.dart';

class CreatorShortsSelector extends StatefulWidget {
  final List<dynamic> initialSelectedShorts;
  final Function(List<dynamic>) onSelected;

  const CreatorShortsSelector({
    super.key,
    required this.initialSelectedShorts,
    required this.onSelected,
  });

  @override
  State<CreatorShortsSelector> createState() => _CreatorShortsSelectorState();
}

class _CreatorShortsSelectorState extends State<CreatorShortsSelector> {
  List<dynamic> _selectedShorts = [];
  bool _isLoading = false;
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    if (_isInit) {
      _selectedShorts = List<dynamic>.from(widget.initialSelectedShorts);
      _fetchCreatorShorts();
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  Future<void> _fetchCreatorShorts() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<Auth>(context, listen: false);
      final shortsProvider = Provider.of<Shorts>(context, listen: false);
      await shortsProvider.fetchCreatorShorts(auth.userId);
    } catch (e) {
      DebugLogger.error('Error fetching creator shorts: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleSelection(dynamic short) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Featured Shorts'),
        actions: [
          TextButton(
            onPressed: () {
              widget.onSelected(_selectedShorts);
              Navigator.of(context).pop();
            },
            child: const Text('DONE',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Consumer<Shorts>(
        builder: (ctx, shortsProvider, _) {
          final shorts = shortsProvider.creatorShorts;

          if (_isLoading && shorts.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24.0),
              child: ListSkeleton(itemCount: 3),
            );
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
                      imageUrl: short['thumbnail'] ?? '',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      placeholder: (ctx, url) =>
                          Container(color: Colors.grey[800]),
                      errorWidget: (ctx, url, error) =>
                          const Icon(Icons.video_library),
                    ),
                  ),
                  title: Text(
                    short['title'] ?? 'Untitled',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${short['views'] ?? 0} views • ${short['likes'] ?? 0} likes',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSelection(short),
                    activeColor: Colors.amber,
                  ),
                  onTap: () => _toggleSelection(short),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
