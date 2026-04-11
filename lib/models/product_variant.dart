import 'package:image_picker/image_picker.dart';

class BackendOptionValue {
  final String optionName;
  final String value;

  BackendOptionValue({required this.optionName, required this.value});
}

class ProductVariant {
  String? name; // optional display name
  int? price;
  int? qty;
  String? existingImageUrl; // 👈 For edit mode preview (backend URL)
  XFile? image; // 👈 For newly picked image
  List<String>
      optionValues; // REQUIRED FOR BACKEND (e.g., ['Size:Small', 'Color:Red'])
  List<BackendOptionValue>? backendOptionValues; // For edit mode hydration

  ProductVariant({
    this.name,
    this.price,
    this.qty,
    this.existingImageUrl,
    this.image,
    List<String>? optionValues,
    this.backendOptionValues,
  }) : optionValues = optionValues ?? [];

  ProductVariant copyWith({
    String? name,
    int? price,
    int? qty,
    String? existingImageUrl,
    XFile? image,
    List<String>? optionValues,
    List<BackendOptionValue>? backendOptionValues,
  }) {
    return ProductVariant(
      name: name ?? this.name,
      price: price ?? this.price,
      qty: qty ?? this.qty,
      existingImageUrl: existingImageUrl ?? this.existingImageUrl,
      image: image ?? this.image,
      optionValues: optionValues ?? this.optionValues,
      backendOptionValues: backendOptionValues ?? this.backendOptionValues,
    );
  }
}
