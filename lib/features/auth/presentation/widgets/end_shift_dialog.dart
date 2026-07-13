import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';

class EndShiftDialog extends StatelessWidget {
  const EndShiftDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('End Shift', style: TextStyles.heading3),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(
            PhosphorIcons.warning,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: Spacing.sm),
          Text('Are you sure you want to end your shift?', style: TextStyles.body),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancel', style: TextStyles.body),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text('End Shift', style: TextStyles.body),
        ),
      ],
    );
  }
}
