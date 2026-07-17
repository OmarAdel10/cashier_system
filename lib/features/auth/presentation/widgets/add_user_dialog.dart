import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/text_styles.dart';
import '../../../../features/settings/data/services/localization_service.dart';
import '../../../../features/settings/presentation/bloc/settings_bloc.dart';
import '../../domain/entities/user_role.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'add_user_dialog_actions.dart';
import 'add_user_dialog_form.dart';

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
          child: AddUserDialogForm(
            usernameController: _usernameController,
            passwordController: _passwordController,
            selectedRoleNotifier: _selectedRoleNotifier,
            langCode: langCode,
          ),
        ),
        actions: [
          ...AddUserDialogActions(
            onCancel: () => Navigator.of(context).pop(),
            onAdd: _add,
            submittingNotifier: _submittingNotifier,
            langCode: langCode,
          ).build(context),
        ],
      ),
    );
  }
}