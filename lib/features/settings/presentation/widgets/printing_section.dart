import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/localization_service.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import 'settings_section.dart';

class PrintingSection extends StatelessWidget {
  const PrintingSection({super.key});

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );
    final autoPrintEnabled = context.select<SettingsBloc, bool>(
      (b) => b.state.settings.autoPrintEnabled,
    );
    final t = LocalizationService();

    return SettingsSection(
      title: t.translate('printing', languageCode: langCode),
      children: [
        SwitchListTile(
          title: Text(t.translate('autoPrint', languageCode: langCode)),
          subtitle: Text(
            t.translate('autoPrintSubtitle', languageCode: langCode),
          ),
          value: autoPrintEnabled,
          onChanged: (v) {
            context.read<SettingsBloc>().add(AutoPrintToggled(v));
          },
        ),
      ],
    );
  }
}
