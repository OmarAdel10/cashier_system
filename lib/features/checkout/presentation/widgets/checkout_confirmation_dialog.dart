import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../receipts/presentation/bloc/receipts_bloc.dart';
import '../../../receipts/presentation/bloc/receipts_state.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';

class CheckoutConfirmationDialog extends StatefulWidget {
  const CheckoutConfirmationDialog({super.key});

  @override
  State<CheckoutConfirmationDialog> createState() =>
      _CheckoutConfirmationDialogState();
}

class _CheckoutConfirmationDialogState
    extends State<CheckoutConfirmationDialog> {
  bool _dismissScheduled = false;
  final _showDismissNotifier = ValueNotifier<bool>(false);
  Timer? _dismissTimer;
  Timer? _showButtonTimer;

  @override
  void initState() {
    super.initState();
    final state = context.read<ReceiptsBloc>().state;
    if (state.status == ReceiptBlocStatus.ready) {
      _scheduleDismiss(2);
    } else if (state.status == ReceiptBlocStatus.error) {
      _scheduleDismiss(5);
    }
    _showButtonTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) _showDismissNotifier.value = true;
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _showButtonTimer?.cancel();
    _showDismissNotifier.dispose();
    super.dispose();
  }

  void _scheduleDismiss(int seconds) {
    if (_dismissScheduled) return;
    _dismissScheduled = true;
    _dismissTimer = Timer(Duration(seconds: seconds), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.select<SettingsBloc, String>((s) => s.state.settings.languageCode);

    return BlocConsumer<ReceiptsBloc, ReceiptsState>(
      listener: (context, state) {
        if (state.status == ReceiptBlocStatus.ready) {
          _scheduleDismiss(2);
        } else if (state.status == ReceiptBlocStatus.error) {
          _scheduleDismiss(5);
        }
      },
      builder: (context, state) {
        final isProcessing =
            state.status == ReceiptBlocStatus.loading ||
            state.status == ReceiptBlocStatus.initial;
        final isSuccess = state.status == ReceiptBlocStatus.ready;
        final isFailure = state.status == ReceiptBlocStatus.error;

        return ListenableBuilder(
          listenable: _showDismissNotifier,
          builder: (context, _) => PopScope(
            canPop: isSuccess || isFailure || _showDismissNotifier.value,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isProcessing)
                      const SizedBox(
                        width: 64,
                        height: 64,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    else if (isSuccess)
                      const PhosphorIcon(
                        PhosphorIcons.checkCircleDuotone,
                        size: 64,
                        color: Colors.green,
                      )
                    else ...[
                      const PhosphorIcon(
                        PhosphorIcons.xCircleDuotone,
                        size: 64,
                        color: Colors.red,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      isProcessing
                          ? t.translate(
                              'checkout.processingSale',
                              languageCode: langCode,
                            )
                          : isSuccess
                          ? t.translate(
                              'checkout.saleConfirmed',
                              languageCode: langCode,
                            )
                          : state.failure?.message ??
                                t.translate(
                                  'checkout.saleFailed',
                                  languageCode: langCode,
                                ),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (isFailure && _showDismissNotifier.value) ...[
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          t.translate('cancel', languageCode: langCode),
                        ),
                      ),
                    ],
                    if (isSuccess && _showDismissNotifier.value) ...[
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(t.translate('ok', languageCode: langCode)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
