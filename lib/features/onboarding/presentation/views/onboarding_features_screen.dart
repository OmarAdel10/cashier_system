import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../bloc/onboarding_bloc.dart';
import '../bloc/onboarding_event.dart';

class OnboardingFeaturesScreen extends StatelessWidget {
  const OnboardingFeaturesScreen({super.key});

  static final _localizationService = LocalizationService();

  static const _items = [
    (PhosphorIcons.basket, 'onboarding.features.item1.title', 'onboarding.features.item1.subtitle'),
    (PhosphorIcons.warehouse, 'onboarding.features.item2.title', 'onboarding.features.item2.subtitle'),
    (PhosphorIcons.chartBar, 'onboarding.features.item3.title', 'onboarding.features.item3.subtitle'),
  ];

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>((b) => b.state.settings.languageCode);
    final theme = Theme.of(context);

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
                Text(
                  _localizationService.translate('onboarding.features.title', languageCode: langCode),
                  style: TextStyles.heading2,
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  _localizationService.translate('onboarding.features.subtitle', languageCode: langCode),
                  style: TextStyles.bodySmall,
                ),
                const SizedBox(height: Spacing.lg),
                for (final (icon, titleKey, subtitleKey) in _items) ...[
                  Row(
                    children: [
                      PhosphorIcon(icon, size: 28, color: theme.colorScheme.primary),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _localizationService.translate(titleKey, languageCode: langCode),
                              style: TextStyles.title,
                            ),
                            const SizedBox(height: Spacing.xs),
                            Text(
                              _localizationService.translate(subtitleKey, languageCode: langCode),
                              style: TextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.lg),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.read<OnboardingBloc>().add(const OnboardingPreviousStep()),
                        child: Text(
                          _localizationService.translate('onboarding.features.back', languageCode: langCode),
                          style: TextStyles.title,
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => context.read<OnboardingBloc>().add(const OnboardingNextStep()),
                          child: Text(
                            _localizationService.translate('onboarding.features.next', languageCode: langCode),
                            style: TextStyles.title,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
                TextButton(
                  onPressed: () => context.read<OnboardingBloc>().add(const OnboardingSkipToSetup()),
                  child: Text(
                    _localizationService.translate('onboarding.features.skip', languageCode: langCode),
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
