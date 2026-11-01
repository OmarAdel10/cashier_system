import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/validated_field.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/widgets/inline_error_banner.dart';
import '../../../auth/presentation/widgets/obscured_field.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../bloc/onboarding_bloc.dart';
import '../bloc/onboarding_event.dart';

class OnboardingSetupScreen extends StatefulWidget {
  const OnboardingSetupScreen({super.key});

  @override
  State<OnboardingSetupScreen> createState() => _OnboardingSetupScreenState();
}

class _OnboardingSetupScreenState extends State<OnboardingSetupScreen> {
  static final _localizationService = LocalizationService();

  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _localErrorNotifier = ValueNotifier<String?>(null);

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _localErrorNotifier.dispose();
    super.dispose();
  }

  void _submit() {
    final langCode = context.read<SettingsBloc>().state.settings.languageCode;
    final pw = _passwordController.text;
    if (pw.length < 8) {
      _localErrorNotifier.value = _localizationService.translate(
        'validation.password.minLength',
        languageCode: langCode,
      );
      return;
    }
    if (_confirmController.text != pw) {
      _localErrorNotifier.value = _localizationService.translate(
        'validation.password.mismatch',
        languageCode: langCode,
      );
      return;
    }
    _localErrorNotifier.value = null;
    context.read<AuthBloc>().add(CompleteAdminSetup(pw));
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
                        PhosphorIcons.lock,
                        size: 64,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: Spacing.md),
                      Text(
                        _localizationService.translate(
                          'onboarding.adminSetup.title',
                          languageCode: langCode,
                        ),
                        style: TextStyles.heading2,
                      ),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        _localizationService.translate(
                          'onboarding.adminSetup.subtitle',
                          languageCode: langCode,
                        ),
                        style: TextStyles.bodySmall,
                      ),
                      const SizedBox(height: Spacing.lg),
                      ValueListenableBuilder<String?>(
                        valueListenable: _localErrorNotifier,
                        builder: (context, localError, _) {
                          if (localError == null && state.failure == null) {
                            return const SizedBox.shrink();
                          }
                          final message = localError ?? state.failure!.message;
                          final onRetry = state.failure != null
                              ? () => context.read<AuthBloc>().add(
                                  const RetrySetup(),
                                )
                              : null;
                          return InlineErrorBanner(
                            message: message,
                            onRetry: onRetry,
                            langCode: langCode,
                          );
                        },
                      ),
                      ObscuredField(
                        controller: _passwordController,
                        label: _localizationService.translate(
                          'auth.password',
                          languageCode: langCode,
                        ),
                        hint: _localizationService.translate(
                          'onboarding.adminSetup.password.hint',
                          languageCode: langCode,
                        ),
                        rules: [
                          ValidatedFieldRule(
                            message: _localizationService.translate(
                              'validation.password.minLength',
                              languageCode: langCode,
                            ),
                            isValid: (v) => v.length >= 8,
                          ),
                        ],
                        prefixIcon: const PhosphorIcon(PhosphorIcons.lock),
                      ),
                      const SizedBox(height: Spacing.md),
                      ObscuredField(
                        controller: _confirmController,
                        label: _localizationService.translate(
                          'auth.confirmPassword',
                          languageCode: langCode,
                        ),
                        hint: _localizationService.translate(
                          'auth.confirmPassword.hint',
                          languageCode: langCode,
                        ),
                        rules: [
                          ValidatedFieldRule(
                            message: _localizationService.translate(
                              'validation.password.mismatch',
                              languageCode: langCode,
                            ),
                            isValid: (v) => v == _passwordController.text,
                          ),
                        ],
                        prefixIcon: const PhosphorIcon(PhosphorIcons.lock),
                        isLast: true,
                        onLastFieldSubmit: _submit,
                      ),
                      const SizedBox(height: Spacing.lg),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _submit,
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
                                    'onboarding.adminSetup.complete',
                                    languageCode: langCode,
                                  ),
                                  style: TextStyles.title,
                                ),
                        ),
                      ),
                      const SizedBox(height: Spacing.sm),
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () => context.read<OnboardingBloc>().add(
                                const OnboardingPreviousStep(),
                              ),
                        child: Text(
                          _localizationService.translate(
                            'onboarding.setup.back',
                            languageCode: langCode,
                          ),
                          style: TextStyles.bodySmall,
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
