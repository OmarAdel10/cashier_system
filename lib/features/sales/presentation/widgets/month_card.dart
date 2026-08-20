import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../../checkout/domain/helpers/price_helper.dart';
import '../../../../core/theme/expense_colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../settings/data/services/localization_service.dart';
import '../bloc/sales_state.dart';
import 'day_section.dart';
import 'month_names.dart';

class MonthCard extends StatefulWidget {
  final int year;
  final int month;
  final MonthGroupedData? monthData;
  final bool isLoading;
  final UserEntity user;
  final String langCode;
  final LocalizationService t;
  final bool isExpanded;

  const MonthCard({
    super.key,
    required this.year,
    required this.month,
    this.monthData,
    required this.isLoading,
    required this.user,
    required this.langCode,
    required this.t,
    this.isExpanded = false,
  });

  @override
  State<MonthCard> createState() => _MonthCardState();
}

class _MonthCardState extends State<MonthCard> {
  late final ValueNotifier<bool> _expansionNotifier;

  @override
  void initState() {
    super.initState();
    _expansionNotifier = ValueNotifier<bool>(widget.isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final monthNameStr = monthName(widget.month, widget.langCode);
    final md = widget.monthData;

    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      child: Column(
        children: [
          InkWell(
            onTap: () => _expansionNotifier.value = !_expansionNotifier.value,
            child: Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Row(
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: _expansionNotifier,
                    builder: (context, value, child) {
                      return Icon(
                        value
                            ? PhosphorIcons.caretDown
                            : PhosphorIcons.caretRight,
                        size: 20,
                      );
                    },
                  ),
                  const SizedBox(width: Spacing.sm),
                  Text('$monthNameStr ${widget.year}', style: TextStyles.title),
                  const Spacer(),
                  if (widget.isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else ...[
                    Text(
                      '${md?.receiptCount ?? 0} ${widget.t.plural(md?.receiptCount ?? 0, 'sales.receipt', 'sales.receipts', languageCode: widget.langCode)}',
                      style: TextStyles.body,
                    ),
                    const SizedBox(width: Spacing.md),
                    Text(
                      PriceHelper.format(
                        md?.totalPiastres ?? 0,
                        languageCode: widget.langCode,
                      ),
                      style: TextStyles.title,
                    ),
                    if (md != null && md.expenseCount > 0) ...[
                      const SizedBox(width: Spacing.md),
                      Text(
                        '${md.expenseCount} ${widget.t.plural(md.expenseCount, 'sales.expense', 'sales.expenses', languageCode: widget.langCode)}',
                        style: TextStyles.body.copyWith(
                          color: ExpenseColors.accent,
                        ),
                      ),
                      const SizedBox(width: Spacing.md),
                      Text(
                        PriceHelper.format(
                          md.days.fold<int>(
                            0,
                            (sum, d) => sum + d.expensesPiastres,
                          ),
                          languageCode: widget.langCode,
                        ),
                        style: TextStyles.title.copyWith(
                          color: ExpenseColors.accent,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          ListenableBuilder(
            listenable: _expansionNotifier,
            builder: (context, _) {
              if (!_expansionNotifier.value || md == null)
                return const SizedBox.shrink();
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  Spacing.md,
                  0,
                  Spacing.md,
                  Spacing.sm,
                ),
                itemCount: md.days.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final day = md.days[index];
                  return DaySection(
                    day: day,
                    user: widget.user,
                    langCode: widget.langCode,
                    t: widget.t,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _expansionNotifier.dispose();
    super.dispose();
  }
}
