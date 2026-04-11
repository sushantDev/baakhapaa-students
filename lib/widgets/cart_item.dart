import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cart.dart';
import '../providers/currency_provider.dart';

class CartItem extends StatelessWidget {
  final String id;
  final String productId;
  final double price;
  final int quantity;
  final String title;
  final String image;

  CartItem(
    this.id,
    this.productId,
    this.price,
    this.quantity,
    this.title,
    this.image,
  );

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<Cart>(context, listen: false);
    final cartItem = cart.items[productId];
    final availableStock = cartItem?.availableStock ?? 0;
    final canAddMore = cart.canAddMoreItems(productId);
    final attributes = cartItem?.attributes;

    String? attributesText;
    if (attributes != null && attributes.isNotEmpty) {
      // Render like: "Color: Red • Size: M"
      attributesText = attributes.entries
          .where((e) => e.key.trim().isNotEmpty && e.value.trim().isNotEmpty)
          .map((e) => '${e.key}: ${e.value}')
          .join(' • ');
      if (attributesText.trim().isEmpty) attributesText = null;
    }

    return Dismissible(
      key: ValueKey(id),
      background: Container(
        color: Theme.of(context).colorScheme.error,
        child: Icon(
          Icons.delete,
          color: Colors.white,
          size: 40,
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        margin: EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 4,
        ),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) {
        return showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Are you sure?'),
            content: Text('Do you want to remove the item from cart?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop(false);
                },
                child: Text('No'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop(true);
                },
                child: Text('Yes'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        Provider.of<Cart>(context, listen: false).removeItem(productId);
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
        child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(5),
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Color.fromARGB(255, 45, 45, 45)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 60,
                        height: 60,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: image,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[300],
                              child: Icon(Icons.image, color: Colors.grey[600]),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[300],
                              child: Icon(Icons.error, color: Colors.grey[600]),
                            ),
                          ),
                        ),
                      ),
                      title: Text(title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (attributesText != null) ...[
                            Text(
                              attributesText,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                              ),
                            ),
                            SizedBox(height: 4),
                          ],
                          Row(
                            children: [
                              Text('Total: Rs. ${(price * quantity)}'),
                              const SizedBox(width: 6),
                              Consumer<CurrencyProvider>(
                                builder: (_, currency, __) => Text(
                                  '~${currency.formatNprAsUsd(price * quantity)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Stock: $availableStock available',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color:
                                        canAddMore ? Colors.green : Colors.grey,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(width: 1),
                                  ),
                                  child: IconButton(
                                    iconSize: 12,
                                    icon: Icon(Icons.add_outlined),
                                    onPressed: canAddMore
                                        ? () {
                                            cart.addQuantity(productId);
                                          }
                                        : () {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'Cannot add more items. Only $availableStock available in stock.'),
                                                backgroundColor: Colors.orange,
                                              ),
                                            );
                                          },
                                    color: Colors.white,
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.all(1),
                                  child: Text(
                                    '$quantity',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                                quantity >= 2
                                    ? Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(width: 1),
                                        ),
                                        child: IconButton(
                                          iconSize: 12,
                                          icon: Icon(Icons.remove_outlined),
                                          onPressed: () {
                                            Provider.of<Cart>(context,
                                                    listen: false)
                                                .subtractQuantity(productId);
                                          },
                                        ),
                                      )
                                    : Container(height: 0),
                              ],
                            ),
                          )
                        ],
                      ),
                      trailing: Text('$quantity x'),
                      autofocus: false,
                      iconColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ]),
      ),
    );
  }
}
