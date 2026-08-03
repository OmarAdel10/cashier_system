import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../domain/entities/receipt_entity.dart';
import '../../domain/entities/receipt_item.dart';
import '../bloc/receipts_bloc.dart';
import '../bloc/receipts_event.dart';
import '../bloc/receipts_state.dart';
import 'item_quantity_row.dart';
import 'order_total_section.dart';

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
  State<ModificationEntryDialog> createState() =>
      _ModificationEntryDialogState();
}

class _ModificationEntryDialogState extends State<ModificationEntryDialog> {
  late final Map<String, ValueNotifier<int>> _qtyNotifiers;
  late final ValueNotifier<int> _subtotalNotifier;
  late final Map<String, FocusNode> _focusNodes;
  late final List<String> _barcodeOrder;
  final _processingNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _qtyNotifiers = {
      for (final item in widget.receipt.items)
        item.barcode: ValueNotifier<int>(item.quantity),
    };
    _focusNodes = {
      for (final item in widget.receipt.items)
        item.barcode: FocusNode(),
    };
    _barcodeOrder = widget.receipt.items.map((e) => e.barcode).toList();
    _subtotalNotifier = ValueNotifier<int>(_computeSubtotal());
    for (final n in _qtyNotifiers.values) {
      n.addListener(_onAnyQtyChanged);
    }
  }

  @override
  void dispose() {
    for (final n in _qtyNotifiers.values) {
      n.removeListener(_onAnyQtyChanged);
      n.dispose();
    }
    for (final n in _focusNodes.values) {
      n.dispose();
    }
    _subtotalNotifier.dispose();
    _processingNotifier.dispose();
    super.dispose();
  }

  int _computeSubtotal() {
    var total = 0;
    for (final item in widget.receipt.items) {
      final qty = _qtyNotifiers[item.barcode]?.value ?? 0;
      total += qty * item.unitPricePiastres;
    }
    return total;
  }

  void _onAnyQtyChanged() {
    _subtotalNotifier.value = _computeSubtotal();
  }

  List<ReceiptItem> get _updatedItems {
    return widget.receipt.items.map((item) {
      final qty = _qtyNotifiers[item.barcode]?.value ?? 0;
      return item.copyWith(quantity: qty);
    }).toList();
  }

  int get _updatedSubtotal => _subtotalNotifier.value;

  @override
  Widget build(BuildContext context) {
    final langCode =
        context.read<SettingsBloc>().state.settings.languageCode;

    return BlocListener<ReceiptsBloc, ReceiptsState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        if (state.status == ReceiptBlocStatus.ready) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                LocalizationService().translate(
                  'sales.modifySuccess',
                  languageCode: langCode,
                ),
              ),
            ),
          );
          Navigator.of(context).pop();
        } else if (state.status == ReceiptBlocStatus.error) {
          if (mounted) _processingNotifier.value = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.failure?.message ??
                    LocalizationService().translate(
                      'checkout.saleFailed',
                      languageCode: langCode,
                    ),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      child: Dialog(
        child: Actions(
          actions: {
            _NextFieldIntent: CallbackAction<_NextFieldIntent>(
              onInvoke: (_) {
                final current = FocusScope.of(context).focusedChild;
                if (current == null) return null;
                for (var i = 0; i < _barcodeOrder.length - 1; i++) {
                  if (_focusNodes[_barcodeOrder[i]] == current) {
                    _focusNodes[_barcodeOrder[i + 1]]?.requestFocus();
                    return null;
                  }
                }
                return null;
              },
            ),
            _PrevFieldIntent: CallbackAction<_PrevFieldIntent>(
              onInvoke: (_) {
                final current = FocusScope.of(context).focusedChild;
                if (current == null) return null;
                for (var i = 1; i < _barcodeOrder.length; i++) {
                  if (_focusNodes[_barcodeOrder[i]] == current) {
                    _focusNodes[_barcodeOrder[i - 1]]?.requestFocus();
                    return null;
                  }
                }
                return null;
              },
            ),
          },
          child: Shortcuts(
            shortcuts: {
              SingleActivator(LogicalKeyboardKey.arrowDown): _NextFieldIntent(),
              SingleActivator(LogicalKeyboardKey.arrowUp): _PrevFieldIntent(),
            },
            child: Focus(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocalizationService().translate(
                        'sales.modifyTitle',
                        languageCode: langCode,
                      ),
                      style: TextStyles.heading3,
                    ),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      '${LocalizationService().translate('sales.orderNumber', languageCode: langCode)}: ${widget.receipt.orderNumber}',
                      style: TextStyles.bodySmall,
                    ),
                    const SizedBox(height: Spacing.md),
                    ...widget.receipt.items.asMap().entries.map((entry) {
                      final item = entry.value;
                      return ItemQuantityRow(
                        item: item,
                        originalQty: item.quantity,
                        isLast: item.barcode == _barcodeOrder.last,
                        qtyNotifier: _qtyNotifiers[item.barcode]!,
                        langCode: langCode,
                        unitPrice: item.unitPricePiastres,
                        focusNode: _focusNodes[item.barcode]!,
                        onNextField: () {
                          final idx = _barcodeOrder.indexOf(item.barcode);
                          if (idx < _barcodeOrder.length - 1) {
                            _focusNodes[_barcodeOrder[idx + 1]]
                                ?.requestFocus();
                          }
                        },
                      );
                    }),
                    const SizedBox(height: Spacing.md),
                    ListenableBuilder(
                      listenable: _processingNotifier,
                      builder: (context, _) => ValueListenableBuilder<int>(
                        valueListenable: _subtotalNotifier,
                        builder: (context, subtotal, _) => OrderTotalSection(
                          subtotal: subtotal,
                          langCode: langCode,
                          isProcessing: _processingNotifier.value,
                          onCancel: _processingNotifier.value
                              ? null
                              : () => Navigator.of(context).pop(),
                          onSave: _processingNotifier.value ? null : _saveChanges,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _saveChanges() {
    _processingNotifier.value = true;
    final updatedSubtotal = _updatedSubtotal;
    final base = widget.receipt.subtotalPiastres;
    final newDiscount = base > 0 && widget.receipt.discountPiastres > 0
        ? (widget.receipt.discountPiastres * updatedSubtotal + base ~/ 2) ~/
              base
        : 0;
    final newTax = base > 0 && widget.receipt.taxPiastres > 0
        ? (widget.receipt.taxPiastres * updatedSubtotal + base ~/ 2) ~/ base
        : 0;
    final newTotal = updatedSubtotal - newDiscount + newTax;

    if (widget.isAuthorized) {
      context.read<ReceiptsBloc>().add(
        AuthorizedModifyReceipt(
          receipt: widget.receipt,
          items: _updatedItems,
          subtotalPiastres: updatedSubtotal,
          discountPiastres: newDiscount,
          taxPiastres: newTax,
          totalPiastres: newTotal,
          adminUsername: widget.adminUsername ?? '',
          adminPassword: widget.adminPassword ?? '',
        ),
      );
    } else {
      context.read<ReceiptsBloc>().add(
        ModifyReceipt(
          receipt: widget.receipt,
          items: _updatedItems,
          subtotalPiastres: updatedSubtotal,
          discountPiastres: newDiscount,
          taxPiastres: newTax,
          totalPiastres: newTotal,
        ),
      );
    }
  }
}

class _NextFieldIntent extends Intent {}

class _PrevFieldIntent extends Intent {}
