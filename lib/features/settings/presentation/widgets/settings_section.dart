import 'package:flutter/material.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';

class SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsSection({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyles.title),
            SizedBox(height: Spacing.sm),
            const Divider(),
            SizedBox(height: Spacing.md),
            ...children,
          ],
        ),
      ),
    );
  }
}
