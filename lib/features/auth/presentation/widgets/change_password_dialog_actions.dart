import 'package:flutter/material.dart';

import '../../../../core/theme/text_styles.dart';
import '../../../../features/settings/data/services/localization_service.dart';

class ChangePasswordDialogActions {
  const ChangePasswordDialogActions({
    required this.onCancel,
    required this.onChange,
    required this.submittingNotifier,
    required this.langCode,
  });

  final VoidCallback onCancel;
  final VoidCallback onChange;
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
            onPressed: submitting ? null : onChange,
            child: submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    LocalizationService().translate(
                      'auth.change',
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
