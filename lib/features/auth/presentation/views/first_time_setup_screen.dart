import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/validated_field.dart';
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
    final pw = _passwordController.text;
    if (pw.length < 8) {
      setState(() => _localError = 'Password must be at least 8 characters');
      return;
    }
    if (_confirmController.text != pw) {
      setState(() => _localError = 'Passwords do not match');
      return;
    }
    setState(() => _localError = null);
    context.read<AuthBloc>().add(CompleteAdminSetup(pw));
  }

  @override
  Widget build(BuildContext context) {
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
                      Text('Set Admin Password', style: TextStyles.heading2),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        'Choose a password for the admin account',
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
                                  _localError ?? state.failure!.message,
                                  style: TextStyles.bodySmall.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ValidatedField(
                        controller: _passwordController,
                        label: 'Password',
                        hint: 'At least 8 characters',
                        obscureText: _obscurePassword,
                        rules: [
                          ValidatedFieldRule(
                            message: 'Min 8 characters',
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
                        label: 'Confirm Password',
                        hint: 'Re-enter password',
                        obscureText: _obscureConfirm,
                        rules: [
                          ValidatedFieldRule(
                            message: 'Passwords must match',
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
                              : Text('Complete Setup', style: TextStyles.title),
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
