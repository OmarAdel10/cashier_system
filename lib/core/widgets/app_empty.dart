import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

class AppEmpty extends StatelessWidget {
  final Object? icon;
  final String? headline;
  final String? body;
  final Widget? action;

  const AppEmpty({
    super.key,
    this.icon,
    this.headline,
    this.body,
    this.action,
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
              icon ?? PhosphorIcons.shoppingCartDuotone,
              size: 48,
              color: iconColor,
            ),
            if (headline != null) ...[
              const SizedBox(height: Spacing.xl),
              Text(headline!, style: TextStyles.heading2),
            ],
            if (body != null) ...[
              const SizedBox(height: Spacing.sm),
              Text(body!, style: TextStyles.body),
            ],
            if (action != null) ...[
              const SizedBox(height: Spacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
