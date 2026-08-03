import 'package:flutter/material.dart';
import '../../../../features/settings/data/services/localization_service.dart';
import '../../domain/entities/product_entity.dart';
import 'product_card.dart';

class ProductColumn extends StatelessWidget {
  final String title;
  final List<ProductEntity> products;
  final LocalizationService t;
  final String langCode;
  final void Function(ProductEntity) onEdit;
  final void Function(ProductEntity) onDelete;

  const ProductColumn({
    super.key,
    required this.title,
    required this.products,
    required this.t,
    required this.langCode,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title (${products.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: products.isEmpty
                ? Center(child: Text(t.translate('inventory.column.empty', languageCode: langCode), style: TextStyle(color: Colors.grey.shade500)))
                : ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (_, i) => ProductCard(
                      product: products[i], t: t, langCode: langCode,
                      onEdit: () => onEdit(products[i]),
                      onDelete: () => onDelete(products[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
