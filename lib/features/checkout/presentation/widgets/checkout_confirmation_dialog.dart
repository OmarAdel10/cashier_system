import 'package:flutter/material.dart';

class CheckoutConfirmationDialog extends StatefulWidget {
  final bool isSuccess;
  final String message;

  const CheckoutConfirmationDialog({
    super.key,
    required this.isSuccess,
    required this.message,
  });

  @override
  State<CheckoutConfirmationDialog> createState() =>
      _CheckoutConfirmationDialogState();
}

class _CheckoutConfirmationDialogState
    extends State<CheckoutConfirmationDialog> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isSuccess ? Icons.check_circle : Icons.error,
                size: 64,
                color: widget.isSuccess
                    ? colorScheme.primary
                    : colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                widget.message,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
