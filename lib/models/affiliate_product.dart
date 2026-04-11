class AffiliateProduct {
  final int id;
  final String title;
  final int qty;
  final int coin;
  final int price;
  final String? type;
  final String? description;
  final int? affiliateCommission;
  final Brand? brand;
  final List<ProductImage>? images;
  final String? image; // Kept for backward compatibility/quick access

  AffiliateProduct({
    required this.id,
    required this.title,
    required this.qty,
    required this.coin,
    required this.price,
    this.type,
    this.description,
    this.affiliateCommission,
    this.brand,
    this.images,
    this.image,
  });

  factory AffiliateProduct.fromJson(Map<String, dynamic> json) {
    final imagesList = json['images'] != null
        ? (json['images'] as List).map((i) => ProductImage.fromJson(i)).toList()
        : null;

    return AffiliateProduct(
      id: json['id'],
      title: json['title'] ?? 'Unknown Product',
      qty: json['qty'] ?? 0,
      coin: json['coin'] ?? 0,
      price: json['price'] ?? 0,
      type: json['type'],
      description: json['description'],
      affiliateCommission: json['affiliate_commission'],
      brand: json['brand'] != null ? Brand.fromJson(json['brand']) : null,
      images: imagesList,
      // Try to get first image's full path if available
      image: json['image'] ??
          (imagesList != null && imagesList.isNotEmpty
              ? imagesList.first.full
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'qty': qty,
      'coin': coin,
      'price': price,
      'type': type,
      'description': description,
      'affiliate_commission': affiliateCommission,
      'brand': brand?.toJson(),
      'images': images?.map((i) => i.toJson()).toList(),
      'image': image,
    };
  }
}

class ProductImage {
  final int id;
  final String full;

  ProductImage({
    required this.id,
    required this.full,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      id: json['id'],
      full: json['full'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full': full,
    };
  }
}

class Brand {
  final int id;
  final String title;
  final String? description;

  Brand({
    required this.id,
    required this.title,
    this.description,
  });

  factory Brand.fromJson(Map<String, dynamic> json) {
    return Brand(
      id: json['id'],
      title: json['title'] ?? 'Unknown Brand',
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
    };
  }
}
