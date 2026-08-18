import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../../checkout/domain/helpers/price_helper.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../receipts/domain/entities/receipt_status.dart';
import '../../../settings/data/services/localization_service.dart';
import '../bloc/sales_state.dart';
import 'shift_section.dart';

class CashierSection extends StatefulWidget {
  final CashierDayGroup cashier;
  final UserEntity user;
  final String langCode;
  final LocalizationService t;

  const CashierSection({
    super.key,
    required this.cashier,
    required this.user,
    required this.langCode,
    required this.t,
  });

  @override
  State<CashierSection> createState() => _CashierSectionState();
}

class _CashierSectionState extends State<CashierSection> {
  final _expansionNotifier = ValueNotifier<bool>(true);

  @override
  Widget build(BuildContext context) {
    final total = widget.cashier.shifts.fold<int>(
      0,
      (sum, sh) =>
          sum +
          sh.receipts.fold<int>(
            0,
            (r, rec) =>
                r +
                (rec.status == ReceiptStatus.expense ? 0 : rec.totalPiastres),
          ),
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
                PhosphorIcon(PhosphorIcons.userDuotone, size: 16),
                const SizedBox(width: Spacing.xs),
                Text(widget.cashier.username, style: TextStyles.body),
                const Spacer(),
                Text(
                  PriceHelper.format(total, languageCode: widget.langCode),
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
                itemCount: widget.cashier.shifts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  return ShiftSection(
                    shiftGroup: widget.cashier.shifts[index],
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
}
