import 'package:flutter/material.dart';

import 'package:cashier_system/core/clock/clock_ticker.dart';
import 'package:cashier_system/core/theme/spacing.dart';
import 'package:cashier_system/core/theme/text_styles.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_entity.dart';
import 'package:cashier_system/features/checkout/domain/helpers/price_helper.dart';
import 'package:cashier_system/features/settings/data/services/localization_service.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class TableCard extends StatelessWidget {
  const TableCard({super.key, required this.table, required this.onTap});

  final TableEntity table;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.select<SettingsBloc, String>(
      (s) => s.state.settings.languageCode,
    );
    final colorScheme = Theme.of(context).colorScheme;

    final (statusColor, statusLabel) = _statusOf(t, langCode);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Spacing.md),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Spacing.md),
          border: Border.all(color: statusColor, width: 2),
          color: colorScheme.surfaceContainerHighest,
        ),
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    table.name,
                    style: TextStyles.heading3.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm,
                    vertical: Spacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.xs,
              children: [
                if (table.isRoom)
                  _Badge(
                    label: t.translate(
                      'table.manage.roomBadge',
                      languageCode: langCode,
                    ),
                  ),
                _Badge(
                  label: t.translate(
                    'table.manage.capacityBadge',
                    languageCode: langCode,
                    params: [table.capacity.toString()],
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (table.status != TableStatus.available) ...[
              _LiveTimer(table: table),
              const SizedBox(height: Spacing.sm),
            ],
            if (table.isRoom && table.status == TableStatus.available)
              Text(
                t.translate(
                  'table.room.hourlyRate',
                  languageCode: langCode,
                  params: [
                    PriceHelper.format(
                      table.hourlyRatePiastres,
                      languageCode: langCode,
                    ),
                  ],
                ),
                style: TextStyles.body.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            if (table.isRoom && table.status != TableStatus.available)
              Text(
                t.translate(
                  'table.room.rent',
                  languageCode: langCode,
                  params: [
                    PriceHelper.format(
                      table.roomChargePiastres,
                      languageCode: langCode,
                    ),
                  ],
                ),
                style: TextStyles.heading3.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  (Color, String) _statusOf(LocalizationService t, String langCode) {
    switch (table.status) {
      case TableStatus.available:
        return (
          Colors.green,
          t.translate('table.status.available', languageCode: langCode),
        );
      case TableStatus.occupied:
        return (
          Colors.blue,
          t.translate('table.status.occupied', languageCode: langCode),
        );
      case TableStatus.orderPending:
        return (
          Colors.amber,
          t.translate('table.status.orderPending', languageCode: langCode),
        );
      case TableStatus.served:
        return (
          Colors.grey,
          t.translate('table.status.served', languageCode: langCode),
        );
      case TableStatus.paymentPending:
        return (
          Colors.red,
          t.translate('table.status.paymentPending', languageCode: langCode),
        );
    }
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyles.caption),
    );
  }
}

class _LiveTimer extends StatelessWidget {
  const _LiveTimer({required this.table});

  final TableEntity table;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ClockTicker.instance,
      builder: (context, nowSeconds, _) {
        final started = table.tabOpenedAt;
        final elapsed = started == null
            ? 0
            : nowSeconds - (started.millisecondsSinceEpoch ~/ 1000);
        final totalSeconds = elapsed < 0 ? 0 : elapsed;
        final hours = totalSeconds ~/ 3600;
        final mins = (totalSeconds % 3600) ~/ 60;
        final secs = totalSeconds % 60;
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              const PhosphorIcon(PhosphorIcons.timer, size: 25),
              const SizedBox(width: Spacing.xs),
              Text(
                '${hours.toString().padLeft(2, '0')}:'
                '${mins.toString().padLeft(2, '0')}:'
                '${secs.toString().padLeft(2, '0')}',
                style: TextStyles.heading2.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
