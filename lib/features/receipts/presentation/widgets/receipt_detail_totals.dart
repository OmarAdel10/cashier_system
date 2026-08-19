import 'package:flutter/material.dart';

import '../../../checkout/domain/helpers/price_helper.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../domain/entities/receipt_entity.dart';

class ReceiptDetailTotals extends StatelessWidget {
  final ReceiptEntity receipt;
  final String langCode;

  const ReceiptDetailTotals({
    super.key,
    required this.receipt,
    required this.langCode,
  });

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final hasAmountPaid = receipt.amountPaidPiastres != null;
    final change = hasAmountPaid
        ? (receipt.amountPaidPiastres! - receipt.totalPiastres)
              .clamp(0, double.infinity)
              .toInt()
        : 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (receipt.discountPiastres > 0 || receipt.taxPiastres > 0)
          _TotalRow(
            label: t.translate('checkout.subTotal', languageCode: langCode),
            value: PriceHelper.format(
              receipt.subtotalPiastres,
              languageCode: langCode,
            ),
          ),
        if (receipt.discountPiastres > 0)
          _TotalRow(
            label: t.translate('discount', languageCode: langCode),
            value:
                '-${PriceHelper.format(receipt.discountPiastres, languageCode: langCode)}',
          ),
        if (receipt.taxPiastres > 0)
          _TotalRow(
            label: t.translate('tax', languageCode: langCode),
            value: PriceHelper.format(
              receipt.taxPiastres,
              languageCode: langCode,
            ),
          ),
        _TotalRow(
          label: t.translate('checkout.paymentType', languageCode: langCode),
          value: t.translate(
            'paymentType.${receipt.paymentType}',
            languageCode: langCode,
          ),
        ),
        if (hasAmountPaid) ...[
          _TotalRow(
            label: t.translate('checkout.paid', languageCode: langCode),
            value: PriceHelper.format(
              receipt.amountPaidPiastres!,
              languageCode: langCode,
            ),
          ),
          if (change > 0)
            _TotalRow(
              label: t.translate('checkout.change', languageCode: langCode),
              value: PriceHelper.format(change, languageCode: langCode),
            ),
        ],
        _TotalRow(
          label: t.translate('checkout.total', languageCode: langCode),
          value: PriceHelper.format(
            receipt.totalPiastres,
            languageCode: langCode,
          ),
          isBold: true,
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _TotalRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isBold ? 6 : 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isBold
                ? const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  )
                : const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
          ),
          Text(
            value,
            style: isBold
                ? TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  )
                : const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
          ),
        ],
      ),
    );
  }
}
