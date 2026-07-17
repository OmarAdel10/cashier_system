import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../../checkout/domain/helpers/price_helper.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../receipts/domain/entities/receipt_entity.dart';
import '../../../receipts/presentation/bloc/receipts_bloc.dart';
import '../../../receipts/presentation/widgets/receipt_detail_dialog.dart';
import '../../../receipts/presentation/widgets/status_badge.dart';
import '../../../settings/data/services/localization_service.dart';
import '../bloc/sales_state.dart';

class ShiftSection extends StatefulWidget {
  final ShiftGroup shiftGroup;
  final UserEntity user;
  final String langCode;
  final LocalizationService t;

  const ShiftSection({
    super.key,
    required this.shiftGroup,
    required this.user,
    required this.langCode,
    required this.t,
  });

  @override
  State<ShiftSection> createState() => _ShiftSectionState();
}

class _ShiftSectionState extends State<ShiftSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final total = widget.shiftGroup.receipts.fold<int>(
      0,
      (sum, r) => sum + r.totalPiastres,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
            child: Row(
              children: [
                Icon(
                  _isExpanded
                      ? PhosphorIcons.caretDown
                      : PhosphorIcons.caretRight,
                  size: 14,
                ),
                const SizedBox(width: Spacing.xs),
                PhosphorIcon(PhosphorIcons.clockDuotone, size: 14),
                const SizedBox(width: Spacing.xs),
                Text(
                  _formatShiftTimeRange(
                      widget.shiftGroup.startedAt, widget.shiftGroup.endedAt),
                  style: TextStyles.bodySmall,
                ),
                const Spacer(),
                Text(
                  PriceHelper.format(total,
                      languageCode: widget.langCode),
                  style: TextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(left: Spacing.md),
            itemCount: widget.shiftGroup.receipts.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final receipt = widget.shiftGroup.receipts[index];
              final time = _formatTime(receipt.createdAt);
              return InkWell(
                onTap: () =>
                    _showReceiptDialog(context, receipt, widget.user),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: Spacing.xs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(receipt.orderNumber,
                                style: TextStyles.body),
                            const SizedBox(height: 2),
                            Text(
                              '$time · ${receipt.items.length} ${widget.t.translate('sales.items', languageCode: widget.langCode)}',
                              style: TextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        PriceHelper.format(receipt.totalPiastres,
                            languageCode: widget.langCode),
                        style: TextStyles.body,
                      ),
                      const SizedBox(width: Spacing.sm),
                      StatusBadge(receipt.status),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

String _formatTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String _formatTime12h(DateTime dt) {
  final hour = dt.hour;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = hour < 12 ? 'AM' : 'PM';
  final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '$hour12:$minute $period';
}

String _formatShiftTimeRange(DateTime startedAt, DateTime? endedAt) {
  final start = _formatTime12h(startedAt);
  if (endedAt == null) return '$start - ongoing';
  return '$start - ${_formatTime12h(endedAt)}';
}

void _showReceiptDialog(
  BuildContext context,
  ReceiptEntity receipt,
  UserEntity user,
) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlocProvider.value(
      value: context.read<ReceiptsBloc>(),
      child: ReceiptDetailDialog(receipt: receipt, user: user),
    ),
  );
}
