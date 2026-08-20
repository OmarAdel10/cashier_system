import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/presentation/bloc/settings_event.dart';
import '../bloc/onboarding_bloc.dart';
import '../bloc/onboarding_event.dart';

class OnboardingPreferencesScreen extends StatelessWidget {
  const OnboardingPreferencesScreen({super.key});

  static final _localizationService = LocalizationService();

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );
    final theme = Theme.of(context);
    final t = _localizationService;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: SizedBox(
          width: 360,
          child: SectionCard(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PhosphorIcon(
                  PhosphorIcons.sliders,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: Spacing.md),
                Text(
                  t.translate(
                    'onboarding.preferences.title',
                    languageCode: langCode,
                  ),
                  style: TextStyles.heading2,
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  t.translate(
                    'onboarding.preferences.subtitle',
                    languageCode: langCode,
                  ),
                  style: TextStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Spacing.lg),
                _TaxPreferenceTile(),
                const SizedBox(height: Spacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => context.read<OnboardingBloc>().add(
                            const OnboardingPreviousStep(),
                          ),
                          child: Text(
                            t.translate(
                              'onboarding.preferences.back',
                              languageCode: langCode,
                            ),
                            style: TextStyles.title,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => context.read<OnboardingBloc>().add(
                            const OnboardingNextStep(),
                          ),
                          child: Text(
                            t.translate(
                              'onboarding.preferences.next',
                              languageCode: langCode,
                            ),
                            style: TextStyles.title,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
                TextButton(
                  onPressed: () => context.read<OnboardingBloc>().add(
                    const OnboardingSkipToSetup(),
                  ),
                  child: Text(
                    t.translate(
                      'onboarding.preferences.skip',
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
    );
  }
}

class _TaxPreferenceTile extends StatelessWidget {
  const _TaxPreferenceTile();

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );
    final taxEnabled = context.select<SettingsBloc, bool>(
      (b) => b.state.settings.taxEnabled,
    );
    final t = LocalizationService();

    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            t.translate('taxToggle', languageCode: langCode),
            style: TextStyles.body,
          ),
          subtitle: Text(
            t.translate('taxToggleSubtitle', languageCode: langCode),
            style: TextStyles.bodySmall,
          ),
          value: taxEnabled,
          onChanged: (v) {
            context.read<SettingsBloc>().add(TaxToggled(v));
          },
        ),
        if (taxEnabled) ...[
          const SizedBox(height: Spacing.md),
          const _TaxPercentField(),
        ],
      ],
    );
  }
}

class _TaxPercentField extends StatefulWidget {
  const _TaxPercentField();

  @override
  State<_TaxPercentField> createState() => _TaxPercentFieldState();
}

class _TaxPercentFieldState extends State<_TaxPercentField> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller.text = context
        .read<SettingsBloc>()
        .state
        .settings
        .taxPercent
        .toString();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );
    final taxPercent = context.select<SettingsBloc, int>(
      (b) => b.state.settings.taxPercent,
    );
    final t = LocalizationService();

    final pctStr = taxPercent.toString();
    if (_controller.text != pctStr) {
      _controller.text = pctStr;
    }

    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: t.translate('taxPercent', languageCode: langCode),
        hintText: t.translate('taxPercentHint', languageCode: langCode),
        suffixText: '%',
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), () {
          final pct = int.tryParse(v.trim()) ?? 0;
          if (pct >= 0 && pct <= 100) {
            context.read<SettingsBloc>().add(
              TaxPercentChanged(pct.clamp(0, 100)),
            );
          }
        });
      },
    );
  }
}
