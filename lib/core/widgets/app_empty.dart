import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

class AppEmpty extends StatelessWidget {
  final String headline;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmpty({
    super.key,
    required this.headline,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.grey.shade600 : Colors.grey.shade400;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.xl, vertical: Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            PhosphorIcon(
              PhosphorIcons.shoppingCartDuotone,
              size: 48,
              color: iconColor,
            ),
            const SizedBox(height: Spacing.xl),
            Text(headline, style: TextStyles.heading2),
            const SizedBox(height: Spacing.sm),
            Text(body, style: TextStyles.body),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Spacing.lg),
              TextButton(
                onPressed: onAction,
                child: Text(actionLabel!, style: TextStyles.bodySmall),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
