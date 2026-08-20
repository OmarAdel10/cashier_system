import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import '../../../../core/theme/app_buttons.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../features/auth/data/models/app_user_model.dart';
import '../../../../features/auth/data/models/app_shift_model.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_event.dart';
import '../../../../features/inventory/data/models/app_product_model.dart';
import '../../../../features/inventory/presentation/bloc/inventory_bloc.dart';
import '../../../../features/inventory/presentation/bloc/inventory_event.dart';
import '../../../../features/receipts/data/models/app_receipt_model.dart';
import '../../../../features/receipts/data/models/app_refund_model.dart';
import '../../../../features/checkout/data/models/app_session_record_model.dart';
import '../../../../features/checkout/data/models/app_station_model.dart';
import '../../../../features/checkout/data/models/app_table_model.dart';
import '../../../../features/checkout/data/models/app_table_round_model.dart';
import '../../../../features/checkout/data/models/app_zone_model.dart';
import '../../../../features/expenses/data/models/app_expense_model.dart';
import '../../data/models/app_settings_model.dart';
import '../../data/services/localization_service.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import 'settings_section.dart';

class ResetSection extends StatelessWidget {
  const ResetSection({super.key});

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );
    final t = LocalizationService();

    return SettingsSection(
      title: t.translate('resetAllData', languageCode: langCode),
      children: [
        Text(
          t.translate('resetAllDataSubtitle', languageCode: langCode),
          style: TextStyles.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: Spacing.sm),
        ElevatedButton(
          style: AppButtons.dangerElevated(Theme.of(context).colorScheme),
          onPressed: () => _resetAllData(context, langCode),
          child: Text(t.translate('resetAllData', languageCode: langCode)),
        ),
      ],
    );
  }

  Future<void> _resetAllData(BuildContext context, String langCode) async {
    final t = LocalizationService();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.translate('resetAllDataConfirm', languageCode: langCode)),
        content: Text(
          t.translate('resetAllDataConfirmDetail', languageCode: langCode),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.translate('cancel', languageCode: langCode)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppButtons.dangerText(Theme.of(ctx).colorScheme),
            child: Text(t.translate('reset', languageCode: langCode)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    Future<void> safeClear(Future<void> Function() clear) async {
      try {
        await clear();
      } catch (e) {
        debugPrint('[Reset] Failed to clear a box: $e');
      }
    }

    await safeClear(() => Hive.box<AppSettingsModel>('settings').clear());
    await safeClear(() => Hive.box<AppProductModel>('inventory').clear());
    await safeClear(() => Hive.box<AppUserModel>('auth_users').clear());
    await safeClear(() => Hive.box<AppShiftModel>('shifts').clear());
    await safeClear(() => Hive.box<String>('active_shifts').clear());
    await safeClear(() => Hive.lazyBox<AppReceiptModel>('receipts').clear());
    await safeClear(() => Hive.lazyBox<AppRefundModel>('refunds').clear());
    await safeClear(() => Hive.lazyBox<String>('audit_log').clear());
    await safeClear(() => Hive.lazyBox<AppExpenseModel>('expenses').clear());
    await safeClear(() => Hive.box<AppStationModel>('stations').clear());
    await safeClear(
      () => Hive.box<AppSessionRecordModel>('session_records').clear(),
    );
    await safeClear(() => Hive.box<AppZoneModel>('floor_zones').clear());
    await safeClear(() => Hive.box<AppTableModel>('tables').clear());
    await safeClear(() => Hive.box<AppTableRoundModel>('table_rounds').clear());
    await safeClear(() => Hive.box<List>('product_categories').clear());

    if (context.mounted) {
      context.read<SettingsBloc>().add(const LoadSettings());
      context.read<InventoryBloc>().add(const LoadInventory());
      context.read<AuthBloc>().add(const LogoutRequested());
    }
  }
}
