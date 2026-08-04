import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';

class EndShiftDialog extends StatelessWidget {
  const EndShiftDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final langCode = context.watch<SettingsBloc>().state.settings.languageCode;
    final t = LocalizationService();

    return AlertDialog(
      title: Text(t.translate('shift.end', languageCode: langCode), style: TextStyles.heading3),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(
            PhosphorIcons.warning,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: Spacing.sm),
          Text(t.translate('shift.end.confirm', languageCode: langCode), style: TextStyles.body),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t.translate('cancel', languageCode: langCode), style: TextStyles.body),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(t.translate('shift.end', languageCode: langCode), style: TextStyles.body),
        ),
      ],
    );
  }
}
