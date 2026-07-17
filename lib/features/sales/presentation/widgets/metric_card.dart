import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';

class MetricCard extends StatelessWidget {
  final Object icon;
  final String label;
  final Widget child;

  const MetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            children: [
              PhosphorIcon(icon, size: 28),
              const SizedBox(height: Spacing.xs),
              Text(
                label,
                style: TextStyles.heading3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.xs),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
