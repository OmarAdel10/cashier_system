import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../../checkout/domain/helpers/price_helper.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../settings/data/services/localization_service.dart';
import '../bloc/sales_state.dart';
import 'cashier_section.dart';
import 'month_names.dart';

class DaySection extends StatefulWidget {
  final DayGroup day;
  final UserEntity user;
  final String langCode;
  final LocalizationService t;

  const DaySection({
    super.key,
    required this.day,
    required this.user,
    required this.langCode,
    required this.t,
  });

  @override
  State<DaySection> createState() => _DaySectionState();
}

class _DaySectionState extends State<DaySection> {
  final _expansionNotifier = ValueNotifier<bool>(true);

  @override
  Widget build(BuildContext context) {
    final dayTotal = widget.day.cashiers.fold<int>(
      0,
      (sum, c) =>
          sum +
          c.shifts.fold<int>(
            0,
            (s, sh) =>
                s + sh.receipts.fold<int>(0, (r, rec) => r + rec.totalPiastres),
          ),
    );
    final dayCount = widget.day.cashiers.fold<int>(
      0,
      (sum, c) =>
          sum + c.shifts.fold<int>(0, (s, sh) => s + sh.receipts.length),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _expansionNotifier.value = !_expansionNotifier.value,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
            child: Row(
              children: [
                Icon(
                  _expansionNotifier.value
                      ? PhosphorIcons.caretDown
                      : PhosphorIcons.caretRight,
                  size: 16,
                ),
                const SizedBox(width: Spacing.xs),
                Text(
                  '${_formatDayDate(widget.day.date)} · ${PriceHelper.format(dayTotal, languageCode: widget.langCode)} · $dayCount ${widget.t.translate('sales.receipts', languageCode: widget.langCode)}',
                  style: TextStyles.body,
                ),
              ],
            ),
          ),
        ),
        ListenableBuilder(
          listenable: _expansionNotifier,
          builder: (context, _) {
            if (!_expansionNotifier.value) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(left: Spacing.md),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.day.cashiers.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  return CashierSection(
                    cashier: widget.day.cashiers[index],
                    user: widget.user,
                    langCode: widget.langCode,
                    t: widget.t,
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _expansionNotifier.dispose();
    super.dispose();
  }

  String _formatDayDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    return '$d ${monthNameShort(dt.month, widget.langCode)} ${dt.year}';
  }
}
