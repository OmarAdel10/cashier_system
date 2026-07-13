import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/validated_field.dart';
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
  UserRole _selectedRole = UserRole.cashier;
  bool _submitting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _add() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.length < 8) return;
    setState(() => _submitting = true);
    context.read<AuthBloc>().add(CreateUser(username, password, _selectedRole));
  }

  @override
  Widget build(BuildContext context) {
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
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: AlertDialog(
        title: Text('Add User', style: TextStyles.heading3),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValidatedField(
                controller: _usernameController,
                label: 'Username',
                hint: 'Enter username',
                rules: [
                  ValidatedFieldRule(
                    message: 'Username is required',
                    isValid: (v) => v.trim().isNotEmpty,
                  ),
                ],
                prefixIcon: const PhosphorIcon(PhosphorIcons.user),
              ),
              const SizedBox(height: Spacing.md),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: PhosphorIcon(PhosphorIcons.lock),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: Spacing.md),
              Row(
                children: [
                  Text('Role: ', style: TextStyles.body),
                  const SizedBox(width: Spacing.sm),
                  SegmentedButton<UserRole>(
                    segments: const [
                      ButtonSegment(value: UserRole.cashier, label: Text('Cashier')),
                      ButtonSegment(value: UserRole.admin, label: Text('Admin')),
                    ],
                    selected: {_selectedRole},
                    onSelectionChanged: (v) => setState(() => _selectedRole = v.first),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyles.body),
          ),
          FilledButton(
            onPressed: _submitting ? null : _add,
            child: _submitting
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Add', style: TextStyles.body),
          ),
        ],
      ),
    );
  }
}