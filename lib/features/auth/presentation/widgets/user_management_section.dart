import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../domain/entities/user_entity.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'add_user_dialog.dart';
import 'change_password_dialog.dart';

class UserManagementSection extends StatelessWidget {
  final UserEntity currentUser;

  const UserManagementSection({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('User Management', style: TextStyles.title),
                    FilledButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => const AddUserDialog(),
                      ),
                      icon: const PhosphorIcon(PhosphorIcons.plus, size: 16),
                      label: const Text('Add User'),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
                const Divider(),
                const SizedBox(height: Spacing.sm),
                if (state.status == AuthStatus.loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(Spacing.lg),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  ...state.users.map((user) => _UserCard(
                    user: user,
                    isSelf: user.username == currentUser.username,
                    theme: theme,
                  )),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserEntity user;
  final bool isSelf;
  final ThemeData theme;

  const _UserCard({
    required this.user,
    required this.isSelf,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          PhosphorIcon(
            PhosphorIcons.user,
            color: isSelf
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(user.username, style: TextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
                    if (isSelf) ...[
                      const SizedBox(width: Spacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'You',
                          style: TextStyles.caption.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  user.role.name,
                  style: TextStyles.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (action) {
              switch (action) {
                case 'changePassword':
                  showDialog(
                    context: context,
                    builder: (_) => ChangePasswordDialog(
                      username: user.username,
                    ),
                  );
                case 'delete':
                  _deleteUser(context, user);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'changePassword',
                child: Row(
                  children: [
                    PhosphorIcon(PhosphorIcons.key, size: 16),
                    SizedBox(width: Spacing.sm),
                    Text('Change Password'),
                  ],
                ),
              ),
              if (!isSelf)
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      PhosphorIcon(
                        PhosphorIcons.trash,
                        size: 16,
                      ),
                      SizedBox(width: Spacing.sm),
                      Text('Delete'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _deleteUser(BuildContext context, UserEntity user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Delete "${user.username}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AuthBloc>().add(DeleteUser(user.username));
    }
  }
}
