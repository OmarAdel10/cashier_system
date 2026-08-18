import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/app_buttons.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../features/settings/data/services/localization_service.dart';

class EndShiftDialog extends StatelessWidget {
  final String langCode;
  const EndShiftDialog({super.key, required this.langCode});

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();

    return AlertDialog(
      title: Text(
        t.translate('shift.end', languageCode: langCode),
        style: TextStyles.heading3,
      ),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(
            PhosphorIcons.warning,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: Spacing.sm),
          Text(
            t.translate('shift.end.confirm', languageCode: langCode),
            style: TextStyles.body,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            t.translate('cancel', languageCode: langCode),
            style: TextStyles.body,
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: AppButtons.danger(Theme.of(context).colorScheme),
          child: Text(
            t.translate('shift.end', languageCode: langCode),
            style: TextStyles.body,
          ),
        ),
      ],
    );
  }
}
