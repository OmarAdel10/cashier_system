import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../features/settings/data/services/localization_service.dart';
import '../../../../features/settings/presentation/bloc/settings_bloc.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/user_role.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import 'change_password_dialog.dart';

class UserCard extends StatelessWidget {
  final UserEntity user;
  final bool isSelf;

  const UserCard({super.key, required this.user, required this.isSelf});

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.select(
      (SettingsBloc b) => b.state.settings.languageCode,
    );
    final theme = Theme.of(context);

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
                    Text(
                      user.username,
                      style: TextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
                          t.translate('auth.you', languageCode: langCode),
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
                    builder: (_) =>
                        ChangePasswordDialog(username: user.username),
                  );
                case 'delete':
                  _deleteUser(context, user);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'changePassword',
                child: Row(
                  children: [
                    const PhosphorIcon(PhosphorIcons.key, size: 16),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      t.translate(
                        'auth.changePassword',
                        languageCode: langCode,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isSelf && user.role != UserRole.admin)
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const PhosphorIcon(PhosphorIcons.trash, size: 16),
                      const SizedBox(width: Spacing.sm),
                      Text(
                        t.translate(
                          'inventory.delete.btn',
                          languageCode: langCode,
                        ),
                      ),
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
    final t = LocalizationService();
    final langCode = context.read<SettingsBloc>().state.settings.languageCode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.translate('auth.deleteUser', languageCode: langCode)),
        content: Text(
          t.translate(
            'auth.deleteUser.confirm',
            languageCode: langCode,
            params: [user.username],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.translate('cancel', languageCode: langCode)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(
              t.translate('inventory.delete.btn', languageCode: langCode),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AuthBloc>().add(DeleteUser(user.username));
    }
  }
}
