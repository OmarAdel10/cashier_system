import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/expense_colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../auth/domain/entities/user_entity.dart';
import '../../checkout/domain/helpers/price_helper.dart';
import '../../inventory/domain/entities/product_entity.dart';
import '../../inventory/presentation/bloc/inventory_bloc.dart';
import '../../settings/data/services/localization_service.dart';
import '../../settings/presentation/bloc/settings_bloc.dart';
import 'bloc/expenses_bloc.dart';
import 'bloc/expenses_event.dart';
import 'bloc/expenses_state.dart';

class _LineDraft {
  _LineDraft({
    required this.barcode,
    required this.name,
    required this.quantity,
    required this.costPiastres,
    required this.isNew,
  });

  final String barcode;
  final String name;
  int quantity;
  int costPiastres;
  final bool isNew;
}

class ExpensePanel extends StatefulWidget {
  const ExpensePanel({super.key, required this.user});

  final UserEntity user;

  @override
  State<ExpensePanel> createState() => _ExpensePanelState();
}

class _QuantityPrompt extends StatefulWidget {
  const _QuantityPrompt({
    required this.current,
    required this.title,
    required this.saveLabel,
    required this.cancelLabel,
  });

  final int current;
  final String title;
  final String saveLabel;
  final String cancelLabel;

  @override
  State<_QuantityPrompt> createState() => _QuantityPromptState();
}

class _QuantityPromptState extends State<_QuantityPrompt> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.current}')
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: '${widget.current}'.length,
        );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(int? qty) {
    if (qty != null && qty >= 1) Navigator.of(context).pop(qty);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const Key('expense_qty_edit_field'),
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onSubmitted: (value) => _submit(int.tryParse(value.trim())),
      ),
      actions: [
        TextButton(
          key: const Key('expense_qty_edit_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          key: const Key('expense_qty_edit_save'),
          onPressed: () => _submit(int.tryParse(_controller.text.trim())),
          child: Text(widget.saveLabel),
        ),
      ],
    );
  }
}

class _ExpensePanelState extends State<ExpensePanel> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _newNameController = TextEditingController();
  final _newCostController = TextEditingController();
  final _lines = <_LineDraft>[];
  final _costControllers = <_LineDraft, TextEditingController>{};
  var _newQuantity = 1;

  @override
  void initState() {
    super.initState();
    _prefillName();
  }

  Future<void> _prefillName() async {
    final suggestion = await context.read<ExpensesBloc>().suggestExpenseName();
    if (mounted && _nameController.text.isEmpty) {
      _nameController.text = suggestion;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _newNameController.dispose();
    _newCostController.dispose();
    for (final controller in _costControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _totalPiastres =>
      _lines.fold(0, (sum, line) => sum + line.quantity * line.costPiastres);

  double? _parseCost(String text) {
    final value = double.tryParse(text);
    if (value == null || value < 0) return null;
    return value;
  }

  String _costToString(int piastres) => (piastres / 100).toStringAsFixed(2);

  void _addLine({
    required String barcode,
    required String name,
    required int quantity,
    required int costPiastres,
    bool isNew = false,
  }) {
    setState(
      () => _lines.add(
        _LineDraft(
          barcode: barcode,
          name: name,
          quantity: quantity,
          costPiastres: costPiastres,
          isNew: isNew,
        ),
      ),
    );
  }

  void _removeLine(_LineDraft line) {
    _costControllers.remove(line)?.dispose();
    setState(() => _lines.remove(line));
  }

  Future<void> _promptQuantity(int current, ValueChanged<int> onApply) async {
    final t = LocalizationService();
    final langCode = context.read<SettingsBloc>().state.settings.languageCode;
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => _QuantityPrompt(
        current: current,
        title: t.translate('expense.quantity', languageCode: langCode),
        saveLabel: t.translate('save', languageCode: langCode),
        cancelLabel: t.translate('cancel', languageCode: langCode),
      ),
    );
    if (result != null && result >= 1) onApply(result);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExpensesBloc, ExpensesState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        final t = LocalizationService();
        final langCode = context
            .read<SettingsBloc>()
            .state
            .settings
            .languageCode;
        if (state.status == ExpenseBlocStatus.ready) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                t.translate('expense.success', languageCode: langCode),
              ),
            ),
          );
        } else if (state.status == ExpenseBlocStatus.error &&
            state.failure != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.failure!.message)));
        }
      },
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.select<SettingsBloc, String>(
      (s) => s.state.settings.languageCode,
    );
    final inventoryMap = context
        .select<InventoryBloc, Map<String, ProductEntity>>(
          (s) => s.state.inventoryMap,
        );
    final query = _searchController.text.trim().toLowerCase();
    final results = inventoryMap.values.where((p) {
      if (query.isEmpty) return false;
      return p.name.toLowerCase().contains(query) ||
          p.barcode.toLowerCase().contains(query);
    }).toList()..sort((a, b) => a.name.compareTo(b.name));

    return Focus(
      onKeyEvent: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.escape &&
            event is KeyDownEvent) {
          Navigator.of(context).maybePop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: ExpenseColors.accent,
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg,
                vertical: Spacing.md,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      t.translate('expense.title', languageCode: langCode),
                      style: TextStyles.heading2.copyWith(color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.md,
                Spacing.md,
                Spacing.md,
                0,
              ),
              child: TextField(
                key: const Key('expense_name_field'),
                controller: _nameController,
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: t.translate(
                    'expense.name',
                    languageCode: langCode,
                  ),
                  prefixIcon: const Icon(Icons.receipt_long_outlined),
                  filled: true,
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: TextField(
                key: const Key('expense_search_field'),
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: t.translate(
                    'expense.search',
                    languageCode: langCode,
                  ),
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                children: [
                  for (final product in results)
                    Card(
                      margin: const EdgeInsets.only(bottom: Spacing.sm),
                      child: ListTile(
                        dense: true,
                        title: Text(product.name, style: TextStyles.body),
                        subtitle: Text(
                          '${t.translate('expense.cost', languageCode: langCode)}: '
                          '${PriceHelper.format(PriceHelper.fromDouble(product.purchasePrice), languageCode: langCode)}',
                          style: TextStyles.bodySmall.copyWith(
                            color: ExpenseColors.accent,
                          ),
                        ),
                        onTap: () => _addLine(
                          barcode: product.barcode,
                          name: product.name,
                          quantity: 1,
                          costPiastres: PriceHelper.fromDouble(
                            product.purchasePrice,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: Spacing.md),
                  if (_lines.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(Spacing.lg),
                      child: Center(
                        child: Text(
                          t.translate('expense.empty', languageCode: langCode),
                          style: TextStyles.body,
                        ),
                      ),
                    )
                  else
                    for (final line in _lines)
                      Card(
                        margin: const EdgeInsets.only(bottom: Spacing.sm),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.md,
                            vertical: Spacing.sm,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(line.name, style: TextStyles.title),
                                    const SizedBox(height: Spacing.xs),
                                    SizedBox(
                                      width: 140,
                                      child: TextField(
                                        key: const Key('expense_line_cost'),
                                        controller: _costControllers
                                            .putIfAbsent(
                                              line,
                                              () => TextEditingController(
                                                text: _costToString(
                                                  line.costPiastres,
                                                ),
                                              ),
                                            ),
                                        decoration: InputDecoration(
                                          labelText: t.translate(
                                            'expense.cost',
                                            languageCode: langCode,
                                          ),
                                          isDense: true,
                                        ),
                                        onChanged: (text) {
                                          final cost = _parseCost(text);
                                          if (cost != null) {
                                            setState(
                                              () => line.costPiastres =
                                                  PriceHelper.fromDouble(cost),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                key: const Key('expense_qty_minus'),
                                icon: const Icon(Icons.remove),
                                onPressed: line.quantity > 1
                                    ? () => setState(() => line.quantity--)
                                    : null,
                              ),
                              SizedBox(
                                width: 32,
                                child: GestureDetector(
                                  key: const Key('expense_qty_text'),
                                  onTap: () => _promptQuantity(
                                    line.quantity,
                                    (q) => setState(() => line.quantity = q),
                                  ),
                                  child: Text(
                                    '${line.quantity}',
                                    textAlign: TextAlign.center,
                                    style: TextStyles.title,
                                  ),
                                ),
                              ),
                              IconButton(
                                key: const Key('expense_qty_plus'),
                                icon: const Icon(Icons.add),
                                onPressed: () =>
                                    setState(() => line.quantity++),
                              ),
                              IconButton(
                                key: const Key('expense_line_remove'),
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _removeLine(line),
                              ),
                            ],
                          ),
                        ),
                      ),
                  const SizedBox(height: Spacing.md),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.translate(
                              'expense.newProduct',
                              languageCode: langCode,
                            ),
                            style: TextStyles.heading3,
                          ),
                          const SizedBox(height: Spacing.sm),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  key: const Key('expense_new_name'),
                                  controller: _newNameController,
                                  decoration: InputDecoration(
                                    labelText: t.translate(
                                      'expense.newProduct',
                                      languageCode: langCode,
                                    ),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: Spacing.sm),
                              SizedBox(
                                width: 110,
                                child: TextField(
                                  key: const Key('expense_new_cost'),
                                  controller: _newCostController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    labelText: t.translate(
                                      'expense.cost',
                                      languageCode: langCode,
                                    ),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: Spacing.sm),
                              IconButton(
                                key: const Key('expense_new_qty_minus'),
                                icon: const Icon(Icons.remove),
                                onPressed: _newQuantity > 1
                                    ? () => setState(() => _newQuantity--)
                                    : null,
                              ),
                              GestureDetector(
                                key: const Key('expense_new_qty_text'),
                                onTap: () => _promptQuantity(
                                  _newQuantity,
                                  (q) => setState(() => _newQuantity = q),
                                ),
                                child: Text(
                                  '$_newQuantity',
                                  style: TextStyles.title,
                                ),
                              ),
                              IconButton(
                                key: const Key('expense_new_qty_plus'),
                                icon: const Icon(Icons.add),
                                onPressed: () => setState(() => _newQuantity++),
                              ),
                              const SizedBox(width: Spacing.sm),
                              FilledButton.icon(
                                key: const Key('expense_new_add'),
                                icon: const Icon(Icons.add, size: 16),
                                label: Text(
                                  t.translate(
                                    'expense.add',
                                    languageCode: langCode,
                                  ),
                                ),
                                onPressed: () {
                                  final name = _newNameController.text.trim();
                                  final cost = _parseCost(
                                    _newCostController.text,
                                  );
                                  if (name.isEmpty || cost == null) return;
                                  _addLine(
                                    barcode: '',
                                    name: name,
                                    quantity: _newQuantity,
                                    costPiastres: PriceHelper.fromDouble(cost),
                                    isNew: true,
                                  );
                                  _newNameController.clear();
                                  _newCostController.clear();
                                  setState(() => _newQuantity = 1);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.translate('expense.total', languageCode: langCode),
                          style: TextStyles.bodySmall,
                        ),
                        Text(
                          PriceHelper.format(
                            _totalPiastres,
                            languageCode: langCode,
                          ),
                          style: TextStyles.heading1.copyWith(
                            color: ExpenseColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    key: const Key('expense_confirm'),
                    style: FilledButton.styleFrom(
                      backgroundColor: ExpenseColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.lg,
                        vertical: Spacing.md,
                      ),
                    ),
                    onPressed: _lines.isEmpty
                        ? null
                        : () {
                            context.read<ExpensesBloc>().add(
                              CreateExpense(
                                username: widget.user.username,
                                name: _nameController.text.trim(),
                                items: [
                                  for (final line in _lines)
                                    ExpenseItemInput(
                                      barcode: line.isNew ? '' : line.barcode,
                                      name: line.name,
                                      quantity: line.quantity,
                                      costPiastres: line.costPiastres,
                                    ),
                                ],
                              ),
                            );
                          },
                    child: Text(
                      t.translate('expense.confirm', languageCode: langCode),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
