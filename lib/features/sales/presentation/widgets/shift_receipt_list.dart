import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../../checkout/domain/helpers/price_helper.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../receipts/domain/entities/receipt_entity.dart';
import '../../../receipts/presentation/bloc/receipts_bloc.dart';
import '../../../receipts/presentation/widgets/receipt_detail_dialog.dart';
import '../../../receipts/presentation/widgets/status_badge.dart';
import '../../../settings/data/services/localization_service.dart';

class ShiftReceiptList extends StatelessWidget {
  final UserEntity user;
  final List<ReceiptEntity>? receipts;
  final String langCode;
  final LocalizationService t;
  final DateTime? shiftStartedAt;

  const ShiftReceiptList({
    super.key,
    required this.user,
    required this.receipts,
    required this.langCode,
    required this.t,
    this.shiftStartedAt,
  });

  @override
  Widget build(BuildContext context) {
    final headerText = t.translate('sales.mySales', languageCode: langCode);

    if (receipts == null || receipts!.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: Text(headerText, style: TextStyles.heading2),
          ),
          const SizedBox(height: Spacing.sm),
          Expanded(
            child: AppEmpty(
              icon: PhosphorIcons.receiptDuotone,
              body:
                  t.translate('state.empty.receipt', languageCode: langCode),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: Text(headerText, style: TextStyles.heading2),
        ),
        const SizedBox(height: Spacing.sm),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            itemCount: receipts!.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              indent: Spacing.sm,
              endIndent: Spacing.sm,
            ),
            itemBuilder: (context, index) {
              final receipt = receipts![index];
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  title:
                      Text(receipt.orderNumber, style: TextStyles.title),
                  subtitle: Text(
                    '${_formatTime(receipt.createdAt)} · ${receipt.items.length} ${t.translate('sales.items', languageCode: langCode)}',
                    style: TextStyles.bodySmall,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusBadge(receipt.status),
                      const SizedBox(width: Spacing.sm),
                      Text(
                        PriceHelper.format(
                          receipt.totalPiastres,
                          languageCode: langCode,
                        ),
                        style: TextStyles.body,
                      ),
                    ],
                  ),
                  onTap: () => _showReceiptDialog(context, receipt, user, shiftStartedAt),
                ),
              );
            },
          ),
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

void _showReceiptDialog(
  BuildContext context,
  ReceiptEntity receipt,
  UserEntity user,
  DateTime? shiftStartedAt,
) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlocProvider.value(
      value: context.read<ReceiptsBloc>(),
      child: ReceiptDetailDialog(
        receipt: receipt,
        user: user,
        shiftStartedAt: shiftStartedAt,
      ),
    ),
  );
}
