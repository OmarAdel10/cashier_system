import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../checkout/domain/helpers/price_helper.dart';
import '../../../../core/theme/expense_colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../settings/data/services/localization_service.dart';
import 'metric_card.dart';

class SummaryBar extends StatelessWidget {
  final int totalPiastres;
  final int receiptCount;
  final int itemsSold;
  final int monthlyOrderCount;
  final int monthlyTotalPiastres;
  final int monthlyItemsSold;
  final int todayExpensesPiastres;
  final int monthlyExpensesPiastres;
  final LocalizationService t;
  final String langCode;

  const SummaryBar({
    super.key,
    required this.totalPiastres,
    required this.receiptCount,
    required this.itemsSold,
    required this.monthlyOrderCount,
    required this.monthlyTotalPiastres,
    required this.monthlyItemsSold,
    required this.todayExpensesPiastres,
    required this.monthlyExpensesPiastres,
    required this.t,
    required this.langCode,
  });

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
                    icon: PhosphorIcons.walletDuotone,
                    label: t.translate(
                      'sales.expensesToday',
                      languageCode: langCode,
                    ),
                    child: Text(
                      PriceHelper.format(
                        todayExpensesPiastres,
                        languageCode: langCode,
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyles.heading1.copyWith(
                        color: ExpenseColors.accent,
                      ),
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
                    icon: PhosphorIcons.walletDuotone,
                    label: t.translate(
                      'sales.expensesMonth',
                      languageCode: langCode,
                    ),
                    child: Text(
                      PriceHelper.format(
                        monthlyExpensesPiastres,
                        languageCode: langCode,
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyles.heading1.copyWith(
                        color: ExpenseColors.accent,
                      ),
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
