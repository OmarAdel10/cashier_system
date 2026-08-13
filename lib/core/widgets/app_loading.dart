import 'package:flutter/material.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

class AppLoading extends StatelessWidget {
  final String message;

  const AppLoading({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.xl,
          vertical: Spacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(message, style: TextStyles.body),
            const SizedBox(height: Spacing.sm),
            const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      ),
    );
  }
}
