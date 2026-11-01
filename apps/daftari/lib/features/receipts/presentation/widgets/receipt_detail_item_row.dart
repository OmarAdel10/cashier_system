import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../checkout/domain/helpers/price_helper.dart';
import '../../domain/entities/receipt_item.dart';

class ReceiptDetailItemRow extends StatelessWidget {
  final ReceiptItem item;
  final int itemIndex;
  final String langCode;

  const ReceiptDetailItemRow({
    super.key,
    required this.item,
    required this.itemIndex,
    required this.langCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: itemIndex.isEven
            ? theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.3)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Text(
            '${item.quantity} × ${PriceHelper.format(item.unitPricePiastres, languageCode: langCode)}',
            style: TextStyles.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          SizedBox(
            width: 80,
            child: Text(
              PriceHelper.format(item.totalPiastres, languageCode: langCode),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
