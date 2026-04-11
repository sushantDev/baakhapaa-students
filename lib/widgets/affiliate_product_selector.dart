import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/affiliate.dart';
import '../models/affiliate_product.dart';
import '../utils/debug_logger.dart';
import 'skeleton_loading.dart';

class AffiliateProductSelector extends StatefulWidget {
  final List<int> initialSelectedIds;
  final Function(List<dynamic>) onSelected;

  const AffiliateProductSelector({
    super.key,
    required this.initialSelectedIds,
    required this.onSelected,
  });

  @override
  State<AffiliateProductSelector> createState() =>
      _AffiliateProductSelectorState();
}

class _AffiliateProductSelectorState extends State<AffiliateProductSelector> {
  final TextEditingController _searchController = TextEditingController();
  List<AffiliateProduct> _selectedProducts = [];
  bool _isInit = true;
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    if (_isInit) {
      _fetchProducts();
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<AffiliateProvider>(context, listen: false);
      await provider.fetchAvailableProducts(search: _searchController.text);
    } catch (e) {
      DebugLogger.error('Error fetching affiliate products: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleSelection(AffiliateProduct product) {
    setState(() {
      final id = product.id;
      final index = _selectedProducts.indexWhere((p) => p.id == id);
      if (index >= 0) {
        _selectedProducts.removeAt(index);
      } else {
        _selectedProducts.add(product);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Affiliate Products'),
        actions: [
          TextButton(
            onPressed: () {
              widget.onSelected(_selectedProducts);
              Navigator.of(context).pop();
            },
            child: const Text('DONE',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
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

                if (_isLoading && products.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: ListSkeleton(itemCount: 3),
                  );
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
                        _selectedProducts.any((p) => p.id == product.id);

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
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
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
                          onChanged: (_) => _toggleSelection(product),
                          activeColor: Colors.amber,
                        ),
                        onTap: () => _toggleSelection(product),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
