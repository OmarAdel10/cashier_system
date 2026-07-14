import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../checkout/domain/helpers/price_helper.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../domain/entities/receipt_entity.dart';
import '../../domain/entities/refund_entity.dart';
import '../bloc/receipts_bloc.dart';
import '../bloc/receipts_event.dart';
import '../bloc/receipts_state.dart';

class RefundConfirmationDialog extends StatefulWidget {
  final ReceiptEntity receipt;

  const RefundConfirmationDialog({super.key, required this.receipt});

  @override
  State<RefundConfirmationDialog> createState() => _RefundConfirmationDialogState();
}

class _RefundConfirmationDialogState extends State<RefundConfirmationDialog> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.watch<SettingsBloc>().state.settings.languageCode;
    final theme = Theme.of(context);

    return BlocListener<ReceiptsBloc, ReceiptsState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        if (state.status == ReceiptBlocStatus.ready) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                t.translate('sales.refundSuccess', languageCode: langCode,
                  params: [PriceHelper.format(widget.receipt.totalPiastres, languageCode: langCode)]),
              ),
            ),
          );
          Navigator.of(context).pop();
        } else if (state.status == ReceiptBlocStatus.error) {
          setState(() => _isProcessing = false);
          final failure = state.failure;
          if (failure is RefundLockFailure) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(t.translate('sales.refundFailed', languageCode: langCode)),
                content: Text(
                  '${t.translate('sales.receiptLocked', languageCode: langCode)}\n${failure.message}',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(t.translate('cancel', languageCode: langCode)),
                  ),
                ],
              ),
            );
            return;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(failure?.message ?? t.translate('checkout.saleFailed', languageCode: langCode)),
                backgroundColor: theme.colorScheme.error,
              ),
            );
          }
        }
      },
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.translate('sales.refundConfirm', languageCode: langCode),
                style: TextStyles.heading3,
              ),
              const SizedBox(height: Spacing.md),
              Text(
                '${t.translate('sales.orderNumber', languageCode: langCode)}: ${widget.receipt.orderNumber}',
                style: TextStyles.body,
              ),
              Text(
                '${t.translate('sales.date', languageCode: langCode)}: ${widget.receipt.createdAt.toString().substring(0, 10)}',
                style: TextStyles.bodySmall,
              ),
              const SizedBox(height: Spacing.md),
              ...widget.receipt.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${item.name} × ${item.quantity}  =  ${PriceHelper.format(item.totalPiastres, languageCode: langCode)}',
                  style: TextStyles.body,
                ),
              )),
              const SizedBox(height: Spacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t.translate('sales.totalRestore', languageCode: langCode),
                    style: TextStyles.title,
                  ),
                  Text(
                    PriceHelper.format(widget.receipt.totalPiastres, languageCode: langCode),
                    style: TextStyles.title.copyWith(color: theme.colorScheme.error),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                t.translate('sales.refundWarning', languageCode: langCode),
                style: TextStyles.caption.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: Spacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                    child: Text(t.translate('cancel', languageCode: langCode)),
                  ),
                  const SizedBox(width: Spacing.sm),
                  ElevatedButton(
                    onPressed: _isProcessing ? null : _processRefund,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(t.translate('sales.refundConfirm', languageCode: langCode)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _processRefund() {
    setState(() => _isProcessing = true);
    context.read<ReceiptsBloc>().add(ProcessRefund(
      receipt: widget.receipt,
      type: RefundType.full,
      amountRestored: widget.receipt.totalPiastres,
    ));
  }
}
