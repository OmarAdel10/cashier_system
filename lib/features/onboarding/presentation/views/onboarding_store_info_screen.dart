import 'package:flutter/material.dart';
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

class OnboardingStoreInfoScreen extends StatefulWidget {
  const OnboardingStoreInfoScreen({super.key});

  @override
  State<OnboardingStoreInfoScreen> createState() =>
      _OnboardingStoreInfoScreenState();
}

class _OnboardingStoreInfoScreenState extends State<OnboardingStoreInfoScreen> {
  static final _localizationService = LocalizationService();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncFromSettings();
  }

  void _syncFromSettings() {
    final s = context.read<SettingsBloc>().state.settings;
    _nameController.text = s.storeName;
    _addressController.text = s.storeAddress;
    _phoneController.text = s.storePhoneNumber;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

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
                  PhosphorIcons.storefront,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: Spacing.md),
                Text(
                  t.translate(
                    'onboarding.storeInfo.title',
                    languageCode: langCode,
                  ),
                  style: TextStyles.heading2,
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  t.translate(
                    'onboarding.storeInfo.subtitle',
                    languageCode: langCode,
                  ),
                  style: TextStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Spacing.lg),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: t.translate('storeName', languageCode: langCode),
                    hintText: t.translate(
                      'storeNameHint',
                      languageCode: langCode,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    context.read<SettingsBloc>().add(StoreNameChanged(value));
                  },
                ),
                const SizedBox(height: Spacing.md),
                TextField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: t.translate(
                      'storeAddress',
                      languageCode: langCode,
                    ),
                    hintText: t.translate(
                      'storeAddressHint',
                      languageCode: langCode,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    context.read<SettingsBloc>().add(
                      StoreAddressChanged(value),
                    );
                  },
                ),
                const SizedBox(height: Spacing.md),
                TextField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: t.translate(
                      'storePhone',
                      languageCode: langCode,
                    ),
                    hintText: t.translate(
                      'storePhoneHint',
                      languageCode: langCode,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    context.read<SettingsBloc>().add(
                      StorePhoneNumberChanged(value),
                    );
                  },
                ),
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
                              'onboarding.storeInfo.back',
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
                              'onboarding.storeInfo.next',
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
                      'onboarding.storeInfo.skip',
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
