import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../data/services/localization_service.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import 'settings_section.dart';

class LocalizationSection extends StatelessWidget {
  const LocalizationSection({super.key});

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );
    final isRtl = context.select<SettingsBloc, bool>(
      (b) => b.state.settings.isRtl,
    );
    final t = LocalizationService();

    return SettingsSection(
      title: t.translate('localization', languageCode: langCode),
      children: [
        Text(
          t.translate('language', languageCode: langCode),
          style: TextStyles.body,
        ),
        SizedBox(height: Spacing.sm),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: 'ar',
              label: Text(t.translate('arabic', languageCode: langCode)),
            ),
            ButtonSegment(
              value: 'en',
              label: Text(t.translate('english', languageCode: langCode)),
            ),
          ],
          selected: {langCode},
          onSelectionChanged: (selection) {
            context.read<SettingsBloc>().add(LanguageToggled(selection.first));
          },
        ),
        SizedBox(height: Spacing.md),
        Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              PhosphorIcon(
                PhosphorIcons.infoDuotone,
                color: Colors.blue.shade700,
              ),
              SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  isRtl
                      ? t.translate('rtlHint', languageCode: langCode)
                      : t.translate('ltrHint', languageCode: langCode),
                  style: TextStyle(color: Colors.blue.shade700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
