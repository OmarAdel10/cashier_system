import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cashier_system/core/theme/expense_colors.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_status.dart';
import 'package:cashier_system/features/settings/data/services/localization_service.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class StatusBadge extends StatelessWidget {
  final ReceiptStatus status;

  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.select(
      (SettingsBloc b) => b.state.settings.languageCode,
    );
    return switch (status) {
      ReceiptStatus.active => _Badge(
        icon: PhosphorIcons.checkCircle,
        color: Colors.green,
        label: t.translate('sales.statusActive', languageCode: langCode),
      ),
      ReceiptStatus.returned => _Badge(
        icon: PhosphorIcons.arrowArcLeft,
        color: Colors.red,
        label: t.translate('sales.statusReturned', languageCode: langCode),
      ),
      ReceiptStatus.modified => _Badge(
        icon: PhosphorIcons.pencilSimple,
        color: Colors.amber,
        label: t.translate('sales.statusModified', languageCode: langCode),
      ),
      ReceiptStatus.expense => _Badge(
        icon: PhosphorIcons.wallet,
        color: ExpenseColors.accent,
        label: t.translate('sales.statusExpense', languageCode: langCode),
      ),
    };
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _Badge({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 2),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}
