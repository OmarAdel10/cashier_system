import 'package:flutter/material.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/animated_counter.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../../domain/helpers/price_helper.dart';

class CartTableWidget extends StatefulWidget {
  final List<CartItemEntity> items;
  final void Function(String barcode, int quantity) onQuantityChanged;
  final ValueChanged<String> onRemove;

  const CartTableWidget({
    super.key,
    required this.items,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  State<CartTableWidget> createState() => _CartTableWidgetState();
}

const _cartColumnWidths = <int, TableColumnWidth>{
  0: FlexColumnWidth(1),
  1: FlexColumnWidth(4),
  2: FlexColumnWidth(1.5),
  3: FlexColumnWidth(2),
};

class _CartTableWidgetState extends State<CartTableWidget> {
  final _globalKey = GlobalKey<AnimatedListState>();

  @override
  void didUpdateWidget(CartTableWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length > oldWidget.items.length) {
      _globalKey.currentState?.insertItem(
        widget.items.length - 1,
        duration: const Duration(milliseconds: 300),
      );
    } else if (widget.items.length < oldWidget.items.length) {
      final barcodes = widget.items.map((e) => e.barcode).toSet();
      for (int i = oldWidget.items.length - 1; i >= 0; i--) {
        if (!barcodes.contains(oldWidget.items[i].barcode)) {
          final removed = oldWidget.items[i];
          _globalKey.currentState?.removeItem(
            i,
            (context, animation) => _CartTableRow(
              index: i,
              item: removed,
              animation: animation,
              onQuantityChanged: widget.onQuantityChanged,
              onRemove: widget.onRemove,
            ),
            duration: const Duration(milliseconds: 300),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalQuantity = widget.items.fold(0, (sum, item) => sum + item.quantity);
    final totalAmount = widget.items.fold(0, (sum, item) => sum + item.totalPiastres);

    return Column(
      children: [
        Table(
          columnWidths: _cartColumnWidths,
          children: [
            TableRow(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              children: [
                _headerCell('No.', colorScheme),
                _headerCell('Name', colorScheme),
                _headerCell('Qty', colorScheme, align: TextAlign.center),
                _headerCell('Price', colorScheme, align: TextAlign.right),
              ],
            ),
          ],
        ),
        Expanded(
          child: AnimatedList(
            key: _globalKey,
            initialItemCount: widget.items.length,
            itemBuilder: (context, index, animation) {
              if (index >= widget.items.length) return const SizedBox.shrink();
              final item = widget.items[index];
              return _CartTableRow(
                index: index,
                item: item,
                animation: animation,
                onQuantityChanged: widget.onQuantityChanged,
                onRemove: widget.onRemove,
              );
            },
          ),
        ),
        Divider(height: 1, color: colorScheme.outlineVariant),
        Table(
          columnWidths: _cartColumnWidths,
          children: [
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.sm, horizontal: Spacing.xs),
                  child: Text('Total', style: TextStyles.title),
                ),
                const SizedBox.shrink(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.sm, horizontal: Spacing.xs),
                  child: AnimatedCounter(
                    value: totalQuantity.toString(),
                    style: TextStyles.title,
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.sm, horizontal: Spacing.xs),
                  child: AnimatedCounter(
                    value: PriceHelper.format(totalAmount),
                    style: TextStyles.title,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _headerCell(String label, ColorScheme colorScheme, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm, horizontal: Spacing.xs),
      child: Text(
        label,
        style: TextStyles.bodySmall.copyWith(
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurfaceVariant,
        ),
        textAlign: align,
      ),
    );
  }
}

class _CartTableRow extends StatefulWidget {
  final int index;
  final CartItemEntity item;
  final Animation<double> animation;
  final void Function(String barcode, int quantity) onQuantityChanged;
  final ValueChanged<String> onRemove;

  const _CartTableRow({
    required this.index,
    required this.item,
    required this.animation,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  State<_CartTableRow> createState() => _CartTableRowState();
}

class _CartTableRowState extends State<_CartTableRow> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.item.quantity.toString();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_CartTableRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing) {
      _controller.text = widget.item.quantity.toString();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      _finishEditing();
    }
  }

  void _startEditing() {
    setState(() => _isEditing = true);
    _controller.text = widget.item.quantity.toString();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
    _focusNode.requestFocus();
  }

  void _finishEditing() {
    setState(() => _isEditing = false);
    final text = _controller.text.trim();
    final qty = int.tryParse(text);
    if (qty != null && qty > 0) {
      widget.onQuantityChanged(widget.item.barcode, qty);
    }
    _controller.text = widget.item.quantity.toString();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizeTransition(
      sizeFactor: widget.animation,
      child: FadeTransition(
        opacity: widget.animation,
        child: Table(
          columnWidths: _cartColumnWidths,
          children: [
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.sm, horizontal: Spacing.xs),
                  child: Text('${widget.index + 1}', style: TextStyles.body),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.sm, horizontal: Spacing.xs),
                  child: Text(
                    widget.item.name,
                    style: TextStyles.body.copyWith(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: _isEditing ? null : _startEditing,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.sm, horizontal: Spacing.xs),
                    child: _isEditing
                        ? TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            textAlign: TextAlign.center,
                            style: TextStyles.body,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                            onSubmitted: (_) => _finishEditing(),
                          )
                        : AnimatedCounter(
                            value: widget.item.quantity.toString(),
                            style: TextStyles.body,
                            textAlign: TextAlign.center,
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.sm, horizontal: Spacing.xs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AnimatedCounter(
                        value: PriceHelper.format(widget.item.totalPiastres),
                        style: TextStyles.body,
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(width: Spacing.xs),
                      InkWell(
                        onTap: () => widget.onRemove(widget.item.barcode),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(Spacing.xs),
                          child: Icon(Icons.close, size: 14, color: colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
