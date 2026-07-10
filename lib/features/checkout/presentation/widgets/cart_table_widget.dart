import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/animated_counter.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../shortcuts/intents.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../../domain/helpers/price_helper.dart';
import '../bloc/checkout_bloc.dart';
import '../bloc/checkout_event.dart';

Widget _tableCell(Widget child, BuildContext context, {bool isLast = false}) {
  final colorScheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.symmetric(
      vertical: Spacing.sm,
      horizontal: Spacing.xs,
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: BorderDirectional(
          end: isLast
              ? BorderSide.none
              : BorderSide(color: colorScheme.outlineVariant),
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
  int _selectedIndex = 0;
  final _cartFocusNode = FocusNode(debugLabel: 'cartTable');

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
    if (_selectedIndex >= widget.items.length) {
      _selectedIndex = (widget.items.length - 1).clamp(0, widget.items.length - 1);
    }
  }

  @override
  void dispose() {
    _cartFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.watch<SettingsBloc>().state.settings.languageCode;
    final colorScheme = Theme.of(context).colorScheme;
    final totalQuantity = widget.items.fold(
      0,
      (sum, item) => sum + item.quantity,
    );
    final totalAmount = widget.items.fold(
      0,
      (sum, item) => sum + item.totalPiastres,
    );

    return Focus(
      focusNode: _cartFocusNode,
      autofocus: true,
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowDown):
              const SelectNextCartItemIntent(),
          SingleActivator(LogicalKeyboardKey.arrowUp):
              const SelectPrevCartItemIntent(),
          SingleActivator(LogicalKeyboardKey.delete):
              const RemoveSelectedCartItemIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            SelectNextCartItemIntent: CallbackAction(
              onInvoke: (_) {
                setState(() {
                  _selectedIndex = (_selectedIndex + 1)
                      .clamp(0, widget.items.length - 1);
                });
                return null;
              },
            ),
            SelectPrevCartItemIntent: CallbackAction(
              onInvoke: (_) {
                setState(() {
                  _selectedIndex = (_selectedIndex - 1)
                      .clamp(0, widget.items.length - 1);
                });
                return null;
              },
            ),
            RemoveSelectedCartItemIntent: CallbackAction(
              onInvoke: (_) {
                if (_selectedIndex >= 0 &&
                    _selectedIndex < widget.items.length) {
                  final barcode =
                      widget.items[_selectedIndex].barcode;
                  context
                      .read<CheckoutBloc>()
                      .add(RemoveFromCart(barcode));
                }
                return null;
              },
            ),
          },
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
                _tableCell(
                  _headerCell(
                    t.translate('checkout.table.no', languageCode: langCode),
                    colorScheme,
                  ),
                  context,
                ),
                _tableCell(
                  _headerCell(
                    t.translate('checkout.table.name', languageCode: langCode),
                    colorScheme,
                  ),
                  context,
                ),
                _tableCell(
                  _headerCell(
                    t.translate('checkout.table.qty', languageCode: langCode),
                    colorScheme,
                  ),
                  context,
                ),
                _tableCell(
                  _headerCell(
                    t.translate('checkout.table.price', languageCode: langCode),
                    colorScheme,
                  ),
                  context,
                  isLast: true,
                ),
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
                isSelected: index == _selectedIndex,
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
                _tableCell(
                  Text(
                    'Total',
                    style: TextStyles.title,
                    textAlign: TextAlign.center,
                  ),
                  context,
                ),
                _tableCell(const SizedBox(), context),
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
                    value: PriceHelper.format(
                      totalAmount,
                      languageCode: langCode,
                    ),
                    style: TextStyles.title,
                    textAlign: TextAlign.right,
                  ),
                  context,
                  isLast: true,
                ),
                // _tableCell(const SizedBox.shrink(), context, isLast: true),
              ],
            ),
          ],
        ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _headerCell(
    String label,
    ColorScheme colorScheme, {
    TextAlign align = TextAlign.center,
  }) {
    return Text(
      label,
      style: TextStyles.title.copyWith(
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
  final bool isSelected;

  const _CartTableRow({
    required this.index,
    required this.item,
    required this.animation,
    required this.onQuantityChanged,
    this.isSelected = false,
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
              decoration: widget.isSelected
                  ? BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.3),
                    )
                  : null,
              children: [
                _tableCell(
                  Text(
                    '${widget.index + 1}',
                    style: TextStyles.body,
                    textAlign: TextAlign.center,
                  ),
                  context,
                ),
                _tableCell(
                  Text(
                    widget.item.name,
                    style: TextStyles.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  context,
                ),
                _tableCell(
                  ValueListenableBuilder<bool>(
                    valueListenable: _isEditing,
                    builder: (context, isEditing, _) {
                      if (isEditing) {
                        return IntrinsicWidth(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            textAlign: TextAlign.center,
                            style: TextStyles.body,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: _onChanged,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                            onSubmitted: (_) => _finishEditing(),
                          ),
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
                    value: PriceHelper.format(
                      widget.item.totalPiastres,
                      languageCode: context
                          .read<SettingsBloc>()
                          .state
                          .settings
                          .languageCode,
                    ),
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
