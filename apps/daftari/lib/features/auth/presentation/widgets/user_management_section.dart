import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../features/settings/data/services/localization_service.dart';
import '../../../../features/settings/presentation/bloc/settings_bloc.dart';
import '../../domain/entities/user_entity.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_state.dart';
import 'add_user_dialog.dart';
import 'user_card.dart';

class UserManagementSection extends StatelessWidget {
  final UserEntity currentUser;

  const UserManagementSection({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.select(
      (SettingsBloc b) => b.state.settings.languageCode,
    );

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
                    Text(
                      t.translate(
                        'auth.userManagement',
                        languageCode: langCode,
                      ),
                      style: TextStyles.title,
                    ),
                    FilledButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => const AddUserDialog(),
                      ),
                      icon: const PhosphorIcon(PhosphorIcons.plus, size: 16),
                      label: Text(
                        t.translate('auth.addUser', languageCode: langCode),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  t.translate(
                    'auth.userManagement.subtitle',
                    languageCode: langCode,
                  ),
                  style: TextStyles.caption,
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
                  ...state.users.map(
                    (user) => UserCard(
                      user: user,
                      isSelf: user.username == currentUser.username,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
