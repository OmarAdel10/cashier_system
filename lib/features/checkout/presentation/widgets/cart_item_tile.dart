import 'package:flutter/material.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../../domain/helpers/price_helper.dart';

class CartItemTile extends StatefulWidget {
  final CartItemEntity item;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  const CartItemTile({
    super.key,
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  State<CartItemTile> createState() => _CartItemTileState();
}

class _CartItemTileState extends State<CartItemTile> {
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
  void didUpdateWidget(CartItemTile oldWidget) {
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
      widget.onQuantityChanged(qty);
    }
    _controller.text = widget.item.quantity.toString();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final item = widget.item;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(item.name, style: TextStyles.body, overflow: TextOverflow.ellipsis),
          ),
          SizedBox(width: Spacing.sm),
          GestureDetector(
            onTap: _isEditing ? null : _startEditing,
            child: SizedBox(
              width: 48,
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
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
                      child: Text(
                        item.quantity.toString(),
                        style: TextStyles.body,
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
          ),
          SizedBox(width: Spacing.sm),
          SizedBox(
            width: 80,
            child: Text(
              PriceHelper.format(item.totalPiastres),
              style: TextStyles.body,
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(width: Spacing.xs),
          InkWell(
            onTap: widget.onRemove,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(Spacing.xs),
              child: Icon(Icons.close, size: 16, color: colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
