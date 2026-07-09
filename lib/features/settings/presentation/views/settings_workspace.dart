import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../data/services/localization_service.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';

class SettingsWorkspace extends StatelessWidget {
  const SettingsWorkspace({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        final langCode = state.settings.languageCode;
        final t = LocalizationService();

        return Scaffold(
          appBar: AppBar(
            title: Text(t.translate('settings', languageCode: langCode)),
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingsSection(
                  title: t.translate('general', languageCode: langCode),
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: t.translate('storeName', languageCode: langCode),
                        hintText: t.translate('storeNameHint', languageCode: langCode),
                        border: const OutlineInputBorder(),
                      ),
                      controller: TextEditingController.fromValue(
                        TextEditingValue(
                          text: state.settings.storeName,
                          selection: TextSelection.collapsed(
                            offset: state.settings.storeName.length,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        context.read<SettingsBloc>().add(StoreNameChanged(value));
                      },
                    ),
                    SizedBox(height: Spacing.lg),
                    TextField(
                      decoration: InputDecoration(
                        labelText: t.translate('receiptFootnote', languageCode: langCode),
                        hintText: t.translate('receiptFootnoteHint', languageCode: langCode),
                        border: const OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                      controller: TextEditingController.fromValue(
                        TextEditingValue(
                          text: state.settings.receiptFootnote,
                          selection: TextSelection.collapsed(
                            offset: state.settings.receiptFootnote.length,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        context.read<SettingsBloc>().add(ReceiptFootnoteChanged(value));
                      },
                    ),
                  ],
                ),
                SizedBox(height: Spacing.lg),
                _SettingsSection(
                  title: t.translate('appearance', languageCode: langCode),
                  children: [
                    SwitchListTile(
                      title: Text(t.translate('darkMode', languageCode: langCode)),
                      subtitle: Text(
                        state.settings.isDarkMode
                            ? t.translate('darkModeActive', languageCode: langCode)
                            : t.translate('lightModeActive', languageCode: langCode),
                      ),
                      value: state.settings.isDarkMode,
                      onChanged: (value) {
                        context.read<SettingsBloc>().add(ThemeToggled(value));
                      },
                    ),
                  ],
                ),
                SizedBox(height: Spacing.lg),
                _SettingsSection(
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
                      selected: {state.settings.languageCode},
                      onSelectionChanged: (selection) {
                        context.read<SettingsBloc>().add(
                              LanguageToggled(selection.first),
                            );
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
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          SizedBox(width: Spacing.sm),
                          Expanded(
                            child: Text(
                              state.settings.isRtl
                                  ? t.translate('rtlHint', languageCode: langCode)
                                  : t.translate('ltrHint', languageCode: langCode),
                              style: TextStyle(color: Colors.blue.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyles.title),
            SizedBox(height: Spacing.sm),
            const Divider(),
            SizedBox(height: Spacing.md),
            ...children,
          ],
        ),
      ),
    );
  }
}
