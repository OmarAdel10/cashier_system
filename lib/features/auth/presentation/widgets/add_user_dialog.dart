import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/validated_field.dart';
import '../../../../features/settings/data/services/localization_service.dart';
import '../../../../features/settings/presentation/bloc/settings_bloc.dart';
import '../../domain/entities/user_role.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class AddUserDialog extends StatefulWidget {
  const AddUserDialog({super.key});

  @override
  State<AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  late final ValueNotifier<UserRole> _selectedRoleNotifier;
  late final ValueNotifier<bool> _submittingNotifier;

  @override
  void initState() {
    super.initState();
    _selectedRoleNotifier = ValueNotifier(UserRole.cashier);
    _submittingNotifier = ValueNotifier(false);
  }

  @override
  void dispose() {
    _selectedRoleNotifier.dispose();
    _submittingNotifier.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _add() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.length < 8) return;
    _submittingNotifier.value = true;
    context.read<AuthBloc>().add(CreateUser(username, password, _selectedRoleNotifier.value));
  }

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.select((SettingsBloc b) => b.state.settings.languageCode);

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (!_submittingNotifier.value) return;
        if (state.status == AuthStatus.loading) return;
        if (state.failure != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.failure!.message)),
          );
          _submittingNotifier.value = false;
          return;
        }
        _submittingNotifier.value = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) Navigator.of(context).pop();
        });
      },
      child: AlertDialog(
        title: Text(t.translate('auth.addUser', languageCode: langCode), style: TextStyles.heading3),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValidatedField(
                controller: _usernameController,
                label: t.translate('auth.username', languageCode: langCode),
                hint: t.translate('auth.username.hint', languageCode: langCode),
                rules: [
                  ValidatedFieldRule(
                    message: t.translate('validation.username.required', languageCode: langCode),
                    isValid: (v) => v.trim().isNotEmpty,
                  ),
                ],
                prefixIcon: const PhosphorIcon(PhosphorIcons.user),
              ),
              const SizedBox(height: Spacing.md),
              ValidatedField(
                controller: _passwordController,
                obscureText: true,
                label: t.translate('auth.password', languageCode: langCode),
                hint: t.translate('auth.password.hint', languageCode: langCode),
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
                valueListenable: _selectedRoleNotifier,
                builder: (context, selectedRole, _) {
                  return Row(
                    children: [
                      Text('${t.translate('auth.role', languageCode: langCode)} ', style: TextStyles.body),
                      const SizedBox(width: Spacing.sm),
                      Flexible(
                        child: SegmentedButton<UserRole>(
                          segments: [
                            ButtonSegment(value: UserRole.cashier, label: Text(t.translate('auth.role.cashier', languageCode: langCode))),
                            ButtonSegment(value: UserRole.admin, label: Text(t.translate('auth.role.admin', languageCode: langCode))),
                          ],
                          selected: {selectedRole},
                          onSelectionChanged: (v) => _selectedRoleNotifier.value = v.first,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.translate('cancel', languageCode: langCode), style: TextStyles.body),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _submittingNotifier,
            builder: (context, submitting, _) {
              return FilledButton(
                onPressed: submitting ? null : _add,
                child: submitting
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(t.translate('auth.add', languageCode: langCode), style: TextStyles.body),
              );
            },
          ),
        ],
      ),
    );
  }
}