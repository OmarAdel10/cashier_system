import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../checkout/domain/helpers/price_helper.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../settings/data/services/localization_service.dart';
import 'metric_card.dart';

class SummaryBar extends StatelessWidget {
  final int totalPiastres;
  final int receiptCount;
  final int itemsSold;
  final int monthlyOrderCount;
  final LocalizationService t;
  final String langCode;

  const SummaryBar({
    super.key,
    required this.totalPiastres,
    required this.receiptCount,
    required this.itemsSold,
    this.monthlyOrderCount = 0,
    required this.t,
    required this.langCode,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MetricCard(
          icon: PhosphorIcons.receiptDuotone,
          label: t.translate('sales.receipts', languageCode: langCode),
          child: Text(
            receiptCount.toString(),
            style: TextStyles.heading1,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: Spacing.sm),
        MetricCard(
          icon: PhosphorIcons.currencyCircleDollarDuotone,
          label: t.translate('sales.total', languageCode: langCode),
          child: RepaintBoundary(
            child: SizedBox(
              height: 40,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: Text(
                  PriceHelper.format(totalPiastres,
                      languageCode: langCode),
                  key: ValueKey(totalPiastres),
                  style: TextStyles.heading1,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: Spacing.sm),
        MetricCard(
          icon: PhosphorIcons.shoppingBagDuotone,
          label: t.translate('sales.itemsSold', languageCode: langCode),
          child: Text(
            itemsSold.toString(),
            style: TextStyles.heading1,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: Spacing.sm),
        MetricCard(
          icon: PhosphorIcons.clipboardTextDuotone,
          label:
              t.translate('sales.monthlyOrders', languageCode: langCode),
          child: Text(
            monthlyOrderCount.toString(),
            style: TextStyles.heading1,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
