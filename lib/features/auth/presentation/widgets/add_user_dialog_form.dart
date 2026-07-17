import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/validated_field.dart';
import '../../../../features/settings/data/services/localization_service.dart';
import '../../domain/entities/user_role.dart';

class AddUserDialogForm extends StatelessWidget {
  const AddUserDialogForm({
    super.key,
    required this.usernameController,
    required this.passwordController,
    required this.selectedRoleNotifier,
    required this.langCode,
  });

  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final ValueNotifier<UserRole> selectedRoleNotifier;
  final String langCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValidatedField(
          controller: usernameController,
          label: LocalizationService().translate('auth.username', languageCode: langCode),
          hint: LocalizationService().translate('auth.username.hint', languageCode: langCode),
          rules: [
            ValidatedFieldRule(
              message: LocalizationService().translate('validation.username.required', languageCode: langCode),
              isValid: (v) => v.trim().isNotEmpty,
            ),
          ],
          prefixIcon: const PhosphorIcon(PhosphorIcons.user),
        ),
        const SizedBox(height: Spacing.md),
        ValidatedField(
          controller: passwordController,
          obscureText: true,
          label: LocalizationService().translate('auth.password', languageCode: langCode),
          hint: LocalizationService().translate('auth.password.hint', languageCode: langCode),
          rules: [
            ValidatedFieldRule(
              message: 'Password must be at least 8 characters',
              isValid: (v) => v.length >= 8,
            ),
          ],
          prefixIcon: const PhosphorIcon(PhosphorIcons.lock),
        ),
        const SizedBox(height: Spacing.md),
        ValueListenableBuilder<UserRole>(
          valueListenable: selectedRoleNotifier,
          builder: (context, selectedRole, _) {
            return Row(
              children: [
                Text('${LocalizationService().translate('auth.role', languageCode: langCode)} ', style: TextStyles.body),
                const SizedBox(width: Spacing.sm),
                Flexible(
                  child: SegmentedButton<UserRole>(
                    segments: [
                      ButtonSegment(value: UserRole.cashier, label: Text(LocalizationService().translate('auth.role.cashier', languageCode: langCode))),
                      ButtonSegment(value: UserRole.admin, label: Text(LocalizationService().translate('auth.role.admin', languageCode: langCode))),
                    ],
                    selected: {selectedRole},
                    onSelectionChanged: (v) => selectedRoleNotifier.value = v.first,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
