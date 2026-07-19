import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/crypto/password_hasher.dart';
import '../../../../core/printing/print_service.dart';
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

  const ReceiptDetailDialog({
    super.key,
    required this.receipt,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode =
        context.read<SettingsBloc>().state.settings.languageCode;
    final storeName =
        context.read<SettingsBloc>().state.settings.storeName;
    final theme = Theme.of(context);
    final canModify = receipt.status != ReceiptStatus.returned;
    final viewOnly = user.role == UserRole.admin;
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
            ReceiptDetailTotals(
              receipt: receipt,
              langCode: langCode,
            ),
            const SizedBox(height: 12),
            ReceiptDetailActions(
              canModify: canModify,
              viewOnly: viewOnly,
              langCode: langCode,
              onRefund: () => _openRefundDialog(context),
              onModify: () => _openModifyDialog(context),
              onReprint: isCashier ? () => _reprint(context) : null,
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

  void _reprint(BuildContext context) {
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

    final printService = PrintService();
    final payload = {
      'printer_name': settings.receiptPrinterName ?? '',
      'store_name': settings.storeName,
      'store_address': settings.storeAddress,
      'store_phone': settings.storePhoneNumber,
      'order_number': receipt.orderNumber,
      'username': receipt.username,
      'created_at': receipt.createdAt.toIso8601String(),
      'is_rtl': settings.isRtl,
      'save_as_png': settings.saveReceiptAsImage,
      'output_directory': settings.exportDirectoryPath,
      'logo_svg': settings.logoSvgPath,
      'items': receipt.items.map((item) => {
        'name': item.name,
        'barcode': item.barcode,
        'quantity': item.quantity,
        'unit_price_piastres': item.unitPricePiastres,
        'total_piastres': item.unitPricePiastres * item.quantity,
      }).toList(),
      'subtotal_piastres': receipt.subtotalPiastres,
      'discount_piastres': receipt.discountPiastres,
      'tax_piastres': receipt.taxPiastres,
      'total_piastres': receipt.totalPiastres,
      'footnote': settings.receiptFootnote,
    };

    printService.printReceipt(payload).then((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.translate('sales.reprintSuccess', languageCode: langCode)),
          ),
        );
      }
    }).catchError((error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.translate('sales.reprintFailed', languageCode: langCode)}: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }).whenComplete(() => printService.dispose());
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
    final langCode =
        context.read<SettingsBloc>().state.settings.languageCode;

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
              labelText: t.translate(
                'settings.password',
                languageCode: langCode,
              ),
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            onSubmitted: (_) => _verify(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isVerifying || _isLocked
              ? null
              : () => Navigator.of(context).pop(),
          child: Text(t.translate('cancel', languageCode: langCode)),
        ),
        FilledButton(
          onPressed: _isVerifying || _isLocked ? null : _verify,
          child: _isVerifying
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
  }

  Future<void> _verify() async {
    if (_isLocked) return;
    setState(() {
      _isVerifying = true;
      _error = null;
    });
    final t = LocalizationService();
    final langCode =
        context.read<SettingsBloc>().state.settings.languageCode;
    final result = await widget.authRepo.getByUsername(widget.adminUsername);
    String? err;
    UserEntity? foundUser;
    result.fold(
      (l) => err = t.translate(
        'sales.authError.invalidCredentials',
        languageCode: langCode,
      ),
      (user) {
        foundUser = user;
        if (user == null ||
            user.passwordHash !=
                hashPassword(_passwordController.text, user.passwordSalt)) {
          err = t.translate(
            'sales.authError.invalidCredentials',
            languageCode: langCode,
          );
        }
      },
    );
    if (!mounted) return;
    if (err != null) {
      _failedAttempts++;
      if (_failedAttempts >= 3) {
        _isLocked = true;
        final delay = _failedAttempts * 2;
        _error =
            '${t.translate('sales.authError.invalidCredentials', languageCode: langCode)} (${delay}s)';
        Future.delayed(Duration(seconds: delay), () {
          if (mounted) {
            setState(() {
              _isLocked = false;
              _failedAttempts = 0;
              _error = null;
            });
          }
        });
      } else {
        setState(() {
          _isVerifying = false;
          _error = err;
        });
      }
    } else {
      final hashed = hashPassword(
        _passwordController.text,
        foundUser!.passwordSalt,
      );
      widget.onVerified(hashed);
    }
  }
}
