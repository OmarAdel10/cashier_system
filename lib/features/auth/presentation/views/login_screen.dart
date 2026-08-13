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
import '../widgets/inline_error_banner.dart';
import '../widgets/obscured_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static final _localizationService = LocalizationService();

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

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
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );

    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (prev, curr) =>
          prev.status != curr.status || prev.failure != curr.failure,
      builder: (context, state) {
        final theme = Theme.of(context);
        final isLoading = state.status == AuthStatus.loading;

        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 400),
              builder: (context, value, child) {
                return Opacity(opacity: value, child: child);
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
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: Spacing.md),
                      Text(
                        _localizationService.translate(
                          'auth.login',
                          languageCode: langCode,
                        ),
                        style: TextStyles.heading2,
                      ),
                      const SizedBox(height: Spacing.lg),
                      if (state.failure != null)
                        InlineErrorBanner(
                          message: state.failure!.message,
                          langCode: langCode,
                        ),
                      ValidatedField(
                        controller: _usernameController,
                        label: _localizationService.translate(
                          'auth.username',
                          languageCode: langCode,
                        ),
                        hint: _localizationService.translate(
                          'auth.username.hint',
                          languageCode: langCode,
                        ),
                        rules: [
                          ValidatedFieldRule(
                            message: _localizationService.translate(
                              'validation.username.required',
                              languageCode: langCode,
                            ),
                            isValid: (v) => v.trim().isNotEmpty,
                          ),
                        ],
                        prefixIcon: const PhosphorIcon(PhosphorIcons.user),
                      ),
                      const SizedBox(height: Spacing.md),
                      ObscuredField(
                        controller: _passwordController,
                        label: _localizationService.translate(
                          'auth.password',
                          languageCode: langCode,
                        ),
                        hint: _localizationService.translate(
                          'auth.password.hint',
                          languageCode: langCode,
                        ),
                        rules: [
                          ValidatedFieldRule(
                            message: _localizationService.translate(
                              'validation.password.required',
                              languageCode: langCode,
                            ),
                            isValid: (v) => v.isNotEmpty,
                          ),
                        ],
                        prefixIcon: const PhosphorIcon(PhosphorIcons.lock),
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _localizationService.translate(
                                    'auth.signIn',
                                    languageCode: langCode,
                                  ),
                                  style: TextStyles.title,
                                ),
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
