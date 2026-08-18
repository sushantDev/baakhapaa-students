import 'package:flutter/material.dart';
import 'product.dart';

class SearchProductItem extends StatelessWidget {
  final Map<String, dynamic> _item;

  const SearchProductItem(this._item, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ProductItem(
      _item,
      compactReward: true,
    );
  }
}
