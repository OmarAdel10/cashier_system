import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/text_styles.dart';
import '../../../../features/settings/data/services/localization_service.dart';
import '../../../../features/settings/presentation/bloc/settings_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'change_password_dialog_actions.dart';
import 'change_password_dialog_form.dart';

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
  late final ValueNotifier<bool> _submittingNotifier;

  @override
  void initState() {
    super.initState();
    _submittingNotifier = ValueNotifier(false);
  }

  @override
  void dispose() {
    _submittingNotifier.dispose();
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

    _submittingNotifier.value = true;
    context.read<AuthBloc>().add(ChangePassword(widget.username, current, newPw));
  }

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.select((SettingsBloc b) => b.state.settings.languageCode);

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (!_submittingNotifier.value) return;
        if (state.failure != null && state.status != AuthStatus.loading) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.failure!.message)),
          );
          _submittingNotifier.value = false;
          return;
        }
        if (state.status != AuthStatus.loading && state.failure == null) {
          _submittingNotifier.value = false;
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
          child: ChangePasswordDialogForm(
            currentController: _currentController,
            newController: _newController,
            confirmController: _confirmController,
            showCurrent: widget.username == context.read<AuthBloc>().state.user?.username,
            langCode: langCode,
          ),
        ),
        actions: [
          ...ChangePasswordDialogActions(
            onCancel: () => Navigator.of(context).pop(),
            onChange: _change,
            submittingNotifier: _submittingNotifier,
            langCode: langCode,
          ).build(context),
        ],
      ),
    );
  }
}
