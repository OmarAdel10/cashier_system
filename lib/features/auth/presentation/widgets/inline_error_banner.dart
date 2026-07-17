import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';

class InlineErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  const InlineErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.sm),
      margin: const EdgeInsets.only(bottom: Spacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PhosphorIcon(
                PhosphorIcons.warningCircle,
                size: 16,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: TextStyles.bodySmall.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: Spacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const PhosphorIcon(PhosphorIcons.arrowClockwise, size: 16),
                label: Text(retryLabel ?? 'Retry'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
