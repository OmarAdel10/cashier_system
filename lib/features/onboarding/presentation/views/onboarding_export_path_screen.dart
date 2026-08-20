import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/export_path_validator.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/presentation/bloc/settings_event.dart';
import '../bloc/onboarding_bloc.dart';
import '../bloc/onboarding_event.dart';

class OnboardingExportPathScreen extends StatefulWidget {
  const OnboardingExportPathScreen({super.key});

  @override
  State<OnboardingExportPathScreen> createState() =>
      _OnboardingExportPathScreenState();
}

class _OnboardingExportPathScreenState
    extends State<OnboardingExportPathScreen> {
  static final _localizationService = LocalizationService();

  final _controller = TextEditingController();
  final _errorNotifier = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    _controller.text = context
        .read<SettingsBloc>()
        .state
        .settings
        .exportDirectoryPath;
  }

  @override
  void dispose() {
    _controller.dispose();
    _errorNotifier.dispose();
    super.dispose();
  }

  Future<void> _chooseFolder(String langCode) async {
    final t = LocalizationService();
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result == null || !mounted) return;
      final normalized = result.replaceAll('/', '\\');
      if (isValidExportPath(normalized)) {
        _errorNotifier.value = null;
        _controller.text = normalized;
      } else {
        _errorNotifier.value = t.translate(
          'exportDirectoryPath.invalid',
          languageCode: langCode,
        );
      }
    } catch (_) {
      if (!mounted) return;
      _errorNotifier.value = t.translate(
        'exportDirectoryPath.error',
        languageCode: langCode,
      );
    }
  }

  void _onNext() {
    final bloc = context.read<SettingsBloc>();
    final langCode = bloc.state.settings.languageCode;
    final current = bloc.state.settings.exportDirectoryPath;
    final value = _controller.text.trim();
    if (value == current) {
      context.read<OnboardingBloc>().add(const OnboardingNextStep());
      return;
    }
    if (value.isEmpty || isValidExportPath(value)) {
      if (value.isNotEmpty) {
        bloc.add(SetExportDirectoryPath(value));
      }
      context.read<OnboardingBloc>().add(const OnboardingNextStep());
      return;
    }
    _errorNotifier.value = LocalizationService().translate(
      'exportDirectoryPath.invalid',
      languageCode: langCode,
    );
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
                  PhosphorIcons.folder,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: Spacing.md),
                Text(
                  t.translate(
                    'onboarding.exportPath.title',
                    languageCode: langCode,
                  ),
                  style: TextStyles.heading2,
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  t.translate(
                    'onboarding.exportPath.subtitle',
                    languageCode: langCode,
                  ),
                  style: TextStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Spacing.lg),
                ListenableBuilder(
                  listenable: _errorNotifier,
                  builder: (context, _) => TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText: t.translate(
                        'exportDirectoryPath',
                        languageCode: langCode,
                      ),
                      hintText: t.translate(
                        'exportDirectoryPath.hint',
                        languageCode: langCode,
                      ),
                      border: const OutlineInputBorder(),
                      errorText: _errorNotifier.value,
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty && !isValidExportPath(value)) {
                        _errorNotifier.value = t.translate(
                          'exportDirectoryPath.invalid',
                          languageCode: langCode,
                        );
                      } else {
                        _errorNotifier.value = null;
                      }
                    },
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _chooseFolder(langCode),
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: Text(
                      t.translate(
                        'onboarding.exportPath.choose',
                        languageCode: langCode,
                      ),
                      style: TextStyles.title,
                    ),
                  ),
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
                              'onboarding.exportPath.back',
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
                          onPressed: _onNext,
                          child: Text(
                            t.translate(
                              'onboarding.exportPath.next',
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
                      'onboarding.exportPath.skip',
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
