import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../features/settings/data/services/localization_service.dart';
import '../../../../features/settings/presentation/bloc/settings_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class ChangePasswordDialog extends StatefulWidget {
  final String username;
  const ChangePasswordDialog({super.key, required this.username});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _change() {
    final isSelf = widget.username == context.read<AuthBloc>().state.user?.username;
    final current = isSelf ? _currentController.text : '';
    final newPw = _newController.text;
    final confirm = _confirmController.text;

    if (isSelf && current.isEmpty) return;
    if (newPw.length < 8 || newPw != confirm) return;

    setState(() => _submitting = true);
    context.read<AuthBloc>().add(ChangePassword(widget.username, current, newPw));
  }

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.watch<SettingsBloc>().state.settings.languageCode;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (!_submitting) return;
        if (state.failure != null && state.status != AuthStatus.loading) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.failure!.message)),
          );
          setState(() => _submitting = false);
          return;
        }
        if (state.status != AuthStatus.loading && state.failure == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.translate('auth.passwordChanged.success', languageCode: langCode))),
          );
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: AlertDialog(
        title: Text(t.translate('auth.changePassword', languageCode: langCode), style: TextStyles.heading3),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.username == context.read<AuthBloc>().state.user?.username)
                Column(
                  children: [
                    TextField(
                      controller: _currentController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: t.translate('auth.currentPassword', languageCode: langCode),
                        prefixIcon: const PhosphorIcon(PhosphorIcons.lock),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: Spacing.md),
                  ],
                ),
              TextField(
                controller: _newController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: t.translate('auth.newPassword', languageCode: langCode),
                  prefixIcon: const PhosphorIcon(PhosphorIcons.lockSimple),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: Spacing.md),
              TextField(
                controller: _confirmController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: t.translate('auth.confirmNewPassword', languageCode: langCode),
                  prefixIcon: const PhosphorIcon(PhosphorIcons.lockSimple),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.translate('cancel', languageCode: langCode), style: TextStyles.body),
          ),
          FilledButton(
            onPressed: _submitting ? null : _change,
            child: _submitting
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t.translate('auth.change', languageCode: langCode), style: TextStyles.body),
          ),
        ],
      ),
    );
  }
}
