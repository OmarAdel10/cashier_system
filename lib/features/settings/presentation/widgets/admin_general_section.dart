import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/spacing.dart';
import '../../data/services/localization_service.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import 'settings_section.dart';

class AdminGeneralSection extends StatefulWidget {
  const AdminGeneralSection({super.key});

  @override
  State<AdminGeneralSection> createState() => _AdminGeneralSectionState();
}

class _AdminGeneralSectionState extends State<AdminGeneralSection> {
  final _storeController = TextEditingController();
  final _footnoteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncFromSettings();
  }

  void _syncFromSettings() {
    final s = context.read<SettingsBloc>().state.settings;
    if (_storeController.text != s.storeName) {
      _storeController.text = s.storeName;
    }
    if (_footnoteController.text != s.receiptFootnote) {
      _footnoteController.text = s.receiptFootnote;
    }
  }

  @override
  void dispose() {
    _storeController.dispose();
    _footnoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );
    final storeName = context.select<SettingsBloc, String>(
      (b) => b.state.settings.storeName,
    );
    final footnote = context.select<SettingsBloc, String>(
      (b) => b.state.settings.receiptFootnote,
    );

    if (_storeController.text != storeName) {
      _storeController.text = storeName;
    }
    if (_footnoteController.text != footnote) {
      _footnoteController.text = footnote;
    }

    final t = LocalizationService();

    return SettingsSection(
      title: t.translate('general', languageCode: langCode),
      children: [
        TextField(
          controller: _storeController,
          decoration: InputDecoration(
            labelText: t.translate('storeName', languageCode: langCode),
            hintText: t.translate('storeNameHint', languageCode: langCode),
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            context.read<SettingsBloc>().add(StoreNameChanged(value));
          },
        ),
        SizedBox(height: Spacing.lg),
        TextField(
          controller: _footnoteController,
          decoration: InputDecoration(
            labelText: t.translate('receiptFootnote', languageCode: langCode),
            hintText: t.translate('receiptFootnoteHint', languageCode: langCode),
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
          onChanged: (value) {
            context.read<SettingsBloc>().add(ReceiptFootnoteChanged(value));
          },
        ),
      ],
    );
  }
}
