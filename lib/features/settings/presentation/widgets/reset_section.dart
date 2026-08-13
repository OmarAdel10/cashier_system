import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
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
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(t.translate('reset', languageCode: langCode)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await Hive.box<AppSettingsModel>('settings').clear();
    await Hive.box<AppProductModel>('inventory').clear();
    await Hive.box<AppUserModel>('auth_users').clear();
    await Hive.box<AppShiftModel>('shifts').clear();
    await Hive.box<String>('active_shifts').clear();
    await Hive.lazyBox<AppReceiptModel>('receipts').clear();
    await Hive.lazyBox<AppRefundModel>('refunds').clear();
    await Hive.lazyBox<String>('audit_log').clear();
    await Hive.lazyBox<AppExpenseModel>('expenses').clear();

    if (context.mounted) {
      context.read<SettingsBloc>().add(const LoadSettings());
      context.read<InventoryBloc>().add(const LoadInventory());
      context.read<AuthBloc>().add(const LogoutRequested());
    }
  }
}
