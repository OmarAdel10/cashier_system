import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../checkout/domain/helpers/price_helper.dart';
import '../../../../core/theme/expense_colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../settings/data/services/localization_service.dart';

class SummaryBar extends StatelessWidget {
  final int totalPiastres;
  final int receiptCount;
  final int itemsSold;
  final int monthlyOrderCount;
  final int monthlyTotalPiastres;
  final int monthlyItemsSold;
  final int todayExpensesPiastres;
  final int monthlyExpensesPiastres;
  final int todayExpenseCount;
  final int monthlyExpenseCount;
  final LocalizationService t;
  final String langCode;

  const SummaryBar({
    super.key,
    required this.totalPiastres,
    required this.receiptCount,
    required this.itemsSold,
    this.monthlyOrderCount = 0,
    this.monthlyTotalPiastres = 0,
    this.monthlyItemsSold = 0,
    this.todayExpensesPiastres = 0,
    this.monthlyExpensesPiastres = 0,
    this.todayExpenseCount = 0,
    this.monthlyExpenseCount = 0,
    required this.t,
    required this.langCode,
  });

  Widget _buildDailySection(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          t.translate('sales.dailySummary', languageCode: langCode),
          style: TextStyles.heading3.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: Spacing.sm),
        IntrinsicHeight(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              //receipts count per day
              Expanded(
                child: Column(
                  children: [
                    // receipts per day
                    Expanded(
                      child: MetricCard(
                        icon: PhosphorIcons.receiptDuotone,
                        label: t.translate(
                          'sales.receipts',
                          languageCode: langCode,
                        ),
                        child: Text(
                          receiptCount.toString(),
                          style: TextStyles.heading1,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),

                    // totals per day
                    Expanded(
                      child: MetricCard(
                        icon: PhosphorIcons.currencyCircleDollarDuotone,
                        label: t.translate(
                          'sales.total',
                          languageCode: langCode,
                        ),
                        child: RepaintBoundary(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                            child: Text(
                              PriceHelper.format(
                                totalPiastres,
                                languageCode: langCode,
                              ),
                              key: ValueKey(totalPiastres),
                              style: TextStyles.heading1,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),

                    // items sold per day
                    Expanded(
                      child: MetricCard(
                        icon: PhosphorIcons.shoppingBagDuotone,
                        label: t.translate(
                          'sales.itemsSold',
                          languageCode: langCode,
                        ),
                        child: Text(
                          itemsSold.toString(),
                          style: TextStyles.heading1,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: Spacing.md),

              // expenses per day
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: MetricCard(
                        icon: PhosphorIcons.trayDuotone,
                        label: t.translate(
                          'sales.expensesCount',
                          languageCode: langCode,
                        ),
                        child: Text(
                          todayExpenseCount.toString(),
                          style: TextStyles.heading1,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    Expanded(
                      child: MetricCard(
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlySection(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          t.translate('sales.monthlySummary', languageCode: langCode),
          style: TextStyles.heading3.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: Spacing.sm),
        IntrinsicHeight(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // monthly orders count & totals & items sold
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: MetricCard(
                        icon: PhosphorIcons.clipboardTextDuotone,
                        label: t.translate(
                          'sales.monthlyOrders',
                          languageCode: langCode,
                        ),
                        child: Text(
                          monthlyOrderCount.toString(),
                          style: TextStyles.heading1,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),

                    // monthly totals
                    Expanded(
                      child: MetricCard(
                        icon: PhosphorIcons.currencyCircleDollarDuotone,
                        label: t.translate(
                          'sales.total',
                          languageCode: langCode,
                        ),
                        child: Text(
                          PriceHelper.format(
                            monthlyTotalPiastres,
                            languageCode: langCode,
                          ),
                          style: TextStyles.heading1,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),

                    // monthly items sold
                    Expanded(
                      child: MetricCard(
                        icon: PhosphorIcons.shoppingBagDuotone,
                        label: t.translate(
                          'sales.itemsSold',
                          languageCode: langCode,
                        ),
                        child: Text(
                          monthlyItemsSold.toString(),
                          style: TextStyles.heading1,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: Spacing.md),

              // monthly expenses
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: MetricCard(
                        icon: PhosphorIcons.trayDuotone,
                        label: t.translate(
                          'sales.expensesCount',
                          languageCode: langCode,
                        ),
                        child: Text(
                          monthlyExpenseCount.toString(),
                          style: TextStyles.heading1,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    Expanded(
                      child: MetricCard(
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildDailySection(context)),
        SizedBox(
          width: Spacing.md,
          child: Center(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.3,
              child: VerticalDivider(width: 1, thickness: 1),
            ),
          ),
        ),
        Expanded(child: _buildMonthlySection(context)),
      ],
    );
  }
}

class MetricCard extends StatelessWidget {
  final Object icon;
  final String label;
  final Widget child;

  const MetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).cardTheme.color,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(icon, size: 20),
              const SizedBox(width: Spacing.xs),
              Flexible(
                child: Text(
                  label,
                  style: TextStyles.heading3,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          child,
        ],
      ),
    );
  }
}
