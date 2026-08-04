import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../checkout/domain/helpers/price_helper.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../domain/entities/receipt_item.dart';

class ItemQuantityRow extends StatefulWidget {
  final ReceiptItem item;
  final int originalQty;
  final bool isLast;
  final ValueNotifier<int> qtyNotifier;
  final String langCode;
  final int unitPrice;
  final FocusNode focusNode;
  final VoidCallback onNextField;

  const ItemQuantityRow({
    super.key,
    required this.item,
    required this.originalQty,
    required this.isLast,
    required this.qtyNotifier,
    required this.langCode,
    required this.unitPrice,
    required this.focusNode,
    required this.onNextField,
  });

  @override
  State<ItemQuantityRow> createState() => _ItemQuantityRowState();
}

class _ItemQuantityRowState extends State<ItemQuantityRow> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.item.quantity.toString(),
    );
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final qty = int.tryParse(_controller.text) ?? 0;
    if (qty != widget.qtyNotifier.value) {
      widget.qtyNotifier.value = qty;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(widget.item.name, style: TextStyles.body),
          ),
          const SizedBox(width: Spacing.sm),
          SizedBox(
            width: 80,
            child: TextField(
              controller: _controller,
              focusNode: widget.focusNode,
              keyboardType: TextInputType.number,
              textInputAction: widget.isLast
                  ? TextInputAction.done
                  : TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: const OutlineInputBorder(),
                labelText: LocalizationService().translate(
                  'checkout.table.qty',
                  languageCode: widget.langCode,
                ),
              ),
              onSubmitted: (_) {
                if (!widget.isLast) widget.onNextField();
              },
            ),
          ),
          const SizedBox(width: Spacing.sm),
          ValueListenableBuilder<int>(
            valueListenable: widget.qtyNotifier,
            builder: (context, qty, _) => _DeltaIndicator(
              original: widget.originalQty,
              current: qty,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          ValueListenableBuilder<int>(
            valueListenable: widget.qtyNotifier,
            builder: (context, qty, _) => SizedBox(
              width: 100,
              child: Text(
                PriceHelper.format(
                  qty * widget.unitPrice,
                  languageCode: widget.langCode,
                ),
                style: TextStyles.body,
                textAlign: TextAlign.end,
              ),
            ),
          ),
        ],
      ),
    );
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
