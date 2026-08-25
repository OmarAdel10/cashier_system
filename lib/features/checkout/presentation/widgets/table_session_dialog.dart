import 'package:cashier_system/core/theme/app_theme.dart';
import 'package:cashier_system/features/inventory/domain/entities/prep_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cashier_system/core/business/business_type.dart';
import 'package:cashier_system/core/theme/spacing.dart';
import 'package:cashier_system/core/theme/text_styles.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_order_line.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_round_entity.dart';
import 'package:cashier_system/features/checkout/domain/helpers/price_helper.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/table_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/table_event.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/table_state.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/zone_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/checkout_table_dialog.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/product_category_grid.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/transfer_merge_dialogs.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';
import 'package:cashier_system/features/receipts/presentation/bloc/receipts_bloc.dart';
import 'package:cashier_system/features/settings/data/services/localization_service.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';

/// Full table session overlay: bill (fired rounds + drafts), round status
/// (Mark-Served), product picker, and Send Order (FireRound).
class TableSessionDialog extends StatefulWidget {
  const TableSessionDialog({super.key, required this.table});

  final TableEntity table;

  @override
  State<TableSessionDialog> createState() => _TableSessionDialogState();
}

class _TableSessionDialogState extends State<TableSessionDialog> {
  final FocusNode _gridFocus = FocusNode();

  @override
  void dispose() {
    _gridFocus.dispose();
    super.dispose();
  }

  TableOrderLine _lineForProduct(ProductEntity product) {
    return TableOrderLine(
      name: product.name,
      barcode: product.barcode,
      quantity: 1,
      unitPricePiastres: PriceHelper.fromDouble(product.price),
      prepCategory: product.prepCategory,
    );
  }

  void _addProduct(TableBloc bloc, ProductEntity product) {
    final lines = bloc.state.draftFor(widget.table.id);
    final existing = lines.where((l) => l.barcode == product.barcode);
    if (existing.isEmpty) {
      bloc.add(
        UpdateDraftLines(widget.table.id, [...lines, _lineForProduct(product)]),
      );
    } else {
      bloc.add(
        UpdateDraftLines(widget.table.id, [
          for (final line in lines)
            line.barcode == product.barcode
                ? line.copyWith(quantity: line.quantity + 1)
                : line,
        ]),
      );
    }
  }

  void _decrementDraft(TableBloc bloc, String barcode) {
    final lines = bloc.state.draftFor(widget.table.id);
    bloc.add(
      UpdateDraftLines(widget.table.id, [
        for (final line in lines)
          if (line.barcode != barcode)
            line
          else if (line.quantity > 1)
            line.copyWith(quantity: line.quantity - 1),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (s) => s.state.settings.languageCode,
    );
    final businessType = BusinessType.fromId(
      context.select<SettingsBloc, String>(
        (s) => s.state.settings.businessType,
      ),
    );
    final t = LocalizationService();

    return BlocBuilder<TableBloc, TablesState>(
      builder: (context, state) {
        final table = _findTable(state) ?? widget.table;
        final rounds =
            state.rounds.where((r) => r.tableId == widget.table.id).toList()
              ..sort((a, b) => a.roundNumber.compareTo(b.roundNumber));
        final drafts = state.draftFor(widget.table.id);
        final billTotal = _billTotal(rounds, drafts);
        final canOrder =
            drafts.isNotEmpty && table.status != TableStatus.paymentPending;

        return Dialog(
          child: SizedBox(
            width: 1100,
            height: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(Spacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.translate(
                            'table.session.title',
                            languageCode: langCode,
                            params: [widget.table.name],
                          ),
                          style: TextStyles.heading2,
                        ),
                      ),
                      if (widget.table.isRoom) ...[
                        Text(
                          t.translate(
                            'table.room.rent',
                            languageCode: langCode,
                            params: [
                              PriceHelper.format(
                                widget.table.roomChargePiastres,
                                languageCode: langCode,
                              ),
                            ],
                          ),
                          style: TextStyles.body,
                        ),
                        const SizedBox(width: Spacing.md),
                      ],
                      _StatusPill(status: table.status),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _BillPanel(
                          rounds: rounds,
                          drafts: drafts,
                          billTotal: billTotal,
                          onMarkServed: (roundId) => context
                              .read<TableBloc>()
                              .add(MarkServed(widget.table.id, roundId)),
                          onDecrement: (barcode) => _decrementDraft(
                            context.read<TableBloc>(),
                            barcode,
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        flex: 6,
                        child: ProductCategoryGrid(
                          businessType: businessType,
                          onProductTap: (product) =>
                              _addProduct(context.read<TableBloc>(), product),
                          gridFocus: _gridFocus,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(Spacing.md),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: Spacing.sm,
                    runSpacing: Spacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t.translate(
                              'table.session.total',
                              languageCode: langCode,
                            ),
                            style: TextStyles.heading3,
                          ),
                          const SizedBox(width: Spacing.sm),
                          Text(
                            PriceHelper.format(
                              billTotal,
                              languageCode: langCode,
                            ),
                            style: TextStyles.heading2,
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        key: const Key('cancel-table'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.errorContainer,
                        ),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: Text(
                                t.translate(
                                  'table.session.cancelTitle',
                                  languageCode: langCode,
                                  params: [widget.table.name],
                                ),
                              ),
                              content: Text(
                                t.translate(
                                  'table.session.cancelMessage',
                                  languageCode: langCode,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: Text(
                                    t.translate(
                                      'cancel',
                                      languageCode: langCode,
                                    ),
                                  ),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, true),
                                  child: Text(
                                    t.translate(
                                      'confirm',
                                      languageCode: langCode,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true && context.mounted) {
                            context.read<TableBloc>().add(
                              ClearTab(widget.table.id),
                            );
                            Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.cancel_outlined),
                        label: Text(
                          t.translate(
                            'table.session.cancel',
                            languageCode: langCode,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        key: const Key('transfer-table'),
                        onPressed: () async {
                          final result = await showDialog<bool>(
                            context: context,
                            builder: (_) => BlocProvider<TableBloc>.value(
                              value: context.read<TableBloc>(),
                              child: TransferTableDialog(
                                sourceTable: widget.table,
                              ),
                            ),
                          );
                          if (result == true && context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.swap_horiz),
                        label: Text(
                          t.translate(
                            'table.session.transfer',
                            languageCode: langCode,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.inversePrimary.withValues(alpha: 0.7),
                        ),
                      ),
                      OutlinedButton.icon(
                        key: const Key('merge-tables'),
                        onPressed: () async {
                          final result = await showDialog<bool>(
                            context: context,
                            builder: (_) => BlocProvider<TableBloc>.value(
                              value: context.read<TableBloc>(),
                              child: MergeTablesDialog(
                                sourceTable: widget.table,
                              ),
                            ),
                          );
                          if (result == true && context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.merge),
                        label: Text(
                          t.translate(
                            'table.session.merge',
                            languageCode: langCode,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.tertiaryFixedDim,
                        ),
                      ),
                      FilledButton.tonalIcon(
                        key: const Key('checkout-table'),
                        onPressed: billTotal > 0
                            ? () async {
                                final settled = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => MultiBlocProvider(
                                    providers: [
                                      BlocProvider<TableBloc>.value(
                                        value: context.read<TableBloc>(),
                                      ),
                                      BlocProvider<ZoneBloc>.value(
                                        value: context.read<ZoneBloc>(),
                                      ),
                                      BlocProvider<ReceiptsBloc>.value(
                                        value: context.read<ReceiptsBloc>(),
                                      ),
                                    ],
                                    child: CheckoutTableDialog(
                                      table: widget.table,
                                    ),
                                  ),
                                );
                                if (settled == true && context.mounted) {
                                  Navigator.pop(context);
                                }
                              }
                            : null,
                        icon: const Icon(Icons.payments_outlined),
                        label: Text(
                          t.translate(
                            'table.session.checkout',
                            languageCode: langCode,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: AppTheme.darkBorderColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.lg),
                      FilledButton.icon(
                        key: const Key('send-order'),
                        onPressed: canOrder
                            ? () => context.read<TableBloc>().add(
                                FireRound(widget.table.id),
                              )
                            : null,
                        icon: const Icon(Icons.send),
                        label: Text(
                          t.translate(
                            'table.session.sendOrder',
                            languageCode: langCode,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int _billTotal(List<TableRoundEntity> rounds, List<TableOrderLine> drafts) {
    var total = 0;
    for (final round in rounds) {
      for (final line in round.lines) {
        total += line.unitPricePiastres * line.quantity;
      }
    }
    for (final line in drafts) {
      total += line.unitPricePiastres * line.quantity;
    }
    return total;
  }

  TableEntity? _findTable(TablesState state) {
    for (final table in state.tables) {
      if (table.id == widget.table.id) return table;
    }
    return null;
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final TableStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (status) {
      TableStatus.available => (Colors.green, 'table.status.available'),
      TableStatus.occupied => (Colors.blue, 'table.status.occupied'),
      TableStatus.orderPending => (
        Colors.amber.shade700,
        'table.status.orderPending',
      ),
      TableStatus.served => (Colors.grey, 'table.status.served'),
      TableStatus.paymentPending => (Colors.red, 'table.status.paymentPending'),
    };
    final langCode = context.select<SettingsBloc, String>(
      (s) => s.state.settings.languageCode,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Spacing.sm),
      ),
      child: Text(
        LocalizationService().translate(label, languageCode: langCode),
        style: TextStyles.bodySmall.copyWith(color: Colors.white),
      ),
    );
  }
}

class _BillPanel extends StatelessWidget {
  const _BillPanel({
    required this.rounds,
    required this.drafts,
    required this.billTotal,
    required this.onMarkServed,
    required this.onDecrement,
  });

  final List<TableRoundEntity> rounds;
  final List<TableOrderLine> drafts;
  final int billTotal;
  final ValueChanged<String> onMarkServed;
  final ValueChanged<String> onDecrement;

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (s) => s.state.settings.languageCode,
    );
    final t = LocalizationService();
    final isEmpty = rounds.isEmpty && drafts.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            Spacing.sm,
            Spacing.md,
            0,
          ),
          child: Text(
            t.translate('table.session.bill', languageCode: langCode),
            style: TextStyles.heading3,
          ),
        ),
        Expanded(
          child: isEmpty
              ? Center(
                  child: Text(
                    t.translate('table.session.empty', languageCode: langCode),
                    style: TextStyles.body,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(Spacing.md),
                  children: [
                    for (final round in rounds) ...[
                      _RoundTile(
                        round: round,
                        onMarkServed: () => onMarkServed(round.id),
                      ),
                      const SizedBox(height: Spacing.sm),
                    ],
                    if (drafts.isNotEmpty) ...[
                      Text(
                        t.translate(
                          'table.session.draft',
                          languageCode: langCode,
                        ),
                        style: TextStyles.heading3,
                      ),
                      const SizedBox(height: Spacing.sm),
                      for (final line in drafts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Spacing.xs),
                          child: Row(
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => onDecrement(line.barcode),
                              ),
                              Expanded(
                                child: Text(
                                  '${line.name} x${line.quantity}',
                                  style: TextStyles.body,
                                ),
                              ),
                              Text(
                                PriceHelper.format(
                                  line.unitPricePiastres * line.quantity,
                                  languageCode: langCode,
                                ),
                                style: TextStyles.body,
                              ),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: Spacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${t.translate('table.session.total', languageCode: langCode)}: '
                            '${PriceHelper.format(billTotal, languageCode: langCode)}',
                            style: TextStyles.heading3,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _RoundTile extends StatelessWidget {
  const _RoundTile({required this.round, required this.onMarkServed});

  final TableRoundEntity round;
  final VoidCallback onMarkServed;

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (s) => s.state.settings.languageCode,
    );
    final t = LocalizationService();
    final isServed = round.status == RoundStatus.served;

    final categories = <PrepCategory>{};
    for (final line in round.lines) {
      if (line.prepCategory != PrepCategory.general) {
        categories.add(line.prepCategory);
      }
    }

    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(Spacing.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.translate(
                    'table.session.round',
                    languageCode: langCode,
                    params: [round.roundNumber.toString()],
                  ),
                  style: TextStyles.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              _RoundPills(categories: categories, isServed: isServed),
              if (!isServed) ...[
                const SizedBox(width: Spacing.sm),
                TextButton(
                  key: Key('mark-served-${round.id}'),
                  onPressed: onMarkServed,
                  child: Text(
                    t.translate(
                      'table.session.markServed',
                      languageCode: langCode,
                    ),
                  ),
                ),
              ],
            ],
          ),
          for (final line in round.lines)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${line.name} x${line.quantity}',
                      style: TextStyles.bodySmall,
                    ),
                  ),
                  Text(
                    PriceHelper.format(
                      line.unitPricePiastres * line.quantity,
                      languageCode: langCode,
                    ),
                    style: TextStyles.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundPills extends StatelessWidget {
  const _RoundPills({required this.categories, required this.isServed});

  final Set<PrepCategory> categories;
  final bool isServed;

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (s) => s.state.settings.languageCode,
    );
    final t = LocalizationService();

    // If served, show only the "Served" pill
    if (isServed) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.xs,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(Spacing.sm),
        ),
        child: Text(
          t.translate('table.round.served', languageCode: langCode),
          style: TextStyles.bodySmall.copyWith(
            color: Colors.white,
            fontSize: 11,
          ),
        ),
      );
    }

    final colors = {
      PrepCategory.food: Colors.amber.shade700,
      PrepCategory.beverage: Colors.blue,
      PrepCategory.shisha: Colors.purple,
      PrepCategory.general: Colors.grey,
      PrepCategory.dessert: Colors.brown,
      PrepCategory.special: Colors.orange,
    };

    final labels = {
      PrepCategory.food: 'table.round.inKitchen',
      PrepCategory.beverage: 'table.round.inBar',
      PrepCategory.shisha: 'table.round.inShishaBar',
      PrepCategory.general: 'table.round.inGeneral',
      PrepCategory.dessert: 'table.round.inDessert',
      PrepCategory.special: 'table.round.inSpecial',
    };

    final pillWidgets = <Widget>[];
    for (final category in categories) {
      final color = colors[category] ?? Colors.grey;
      final labelKey = labels[category] ?? '';
      pillWidgets.add(
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.xs,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(Spacing.sm),
          ),
          child: Text(
            t.translate(labelKey, languageCode: langCode),
            style: TextStyles.bodySmall.copyWith(
              color: Colors.white,
              fontSize: 11,
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: Spacing.xs,
      runSpacing: Spacing.xs,
      children: pillWidgets,
    );
  }
}
