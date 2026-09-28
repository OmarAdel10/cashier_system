// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'add_user_dialog.dart';
import 'users_bloc.dart';

/// The Users Management screen (spec §2.5.2: Professional = view + create;
/// the owner manages admins, any admin creates cashiers — §2.4).
class UsersView extends StatelessWidget {
  final bool isOwner;
  const UsersView({super.key, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UsersBloc, UsersState>(
      listener: (context, state) {
        if (state is UsersError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.messageAr)));
        }
      },
      builder: (context, state) {
        return switch (state) {
          UsersLoading() => const Center(child: CircularProgressIndicator()),
          UsersLoaded(:final users) => _UsersBody(
            users: users,
            isOwner: isOwner,
          ),
          UsersError() => const Center(child: Text('فشل التحميل')),
        };
      },
    );
  }
}

class _UsersBody extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final bool isOwner;
  const _UsersBody({required this.users, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'المستخدمون (${users.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => BlocProvider<UsersBloc>.value(
                    value: context.read<UsersBloc>(),
                    child: AddUserDialog(isOwner: isOwner),
                  ),
                ),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('إضافة مستخدم'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final u in users)
                ListTile(
                  leading: Icon(
                    u['role'] == 'admin'
                        ? Icons.admin_panel_settings_outlined
                        : Icons.point_of_sale_outlined,
                  ),
                  title: Text(
                    (u['display_name'] as String?)?.isNotEmpty == true
                        ? u['display_name']! as String
                        : u['username']! as String,
                  ),
                  subtitle: Text(
                    '${u['username']} · ${u['role'] == 'admin' ? 'أدمن' : 'كاشير'}'
                    '${u['is_active'] == 1 ? '' : ' · معطل'}',
                  ),
                  trailing: isOwner
                      ? PopupMenuButton<String>(
                          onSelected: (action) {
                            final bloc = context.read<UsersBloc>();
                            final username = u['username']! as String;
                            if (action == 'deactivate') {
                              bloc.add(UserDeleted(username));
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'deactivate',
                              child: Text('تعطيل'),
                            ),
                          ],
                        )
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
