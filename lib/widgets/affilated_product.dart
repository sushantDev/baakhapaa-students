import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:baakhapaa/screens/shop/single_product_screen.dart';

class AffiliatedProduct extends StatelessWidget {
  final double height;
  final double itemWidth;
  final Color color;
  final VoidCallback? onClose;
  final List<dynamic>? products;
  final int? affiliateId;

  const AffiliatedProduct({
    super.key,
    this.height = 120,
    this.itemWidth = 120,
    this.color = Colors.grey,
    this.onClose,
    this.products,
    this.affiliateId,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 13, 13, 13).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Shop Now",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                    Icon(
                      Icons.close,
                      color: Colors.white.withOpacity(0.7),
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: height,
                  child: products != null && products!.isNotEmpty
                      ? ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: products!.length,
                          itemBuilder: (context, i) {
                            final product = products![i];
                            final productId = product['id'] ?? 0;
                            final productTitle = product['title'] ?? 'Product';
                            final productCoin = product['coin'] ?? 0;
                            final productImage = product['image'] ?? '';

                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).pushNamed(
                                  SingleProductScreen.routeName,
                                  arguments: {
                                    'id': productId,
                                    'affiliateId': affiliateId,
                                  },
                                );
                              },
                              child: Container(
                                width: itemWidth,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Product Image
                                      Expanded(
                                        child: Stack(
                                          children: [
                                            Container(
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    color.withOpacity(0.4),
                                                    color.withOpacity(0.2),
                                                  ],
                                                ),
                                              ),
                                              child: productImage.isNotEmpty
                                                  ? CachedNetworkImage(
                                                      imageUrl: productImage,
                                                      fit: BoxFit.cover,
                                                      placeholder:
                                                          (context, url) =>
                                                              Center(
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          valueColor:
                                                              AlwaysStoppedAnimation<
                                                                  Color>(
                                                            Colors.white
                                                                .withOpacity(
                                                                    0.5),
                                                          ),
                                                        ),
                                                      ),
                                                      errorWidget: (context,
                                                              url, error) =>
                                                          Center(
                                                        child: Icon(
                                                          Icons.image_outlined,
                                                          size: 40,
                                                          color: Colors.white
                                                              .withOpacity(0.3),
                                                        ),
                                                      ),
                                                    )
                                                  : Center(
                                                      child: Icon(
                                                        Icons.image_outlined,
                                                        size: 40,
                                                        color: Colors.white
                                                            .withOpacity(0.3),
                                                      ),
                                                    ),
                                            ),
                                            // Coin badge
                                            Positioned(
                                              top: 6,
                                              right: 6,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.3),
                                                      blurRadius: 4,
                                                      offset:
                                                          const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Image.asset(
                                                      'assets/images/coins.png',
                                                      height: 12,
                                                      width: 12,
                                                      fit: BoxFit.contain,
                                                    ),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      '$productCoin',
                                                      style: TextStyle(
                                                        color: Colors.black,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Product Title
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(16),
                                            bottomRight: Radius.circular(16),
                                          ),
                                        ),
                                        child: Text(
                                          productTitle,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : Center(
                          child: Text(
                            'No products available',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
