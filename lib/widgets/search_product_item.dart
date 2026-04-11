import 'package:flutter/material.dart';
import 'product.dart';

class SearchProductItem extends StatelessWidget {
  final Map<String, dynamic> _item;

  SearchProductItem(this._item);

  @override
  Widget build(BuildContext context) {
    return ProductItem(
      _item,
      compactReward: true,
    );
  }
}
