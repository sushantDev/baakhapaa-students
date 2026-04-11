import 'package:baakhapaa/models/product_option_draft.dart';
import 'package:baakhapaa/models/product_variant.dart';
import 'package:image_picker/image_picker.dart';

class ProductDraft {
  final int? id;

  final String title;
  final String? description;
  final int? price;
  final int? coin;
  final int? qty;
  final int? brandId;
  final int? categoryId;
  // final int? episodeId;
  final String type; // ✅ ADD THIS
  final String? vendorLink;
  final DateTime? expiresAt;
  final List<XFile> images;
  final List<String>? existingImageUrls;
  final List<ProductOptionDraft> options;
  final List<ProductVariant> variants;

  // Challenge fields
  final bool? isChallenge;
  final int? challengeId;

  ProductDraft({
    this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.coin,
    required this.qty,
    required this.brandId,
    this.categoryId,
    // this.episodeId,
    required this.type,
    this.vendorLink,
    required this.expiresAt,
    required this.images,
    this.existingImageUrls,
    List<ProductOptionDraft>? options,
    List<ProductVariant>? variants,
    this.isChallenge,
    this.challengeId,
  })  : options = options ?? <ProductOptionDraft>[],
        variants = variants ?? <ProductVariant>[];
  // ───────────────── COPY WITH ─────────────────

  ProductDraft copyWith({
    int? id,
    String? title,
    String? description,
    int? price,
    int? coin,
    int? qty,
    int? brandId,
    int? categoryId,
    // int? episodeId,
    String? type,
    String? vendorLink,
    DateTime? expiresAt,
    List<XFile>? images,
    List<String>? existingImageUrls,
    List<ProductOptionDraft>? options,
    List<ProductVariant>? variants,
    bool? isChallenge,
    int? challengeId,
  }) {
    return ProductDraft(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      coin: coin ?? this.coin,
      qty: qty ?? this.qty,
      brandId: brandId ?? this.brandId,
      categoryId: categoryId ?? this.categoryId,
      // episodeId: episodeId ?? this.episodeId,
      type: type ?? this.type,
      vendorLink: vendorLink ?? this.vendorLink,
      expiresAt: expiresAt ?? this.expiresAt,
      images: images ?? this.images,
      existingImageUrls: existingImageUrls ?? this.existingImageUrls,
      options: options ?? this.options,
      variants: variants ?? this.variants,
      isChallenge: isChallenge ?? this.isChallenge,
      challengeId: challengeId ?? this.challengeId,
    );
  }
}
