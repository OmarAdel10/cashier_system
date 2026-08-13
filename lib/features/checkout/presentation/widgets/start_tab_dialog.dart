import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cashier_system/core/theme/spacing.dart';
import 'package:cashier_system/core/theme/text_styles.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_entity.dart';
import 'package:cashier_system/features/checkout/domain/helpers/price_helper.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/table_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/table_event.dart';
import 'package:cashier_system/features/settings/data/services/localization_service.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';

/// Overlay dialog confirming a new tab on an available table.
class StartTabDialog extends StatelessWidget {
  const StartTabDialog({super.key, required this.table});

  final TableEntity table;

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.select<SettingsBloc, String>(
      (s) => s.state.settings.languageCode,
    );
    final isRoom = table.isRoom;

    return AlertDialog(
      title: Text(
        t.translate(
          'table.startTab.title',
          languageCode: langCode,
          params: [table.name],
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.translate('table.startTab.message', languageCode: langCode),
            style: TextStyles.body,
          ),
          if (isRoom) ...[
            const SizedBox(height: Spacing.sm),
            Text(
              t.translate(
                'table.startTab.roomNote',
                languageCode: langCode,
                params: [
                  PriceHelper.format(
                    table.hourlyRatePiastres,
                    languageCode: langCode,
                  ),
                ],
              ),
              style: TextStyles.body.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.translate('cancel', languageCode: langCode)),
        ),
        FilledButton(
          onPressed: () {
            context.read<TableBloc>().add(OpenTab(table.id));
            Navigator.pop(context);
          },
          child: Text(t.translate('confirm', languageCode: langCode)),
        ),
      ],
    );
  }
}
