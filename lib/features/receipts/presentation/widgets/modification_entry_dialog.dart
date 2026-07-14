import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../checkout/domain/helpers/price_helper.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../domain/entities/receipt_entity.dart';
import '../../domain/entities/receipt_item.dart';
import '../bloc/receipts_bloc.dart';
import '../bloc/receipts_event.dart';
import '../bloc/receipts_state.dart';

class ModificationEntryDialog extends StatefulWidget {
  final ReceiptEntity receipt;
  final bool isAuthorized;
  final String? adminUsername;
  final String? adminPassword;

  const ModificationEntryDialog({
    super.key,
    required this.receipt,
    this.isAuthorized = false,
    this.adminUsername,
    this.adminPassword,
  });

  @override
  State<ModificationEntryDialog> createState() => _ModificationEntryDialogState();
}

class _ModificationEntryDialogState extends State<ModificationEntryDialog> {
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, int> _originalQtys;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controllers = {};
    _originalQtys = {};
    for (final item in widget.receipt.items) {
      _controllers[item.barcode] = TextEditingController(text: item.quantity.toString());
      _originalQtys[item.barcode] = item.quantity;
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _updatedSubtotal {
    var total = 0;
    for (final item in widget.receipt.items) {
      final qty = int.tryParse(_controllers[item.barcode]?.text ?? '') ?? 0;
      total += qty * item.unitPricePiastres;
    }
    return total;
  }

  List<ReceiptItem> get _updatedItems {
    return widget.receipt.items.map((item) {
      final qty = int.tryParse(_controllers[item.barcode]?.text ?? '') ?? 0;
      return item.copyWith(quantity: qty);
    }).toList();
  }

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
              content: Text(t.translate('sales.modifySuccess', languageCode: langCode)),
            ),
          );
          Navigator.of(context).pop();
        } else if (state.status == ReceiptBlocStatus.error) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.failure?.message ?? t.translate('checkout.saleFailed', languageCode: langCode)),
              backgroundColor: theme.colorScheme.error,
            ),
          );
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
                t.translate('sales.modifyTitle', languageCode: langCode),
                style: TextStyles.heading3,
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                '${t.translate('sales.orderNumber', languageCode: langCode)}: ${widget.receipt.orderNumber}',
                style: TextStyles.bodySmall,
              ),
              const SizedBox(height: Spacing.md),
              ...widget.receipt.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(item.name, style: TextStyles.body),
                    ),
                    const SizedBox(width: Spacing.sm),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _controllers[item.barcode],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          border: const OutlineInputBorder(),
                          labelText: t.translate('checkout.table.qty', languageCode: langCode),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    _DeltaIndicator(
                      original: _originalQtys[item.barcode] ?? 0,
                      current: int.tryParse(_controllers[item.barcode]?.text ?? '') ?? 0,
                    ),
                    const SizedBox(width: Spacing.sm),
                    SizedBox(
                      width: 100,
                      child: Text(
                        PriceHelper.format(
                          (int.tryParse(_controllers[item.barcode]?.text ?? '') ?? 0) * item.unitPricePiastres,
                          languageCode: langCode,
                        ),
                        style: TextStyles.body,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: Spacing.md),
              const Divider(height: 1),
              const SizedBox(height: Spacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t.translate('checkout.total', languageCode: langCode), style: TextStyles.title),
                  Text(
                    PriceHelper.format(_updatedSubtotal, languageCode: langCode),
                    style: TextStyles.title,
                  ),
                ],
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
                  FilledButton(
                    onPressed: _isProcessing ? null : _saveChanges,
                    child: _isProcessing
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(t.translate('save', languageCode: langCode)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveChanges() {
    setState(() => _isProcessing = true);
    final updatedSubtotal = _updatedSubtotal;
    final ratio = widget.receipt.subtotalPiastres > 0
        ? updatedSubtotal / widget.receipt.subtotalPiastres
        : 1.0;
    final newDiscount = (widget.receipt.discountPiastres * ratio).round();
    final newTax = (widget.receipt.taxPiastres * ratio).round();
    final newTotal = updatedSubtotal - newDiscount + newTax;

    if (widget.isAuthorized) {
      context.read<ReceiptsBloc>().add(AuthorizedModifyReceipt(
        receipt: widget.receipt,
        items: _updatedItems,
        subtotalPiastres: updatedSubtotal,
        discountPiastres: newDiscount,
        taxPiastres: newTax,
        totalPiastres: newTotal,
        adminUsername: widget.adminUsername ?? '',
        adminPassword: widget.adminPassword ?? '',
      ));
    } else {
      context.read<ReceiptsBloc>().add(ModifyReceipt(
        receipt: widget.receipt,
        items: _updatedItems,
        subtotalPiastres: updatedSubtotal,
        discountPiastres: newDiscount,
        taxPiastres: newTax,
        totalPiastres: newTotal,
      ));
    }
  }
}

class _DeltaIndicator extends StatelessWidget {
  final int original;
  final int current;

  const _DeltaIndicator({required this.original, required this.current});

  @override
  Widget build(BuildContext context) {
    final delta = current - original;
    if (delta == 0) return const SizedBox(width: 40);

    final color = delta > 0 ? Colors.green : Colors.red;
    final sign = delta > 0 ? '+' : '';

    return SizedBox(
      width: 40,
      child: Text(
        '$sign$delta',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
    );
  }
}
