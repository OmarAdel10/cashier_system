import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/validated_field.dart';
import '../../../../features/settings/data/services/localization_service.dart';
import '../../../../features/settings/presentation/bloc/settings_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) return;
    context.read<AuthBloc>().add(LoginRequested(username, password));
  }

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.watch<SettingsBloc>().state.settings.languageCode;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state.status == AuthStatus.loading;

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 400),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: child,
                );
              },
              child: SizedBox(
                width: 360,
                child: SectionCard(
                  padding: const EdgeInsets.all(Spacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        PhosphorIcons.userCircle,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: Spacing.md),
                      Text(t.translate('auth.login', languageCode: langCode), style: TextStyles.heading2),
                      const SizedBox(height: Spacing.lg),
                      if (state.failure != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(Spacing.sm),
                          margin: const EdgeInsets.only(bottom: Spacing.md),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              PhosphorIcon(
                                PhosphorIcons.warningCircle,
                                size: 16,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(width: Spacing.sm),
                              Expanded(
                                child: Text(
                                  state.failure!.message,
                                  style: TextStyles.bodySmall.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ValidatedField(
                        controller: _usernameController,
                        label: t.translate('auth.username', languageCode: langCode),
                        hint: t.translate('auth.username.hint', languageCode: langCode),
                        rules: [
                          ValidatedFieldRule(
                            message: t.translate('validation.username.required', languageCode: langCode),
                            isValid: (v) => v.trim().isNotEmpty,
                          ),
                        ],
                        prefixIcon: const PhosphorIcon(PhosphorIcons.user),
                      ),
                      const SizedBox(height: Spacing.md),
                      ValidatedField(
                        controller: _passwordController,
                        label: t.translate('auth.password', languageCode: langCode),
                        hint: t.translate('auth.password.hint', languageCode: langCode),
                        obscureText: _obscurePassword,
                        rules: [
                          ValidatedFieldRule(
                            message: t.translate('validation.password.required', languageCode: langCode),
                            isValid: (v) => v.isNotEmpty,
                          ),
                        ],
                        prefixIcon: const PhosphorIcon(PhosphorIcons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? PhosphorIcons.eye
                                : PhosphorIcons.eyeSlash,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        isLast: true,
                        onLastFieldSubmit: _login,
                      ),
                      const SizedBox(height: Spacing.lg),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _login,
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(t.translate('auth.signIn', languageCode: langCode), style: TextStyles.title),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
