import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

enum ErrorSeverity { recoverable, terminal }

class AppError extends StatelessWidget {
  final String headline;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;
  final ErrorSeverity severity;

  const AppError({
    super.key,
    required this.headline,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    this.severity = ErrorSeverity.recoverable,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = severity == ErrorSeverity.terminal
        ? const Color(0xFFDC2626)
        : const Color(0xFF007ACC);

    final icon = severity == ErrorSeverity.terminal
        ? PhosphorIcons.xCircleDuotone
        : PhosphorIcons.warningCircleDuotone;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.xl, vertical: Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            PhosphorIcon(icon, size: 48, color: iconColor),
            const SizedBox(height: Spacing.xl),
            Text(headline, style: TextStyles.heading2),
            const SizedBox(height: Spacing.sm),
            Text(body, style: TextStyles.body),
            const SizedBox(height: Spacing.lg),
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionLabel, style: TextStyles.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}
