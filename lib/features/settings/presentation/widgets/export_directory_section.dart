import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/export_path_validator.dart';
import '../../data/services/localization_service.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import 'settings_section.dart';

class ExportDirectorySection extends StatefulWidget {
  const ExportDirectorySection({super.key});

  @override
  State<ExportDirectorySection> createState() => _ExportDirectorySectionState();
}

class _ExportDirectorySectionState extends State<ExportDirectorySection> {
  final _controller = TextEditingController();
  final _errorNotifier = ValueNotifier<String?>(null);
  late final Stream<SettingsState> _settingsStream;
  late final StreamSubscription<SettingsState> _settingsSubscription;

  @override
  void initState() {
    super.initState();
    _settingsStream = context.read<SettingsBloc>().stream.distinct(
      (prev, curr) =>
          prev.settings.exportDirectoryPath ==
          curr.settings.exportDirectoryPath,
    );
    _settingsSubscription = _settingsStream.listen(_onSettingsChanged);
    _syncFromSettings();
  }

  void _onSettingsChanged(SettingsState state) {
    if (!mounted) return;
    final path = state.settings.exportDirectoryPath;
    if (_controller.text != path) {
      _controller.text = path;
    }
  }

  void _syncFromSettings() {
    final path = context
        .read<SettingsBloc>()
        .state
        .settings
        .exportDirectoryPath;
    if (_controller.text != path) {
      _controller.text = path;
    }
  }

  @override
  void dispose() {
    unawaited(_settingsSubscription.cancel());
    _controller.dispose();
    _errorNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );

    final t = LocalizationService();

    return SettingsSection(
      title: t.translate('exportDirectoryPath', languageCode: langCode),
      children: [
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
              helperText: t.translate(
                'exportDirectoryPath.subtitle',
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
            onEditingComplete: () {
              try {
                final value = _controller.text.trim();
                if (value.isNotEmpty && isValidExportPath(value)) {
                  context.read<SettingsBloc>().add(
                    SetExportDirectoryPath(value),
                  );
                }
              } catch (e) {
                _errorNotifier.value = t.translate(
                  'exportDirectoryPath.error',
                  languageCode: langCode,
                );
              }
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: () async {
                try {
                  final result = await FilePicker.platform.getDirectoryPath();
                  if (result != null && context.mounted) {
                    final normalized = result.replaceAll('/', '\\');
                    if (isValidExportPath(normalized)) {
                      _errorNotifier.value = null;
                      context.read<SettingsBloc>().add(
                        SetExportDirectoryPath(normalized),
                      );
                    } else {
                      _errorNotifier.value = t.translate(
                        'exportDirectoryPath.invalid',
                        languageCode: langCode,
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    _errorNotifier.value = t.translate(
                      'exportDirectoryPath.error',
                      languageCode: langCode,
                    );
                  }
                }
              },
              icon: const Icon(Icons.folder_open, size: 18),
              label: Text(
                t.translate(
                  'exportDirectoryPath.choose',
                  languageCode: langCode,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
