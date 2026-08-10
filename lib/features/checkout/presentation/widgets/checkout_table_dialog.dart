import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cashier_system/core/theme/spacing.dart';
import 'package:cashier_system/core/theme/text_styles.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/shift_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/shift_event.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_order_line.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_round_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/zone_entity.dart';
import 'package:cashier_system/features/checkout/domain/helpers/price_helper.dart';
import 'package:cashier_system/features/checkout/domain/helpers/table_bill_composer.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/table_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/table_event.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/zone_bloc.dart';
import 'package:cashier_system/features/receipts/presentation/bloc/receipts_bloc.dart';
import 'package:cashier_system/features/receipts/presentation/bloc/receipts_event.dart';
import 'package:cashier_system/features/settings/data/services/localization_service.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';

/// Settles a cafe table tab: applies discount, optional equal split,
/// payment type and paid amount, then issues one receipt per split part,
/// archives the rounds and closes the tab (CompleteCheckout).
class CheckoutTableDialog extends StatefulWidget {
  const CheckoutTableDialog({super.key, required this.table});

  final TableEntity table;

  @override
  State<CheckoutTableDialog> createState() => _CheckoutTableDialogState();
}

class _CheckoutTableDialogState extends State<CheckoutTableDialog> {
  int _discountPercent = 0;
  int _splitCount = 1;
  String? _paymentTypeId;
  int? _amountPaidPiastres;
  final TextEditingController _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.select<SettingsBloc, String>(
      (s) => s.state.settings.languageCode,
    );
    final settings = context.watch<SettingsBloc>().state.settings;
    final tablesState = context.watch<TableBloc>().state;
    final zone = context.watch<ZoneBloc>().state.zones.firstWhere(
      (z) => z.id == widget.table.zoneId,
      orElse: () => const ZoneEntity(id: '', name: '', kind: ZoneKind.takeaway),
    );

    final table =
        tablesState.tables.where((t) => t.id == widget.table.id).firstOrNull ??
        widget.table;
    final rounds = tablesState.rounds
        .where((r) => r.tableId == table.id && r.status != RoundStatus.archived)
        .toList();
    final draftLines = tablesState.draftFor(table.id);
    final firedLines = <TableOrderLine>[];
    for (final round in rounds) {
      firedLines.addAll(round.lines);
    }

    final bill = TableBillComposer(
      zoneKind: zone.kind,
      isRoom: table.isRoom,
      chargedHours: table.chargedHours,
      hourlyRatePiastres: table.hourlyRatePiastres,
      firedLines: firedLines,
      draftLines: draftLines,
      minChargeEnabled: settings.minChargeEnabled,
      minChargePerTablePiastres: settings.minChargePerTablePiastres,
      serviceChargeEnabled: settings.serviceChargeEnabled,
      serviceChargePercent: settings.serviceChargePercent,
      discountPercent: _discountPercent,
      taxPercent: settings.taxEnabled ? settings.taxPercent : 0,
      roomChargeLabel: t.translate(
        'table.checkout.roomRent',
        languageCode: langCode,
      ),
      serviceChargeLabel: t.translate(
        'table.checkout.serviceCharge',
        languageCode: langCode,
      ),
      minChargeLabel: t.translate(
        'table.checkout.minimumCharge',
        languageCode: langCode,
      ),
    ).compose();
    final splits = bill.split(_splitCount);

    final paymentTypes = settings.shownPaymentTypeIds.isEmpty
        ? const ['cash']
        : settings.shownPaymentTypeIds;
    final paymentTypeId = _paymentTypeId ?? paymentTypes.first;

    final shiftId = context.select<ShiftBloc, String?>(
      (s) => s.state.shift?.id,
    );

    return AlertDialog(
      title: Text(
        t.translate(
          'table.checkout.title',
          languageCode: langCode,
          params: [table.name],
        ),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in bill.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.quantity > 1
                            ? '${item.name} x${item.quantity}'
                            : item.name,
                        style: TextStyles.body,
                      ),
                      Text(
                        PriceHelper.format(
                          item.quantity * item.unitPricePiastres,
                          languageCode: langCode,
                        ),
                        style: TextStyles.body,
                      ),
                    ],
                  ),
                ),
              const Divider(height: Spacing.lg),
              _SummaryRow(
                label: t.translate(
                  'table.checkout.subtotal',
                  languageCode: langCode,
                ),
                amount: bill.subtotalPiastres,
                langCode: langCode,
              ),
              if (bill.discountPiastres > 0)
                _SummaryRow(
                  label: t.translate(
                    'table.checkout.discount',
                    languageCode: langCode,
                  ),
                  amount: -bill.discountPiastres,
                  langCode: langCode,
                ),
              if (bill.taxPiastres > 0)
                _SummaryRow(
                  label: t.translate(
                    'table.checkout.tax',
                    languageCode: langCode,
                  ),
                  amount: bill.taxPiastres,
                  langCode: langCode,
                ),
              _SummaryRow(
                label: t.translate(
                  'table.checkout.total',
                  languageCode: langCode,
                ),
                amount: bill.totalPiastres,
                langCode: langCode,
                emphasized: true,
              ),
              const SizedBox(height: Spacing.md),
              _StepperRow(
                key: const Key('discount-stepper'),
                label: t.translate(
                  'table.checkout.discount',
                  languageCode: langCode,
                ),
                valueLabel: '$_discountPercent%',
                onDecrement: _discountPercent > 0
                    ? () => setState(() => _discountPercent--)
                    : null,
                onIncrement: _discountPercent < 100
                    ? () => setState(() => _discountPercent++)
                    : null,
              ),
              _StepperRow(
                key: const Key('split-stepper'),
                label: t.translate(
                  'table.checkout.split',
                  languageCode: langCode,
                ),
                valueLabel: _splitCount > 1
                    ? '$_splitCount ・ ${t.translate('table.checkout.perReceipt', languageCode: langCode)} ${PriceHelper.format(splits.last.totalPiastres, languageCode: langCode)}'
                    : '$_splitCount',
                onDecrement: _splitCount > 1
                    ? () => setState(() => _splitCount--)
                    : null,
                onIncrement: _splitCount < 10
                    ? () => setState(() => _splitCount++)
                    : null,
              ),
              const SizedBox(height: Spacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.translate(
                        'table.checkout.paymentType',
                        languageCode: langCode,
                      ),
                      style: TextStyles.body,
                    ),
                  ),
                  DropdownButton<String>(
                    key: const Key('checkout-payment-type'),
                    value: paymentTypeId,
                    items: [
                      for (final type in paymentTypes)
                        DropdownMenuItem(value: type, child: Text(type)),
                    ],
                    onChanged: (value) => setState(() {
                      _paymentTypeId = value;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.translate(
                        'table.checkout.amountPaid',
                        languageCode: langCode,
                      ),
                      style: TextStyles.body,
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      key: const Key('checkout-amount-paid'),
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        final parsed = int.tryParse(value);
                        setState(() => _amountPaidPiastres = parsed);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              if (_splitCount > 1)
                Text(
                  '${t.translate('table.checkout.perReceipt', languageCode: langCode)}: '
                  '${splits.map((s) => PriceHelper.format(s.totalPiastres, languageCode: langCode)).join(', ')}',
                  style: TextStyles.bodySmall,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            t.translate('table.checkout.cancel', languageCode: langCode),
          ),
        ),
        FilledButton(
          key: const Key('checkout-confirm'),
          onPressed: shiftId == null || bill.totalPiastres <= 0
              ? null
              : () => _confirm(bill, splits, paymentTypeId, shiftId),
          child: Text(
            t.translate('table.checkout.confirm', languageCode: langCode),
          ),
        ),
      ],
    );
  }

  void _confirm(
    ComposedTableBill bill,
    List<TableBillSplit> splits,
    String paymentTypeId,
    String shiftId,
  ) {
    final receiptsBloc = context.read<ReceiptsBloc>();
    final shiftBloc = context.read<ShiftBloc>();
    final shift = shiftBloc.state.shift;
    final username = context.read<AuthBloc>().state.user?.username ?? '';
    var pendingIncrements = 0;
    final paidParts = _amountPaidPiastres == null
        ? null
        : ComposedTableBill.splitAmount(_amountPaidPiastres!, splits.length);

    for (var i = 0; i < splits.length; i++) {
      final split = splits[i];
      final counter = shift!.orderCount + pendingIncrements;
      pendingIncrements++;
      shiftBloc.add(IncrementShiftOrderCount(shift.id));
      receiptsBloc.add(
        CreateReceipt(
          shiftId: shiftId,
          orderNumber: 'ORD-${counter.toString().padLeft(5, '0')}',
          items: split.items,
          subtotalPiastres: split.subtotalPiastres,
          discountPiastres: split.discountPiastres,
          taxPiastres: split.taxPiastres,
          totalPiastres: split.totalPiastres,
          username: username,
          taxPercent: bill.taxPercent,
          discountPercent: bill.discountPercent,
          amountPaidPiastres: paidParts?[i],
          paymentType: paymentTypeId,
        ),
      );
    }

    context.read<TableBloc>().add(CompleteCheckout(widget.table.id));
    Navigator.pop(context, true);
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.amount,
    required this.langCode,
    this.emphasized = false,
  });

  final String label;
  final int amount;
  final String langCode;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: emphasized ? TextStyles.heading3 : TextStyles.body,
          ),
          Text(
            PriceHelper.format(amount, languageCode: langCode),
            style: emphasized ? TextStyles.heading3 : TextStyles.body,
          ),
        ],
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final String valueLabel;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyles.body)),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: onDecrement,
          ),
          SizedBox(
            width: 140,
            child: Text(
              valueLabel,
              style: TextStyles.body,
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_circle_outline),
            onPressed: onIncrement,
          ),
        ],
      ),
    );
  }
}
