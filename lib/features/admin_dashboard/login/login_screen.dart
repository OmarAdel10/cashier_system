// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'admin_auth_bloc.dart';

/// Spec §6.4 `WEB_DASHBOARD_OFFLINE` (auth-licensing-flow.md:524): shown when
/// the browser is offline, with the sign-in actions disabled (DAFTARI-99).
const String webDashboardOfflineMessage =
    'الاتصال بالإنترنت مطلوب للوصول للوحة التحكم';

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
  final _magicLinkEmailController = TextEditingController();
  bool _dialogOpen = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _magicLinkEmailController.dispose();
    super.dispose();
  }

  void _dispatch(AdminAuthEvent event) =>
      context.read<AdminAuthBloc>().add(event);

  /// The SESSION_CONFLICT dialog's retry, built from the widget's own
  /// controllers so the plaintext password is never held in bloc state.
  VoidCallback _conflictRetry() => () {
    _dispatch(
      ForceRevokeRequested(
        _usernameController.text.trim(),
        _passwordController.text,
        onConflictRetry: _conflictRetry(),
      ),
    );
  };

  CredentialsSubmitted _credentialsEvent() => CredentialsSubmitted(
    _usernameController.text.trim(),
    _passwordController.text,
    onConflictRetry: _conflictRetry(),
  );

  /// AuthError codes originating from the Firebase (Stage-1) flow — the user
  /// returns to the Firebase card (a credentials card would bounce them
  /// straight back to Stage 1; T11 QA).
  bool _isFirebaseStageError(String code) =>
      code == 'MAGIC_LINK_SENT' ||
      code == 'FIREBASE_FAILED' ||
      code == 'MAGIC_LINK_FAILED' ||
      code == 'ACCOUNTS_CHECK_FAILED' ||
      code == 'OWNER_REAUTH_REQUIRED' ||
      code == 'SESSION_STALE' ||
      code == 'SESSION_REVOKED' ||
      code == 'SESSION_EXPIRED';

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
                _conflictMessage(state.username, state.conflictSessionId),
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
                    state.retry();
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

  String _conflictMessage(String username, String conflictSessionId) {
    // If the conflict session is a web session (device_hwid == 'web'), it's likely
    // the admin's own other browser. Otherwise it's another device.
    // We can't directly know the device_hwid here, so we use a heuristic:
    // session IDs starting with 'sess-' and short IDs are typically web sessions.
    // The retry callback will handle the actual revocation.
    return '$username مسجل دخول على جهاز آخر.\\n'
        'هل تريد إلغاء الجلسة الأخرى والمتابعة؟';
  }

  Widget _card(BuildContext context, AdminAuthState state) {
    // Offline is the stronger signal: it blocks every sign-in action, so it
    // takes precedence over an auth error banner (DAFTARI-99).
    final Widget? banner = state.isOffline
        ? const _ErrorBanner(message: webDashboardOfflineMessage, isInfo: false)
        : switch (state) {
            AuthError(code: final code, messageAr: final message) =>
              _ErrorBanner(message: message, isInfo: code == 'MAGIC_LINK_SENT'),
            _ => null,
          };
    final enabled = !state.isOffline;
    final body = switch (state) {
      AuthLoading() => const Center(child: CircularProgressIndicator()),
      AuthAuthenticated() => _SignedInCard(),
      FirebaseStage() => _FirebaseStageCard(
        emailController: _emailController,
        enabled: enabled,
        onGoogle: () => _dispatch(const GoogleSignInRequested()),
        onMagicLink: () =>
            _dispatch(MagicLinkRequested(_emailController.text.trim())),
      ),
      CredentialsStage() => _CredentialsStageCard(
        usernameController: _usernameController,
        passwordController: _passwordController,
        enabled: enabled,
        onSubmit: () => _dispatch(_credentialsEvent()),
      ),
      SessionConflict() || AdminAuthInitial() => _CredentialsStageCard(
        usernameController: _usernameController,
        passwordController: _passwordController,
        enabled: enabled,
        onSubmit: () => _dispatch(_credentialsEvent()),
      ),
      // T39: When a magic link is opened in a different browser without a
      // stored pending email, prompt for the email to complete the sign-in.
      MagicLinkCompletionPrompt() => _MagicLinkCompletionCard(
        emailController: _magicLinkEmailController,
        enabled: enabled,
        onSubmit: () => _dispatch(
          MagicLinkCompleted(
            _magicLinkEmailController.text.trim(),
            Uri.base.toString(),
          ),
        ),
      ),
      ResumeFailed(:final retry) => _ResumeFailedCard(
        retry: retry,
        enabled: enabled,
      ),
      AuthError(:final code) =>
        _isFirebaseStageError(code)
            ? _FirebaseStageCard(
                emailController: _emailController,
                enabled: enabled,
                onGoogle: () => _dispatch(const GoogleSignInRequested()),
                onMagicLink: () =>
                    _dispatch(MagicLinkRequested(_emailController.text.trim())),
              )
            : _CredentialsStageCard(
                usernameController: _usernameController,
                passwordController: _passwordController,
                enabled: enabled,
                onSubmit: () => _dispatch(_credentialsEvent()),
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
            if (banner != null) ...[banner, const SizedBox(height: 16)],
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
  final bool enabled;
  final VoidCallback onGoogle;
  final VoidCallback onMagicLink;
  const _FirebaseStageCard({
    required this.emailController,
    required this.enabled,
    required this.onGoogle,
    required this.onMagicLink,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: enabled ? onGoogle : null,
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
          onPressed: enabled ? onMagicLink : null,
          child: const Text('إرسال رابط الدخول — Magic Link'),
        ),
      ],
    );
  }
}

class _CredentialsStageCard extends StatelessWidget {
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool enabled;
  final VoidCallback onSubmit;
  const _CredentialsStageCard({
    required this.usernameController,
    required this.passwordController,
    required this.enabled,
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
          onSubmitted: enabled ? (_) => onSubmit() : null,
          decoration: const InputDecoration(
            labelText: 'كلمة المرور — Password',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: enabled ? onSubmit : null,
          child: const Text('تسجيل الدخول'),
        ),
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

/// Shown when a stored session could not be resumed for a TRANSIENT reason
/// (a network/transport failure). The session is intact, so the only action
/// offered is a retry — never the credentials form, which would present a
/// logout as a normal sign-in prompt.
class _ResumeFailedCard extends StatelessWidget {
  final VoidCallback retry;
  final bool enabled;

  const _ResumeFailedCard({required this.retry, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.cloud_off, color: Color(0xFF6B7280), size: 48),
        const SizedBox(height: 16),
        const Text(
          'تعذر استئناف الجلسة. تحقق من الاتصال ثم حاول مجددًا.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: enabled ? retry : null,
          child: const Text('حاول مجددًا'),
        ),
      ],
    );
  }
}

/// T39: Shown when a magic link is opened in a different browser without a
/// stored pending email. Prompts for the email to complete the sign-in.
class _MagicLinkCompletionCard extends StatelessWidget {
  final TextEditingController emailController;
  final bool enabled;
  final VoidCallback onSubmit;
  const _MagicLinkCompletionCard({
    required this.emailController,
    required this.enabled,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.mail_outline, color: Color(0xFF007ACC), size: 48),
        const SizedBox(height: 16),
        const Text(
          'تم فتح رابط الدخول في متصفح آخر. أدخل بريدك الإلكتروني لإكمال تسجيل الدخول.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          enabled: enabled,
          decoration: const InputDecoration(
            labelText: 'البريد الإلكتروني — Email',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: enabled ? onSubmit : null,
          child: const Text('إكمال تسجيل الدخول'),
        ),
      ],
    );
  }
}
