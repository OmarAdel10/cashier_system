import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/crypto/password_hasher.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/domain/repositories/i_auth_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../checkout/domain/helpers/price_helper.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../domain/entities/receipt_entity.dart';
import '../../domain/entities/receipt_status.dart';
import '../bloc/receipts_bloc.dart';
import 'modification_entry_dialog.dart';
import 'refund_confirmation_dialog.dart';
import 'status_badge.dart';

class ReceiptDetailDialog extends StatelessWidget {
  final ReceiptEntity receipt;
  final UserEntity user;

  const ReceiptDetailDialog({super.key, required this.receipt, required this.user});

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final settings = context.watch<SettingsBloc>().state.settings;
    final langCode = settings.languageCode;
    final storeName = settings.storeName;
    final theme = Theme.of(context);
    final isActive = receipt.status == ReceiptStatus.active;
    final canModify = receipt.status == ReceiptStatus.active;
    final viewOnly = user.role == UserRole.admin;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 64, vertical: 48),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${t.translate('sales.orderNumber', languageCode: langCode)}: ${receipt.orderNumber}',
                  style: TextStyles.title,
                ),
                const Spacer(),
                StatusBadge(receipt.status),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            if (storeName.isNotEmpty) ...[
              Text(
                storeName,
                style: TextStyles.heading3,
              ),
              const SizedBox(height: Spacing.sm),
            ],
            Text(
              '${t.translate('sales.date', languageCode: langCode)}: ${receipt.createdAt.toString().substring(0, 19)}',
              style: TextStyles.bodySmall,
            ),
            Text(
              '${t.translate('sales.cashier', languageCode: langCode)}: ${receipt.username}',
              style: TextStyles.bodySmall,
            ),
            const SizedBox(height: Spacing.md),
            const Divider(height: 1),
            const SizedBox(height: Spacing.sm),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.translate('checkout.cart', languageCode: langCode),
                      style: TextStyles.heading3,
                    ),
                    const SizedBox(height: Spacing.sm),
                    ...receipt.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '${item.name} × ${item.quantity}  @  ${PriceHelper.format(item.unitPricePiastres, languageCode: langCode)}  =  ${PriceHelper.format(item.totalPiastres, languageCode: langCode)}',
                        style: TextStyles.body,
                      ),
                    )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            const Divider(height: 1),
            const SizedBox(height: Spacing.sm),
            _TotalRow(
              label: t.translate('checkout.total', languageCode: langCode),
              value: PriceHelper.format(receipt.subtotalPiastres, languageCode: langCode),
            ),
            if (receipt.discountPiastres > 0)
              _TotalRow(
                label: t.translate('discount', languageCode: langCode),
                value: '-${PriceHelper.format(receipt.discountPiastres, languageCode: langCode)}',
              ),
            if (receipt.taxPiastres > 0)
              _TotalRow(
                label: t.translate('tax', languageCode: langCode),
                value: PriceHelper.format(receipt.taxPiastres, languageCode: langCode),
              ),
            _TotalRow(
              label: t.translate('checkout.total', languageCode: langCode),
              value: PriceHelper.format(receipt.totalPiastres, languageCode: langCode),
              isBold: true,
            ),
            const SizedBox(height: Spacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isActive && !viewOnly)
                  TextButton.icon(
                    onPressed: () => _openRefundDialog(context),
                    icon: const PhosphorIcon(PhosphorIcons.arrowArcLeft, size: 16),
                    label: Text(t.translate('sales.returnRefund', languageCode: langCode)),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                if (isActive && !viewOnly) const SizedBox(width: Spacing.sm),
                if (canModify && !viewOnly)
                  TextButton.icon(
                    onPressed: () => _openModifyDialog(context, isActive),
                    icon: const PhosphorIcon(PhosphorIcons.pencilSimple, size: 16),
                    label: Text(t.translate('sales.modify', languageCode: langCode)),
                  ),
                if ((isActive || canModify) && !viewOnly) const SizedBox(width: Spacing.sm),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(t.translate('cancel', languageCode: langCode)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openRefundDialog(BuildContext context) {
    Navigator.of(context).pop();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<ReceiptsBloc>(),
        child: RefundConfirmationDialog(receipt: receipt),
      ),
    );
  }

  void _openModifyDialog(BuildContext context, bool isActive) {
    Navigator.of(context).pop();
    if (isActive) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => BlocProvider.value(
          value: context.read<ReceiptsBloc>(),
          child: ModificationEntryDialog(receipt: receipt),
        ),
      );
      return;
    }
    final authRepo = context.read<IAuthRepository>();
    final currentUser = context.read<AuthBloc>().state.user;
    final receiptsBloc = context.read<ReceiptsBloc>();
    if (currentUser == null) return;
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AdminPasswordDialog(
        adminUsername: currentUser.username,
        authRepo: authRepo,
        onVerified: (adminPassword) {
          Navigator.of(ctx).pop();
          navigator.push(
            DialogRoute(
              context: ctx,
              builder: (_) => BlocProvider.value(
                value: receiptsBloc,
                child: ModificationEntryDialog(
                  receipt: receipt,
                  isAuthorized: true,
                  adminUsername: currentUser.username,
                  adminPassword: adminPassword,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AdminPasswordDialog extends StatefulWidget {
  final String adminUsername;
  final IAuthRepository authRepo;
  final void Function(String adminPassword) onVerified;

  const _AdminPasswordDialog({
    required this.adminUsername,
    required this.authRepo,
    required this.onVerified,
  });

  @override
  State<_AdminPasswordDialog> createState() => _AdminPasswordDialogState();
}

class _AdminPasswordDialogState extends State<_AdminPasswordDialog> {
  final _passwordController = TextEditingController();
  bool _isVerifying = false;
  String? _error;
  int _failedAttempts = 0;
  bool _isLocked = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.watch<SettingsBloc>().state.settings.languageCode;

    return AlertDialog(
      title: Text(t.translate('sales.adminAuthTitle', languageCode: langCode)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t.translate('sales.adminAuthPrompt', languageCode: langCode)),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _passwordController,
            obscureText: true,
            enabled: !_isLocked,
            decoration: InputDecoration(
              labelText: t.translate('settings.password', languageCode: langCode),
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            onSubmitted: (_) => _verify(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isVerifying || _isLocked ? null : () => Navigator.of(context).pop(),
          child: Text(t.translate('cancel', languageCode: langCode)),
        ),
        FilledButton(
          onPressed: _isVerifying || _isLocked ? null : _verify,
          child: _isVerifying
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(t.translate('settings.verifyPassword', languageCode: langCode)),
        ),
      ],
    );
  }

  Future<void> _verify() async {
    if (_isLocked) return;
    setState(() { _isVerifying = true; _error = null; });
    final t = LocalizationService();
    final langCode = context.watch<SettingsBloc>().state.settings.languageCode;
    final result = await widget.authRepo.getByUsername(widget.adminUsername);
    String? err;
    UserEntity? foundUser;
    result.fold(
      (l) => err = t.translate('sales.authError.invalidCredentials', languageCode: langCode),
      (user) {
        foundUser = user;
        if (user == null || user.passwordHash != hashPassword(_passwordController.text, user.passwordSalt)) {
          err = t.translate('sales.authError.invalidCredentials', languageCode: langCode);
        }
      },
    );
    if (!mounted) return;
    if (err != null) {
      _failedAttempts++;
      if (_failedAttempts >= 3) {
        _isLocked = true;
        final delay = _failedAttempts * 2;
        _error = '${t.translate('sales.authError.invalidCredentials', languageCode: langCode)} (${delay}s)';
        Future.delayed(Duration(seconds: delay), () {
          if (mounted) setState(() { _isLocked = false; _failedAttempts = 0; _error = null; });
        });
      } else {
        setState(() { _isVerifying = false; _error = err; });
      }
    } else {
      final hashed = hashPassword(_passwordController.text, foundUser!.passwordSalt);
      widget.onVerified(hashed);
    }
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _TotalRow({required this.label, required this.value, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: isBold ? TextStyles.title : TextStyles.body),
          Text(value, style: isBold ? TextStyles.title : TextStyles.body),
        ],
      ),
    );
  }
}
