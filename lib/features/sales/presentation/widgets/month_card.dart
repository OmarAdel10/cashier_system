import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../../checkout/domain/helpers/price_helper.dart';
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
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;
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
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Row(
                children: [
                  Icon(
                    _isExpanded
                        ? PhosphorIcons.caretDown
                        : PhosphorIcons.caretRight,
                    size: 20,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Text('$monthNameStr ${widget.year}',
                      style: TextStyles.title),
                  const Spacer(),
                  if (widget.isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else ...[
                    Text(
                      '${md?.receiptCount ?? 0} ${widget.t.translate('sales.receipts', languageCode: widget.langCode)}',
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
                  ],
                ],
              ),
            ),
          ),
          if (_isExpanded && md != null)
            ListView.separated(
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
            ),
        ],
      ),
    );
  }
}
