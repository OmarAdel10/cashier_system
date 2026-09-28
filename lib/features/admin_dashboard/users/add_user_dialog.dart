// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'users_bloc.dart';

/// The Add User dialog (spec §2.3.3 form components): username (validated
/// against the api's regex), password (min 8), role SegmentedButton — the
/// OWNER sees admin/cashier; a session admin is locked to cashier
/// (spec §2.4: only the Firebase owner creates admins).
class AddUserDialog extends StatefulWidget {
  final bool isOwner;
  const AddUserDialog({super.key, required this.isOwner});

  @override
  State<AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController();
  String _role = 'cashier';
  String? _errorAr;

  static final _usernameRe = RegExp(r'^[a-zA-Z0-9_]{3,30}$');

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _displayName.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    final username = _username.text.trim();
    final password = _password.text;
    final displayName = _displayName.text.trim();
    if (!_usernameRe.hasMatch(username)) {
      setState(
        () => _errorAr = 'اسم المستخدم: 3-30 حرفًا إنجليزيًا/أرقامًا فقط.',
      );
      return;
    }
    if (password.length < 8) {
      setState(() => _errorAr = 'كلمة المرور: 8 أحرف على الأقل.');
      return;
    }
    context.read<UsersBloc>().add(
      UserCreated(
        username,
        password,
        _role,
        displayName.isEmpty ? null : displayName,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة مستخدم'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _username,
            decoration: const InputDecoration(labelText: 'اسم المستخدم'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'كلمة المرور'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _displayName,
            decoration: const InputDecoration(
              labelText: 'الاسم المعروض (اختياري)',
            ),
          ),
          const SizedBox(height: 12),
          if (widget.isOwner)
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'cashier', label: Text('كاشير')),
                ButtonSegment(value: 'admin', label: Text('أدمن')),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            )
          else
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'الدور: كاشير',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          if (_errorAr != null) ...[
            const SizedBox(height: 12),
            Text(_errorAr!, style: const TextStyle(color: Color(0xFFEF4444))),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => _submit(context),
          child: const Text('إضافة'),
        ),
      ],
    );
  }
}
