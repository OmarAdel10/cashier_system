import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../features/settings/data/services/localization_service.dart';

class ChangePasswordDialogForm extends StatelessWidget {
  const ChangePasswordDialogForm({
    super.key,
    required this.currentController,
    required this.newController,
    required this.confirmController,
    required this.showCurrent,
    required this.langCode,
  });

  final TextEditingController currentController;
  final TextEditingController newController;
  final TextEditingController confirmController;
  final bool showCurrent;
  final String langCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showCurrent)
          Column(
            children: [
              TextField(
                controller: currentController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: LocalizationService().translate(
                    'auth.currentPassword',
                    languageCode: langCode,
                  ),
                  prefixIcon: const PhosphorIcon(PhosphorIcons.lock),
                  border: const OutlineInputBorder(),
                ),
              ),
              SizedBox(height: Spacing.md),
            ],
          ),
        TextField(
          controller: newController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: LocalizationService().translate(
              'auth.newPassword',
              languageCode: langCode,
            ),
            prefixIcon: const PhosphorIcon(PhosphorIcons.lockSimple),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: Spacing.md),
        TextField(
          controller: confirmController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: LocalizationService().translate(
              'auth.confirmNewPassword',
              languageCode: langCode,
            ),
            prefixIcon: const PhosphorIcon(PhosphorIcons.lockSimple),
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
