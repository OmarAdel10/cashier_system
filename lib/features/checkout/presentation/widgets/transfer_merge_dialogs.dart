import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cashier_system/core/theme/spacing.dart';
import 'package:cashier_system/core/theme/text_styles.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_entity.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/table_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/table_event.dart';
import 'package:cashier_system/features/settings/data/services/localization_service.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';

/// Dialog to transfer a table's tab and rounds to another available table.
class TransferTableDialog extends StatefulWidget {
  const TransferTableDialog({super.key, required this.sourceTable});

  final TableEntity sourceTable;

  @override
  State<TransferTableDialog> createState() => _TransferTableDialogState();
}

class _TransferTableDialogState extends State<TransferTableDialog> {
  String? _selectedTargetId;

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (s) => s.state.settings.languageCode,
    );
    final t = LocalizationService();
    final tablesState = context.watch<TableBloc>().state;

    final availableTargets = tablesState.tables
        .where(
          (t) =>
              t.id != widget.sourceTable.id &&
              t.status == TableStatus.available,
        )
        .toList();

    return AlertDialog(
      title: Text(t.translate('table.transfer.title', languageCode: langCode)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.translate(
                'table.transfer.source',
                languageCode: langCode,
                params: [widget.sourceTable.name],
              ),
              style: TextStyles.body,
            ),
            const SizedBox(height: Spacing.md),
            Text(
              t.translate(
                'table.transfer.selectTarget',
                languageCode: langCode,
              ),
              style: TextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: Spacing.sm),
            if (availableTargets.isEmpty)
              Text(
                t.translate('table.transfer.noTargets', languageCode: langCode),
                style: TextStyles.body.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              )
            else
              DropdownButtonFormField<String>(
                key: const Key('transfer-target-dropdown'),
                initialValue: _selectedTargetId,
                decoration: InputDecoration(
                  labelText: t.translate(
                    'table.transfer.target',
                    languageCode: langCode,
                  ),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final table in availableTargets)
                    DropdownMenuItem(value: table.id, child: Text(table.name)),
                ],
                onChanged: (value) => setState(() => _selectedTargetId = value),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            t.translate('table.transfer.cancel', languageCode: langCode),
          ),
        ),
        FilledButton(
          key: const Key('transfer-confirm'),
          onPressed: _selectedTargetId == null
              ? null
              : () {
                  context.read<TableBloc>().add(
                    TransferTable(widget.sourceTable.id, _selectedTargetId!),
                  );
                  Navigator.pop(context, true);
                },
          child: Text(
            t.translate('table.transfer.confirm', languageCode: langCode),
          ),
        ),
      ],
    );
  }
}

/// Dialog to merge a source table's tab and rounds into a target table.
class MergeTablesDialog extends StatefulWidget {
  const MergeTablesDialog({super.key, required this.sourceTable});

  final TableEntity sourceTable;

  @override
  State<MergeTablesDialog> createState() => _MergeTablesDialogState();
}

class _MergeTablesDialogState extends State<MergeTablesDialog> {
  String? _selectedTargetId;

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (s) => s.state.settings.languageCode,
    );
    final t = LocalizationService();
    final tablesState = context.watch<TableBloc>().state;

    final availableTargets = tablesState.tables
        .where(
          (t) =>
              t.id != widget.sourceTable.id &&
              t.status != TableStatus.available,
        )
        .toList();

    return AlertDialog(
      title: Text(t.translate('table.merge.title', languageCode: langCode)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.translate(
                'table.merge.source',
                languageCode: langCode,
                params: [widget.sourceTable.name],
              ),
              style: TextStyles.body,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              t.translate('table.merge.warning', languageCode: langCode),
              style: TextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: Spacing.md),
            Text(
              t.translate('table.merge.selectTarget', languageCode: langCode),
              style: TextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: Spacing.sm),
            if (availableTargets.isEmpty)
              Text(
                t.translate('table.merge.noTargets', languageCode: langCode),
                style: TextStyles.body.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              )
            else
              DropdownButtonFormField<String>(
                key: const Key('merge-target-dropdown'),
                initialValue: _selectedTargetId,
                decoration: InputDecoration(
                  labelText: t.translate(
                    'table.merge.target',
                    languageCode: langCode,
                  ),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final table in availableTargets)
                    DropdownMenuItem(value: table.id, child: Text(table.name)),
                ],
                onChanged: (value) => setState(() => _selectedTargetId = value),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            t.translate('table.merge.cancel', languageCode: langCode),
          ),
        ),
        FilledButton(
          key: const Key('merge-confirm'),
          onPressed: _selectedTargetId == null
              ? null
              : () {
                  context.read<TableBloc>().add(
                    MergeTables(widget.sourceTable.id, _selectedTargetId!),
                  );
                  Navigator.pop(context, true);
                },
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(
            t.translate('table.merge.confirm', languageCode: langCode),
          ),
        ),
      ],
    );
  }
}
