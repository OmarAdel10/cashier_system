import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/business/business_type.dart';
import '../../../../core/business/business_type_registry.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/presentation/bloc/settings_event.dart';
import '../bloc/onboarding_bloc.dart';
import '../bloc/onboarding_event.dart';

class OnboardingBusinessTypeScreen extends StatelessWidget {
  const OnboardingBusinessTypeScreen({super.key});

  static final _localizationService = LocalizationService();

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );
    final theme = Theme.of(context);
    final selected = context.select<OnboardingBloc, BusinessType?>(
      (b) => b.state.businessType,
    );
    final t = _localizationService;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: SizedBox(
          width: 580,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 620),
            child: SingleChildScrollView(
              child: SectionCard(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.translate(
                        'onboarding.businessType.title',
                        languageCode: langCode,
                      ),
                      style: TextStyles.heading2,
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      t.translate(
                        'onboarding.businessType.subtitle',
                        languageCode: langCode,
                      ),
                      style: TextStyles.bodySmall,
                    ),
                    const SizedBox(height: Spacing.lg),
GridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: Spacing.md,
                    crossAxisSpacing: Spacing.md,
                    shrinkWrap: true,
                    childAspectRatio: 1.5,
                    physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (final type in BusinessType.values)
                          Builder(
                            builder: (context) {
                              final meta = BusinessTypeRegistry.metadata[type]!;
                              return _BusinessTypeTile(
                                icon: meta.icon,
                                label: t.translate(
                                  meta.labelKey,
                                  languageCode: langCode,
                                ),
                                selected: selected == type,
                                onTap: () {
                                  context.read<SettingsBloc>().add(
                                    BusinessTypeChanged(type.name),
                                  );
                                  context.read<OnboardingBloc>().add(
                                    OnboardingSelectBusinessType(type),
                                  );
                                },
                              );
                            },
                          ),
                      ],
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
                                  'onboarding.businessType.back',
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
                              onPressed: selected == null
                                  ? null
                                  : () => context.read<OnboardingBloc>().add(
                                      const OnboardingNextStep(),
                                    ),
                              child: Text(
                                t.translate(
                                  'onboarding.businessType.next',
                                  languageCode: langCode,
                                ),
                                style: TextStyles.title,
                              ),
                            ),
                          ),
                        ),
                      ],
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

class _BusinessTypeTile extends StatelessWidget {
  const _BusinessTypeTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Spacing.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 156,
        padding: const EdgeInsets.symmetric(
          vertical: Spacing.md,
          horizontal: Spacing.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Spacing.sm),
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerLow,
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(icon, size: 32, color: color),
            const SizedBox(height: Spacing.xs),
            Text(
              label,
              style: TextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
