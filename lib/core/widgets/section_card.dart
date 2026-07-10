import 'package:flutter/material.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

class SectionCard extends StatelessWidget {
  final String? title;
  final List<Widget>? actions;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final MainAxisSize mainAxisSize;
  final FlexFit childFit;

  const SectionCard({
    super.key,
    this.title,
    this.actions,
    required this.child,
    this.padding,
    this.mainAxisSize = MainAxisSize.min,
    this.childFit = FlexFit.tight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectivePadding = padding ?? const EdgeInsets.all(Spacing.md);

    final cardChild = title != null && mainAxisSize == MainAxisSize.max
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: mainAxisSize,
            children: [
              Flexible(fit: childFit, child: child),
            ],
          )
        : child;

    final card = Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      color: theme.colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.all(Spacing.sm),
      child: Padding(
        padding: title != null
            ? effectivePadding.add(const EdgeInsets.only(top: Spacing.md + 4))
            : effectivePadding,
        child: cardChild,
      ),
    );

    if (title == null) return card;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        PositionedDirectional(
          start: Spacing.md,
          top: -10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
            color: theme.colorScheme.surface,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(child: Text(title!, style: TextStyles.heading3)),
                if (actions != null) ...[
                  const SizedBox(width: Spacing.sm),
                  ...actions!,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
