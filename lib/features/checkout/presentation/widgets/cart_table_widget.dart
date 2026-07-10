import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/animated_counter.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../../domain/helpers/price_helper.dart';

Widget _tableCell(Widget child, BuildContext context, {bool isLast = false}) {
  final colorScheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: Spacing.sm, horizontal: Spacing.xs),
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: BorderDirectional(
          end: isLast ? BorderSide.none : BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: child,
    ),
  );
}

class CartTableWidget extends StatefulWidget {
  final List<CartItemEntity> items;
  final void Function(String barcode, int quantity) onQuantityChanged;

  const CartTableWidget({
    super.key,
    required this.items,
    required this.onQuantityChanged,
  });

  @override
  State<CartTableWidget> createState() => _CartTableWidgetState();
}

const _cartColumnWidths = <int, TableColumnWidth>{
  0: FlexColumnWidth(1),
  1: FlexColumnWidth(4),
  2: FlexColumnWidth(1.5),
  3: FlexColumnWidth(2),
  4: FlexColumnWidth(2),
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

    return Flexible(
      fit: FlexFit.loose,
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                  _tableCell(_headerCell('No.', colorScheme), context),
                  _tableCell(_headerCell('Name', colorScheme), context),
                  _tableCell(_headerCell('Qty', colorScheme, align: TextAlign.center), context),
                  _tableCell(_headerCell('Price', colorScheme, align: TextAlign.right), context),
                  _tableCell(_headerCell('Total', colorScheme, align: TextAlign.right), context, isLast: true),
                ],
              ),
            ],
          ),
          Flexible(
            fit: FlexFit.loose,
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
                  _tableCell(Text('Total', style: TextStyles.title), context),
                  _tableCell(const SizedBox.shrink(), context),
                  _tableCell(
                    AnimatedCounter(
                      value: totalQuantity.toString(),
                      style: TextStyles.title,
                      textAlign: TextAlign.center,
                    ),
                    context,
                  ),
                  _tableCell(
                    AnimatedCounter(
                      value: PriceHelper.format(totalAmount),
                      style: TextStyles.title,
                      textAlign: TextAlign.right,
                    ),
                    context,
                  ),
                  _tableCell(const SizedBox.shrink(), context, isLast: true),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String label, ColorScheme colorScheme, {TextAlign align = TextAlign.left}) {
    return Text(
      label,
      style: TextStyles.bodySmall.copyWith(
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurfaceVariant,
      ),
      textAlign: align,
    );
  }
}

class _CartTableRow extends StatefulWidget {
  final int index;
  final CartItemEntity item;
  final Animation<double> animation;
  final void Function(String barcode, int quantity) onQuantityChanged;

  const _CartTableRow({
    required this.index,
    required this.item,
    required this.animation,
    required this.onQuantityChanged,
  });

  @override
  State<_CartTableRow> createState() => _CartTableRowState();
}

class _CartTableRowState extends State<_CartTableRow> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _isEditing = ValueNotifier<bool>(false);
  final _hasTyped = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_CartTableRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing.value) {
      _controller.text = widget.item.quantity.toString();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    _isEditing.dispose();
    _hasTyped.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isEditing.value) {
      _finishEditing();
    }
  }

  void _startEditing() {
    _isEditing.value = true;
    _hasTyped.value = false;
    _controller.text = widget.item.quantity.toString();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
    _focusNode.requestFocus();
  }

  void _onChanged(String value) {
    if (!_hasTyped.value && value.isNotEmpty) {
      _hasTyped.value = true;
    }
  }

  void _finishEditing() {
    _isEditing.value = false;
    if (!_hasTyped.value) return;
    final qty = int.tryParse(_controller.text.trim());
    if (qty != null && qty >= 1) {
      widget.onQuantityChanged(widget.item.barcode, qty);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: widget.animation,
      child: FadeTransition(
        opacity: widget.animation,
        child: Table(
          columnWidths: _cartColumnWidths,
          children: [
            TableRow(
              children: [
                _tableCell(Text('${widget.index + 1}', style: TextStyles.body), context),
                _tableCell(
                  Text(
                    widget.item.name,
                    style: TextStyles.body.copyWith(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  context,
                ),
                _tableCell(
                  ValueListenableBuilder<bool>(
                    valueListenable: _isEditing,
                    builder: (context, isEditing, _) {
                      if (isEditing) {
                        return TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          textAlign: TextAlign.center,
                          style: TextStyles.body,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: _onChanged,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          onSubmitted: (_) => _finishEditing(),
                        );
                      }
                      return GestureDetector(
                        onTap: _startEditing,
                        child: AnimatedCounter(
                          value: widget.item.quantity.toString(),
                          style: TextStyles.body,
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                  context,
                ),
                _tableCell(
                  AnimatedCounter(
                    value: PriceHelper.format(widget.item.totalPiastres),
                    style: TextStyles.body,
                    textAlign: TextAlign.right,
                  ),
                  context,
                ),
                _tableCell(
                  AnimatedCounter(
                    value: PriceHelper.format(widget.item.totalPiastres),
                    style: TextStyles.body,
                    textAlign: TextAlign.right,
                  ),
                  context,
                  isLast: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
