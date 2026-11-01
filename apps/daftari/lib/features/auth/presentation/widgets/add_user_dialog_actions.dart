import 'package:flutter/material.dart';

import '../../../../core/theme/text_styles.dart';
import '../../../../features/settings/data/services/localization_service.dart';

class AddUserDialogActions {
  const AddUserDialogActions({
    required this.onCancel,
    required this.onAdd,
    required this.submittingNotifier,
    required this.langCode,
  });

  final VoidCallback onCancel;
  final VoidCallback onAdd;
  final ValueNotifier<bool> submittingNotifier;
  final String langCode;

  List<Widget> build(BuildContext context) {
    return [
      TextButton(
        onPressed: onCancel,
        child: Text(
          LocalizationService().translate('cancel', languageCode: langCode),
          style: TextStyles.body,
        ),
      ),
      ValueListenableBuilder<bool>(
        valueListenable: submittingNotifier,
        builder: (context, submitting, _) {
          return FilledButton(
            onPressed: submitting ? null : onAdd,
            child: submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    LocalizationService().translate(
                      'auth.add',
                      languageCode: langCode,
                    ),
                    style: TextStyles.body,
                  ),
          );
        },
      ),
    ];
  }
}
