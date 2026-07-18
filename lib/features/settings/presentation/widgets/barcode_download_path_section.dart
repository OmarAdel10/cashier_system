import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/localization_service.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import 'settings_section.dart';

class BarcodeDownloadPathSection extends StatelessWidget {
  const BarcodeDownloadPathSection({super.key});

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );
    final downloadPath = context.select<SettingsBloc, String>(
      (b) => b.state.settings.barcodeDownloadPath,
    );
    final t = LocalizationService();

    return SettingsSection(
      title: t.translate('barcodeDownloadPath', languageCode: langCode),
      children: [
        ListTile(
          title: Text(
            downloadPath.isNotEmpty
                ? downloadPath
                : t.translate('barcodeDownloadPath.notSet', languageCode: langCode),
            style: TextStyle(
              fontSize: 13,
              color: downloadPath.isNotEmpty ? null : Colors.grey,
            ),
          ),
          trailing: FilledButton.tonalIcon(
            onPressed: () async {
              final result = await FilePicker.platform.getDirectoryPath();
              if (result != null && context.mounted) {
                context.read<SettingsBloc>().add(SetBarcodeDownloadPath(result));
              }
            },
            icon: const Icon(Icons.folder_open, size: 18),
            label: Text(t.translate('barcodeDownloadPath.choose', languageCode: langCode)),
          ),
        ),
      ],
    );
  }
}
