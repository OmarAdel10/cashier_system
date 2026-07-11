import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_error.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../features/shortcuts/default_bindings.dart';
import '../../../../features/shortcuts/helpers/key_binding_parser.dart';
import '../../../../features/shortcuts/presentation/widgets/key_capture_dialog.dart';
import '../../data/services/localization_service.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';

const Map<String, List<String>> _shortcutGroups = {
  'shortcuts.navigation': [
    'nav.checkout', 'nav.inventory', 'nav.sales', 'nav.settings',
  ],
  'shortcuts.search': [
    'search.toggle', 'search.toggle.slash', 'search.toggle.ctrl',
  ],
  'shortcuts.cart': [
    'cart.confirm', 'cart.confirm.space',
    'cart.selected.up', 'cart.selected.down', 'cart.selected.delete',
  ],
  'shortcuts.quickTiles': [
    'cart.quick.1', 'cart.quick.2', 'cart.quick.3', 'cart.quick.4',
    'cart.quick.5', 'cart.quick.6', 'cart.quick.7', 'cart.quick.8',
  ],
};

class SettingsWorkspace extends StatelessWidget {
  const SettingsWorkspace({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        final langCode = state.settings.languageCode;
        final t = LocalizationService();
        final merged = Map<String, String>.from(defaultBindings);
        merged.addAll(state.settings.customBindings);

        Future<void> onRebind(String actionToken, String currentCombo) async {
          final result = await showDialog<String>(
            context: context,
            builder: (_) => KeyCaptureDialog(
              currentCombo: currentCombo,
              languageCode: langCode,
            ),
          );
          if (result != null &&
              result != currentCombo &&
              context.mounted) {
            context.read<SettingsBloc>().add(
              CustomBindingsChanged(actionToken, result),
            );
          }
        }

        void onReset(String actionToken) {
          context.read<SettingsBloc>().add(
            CustomBindingsChanged(
              actionToken,
              defaultBindings[actionToken]!,
            ),
          );
        }

        String actionLabel(String actionToken) {
          if (actionToken.startsWith('cart.quick.')) {
            final num = actionToken.split('.').last;
            return t.translate(
              'shortcuts.action.quick',
              languageCode: langCode,
              params: [num],
            );
          }
          return t.translate(
            'shortcuts.action.$actionToken',
            languageCode: langCode,
          );
        }

        final title = t.translate('settings', languageCode: langCode);
        final Widget body = switch (state.status) {
          SettingsStatus.loading || SettingsStatus.initial => AppLoading(
            message: t.translate(
              'state.loading.loading',
              languageCode: langCode,
            ),
          ),
          SettingsStatus.error => AppError(
            headline: title,
            body: t.translate('state.error.load', languageCode: langCode),
            actionLabel: t.translate(
              'state.error.load.action',
              languageCode: langCode,
            ),
            onAction: () =>
                context.read<SettingsBloc>().add(const LoadSettings()),
          ),
          SettingsStatus.ready => SingleChildScrollView(
            padding: EdgeInsets.all(Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingsSection(
                  title: t.translate('general', languageCode: langCode),
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: t.translate(
                          'storeName',
                          languageCode: langCode,
                        ),
                        hintText: t.translate(
                          'storeNameHint',
                          languageCode: langCode,
                        ),
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
                        context.read<SettingsBloc>().add(
                          StoreNameChanged(value),
                        );
                      },
                    ),
                    SizedBox(height: Spacing.lg),
                    TextField(
                      decoration: InputDecoration(
                        labelText: t.translate(
                          'receiptFootnote',
                          languageCode: langCode,
                        ),
                        hintText: t.translate(
                          'receiptFootnoteHint',
                          languageCode: langCode,
                        ),
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
                        context.read<SettingsBloc>().add(
                          ReceiptFootnoteChanged(value),
                        );
                      },
                    ),
                  ],
                ),
                SizedBox(height: Spacing.lg),
                _SettingsSection(
                  title: t.translate('appearance', languageCode: langCode),
                  children: [
                    SwitchListTile(
                      title: Text(
                        t.translate('darkMode', languageCode: langCode),
                      ),
                      subtitle: Text(
                        state.settings.isDarkMode
                            ? t.translate(
                                'darkModeActive',
                                languageCode: langCode,
                              )
                            : t.translate(
                                'lightModeActive',
                                languageCode: langCode,
                              ),
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
                          label: Text(
                            t.translate('arabic', languageCode: langCode),
                          ),
                        ),
                        ButtonSegment(
                          value: 'en',
                          label: Text(
                            t.translate('english', languageCode: langCode),
                          ),
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
                          PhosphorIcon(
                            PhosphorIcons.infoDuotone,
                            color: Colors.blue.shade700,
                          ),
                          SizedBox(width: Spacing.sm),
                          Expanded(
                            child: Text(
                              state.settings.isRtl
                                  ? t.translate(
                                      'rtlHint',
                                      languageCode: langCode,
                                    )
                                  : t.translate(
                                      'ltrHint',
                                      languageCode: langCode,
                                    ),
                              style: TextStyle(color: Colors.blue.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Spacing.lg),
                _SettingsSection(
                  title: t.translate(
                    'shortcuts', languageCode: langCode),
                  children: [
                    for (final groupEntry
                        in _shortcutGroups.entries) ...[
                      Padding(
                        padding: EdgeInsets.only(
                          top: Spacing.sm,
                          bottom: Spacing.xs,
                        ),
                        child: Text(
                          t.translate(
                            groupEntry.key,
                            languageCode: langCode,
                          ),
                          style: TextStyles.title.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      for (final actionToken
                          in groupEntry.value)
                        _ShortcutRow(
                          actionToken: actionToken,
                          label: actionLabel(actionToken),
                          currentCombo:
                              merged[actionToken] ??
                              defaultBindings[
                                  actionToken] ??
                              '',
                          isCustom: state.settings
                              .customBindings
                              .containsKey(actionToken),
                          rebindTooltip: t.translate(
                            'shortcuts.tapToRebind',
                            languageCode: langCode,
                          ),
                          resetTooltip: t.translate(
                            'shortcuts.resetToDefault',
                            languageCode: langCode,
                          ),
                          onTap: () => onRebind(
                            actionToken,
                            merged[actionToken] ??
                                defaultBindings[
                                    actionToken] ??
                                '',
                          ),
                          onReset: () =>
                              onReset(actionToken),
                        ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        };

        return Scaffold(
          body: SectionCard(
            title: title,
            mainAxisSize: MainAxisSize.max,
            child: body,
          ),
        );
      },
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final String actionToken;
  final String label;
  final String currentCombo;
  final bool isCustom;
  final String rebindTooltip;
  final String resetTooltip;
  final VoidCallback onTap;
  final VoidCallback onReset;

  const _ShortcutRow({
    required this.actionToken,
    required this.label,
    required this.currentCombo,
    required this.isCustom,
    required this.rebindTooltip,
    required this.resetTooltip,
    required this.onTap,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Spacing.xs),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: Spacing.xs,
            horizontal: Spacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isCustom
                  ? colorScheme.primary.withValues(alpha: 0.4)
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyles.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isCustom)
                Tooltip(
                  message: rebindTooltip,
                  child: Icon(
                    PhosphorIcons.arrowCounterClockwise,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                ),
              SizedBox(width: Spacing.sm),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Spacing.sm,
                  vertical: Spacing.xs,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  displayCombo(currentCombo),
                  style: TextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              if (isCustom) ...[
                SizedBox(width: Spacing.xs),
                Tooltip(
                  message: resetTooltip,
                  child: InkWell(
                    onTap: onReset,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: EdgeInsets.all(Spacing.xs),
                      child: Icon(
                        PhosphorIcons.x,
                        size: 14,
                        color: colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

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
