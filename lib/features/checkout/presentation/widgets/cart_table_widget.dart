import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/animated_counter.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../../domain/helpers/price_helper.dart';
import '../bloc/checkout_bloc.dart';
import '../bloc/checkout_event.dart';

Widget _tableCell(
  Widget child,
  ColorScheme colorScheme, {
  bool isLast = false,
}) {
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
  final _selectedIndex = ValueNotifier<int>(0);
  final _editingIndex = ValueNotifier<int>(-1);
  final _rowFinishCallbacks = <String, VoidCallback>{};
  String _langCode = '';

  @override
  void didUpdateWidget(CartTableWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldBarcodes = oldWidget.items.map((e) => e.barcode).toSet();
    final newBarcodes = widget.items.map((e) => e.barcode).toSet();

    for (int i = oldWidget.items.length - 1; i >= 0; i--) {
      if (!newBarcodes.contains(oldWidget.items[i].barcode)) {
        final removed = oldWidget.items[i];
        _globalKey.currentState?.removeItem(
          i,
          (context, animation) => _CartTableRow(
            index: i,
            item: removed,
            animation: animation,
            onQuantityChanged: widget.onQuantityChanged,
            selectedIndexNotifier: _selectedIndex,
            editingIndexNotifier: _editingIndex,
            onRegisterFinishCallback: (barcode, cb) =>
                _rowFinishCallbacks[barcode] = cb,
            onEditingComplete: () {
              _editingIndex.value = -1;
            },
            languageCode: _langCode,
          ),
          duration: const Duration(milliseconds: 300),
        );
      }
    }

    for (int i = 0; i < widget.items.length; i++) {
      if (!oldBarcodes.contains(widget.items[i].barcode)) {
        _globalKey.currentState?.insertItem(
          i,
          duration: const Duration(milliseconds: 300),
        );
      }
    }

    if (widget.items.isEmpty) {
      _selectedIndex.value = 0;
      _editingIndex.value = -1;
      return;
    }
    if (_selectedIndex.value >= widget.items.length) {
      _selectedIndex.value = widget.items.length - 1;
    }
    if (_editingIndex.value >= widget.items.length) {
      _editingIndex.value = -1;
    }
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    _selectedIndex.dispose();
    _editingIndex.dispose();
    super.dispose();
  }

  bool _isTypingInTextField() {
    final focus = FocusManager.instance.primaryFocus;
    return focus?.context?.findAncestorWidgetOfExactType<TextField>() != null;
  }

  /// Global cart navigation: works regardless of which widget holds focus
  /// (scanner, cart, tower) without stealing focus from any of them.
  /// Guards: cart non-empty, widget on-stage (IndexedStack), no TextField
  /// being edited (let text editing own the keys).
  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (widget.items.isEmpty) return false;
    if (!TickerMode.valuesOf(context).enabled) return false;
    if (_isTypingInTextField()) return false;
    if (_editingIndex.value >= 0) return false;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        _selectPrev();
        return true;
      case LogicalKeyboardKey.arrowDown:
        _selectNext();
        return true;
      case LogicalKeyboardKey.delete:
        _removeSelected();
        return true;
      case LogicalKeyboardKey.enter:
        _toggleEditing();
        return true;
      default:
        return false;
    }
  }

  void _selectNext() {
    final len = widget.items.length;
    _selectedIndex.value = (_selectedIndex.value + 1) % len;
  }

  void _selectPrev() {
    final len = widget.items.length;
    _selectedIndex.value = (_selectedIndex.value - 1 + len) % len;
  }

  void _removeSelected() {
    if (_selectedIndex.value >= 0 &&
        _selectedIndex.value < widget.items.length) {
      final barcode = widget.items[_selectedIndex.value].barcode;
      context.read<CheckoutBloc>().add(RemoveFromCart(barcode));
    }
  }

  void _toggleEditing() {
    if (_editingIndex.value >= 0) {
      if (_editingIndex.value < widget.items.length) {
        final barcode = widget.items[_editingIndex.value].barcode;
        _rowFinishCallbacks[barcode]?.call();
      }
      _editingIndex.value = -1;
    } else {
      _editingIndex.value = _selectedIndex.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    _langCode = context.select<SettingsBloc, String>(
      (s) => s.state.settings.languageCode,
    );
    final langCode = _langCode;
    final colorScheme = Theme.of(context).colorScheme;
    final totalQuantity = widget.items.fold(
      0,
      (sum, item) => sum + item.quantity,
    );
    final totalAmount = widget.items.fold(
      0,
      (sum, item) => sum + item.totalPiastres,
    );

    return Column(
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
                  colorScheme,
                ),
                _tableCell(
                  _headerCell(
                    t.translate('checkout.table.name', languageCode: langCode),
                    colorScheme,
                  ),
                  colorScheme,
                ),
                _tableCell(
                  _headerCell(
                    t.translate('checkout.table.qty', languageCode: langCode),
                    colorScheme,
                  ),
                  colorScheme,
                ),
                _tableCell(
                  _headerCell(
                    t.translate('checkout.table.price', languageCode: langCode),
                    colorScheme,
                  ),
                  colorScheme,
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
                selectedIndexNotifier: _selectedIndex,
                editingIndexNotifier: _editingIndex,
                onRegisterFinishCallback: (barcode, cb) =>
                    _rowFinishCallbacks[barcode] = cb,
                onEditingComplete: () {
                  _editingIndex.value = -1;
                },
                languageCode: langCode,
                onTap: () {
                  _selectedIndex.value = index;
                  _editingIndex.value = -1;
                  // Focus managed globally via FocusController zone;
                  // no local focus node acquisition needed.
                },
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
                    t.translate('checkout.total', languageCode: langCode),
                    style: TextStyles.title,
                    textAlign: TextAlign.center,
                  ),
                  colorScheme,
                ),
                _tableCell(const SizedBox(), colorScheme),
                _tableCell(
                  AnimatedCounter(
                    value: totalQuantity.toString(),
                    style: TextStyles.title,
                    textAlign: TextAlign.center,
                  ),
                  colorScheme,
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
                  colorScheme,
                  isLast: true,
                ),
              ],
            ),
          ],
        ),
      ],
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
  final ValueNotifier<int> selectedIndexNotifier;
  final ValueNotifier<int> editingIndexNotifier;
  final void Function(String barcode, VoidCallback callback)
  onRegisterFinishCallback;
  final VoidCallback? onEditingComplete;
  final VoidCallback? onTap;
  final String languageCode;

  const _CartTableRow({
    required this.index,
    required this.item,
    required this.animation,
    required this.onQuantityChanged,
    required this.selectedIndexNotifier,
    required this.editingIndexNotifier,
    required this.onRegisterFinishCallback,
    this.onEditingComplete,
    this.onTap,
    required this.languageCode,
  });

  @override
  State<_CartTableRow> createState() => _CartTableRowState();
}

class _CartTableRowState extends State<_CartTableRow> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isEditing = false;
  bool _hasTyped = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    widget.editingIndexNotifier.addListener(_onEditingIndexChanged);
    widget.onRegisterFinishCallback(widget.item.barcode, _finishEditing);
  }

  @override
  void didUpdateWidget(_CartTableRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing) {
      _controller.text = widget.item.quantity.toString();
    }
    if (oldWidget.item.barcode != widget.item.barcode) {
      widget.onRegisterFinishCallback(widget.item.barcode, _finishEditing);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    widget.editingIndexNotifier.removeListener(_onEditingIndexChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      _finishEditing(notifyParent: false);
      final index = widget.index;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.editingIndexNotifier.value == index) {
          widget.editingIndexNotifier.value = -1;
        }
      });
    }
  }

  void _onEditingIndexChanged() {
    if (widget.editingIndexNotifier.value == widget.index) {
      if (!_isEditing) _startEditing();
    } else if (_isEditing) {
      _finishEditing(notifyParent: false);
    }
  }

  void _startEditing() {
    _isEditing = true;
    _hasTyped = false;
    _controller.text = widget.item.quantity.toString();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
    _focusNode.requestFocus();
  }

  void _onChanged(String value) {
    if (!_hasTyped && value.isNotEmpty) {
      _hasTyped = true;
    }
  }

  void _finishEditing({bool notifyParent = true}) {
    if (!_isEditing) return;
    _isEditing = false;
    if (_hasTyped) {
      final qty = int.tryParse(_controller.text.trim());
      if (qty != null && qty >= 1) {
        widget.onQuantityChanged(widget.item.barcode, qty);
      }
    }
    _hasTyped = false;
    if (notifyParent) {
      widget.onEditingComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: widget.animation,
      child: FadeTransition(
        opacity: widget.animation,
        child: GestureDetector(
          onTap: widget.onTap,
          child: ValueListenableBuilder<int>(
            valueListenable: widget.selectedIndexNotifier,
            builder: (context, selectedIndex, _) {
              final cs = Theme.of(context).colorScheme;
              return Table(
                columnWidths: _cartColumnWidths,
                children: [
                  TableRow(
                    decoration: selectedIndex == widget.index
                        ? BoxDecoration(
                            color: cs.primaryContainer.withValues(alpha: 0.3),
                          )
                        : null,
                    children: [
                      _tableCell(
                        Text(
                          '${widget.index + 1}',
                          style: TextStyles.body,
                          textAlign: TextAlign.center,
                        ),
                        cs,
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
                        cs,
                      ),
                      _tableCell(
                        ValueListenableBuilder<int>(
                          valueListenable: widget.editingIndexNotifier,
                          builder: (context, editingIndex, _) {
                            if (editingIndex == widget.index) {
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
                                ),
                              );
                            }
                            return GestureDetector(
                              onTap: () {
                                widget.editingIndexNotifier.value =
                                    widget.index;
                              },
                              child: AnimatedCounter(
                                value: widget.item.quantity.toString(),
                                style: TextStyles.body,
                                textAlign: TextAlign.center,
                              ),
                            );
                          },
                        ),
                        cs,
                      ),
                      _tableCell(
                        AnimatedCounter(
                          value: PriceHelper.format(
                            widget.item.totalPiastres,
                            languageCode: widget.languageCode,
                          ),
                          style: TextStyles.body,
                          textAlign: TextAlign.right,
                        ),
                        cs,
                        isLast: true,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
