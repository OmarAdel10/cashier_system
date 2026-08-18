import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/printing/print_service.dart';
import '../../../../core/printing/svg_checks.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/presentation/bloc/settings_event.dart';
import '../bloc/onboarding_bloc.dart';
import '../bloc/onboarding_event.dart';

class OnboardingBrandingScreen extends StatefulWidget {
  const OnboardingBrandingScreen({super.key});

  @override
  State<OnboardingBrandingScreen> createState() =>
      _OnboardingBrandingScreenState();
}

class _OnboardingBrandingScreenState extends State<OnboardingBrandingScreen> {
  static final _localizationService = LocalizationService();

  bool _validatingSvg = false;

  Uint8List? _tryDecodeBase64(String? data) {
    if (data == null || data.trim().isEmpty) return null;
    try {
      return base64Decode(data.trim());
    } catch (_) {
      return null;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _localizedSvgError(String langCode, String? code) {
    final t = LocalizationService();
    final key = switch (code) {
      'TOO_LARGE' => 'svg.tooLarge',
      'NOT_SVG' => 'svg.invalidFile',
      'MALFORMED_XML' => 'svg.malformedXml',
      'DOCTYPE_FORBIDDEN' => 'svg.forbiddenDtd',
      'SCRIPT_FORBIDDEN' ||
      'FORBIDDEN_ELEMENT' ||
      'EVENT_ATTR_FORBIDDEN' ||
      'UNSAFE_CONTENT' => 'svg.containsScript',
      'EXTERNAL_REF_FORBIDDEN' => 'svg.externalReference',
      'TOO_COMPLEX' => 'svg.tooComplex',
      'NOT_RENDERABLE' || 'DIMENSIONS_INVALID' => 'svg.notRenderable',
      _ => 'svg.validationFailed',
    };
    return t.translate(key, languageCode: langCode);
  }

  Future<void> _pickLogo(String langCode) async {
    final t = LocalizationService();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['svg'],
    );
    if (result == null || !mounted) return;
    final file = File(result.files.single.path!);
    final size = await file.length();
    if (!mounted) return;
    if (size > SvgQuickCheck.maxBytes) {
      _showMessage(t.translate('svg.tooLarge', languageCode: langCode));
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) return;

    final quick = SvgQuickCheck.check(bytes);
    if (!quick.valid) {
      _showMessage(_localizedSvgError(langCode, quick.errorCode));
      return;
    }

    setState(() => _validatingSvg = true);
    final service = PrintService();
    try {
      final errors = await service
          .validateSvg(base64Encode(bytes))
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (errors.isNotEmpty) {
        _showMessage(_localizedSvgError(langCode, errors.first));
        return;
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        t.translate('svg.serverUnreachable', languageCode: langCode),
      );
      return;
    } finally {
      service.dispose();
      if (mounted) setState(() => _validatingSvg = false);
    }
    if (!mounted) return;
    context.read<SettingsBloc>().add(LogoSvgChanged(base64Encode(bytes)));
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );
    final logoSvgData = context.select<SettingsBloc, String?>(
      (b) => b.state.settings.logoSvgData,
    );
    final theme = Theme.of(context);
    final t = _localizationService;
    final logoBytes = _tryDecodeBase64(logoSvgData);

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
                  PhosphorIcons.image,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: Spacing.md),
                Text(
                  t.translate(
                    'onboarding.branding.title',
                    languageCode: langCode,
                  ),
                  style: TextStyles.heading2,
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  t.translate(
                    'onboarding.branding.subtitle',
                    languageCode: langCode,
                  ),
                  style: TextStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Spacing.lg),
                if (logoBytes != null)
                  Container(
                    width: 120,
                    height: 120,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SvgPicture.memory(
                      logoBytes,
                      fit: BoxFit.contain,
                      placeholderBuilder: (_) => const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        size: 40,
                        color: theme.colorScheme.outlineVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        t.translate('logoSvg.notSet', languageCode: langCode),
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: Spacing.md),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.tonalIcon(
                    onPressed: _validatingSvg
                        ? null
                        : () => _pickLogo(langCode),
                    icon: const Icon(Icons.image, size: 18),
                    label: _validatingSvg
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            t.translate(
                              'onboarding.branding.choose',
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
                              'onboarding.branding.back',
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
                              'onboarding.branding.next',
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
                      'onboarding.branding.skip',
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
