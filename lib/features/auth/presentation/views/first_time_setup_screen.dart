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

class FirstTimeSetupScreen extends StatefulWidget {
  const FirstTimeSetupScreen({super.key});

  @override
  State<FirstTimeSetupScreen> createState() => _FirstTimeSetupScreenState();
}

class _FirstTimeSetupScreenState extends State<FirstTimeSetupScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _localError;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final t = LocalizationService();
    final langCode = context.read<SettingsBloc>().state.settings.languageCode;
    final pw = _passwordController.text;
    if (pw.length < 8) {
      setState(() => _localError = t.translate('validation.password.minLength', languageCode: langCode));
      return;
    }
    if (_confirmController.text != pw) {
      setState(() => _localError = t.translate('validation.password.mismatch', languageCode: langCode));
      return;
    }
    setState(() => _localError = null);
    context.read<AuthBloc>().add(CompleteAdminSetup(pw));
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
                        PhosphorIcons.lock,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: Spacing.md),
                      Text(t.translate('auth.adminSetup.title', languageCode: langCode), style: TextStyles.heading2),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        t.translate('auth.adminSetup.subtitle', languageCode: langCode),
                        style: TextStyles.bodySmall,
                      ),
                      const SizedBox(height: Spacing.lg),
                      if (_localError != null || state.failure != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(Spacing.sm),
                          margin: const EdgeInsets.only(bottom: Spacing.md),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  PhosphorIcon(
                                    PhosphorIcons.warningCircle,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  const SizedBox(width: Spacing.sm),
                                  Expanded(
                                    child: Text(
                                      _localError ?? state.failure!.message,
                                      style: TextStyles.bodySmall.copyWith(
                                        color: Theme.of(context).colorScheme.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (state.failure != null) ...[
                                const SizedBox(height: Spacing.sm),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => context.read<AuthBloc>().add(const RetrySetup()),
                                    icon: const PhosphorIcon(PhosphorIcons.arrowClockwise, size: 16),
                                    label: Text('Retry'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ValidatedField(
                        controller: _passwordController,
                        label: t.translate('auth.password', languageCode: langCode),
                        hint: t.translate('auth.adminSetup.password.hint', languageCode: langCode),
                        obscureText: _obscurePassword,
                        rules: [
                          ValidatedFieldRule(
                            message: t.translate('validation.password.minLength', languageCode: langCode),
                            isValid: (v) => v.length >= 8,
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
                      ),
                      const SizedBox(height: Spacing.md),
                      ValidatedField(
                        controller: _confirmController,
                        label: t.translate('auth.confirmPassword', languageCode: langCode),
                        hint: t.translate('auth.confirmPassword.hint', languageCode: langCode),
                        obscureText: _obscureConfirm,
                        rules: [
                          ValidatedFieldRule(
                            message: t.translate('validation.password.mismatch', languageCode: langCode),
                            isValid: (v) => v == _passwordController.text,
                          ),
                        ],
                        prefixIcon: const PhosphorIcon(PhosphorIcons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? PhosphorIcons.eye
                                : PhosphorIcons.eyeSlash,
                          ),
                          onPressed: () =>
                              setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
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
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(t.translate('auth.adminSetup.complete', languageCode: langCode), style: TextStyles.title),
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
