// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'admin_auth_bloc.dart';

/// The two-stage dashboard login (auth-licensing spec §1.3.2):
/// Stage 1 — Firebase (Google / magic link, owner, periodic);
/// Stage 2 — username/password (daily, admin accounts).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _dialogOpen = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _dispatch(AdminAuthEvent event) =>
      context.read<AdminAuthBloc>().add(event);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminAuthBloc, AdminAuthState>(
      listener: (context, state) {
        if (state is SessionConflict && !_dialogOpen) {
          _dialogOpen = true;
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: const Text('تعارض جلسة'),
              content: Text(
                '${state.username} مسجل دخول على جهاز آخر.\n'
                'هل تريد إلغاء الجلسة الأخرى والمتابعة؟',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _dialogOpen = false;
                    Navigator.of(context).pop();
                    _dispatch(const LogoutRequested());
                  },
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () {
                    _dialogOpen = false;
                    Navigator.of(context).pop();
                    _dispatch(
                      ForceRevokeRequested(state.username, state.password),
                    );
                  },
                  child: const Text('إلغاء الجلسة الأخرى'),
                ),
              ],
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _card(context, state),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _card(BuildContext context, AdminAuthState state) {
    final errorBanner = switch (state) {
      AuthError(code: final code, messageAr: final message) => _ErrorBanner(
        message: message,
        isInfo: code == 'MAGIC_LINK_SENT',
      ),
      _ => null,
    };
    final body = switch (state) {
      AuthLoading() => const Center(child: CircularProgressIndicator()),
      AuthAuthenticated() => _SignedInCard(),
      FirebaseStage() => _FirebaseStageCard(
        emailController: _emailController,
        onGoogle: () => _dispatch(const GoogleSignInRequested()),
        onMagicLink: () =>
            _dispatch(MagicLinkRequested(_emailController.text.trim())),
      ),
      CredentialsStage() => _CredentialsStageCard(
        usernameController: _usernameController,
        passwordController: _passwordController,
        onSubmit: () => _dispatch(
          CredentialsSubmitted(
            _usernameController.text.trim(),
            _passwordController.text,
          ),
        ),
      ),
      SessionConflict() || AdminAuthInitial() => _CredentialsStageCard(
        usernameController: _usernameController,
        passwordController: _passwordController,
        onSubmit: () => _dispatch(
          CredentialsSubmitted(
            _usernameController.text.trim(),
            _passwordController.text,
          ),
        ),
      ),
      AuthError(:final code) =>
        code == 'MAGIC_LINK_SENT'
            ? _FirebaseStageCard(
                emailController: _emailController,
                onGoogle: () => _dispatch(const GoogleSignInRequested()),
                onMagicLink: () =>
                    _dispatch(MagicLinkRequested(_emailController.text.trim())),
              )
            : _CredentialsStageCard(
                usernameController: _usernameController,
                passwordController: _passwordController,
                onSubmit: () => _dispatch(
                  CredentialsSubmitted(
                    _usernameController.text.trim(),
                    _passwordController.text,
                  ),
                ),
              ),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'دفتري — لوحة التحكم',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (errorBanner != null) ...[
              errorBanner,
              const SizedBox(height: 16),
            ],
            body,
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final bool isInfo;
  const _ErrorBanner({required this.message, required this.isInfo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isInfo
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
            : Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isInfo
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _FirebaseStageCard extends StatelessWidget {
  final TextEditingController emailController;
  final VoidCallback onGoogle;
  final VoidCallback onMagicLink;
  const _FirebaseStageCard({
    required this.emailController,
    required this.onGoogle,
    required this.onMagicLink,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: onGoogle,
          icon: const Icon(Icons.login),
          label: const Text('المتابعة عبر جوجل — Sign in with Google'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'البريد الإلكتروني — Email',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onMagicLink,
          child: const Text('إرسال رابط الدخول — Magic Link'),
        ),
      ],
    );
  }
}

class _CredentialsStageCard extends StatelessWidget {
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final VoidCallback onSubmit;
  const _CredentialsStageCard({
    required this.usernameController,
    required this.passwordController,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: usernameController,
          decoration: const InputDecoration(
            labelText: 'اسم المستخدم — Username',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: passwordController,
          obscureText: true,
          onSubmitted: (_) => onSubmit(),
          decoration: const InputDecoration(
            labelText: 'كلمة المرور — Password',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onSubmit, child: const Text('تسجيل الدخول')),
      ],
    );
  }
}

class _SignedInCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 48),
        const SizedBox(height: 16),
        const Text('تم تسجيل الدخول', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () =>
              context.read<AdminAuthBloc>().add(const LogoutRequested()),
          child: const Text('تسجيل الخروج'),
        ),
      ],
    );
  }
}
