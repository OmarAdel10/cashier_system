import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../features/settings/data/services/localization_service.dart';
import '../../domain/entities/product_entity.dart';

class ProductCard extends StatelessWidget {
  final ProductEntity product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final LocalizationService t;
  final String langCode;
  final String? priceSuffix;

  const ProductCard({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.t,
    required this.langCode,
    this.priceSuffix,
  });

  @override
  Widget build(BuildContext context) {
    final priceStr = langCode == 'ar'
        ? '${product.price.toStringAsFixed(2)} ج.م'
        : 'EGP ${product.price.toStringAsFixed(2)}';
    final priceLabel = priceSuffix == null
        ? priceStr
        : '$priceStr ${t.translate(priceSuffix!, languageCode: langCode)}';
    final stockStr = product.stock.toString();
    final errorColor = Theme.of(context).colorScheme.error;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: product.isQuickTile && product.tileColorHex != null
            ? Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(
                    int.parse(product.tileColorHex!.replaceFirst('#', '0xFF')),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(PhosphorIcons.package, color: Colors.white),
              )
            : const Icon(PhosphorIcons.package, size: 32),
        title: Text(product.name),
        subtitle: Text(
          t.translate(
            'product.card.subtitle',
            languageCode: langCode,
            params: [product.barcode, priceLabel, stockStr],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(PhosphorIcons.pencil),
              onPressed: onEdit,
            ),
            IconButton(
              icon: Icon(PhosphorIcons.trash, color: errorColor),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
