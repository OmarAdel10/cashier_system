import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/business/business_type.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/presentation/widgets/printing_section.dart';
import '../bloc/onboarding_bloc.dart';
import '../bloc/onboarding_event.dart';

class OnboardingPrintingScreen extends StatelessWidget {
  const OnboardingPrintingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );
    final theme = Theme.of(context);
    final t = LocalizationService();
    final mode = BusinessType.fromId(
      context.read<SettingsBloc>().state.settings.businessType,
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: SizedBox(
          width: 560,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 760),
            child: SingleChildScrollView(
              child: SectionCard(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.printer,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: Spacing.md),
                    Text(
                      t.translate(
                        'onboarding.printing.title',
                        languageCode: langCode,
                      ),
                      style: TextStyles.heading2,
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      t.translate(
                        'onboarding.printing.subtitle',
                        languageCode: langCode,
                      ),
                      style: TextStyles.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Spacing.lg),
                    PrintingSection(
                      showReceiptPrinter: mode.receiptsEnabled,
                      showBarcodePrinter: mode.barcodesEnabled,
                      isSettingsSection: false,
                    ),
                    const SizedBox(height: Spacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () => context
                                  .read<OnboardingBloc>()
                                  .add(const OnboardingPreviousStep()),
                              child: Text(
                                t.translate(
                                  'onboarding.printing.back',
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
                              onPressed: () => context
                                  .read<OnboardingBloc>()
                                  .add(const OnboardingNextStep()),
                              child: Text(
                                t.translate(
                                  'onboarding.printing.next',
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
                          'onboarding.printing.skip',
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
      ),
    );
  }
}
