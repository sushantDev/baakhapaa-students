import 'package:baakhapaa/models/product_draft.dart';
import 'package:baakhapaa/models/product_variant.dart';
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/providers/vendor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';

import '../../shop/create/create_product_screen.dart';
import '../../../utils/debug_logger.dart';

class VendorProductTypeScreen extends StatefulWidget {
  static const routeName = '/vendor-product-type';

  const VendorProductTypeScreen({super.key});

  @override
  State<VendorProductTypeScreen> createState() =>
      _VendorProductTypeScreenState();
}

class _VendorProductTypeScreenState extends State<VendorProductTypeScreen>
    with WidgetsBindingObserver {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadProducts();
    });
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;

    try {
      final auth = Provider.of<Auth>(context, listen: false);
      final vendor = Provider.of<Vendor>(context, listen: false);
      DebugLogger.info(
          '🔍 Fetching products for userId: ${auth.userId}'); // Debug log
      await vendor.fetchProducts(auth.userId);
      if (mounted) {
        DebugLogger.info(
            '✅ Loaded ${vendor.products.length} products'); // Debug log
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load products: ${e.toString()}')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    final products = context.watch<Vendor>().products;
    if (_searchQuery.isEmpty) return products;
    return products
        .where((p) =>
            p['title'].toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Product Studio',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButton: _buildFAB(context),
      body: _buildBody(isDark),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // BODY
  // ──────────────────────────────────────────────────────────────

  Widget _buildBody(bool isDark) {
    final products = context.watch<Vendor>().products;

    // Show empty state if no products
    if (products.isEmpty && _searchQuery.isEmpty) {
      return _buildEmptyState(isDark);
    }

    return RefreshIndicator(
      onRefresh: _loadProducts,
      displacement: 80,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildHeader(isDark),
          _buildStats(isDark),
          _buildSearch(isDark),
          _buildProductList(isDark),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // HEADER
  // ──────────────────────────────────────────────────────────────

  SliverToBoxAdapter _buildHeader(bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vendor Dashboard',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Manage your store products',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // STATS
  // ──────────────────────────────────────────────────────────────

  SliverToBoxAdapter _buildStats(bool isDark) {
    final products = context.watch<Vendor>().products;
    final total = products.length;
    final active = products.where((p) => p['approved'] == 1).length;
    final pending = products.where((p) => p['approved'] == 0).length;
    final outOfStock = products.where((p) => p['qty'] == 0).length;

    return SliverToBoxAdapter(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            _statCard('Products', '$total', Icons.inventory, Colors.indigo),
            _statCard('Active', '$active', Icons.check_circle, Colors.green),
            _statCard(
                'Pending', '$pending', Icons.hourglass_empty, Colors.orange),
            _statCard('Out of Stock', '$outOfStock', Icons.warning, Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withOpacity(.8)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(.9))),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // SEARCH
  // ──────────────────────────────────────────────────────────────

  SliverToBoxAdapter _buildSearch(bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Search products...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // PRODUCT LIST
  // ──────────────────────────────────────────────────────────────

  SliverList _buildProductList(bool isDark) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final product = _filteredProducts[index];
          return _buildProductCard(product, isDark);
        },
        childCount: _filteredProducts.length,
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, bool isDark) {
    final outOfStock = product['qty'] == 0;
    final images = product['images'] as List? ?? [];
    final isApproved = product['approved'] == 1;

    // Extract image URL from object {"id": 633, "full": "products/..."}
    String? imageUrl;
    if (images.isNotEmpty) {
      if (images[0] is Map) {
        final path = images[0]['full']?.toString();
        if (path != null) {
          // Base URL for product images
          imageUrl = 'https://student.baakhapaa.com/storage/$path';
        }
      } else if (images[0] is String) {
        imageUrl = 'https://student.baakhapaa.com/storage/${images[0]}';
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  if (imageUrl != null)
                    Image.network(
                      imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 180,
                        color: Colors.grey.shade300,
                        child: const Center(child: Icon(Icons.image, size: 60)),
                      ),
                    )
                  else
                    Container(
                      height: 180,
                      color: Colors.grey.shade300,
                      child: const Center(child: Icon(Icons.image, size: 60)),
                    ),
                  if (images.length > 1)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '+${images.length - 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (!isApproved)
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Not Approved',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['title'],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Rs. ${product['price']}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  /// Stock status
                  Row(
                    children: [
                      Icon(
                        outOfStock ? Icons.warning : Icons.check_circle,
                        size: 16,
                        color: outOfStock ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        outOfStock
                            ? 'Out of Stock'
                            : 'Stock: ${product['qty']}',
                        style: TextStyle(
                          color: outOfStock ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  /// ACTION BUTTONS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _actionButton(
                        icon: Icons.edit,
                        color: Colors.blue,
                        label: 'Edit',
                        onTap: () => _editProduct(product),
                      ),
                      const SizedBox(width: 12),
                      _actionButton(
                        icon: Icons.delete,
                        color: Colors.red,
                        label: 'Delete',
                        onTap: () => _confirmDelete(product['id']),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  // ──────────────────────────────────────────────────────────────
  // ACTION BUTTON
  // ──────────────────────────────────────────────────────────────

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // EMPTY STATE
  // ──────────────────────────────────────────────────────────────
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  size: 64,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Products Yet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Start creating your first product to build your store and reach customers with amazing products.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.black54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667eea).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.push(
                      context,
                      PageTransition(
                        type: PageTransitionType.rightToLeft,
                        child: const CreateProductScreen(),
                      ),
                    ).then((_) => _loadProducts());
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 24),
                  label: const Text('Create Your First Product'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 18),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // ──────────────────────────────────────────────────────────────
  // FAB
  // ──────────────────────────────────────────────────────────────

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        HapticFeedback.mediumImpact();
        Navigator.push(
          context,
          PageTransition(
            type: PageTransitionType.rightToLeft,
            child: const CreateProductScreen(),
          ),
        );
      },
      icon: const Icon(Icons.add),
      label: const Text('New Product'),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // BOTTOM SHEET (EDIT / DELETE)
  // ──────────────────────────────────────────────────────────────

  // void _showProductOptions(Map<String, dynamic> product, bool isDark) {
  //   showModalBottomSheet(
  //     context: context,
  //     backgroundColor: Colors.transparent,
  //     builder: (_) => Container(
  //       decoration: BoxDecoration(
  //         color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
  //         borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
  //       ),
  //       child: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           _optionTile(
  //             Icons.edit,
  //             'Edit Product',
  //             onTap: () {
  //               Navigator.pop(context);
  //               _editProduct(product);
  //             },
  //           ),
  //           _optionTile(
  //             Icons.delete,
  //             'Delete Product',
  //             isDestructive: true,
  //             onTap: () {
  //               Navigator.pop(context);
  //               _confirmDelete(product['id']);
  //             },
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // Widget _optionTile(
  //   IconData icon,
  //   String title, {
  //   bool isDestructive = false,
  //   VoidCallback? onTap,
  // }) {
  //   return ListTile(
  //     leading: Icon(icon, color: isDestructive ? Colors.red : null),
  //     title: Text(
  //       title,
  //       style: TextStyle(
  //         color: isDestructive ? Colors.red : null,
  //       ),
  //     ),
  //     onTap: onTap,
  //   );
  // }

  // ──────────────────────────────────────────────────────────────
  // DELETE CONFIRMATION
  // ──────────────────────────────────────────────────────────────

  void _confirmDelete(int productId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text(
          'Are you sure you want to delete this product? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _deleteProduct(productId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteProduct(int productId) async {
    try {
      await context.read<Vendor>().deleteProduct(productId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _editProduct(Map<String, dynamic> product) async {
    final categories = product['categories'] as List? ?? [];
    // final episodes = product['episodes'] as List? ?? [];
    final brand = product['brand'] as Map<String, dynamic>?;

    // Safely extract string values
    final vendorLink = product['vendor_link']?.toString() ?? '';
    final description = product['description']?.toString() ?? '';

    // Extract existing image URLs
    final images = product['images'] as List? ?? [];
    final existingImageUrls = images
        .map((img) {
          if (img is Map && img['full'] != null) {
            return img['full'].toString();
          }
          return null;
        })
        .where((url) => url != null)
        .cast<String>()
        .toList();

    // Extract and parse variants from backend
    final backendVariants = product['variants'] as List? ?? [];
    final parsedVariants = backendVariants.map((v) {
      final optionValues = v['option_values'] as List? ?? [];
      final backendOptionValues = optionValues.map((ov) {
        return BackendOptionValue(
          optionName: ov['option']['name'].toString(),
          value: ov['value'].toString(),
        );
      }).toList();

      // Parse option values as "OptionName:Value" format
      final optionValueStrings = backendOptionValues
          .map((ov) => '${ov.optionName}:${ov.value}')
          .toList();

      return ProductVariant(
        price: v['price'] != null
            ? double.parse(v['price'].toString()).round()
            : null, // 🔥 Parse String price correctly
        qty: v['qty'] as int?,
        existingImageUrl: v['image']?.toString(), // 🔥 Set backend image URL
        backendOptionValues: backendOptionValues,
        optionValues: optionValueStrings, // 🔥 Set formatted option values
      );
    }).toList();

    final result = await Navigator.push(
      context,
      PageTransition(
        type: PageTransitionType.rightToLeft,
        child: CreateProductScreen(
          productId: product['id'],
          product: ProductDraft(
            id: product['id'],
            title: product['title']?.toString() ?? '',
            qty: product['qty'] as int?,
            coin: product['coin'] as int?,
            price: product['price'] as int?,
            brandId: brand?['id'] as int? ?? 0,
            categoryId:
                categories.isNotEmpty ? categories[0]['id'] as int? : null,
            // episodeId: episodes.isNotEmpty ? episodes[0]['id'] as int? : null,
            vendorLink: vendorLink,
            description: description,
            expiresAt: DateTime.parse(product['expires_at']),
            images: [], // New images will be picked separately
            existingImageUrls: existingImageUrls, // 👈 Pass existing images
            type: 'product',
            variants: parsedVariants, // 👈 Pass parsed variants
          ),
        ),
      ),
    );

    if (result == true) {
      _loadProducts(); // Refresh list after edit
    }
  }
}
