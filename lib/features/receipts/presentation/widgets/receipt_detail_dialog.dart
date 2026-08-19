import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/crypto/password_hasher.dart';
import '../../../../core/printing/receipt_print_helper.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/domain/repositories/i_auth_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../domain/entities/receipt_entity.dart';
import '../../domain/entities/receipt_status.dart';
import '../bloc/receipts_bloc.dart';
import 'modification_entry_dialog.dart';
import 'receipt_detail_actions.dart';
import 'receipt_detail_item_row.dart';
import 'receipt_detail_totals.dart';
import 'refund_confirmation_dialog.dart';
import 'status_badge.dart';

class ReceiptDetailDialog extends StatelessWidget {
  final ReceiptEntity receipt;
  final UserEntity user;
  final DateTime? shiftStartedAt;

  const ReceiptDetailDialog({
    super.key,
    required this.receipt,
    required this.user,
    this.shiftStartedAt,
  });

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.read<SettingsBloc>().state.settings.languageCode;
    final storeName = context.read<SettingsBloc>().state.settings.storeName;
    final theme = Theme.of(context);
    final canModify =
        receipt.status != ReceiptStatus.returned &&
        receipt.status != ReceiptStatus.expense;
    final viewOnly =
        user.role == UserRole.admin || receipt.status == ReceiptStatus.expense;
    final isCashier = user.role == UserRole.cashier;

    return Dialog(
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 800),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${t.translate('sales.orderNumber', languageCode: langCode)}: ${receipt.orderNumber}',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (storeName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(storeName, style: TextStyles.heading3),
                      ],
                    ],
                  ),
                ),
                StatusBadge(receipt.status),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  receipt.createdAt.toString().substring(0, 10),
                  style: TextStyles.body,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('•', style: TextStyle(color: Colors.grey)),
                ),
                Text(receipt.username, style: TextStyles.body),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: Spacing.sm),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        PhosphorIcon(
                          PhosphorIcons.shoppingCartSimple,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: Spacing.sm),
                        Text(
                          t.translate('checkout.cart', languageCode: langCode),
                          style: TextStyles.heading3,
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.sm),
                    ...receipt.items.asMap().entries.map((entry) {
                      final itemIndex = entry.key;
                      final item = entry.value;
                      return ReceiptDetailItemRow(
                        item: item,
                        itemIndex: itemIndex,
                        langCode: langCode,
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            const Divider(height: 1),
            const SizedBox(height: Spacing.sm),
            ReceiptDetailTotals(receipt: receipt, langCode: langCode),
            const SizedBox(height: 12),
            ReceiptDetailActions(
              canModify: canModify,
              viewOnly: viewOnly,
              langCode: langCode,
              onRefund: () => _openRefundDialog(context),
              onModify: () => _openModifyDialog(context),
              onReprint: isCashier && receipt.status != ReceiptStatus.expense
                  ? () => _reprint(context)
                  : null,
              onSavePng: () => _savePng(context),
              onSavePdf: () => _savePdf(context),
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

  void _openModifyDialog(BuildContext context) {
    Navigator.of(context).pop();
    if (receipt.modificationCount == 0) {
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

  Future<void> _reprint(BuildContext context) async {
    final t = LocalizationService();
    final langCode = context.read<SettingsBloc>().state.settings.languageCode;
    final settings = context.read<SettingsBloc>().state.settings;

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t.translate('sales.reprinting', languageCode: langCode)),
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      await ReceiptPrintHelper.printReceipt(
        receipt: receipt,
        settings: settings,
        shiftStartedAt: shiftStartedAt,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t.translate('sales.reprintSuccess', languageCode: langCode),
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${t.translate('sales.reprintFailed', languageCode: langCode)}: $error',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _savePng(BuildContext context) async {
    final t = LocalizationService();
    final langCode = context.read<SettingsBloc>().state.settings.languageCode;
    final settings = context.read<SettingsBloc>().state.settings;

    try {
      final pngPath = await ReceiptPrintHelper.saveAsPng(
        receipt: receipt,
        settings: settings,
        shiftStartedAt: shiftStartedAt,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(pngPath),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${t.translate('sales.reprintFailed', languageCode: langCode)}: $error',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _savePdf(BuildContext context) async {
    final t = LocalizationService();
    final langCode = context.read<SettingsBloc>().state.settings.languageCode;
    final settings = context.read<SettingsBloc>().state.settings;

    try {
      final pdfPath = await ReceiptPrintHelper.saveAsPdf(
        receipt: receipt,
        settings: settings,
        shiftStartedAt: shiftStartedAt,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(pdfPath),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${t.translate('sales.reprintFailed', languageCode: langCode)}: $error',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
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
  final _isVerifying = ValueNotifier<bool>(false);
  final _error = ValueNotifier<String?>(null);
  final _failedAttempts = ValueNotifier<int>(0);
  final _isLocked = ValueNotifier<bool>(false);
  Timer? _lockTimer;

  @override
  void dispose() {
    _lockTimer?.cancel();
    _passwordController.dispose();
    _isVerifying.dispose();
    _error.dispose();
    _failedAttempts.dispose();
    _isLocked.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.read<SettingsBloc>().state.settings.languageCode;

    return ListenableBuilder(
      listenable: Listenable.merge([_isVerifying, _error, _isLocked]),
      builder: (context, _) {
        return AlertDialog(
          title: Text(
            t.translate('sales.adminAuthTitle', languageCode: langCode),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.translate('sales.adminAuthPrompt', languageCode: langCode),
              ),
              const SizedBox(height: Spacing.md),
              TextField(
                controller: _passwordController,
                obscureText: true,
                enabled: !_isLocked.value,
                decoration: InputDecoration(
                  labelText: t.translate(
                    'settings.password',
                    languageCode: langCode,
                  ),
                  border: const OutlineInputBorder(),
                  errorText: _error.value,
                ),
                onSubmitted: (_) => _verify(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isVerifying.value
                  ? null
                  : () {
                      _lockTimer?.cancel();
                      Navigator.of(context).pop();
                    },
              child: Text(t.translate('cancel', languageCode: langCode)),
            ),
            FilledButton(
              onPressed: _isVerifying.value || _isLocked.value ? null : _verify,
              child: _isVerifying.value
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      t.translate(
                        'settings.verifyPassword',
                        languageCode: langCode,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _verify() async {
    if (_isLocked.value) return;
    _isVerifying.value = true;
    _error.value = null;
    final t = LocalizationService();
    final langCode = context.read<SettingsBloc>().state.settings.languageCode;
    final result = await widget.authRepo.getByUsername(widget.adminUsername);
    String? err;
    result.fold(
      (l) => err = t.translate(
        'sales.authError.invalidCredentials',
        languageCode: langCode,
      ),
      (user) {
        final matchesNewScheme =
            user != null &&
            user.passwordHash ==
                hashPassword(_passwordController.text, user.passwordSalt);
        final matchesLegacy =
            user != null &&
            user.passwordHash ==
                hashPasswordLegacy(_passwordController.text, user.passwordSalt);
        if (!matchesNewScheme && !matchesLegacy) {
          err = t.translate(
            'sales.authError.invalidCredentials',
            languageCode: langCode,
          );
        }
      },
    );
    if (!mounted) return;
    if (err != null) {
      _failedAttempts.value++;
      if (_failedAttempts.value >= 3) {
        _isVerifying.value = false;
        _isLocked.value = true;
        var remaining = _failedAttempts.value * 2;
        _error.value =
            '${t.translate('sales.authError.invalidCredentials', languageCode: langCode)} (${remaining}s remaining)';
        _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          remaining--;
          if (remaining <= 0) {
            timer.cancel();
            _isLocked.value = false;
            _failedAttempts.value = 0;
            _error.value = null;
          } else {
            _error.value =
                '${t.translate('sales.authError.invalidCredentials', languageCode: langCode)} (${remaining}s remaining)';
          }
        });
      } else {
        _isVerifying.value = false;
        _error.value = err;
      }
    } else {
      widget.onVerified(_passwordController.text);
    }
  }
}
