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
  final int profitPiastres;
  final int monthlyOrderCount;
  final int monthlyTotalPiastres;
  final int monthlyItemsSold;
  final int monthlyProfitPiastres;
  final LocalizationService t;
  final String langCode;

  const SummaryBar({
    super.key,
    required this.totalPiastres,
    required this.receiptCount,
    required this.itemsSold,
    this.profitPiastres = 0,
    this.monthlyOrderCount = 0,
    this.monthlyTotalPiastres = 0,
    this.monthlyItemsSold = 0,
    this.monthlyProfitPiastres = 0,
    required this.t,
    required this.langCode,
  });

  String _margin(int profit, int revenue) {
    if (revenue == 0) return '0.0%';
    return '${(profit / revenue * 100).toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.translate('sales.dailySummary', languageCode: langCode),
                style: TextStyles.heading3.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Row(
                children: [
                  MetricCard(
                    icon: PhosphorIcons.receiptDuotone,
                    label: t.translate(
                      'sales.receipts',
                      languageCode: langCode,
                    ),
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
                            PriceHelper.format(
                              totalPiastres,
                              languageCode: langCode,
                            ),
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
                    label: t.translate(
                      'sales.itemsSold',
                      languageCode: langCode,
                    ),
                    child: Text(
                      itemsSold.toString(),
                      style: TextStyles.heading1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  MetricCard(
                    icon: PhosphorIcons.chartLineUpDuotone,
                    label: t.translate('sales.profit', languageCode: langCode),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            PriceHelper.format(
                              profitPiastres,
                              languageCode: langCode,
                            ),
                            style: TextStyles.heading1,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${t.translate('sales.margin', languageCode: langCode)}: ${_margin(profitPiastres, totalPiastres)}',
                          style: TextStyles.caption,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          width: Spacing.md,
          child: Center(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.2,
              child: VerticalDivider(width: 1, thickness: 1),
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.translate('sales.monthlySummary', languageCode: langCode),
                style: TextStyles.heading3.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Row(
                children: [
                  MetricCard(
                    icon: PhosphorIcons.clipboardTextDuotone,
                    label: t.translate(
                      'sales.monthlyOrders',
                      languageCode: langCode,
                    ),
                    child: Text(
                      monthlyOrderCount.toString(),
                      style: TextStyles.heading1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  MetricCard(
                    icon: PhosphorIcons.currencyCircleDollarDuotone,
                    label: t.translate('sales.total', languageCode: langCode),
                    child: Text(
                      PriceHelper.format(
                        monthlyTotalPiastres,
                        languageCode: langCode,
                      ),
                      style: TextStyles.heading1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  MetricCard(
                    icon: PhosphorIcons.shoppingBagDuotone,
                    label: t.translate(
                      'sales.itemsSold',
                      languageCode: langCode,
                    ),
                    child: Text(
                      monthlyItemsSold.toString(),
                      style: TextStyles.heading1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  MetricCard(
                    icon: PhosphorIcons.chartLineUpDuotone,
                    label: t.translate('sales.profit', languageCode: langCode),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            PriceHelper.format(
                              monthlyProfitPiastres,
                              languageCode: langCode,
                            ),
                            style: TextStyles.heading1,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${t.translate('sales.margin', languageCode: langCode)}: ${_margin(monthlyProfitPiastres, monthlyTotalPiastres)}',
                          style: TextStyles.caption,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
