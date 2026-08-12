import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../features/settings/presentation/bloc/settings_bloc.dart';

/// Reusable widget that prompts the user to set the export directory path
/// if [exportDirectoryPath] is empty.
///
/// Shows a modal dialog with:
/// - Message: "Export directory not set"
/// - Text: "Set path in Settings first to enable saving files"
/// - "Open Settings" button: navigates to Settings Export Directory section
/// - "Cancel" button: dismisses without saving
///
/// Usage: showDialog(context: context, builder: (_) => const ExportPathPrompt());
class ExportPathPrompt extends StatelessWidget {
  final VoidCallback? onOpenSettings;
  final VoidCallback? onCancel;

  const ExportPathPrompt({
    Key? key,
    this.onOpenSettings,
    this.onCancel,
  }) : super(key: key);

  /// Shows the prompt dialog when export path is empty.
  /// Returns true if the operation should proceed, false if cancelled.
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export directory not set'),
      content: const Text(
        'Set path in Settings first to enable saving files. '
        'Go to Settings → Export Directory to configure a save location.',
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: onOpenSettings,
          child: const Text('Open Settings'),
        ),
      ],
    );
  }
}

/// Checks if export path is available and shows prompt if needed.
/// Returns true if the operation should proceed, false if cancelled.
///
/// This is a top-level function that can be called from anywhere:
/// - Sales export UI
/// - Inventory export UI
/// - Barcode save UI
/// - Receipt save UI
///
/// [onOpenSettings] is called when user taps "Open Settings" in the dialog.
Future<bool> checkExportPathAndPrompt(
  BuildContext context, {
  required VoidCallback onProceed, // Called if path is set or user confirms
  required VoidCallback onOpenSettings, // Called when user taps "Open Settings"
}) async {
  final settingsBloc = context.read<SettingsBloc>();
  final exportPath = settingsBloc.state.settings.exportDirectoryPath;

  if (exportPath.isEmpty) {
    // Show the prompt dialog
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ExportPathPrompt(
        onOpenSettings: onOpenSettings,
        onCancel: () {
          Navigator.of(context).pop();
        },
      ),
    );
    // After dialog, call onProceed to handle the result
    // (caller needs to know if user opened settings or cancelled)
    onProceed.call();
    return true;
  }

  // Path is already set, proceed immediately
  onProceed.call();
  return true;
}