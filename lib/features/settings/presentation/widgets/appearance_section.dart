import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/localization_service.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import 'settings_section.dart';

class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );
    final isDarkMode = context.select<SettingsBloc, bool>(
      (b) => b.state.settings.isDarkMode,
    );
    final t = LocalizationService();

    return SettingsSection(
      title: t.translate('appearance', languageCode: langCode),
      children: [
        SwitchListTile(
          title: Text(t.translate('darkMode', languageCode: langCode)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isDarkMode
                    ? t.translate('darkModeActive', languageCode: langCode)
                    : t.translate('lightModeActive', languageCode: langCode),
              ),
              Text(
                t.translate('darkModeSubtitle', languageCode: langCode),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          value: isDarkMode,
          onChanged: (value) {
            context.read<SettingsBloc>().add(ThemeToggled(value));
          },
        ),
      ],
    );
  }
}
