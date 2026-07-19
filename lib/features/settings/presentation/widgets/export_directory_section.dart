import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/localization_service.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import 'settings_section.dart';

class ExportDirectorySection extends StatefulWidget {
  const ExportDirectorySection({super.key});

  @override
  State<ExportDirectorySection> createState() => _ExportDirectorySectionState();
}

class _ExportDirectorySectionState extends State<ExportDirectorySection> {
  final _controller = TextEditingController();
  String? _error;

  static final _drivePathRegex = RegExp(r'^[a-zA-Z]:\\(?:[^<>:"/\\|?*\n]+\\)*[^<>:"/\\|?*\n]*$');

  @override
  void initState() {
    super.initState();
    _syncFromSettings();
  }

  void _syncFromSettings() {
    final path = context.read<SettingsBloc>().state.settings.exportDirectoryPath;
    if (_controller.text != path) {
      _controller.text = path;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );
    final exportPath = context.select<SettingsBloc, String>(
      (b) => b.state.settings.exportDirectoryPath,
    );

    if (_controller.text != exportPath) {
      _controller.text = exportPath;
    }

    final t = LocalizationService();

    return SettingsSection(
      title: t.translate('exportDirectoryPath', languageCode: langCode),
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: t.translate('exportDirectoryPath', languageCode: langCode),
            hintText: r'D:\Exports',
            border: const OutlineInputBorder(),
            errorText: _error,
          ),
          onChanged: (value) {
            if (value.isNotEmpty && !_drivePathRegex.hasMatch(value)) {
              setState(() {
                _error = t.translate('exportDirectoryPath.invalid', languageCode: langCode);
              });
            } else {
              setState(() => _error = null);
              if (value.isNotEmpty) {
                context.read<SettingsBloc>().add(SetExportDirectoryPath(value));
              }
            }
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: () async {
                final result = await FilePicker.platform.getDirectoryPath();
                if (result != null && context.mounted) {
                  setState(() => _error = null);
                  context.read<SettingsBloc>().add(SetExportDirectoryPath(result));
                }
              },
              icon: const Icon(Icons.folder_open, size: 18),
              label: Text(t.translate('exportDirectoryPath.choose', languageCode: langCode)),
            ),
          ],
        ),
      ],
    );
  }
}
