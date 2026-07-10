import 'package:flutter/material.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

class SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final MainAxisSize mainAxisSize;

  const SectionCard({
    super.key,
    this.title,
    required this.child,
    this.padding,
    this.mainAxisSize = MainAxisSize.min,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectivePadding = padding ?? const EdgeInsets.all(Spacing.md);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      color: theme.colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.all(Spacing.sm),
      child: Padding(
        padding: effectivePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: mainAxisSize,
          children: [
            if (title != null) ...[
              Text(title!, style: TextStyles.heading3),
              const SizedBox(height: Spacing.sm),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
