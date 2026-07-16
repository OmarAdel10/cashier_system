import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_error.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../features/auth/domain/entities/user_entity.dart';
import '../../../../features/auth/domain/entities/user_role.dart';
import '../../../../features/auth/presentation/widgets/user_management_section.dart';
import '../../../../features/shortcuts/default_bindings.dart';
import '../../../../features/shortcuts/helpers/key_binding_parser.dart';
import '../../../../features/shortcuts/presentation/widgets/key_capture_dialog.dart';
import '../../../../features/auth/data/models/app_user_model.dart';
import '../../../../features/auth/data/models/app_shift_model.dart';
import '../../../../features/inventory/data/models/app_product_model.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_event.dart';
import '../../../../features/inventory/presentation/bloc/inventory_bloc.dart';
import '../../../../features/inventory/presentation/bloc/inventory_event.dart';
import '../../data/models/app_settings_model.dart';
import '../../data/services/localization_service.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';

const Map<String, List<String>> _shortcutGroups = {
  'shortcuts.navigation': [
    'nav.checkout', 'nav.inventory', 'nav.sales', 'nav.settings',
  ],
  'shortcuts.search': [
    'search.toggle',
    'search.clear',
  ],
  'shortcuts.cashDrawer': [
    'cart.amount.5eg', 'cart.amount.10eg', 'cart.amount.20eg',
    'cart.amount.50eg', 'cart.amount.100eg', 'cart.amount.200eg',
    'cart.amount.clear',
  ],
  'shortcuts.cart': [
    'cart.confirm',
    'cart.selected.up', 'cart.selected.down', 'cart.selected.delete', 'cart.selected.edit',
    'cart.discount',
  ],
  'shortcuts.quickTiles': [
    'cart.quick.1', 'cart.quick.2', 'cart.quick.3', 'cart.quick.4',
    'cart.quick.5', 'cart.quick.6', 'cart.quick.7', 'cart.quick.8',
    'cart.quick.9', 'cart.quick.10',
  ],
  'shortcuts.inventory': [
    'inventory.addProduct',
  ],
};

class _UsersLoader extends StatefulWidget {
  final Widget child;
  const _UsersLoader({required this.child});
  @override
  State<_UsersLoader> createState() => _UsersLoaderState();
}

class _UsersLoaderState extends State<_UsersLoader> {
  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(const LoadUsers());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class SettingsWorkspace extends StatelessWidget {
  final UserEntity? currentUser;

  const SettingsWorkspace({super.key, this.currentUser});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        final langCode = state.settings.languageCode;
        final t = LocalizationService();

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

        List<String> combosForAction(String actionToken) {
          final custom = state.settings.customBindings[actionToken];
          if (custom != null && custom.isNotEmpty) return custom;
          return defaultBindings[actionToken] ?? [];
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
                if (currentUser != null && currentUser!.role == UserRole.admin)
                  _UsersLoader(child: UserManagementSection(currentUser: currentUser!)),
                if (currentUser != null && currentUser!.role == UserRole.admin)
                  SizedBox(height: Spacing.lg),
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
                  title: t.translate('tax', languageCode: langCode),
                  children: [
                    SwitchListTile(
                      title: Text(
                        t.translate('taxToggle', languageCode: langCode),
                      ),
                      subtitle: Text(
                        t.translate('taxToggleSubtitle', languageCode: langCode),
                      ),
                      value: state.settings.taxEnabled,
                      onChanged: (v) {
                        context.read<SettingsBloc>().add(TaxToggled(v));
                      },
                    ),
                    if (state.settings.taxEnabled) ...[
                      SizedBox(height: Spacing.sm),
                      const _TaxPercentField(),
                    ],
                  ],
                ),
                SizedBox(height: Spacing.lg),
                _SettingsSection(
                  title: t.translate('printing', languageCode: langCode),
                  children: [
                    SwitchListTile(
                      title: Text(
                        t.translate('autoPrint', languageCode: langCode),
                      ),
                      subtitle: Text(
                        t.translate('autoPrintSubtitle', languageCode: langCode),
                      ),
                      value: state.settings.autoPrintEnabled,
                      onChanged: (v) {
                        context.read<SettingsBloc>().add(AutoPrintToggled(v));
                      },
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
                          combos: combosForAction(actionToken),
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
                          onAdd: () async {
                            final result = await showDialog<String>(
                              context: context,
                              builder: (_) => KeyCaptureDialog(
                                currentCombo: '',
                                languageCode: langCode,
                              ),
                            );
                            if (result != null && context.mounted) {
                              context.read<SettingsBloc>().add(
                                AddCustomBinding(actionToken, result),
                              );
                            }
                          },
                          onRemove: (combo) {
                            context.read<SettingsBloc>().add(
                              RemoveCustomBinding(actionToken, combo),
                            );
                          },
                          onReset: () {
                            context.read<SettingsBloc>().add(
                              ResetCustomBinding(actionToken),
                            );
                          },
                ),
                    ],
                  ],
                ),
                SizedBox(height: Spacing.lg),
                _SettingsSection(
                  title: t.translate('resetAllData', languageCode: langCode),
                  children: [
                    Text(
                      t.translate('resetAllDataSubtitle', languageCode: langCode),
                      style: TextStyles.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: Spacing.sm),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      ),
                      onPressed: () => _resetAllData(context),
                      child: Text(
                        t.translate('resetAllData', languageCode: langCode),
                      ),
                    ),
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
 
  Future<void> _resetAllData(BuildContext context) async {
    final t = LocalizationService();
    final langCode = context.read<SettingsBloc>().state.settings.languageCode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.translate('resetAllDataConfirm', languageCode: langCode)),
        content: Text(t.translate('resetAllDataConfirmDetail', languageCode: langCode)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.translate('cancel', languageCode: langCode)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(t.translate('reset', languageCode: langCode)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
 
    await Hive.box<AppSettingsModel>('settings').clear();
    await Hive.box<AppProductModel>('inventory').clear();
    await Hive.box<AppUserModel>('auth_users').clear();
    await Hive.box<AppShiftModel>('shifts').clear();
    await HydratedBloc.storage.clear();
 
    if (context.mounted) {
      context.read<SettingsBloc>().add(const LoadSettings());
      context.read<InventoryBloc>().add(const LoadInventory());
    }
  }
}

class _ShortcutRow extends StatelessWidget {
  final String actionToken;
  final String label;
  final List<String> combos;
  final bool isCustom;
  final String rebindTooltip;
  final String resetTooltip;
  final VoidCallback onAdd;
  final void Function(String combo) onRemove;
  final VoidCallback onReset;

  const _ShortcutRow({
    required this.actionToken,
    required this.label,
    required this.combos,
    required this.isCustom,
    required this.rebindTooltip,
    required this.resetTooltip,
    required this.onAdd,
    required this.onRemove,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Spacing.xs),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyles.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: Spacing.xs),
                  Wrap(
                    spacing: Spacing.xs,
                    runSpacing: Spacing.xs,
                    children: [
                      ...combos.map((combo) => _ShortcutChip(
                        combo: combo,
                        onRemove: isCustom ? () => onRemove(combo) : null,
                        colorScheme: colorScheme,
                      )),
                      InkWell(
                        onTap: onAdd,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: Spacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                              style: BorderStyle.solid,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            PhosphorIcons.plus,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isCustom)
              Tooltip(
                message: resetTooltip,
                child: InkWell(
                  onTap: onReset,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: EdgeInsets.all(Spacing.xs),
                    child: Icon(
                      PhosphorIcons.arrowCounterClockwise,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  final String combo;
  final VoidCallback? onRemove;
  final ColorScheme colorScheme;

  const _ShortcutChip({
    required this.combo,
    this.onRemove,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: Spacing.sm,
        right: onRemove != null ? 2 : Spacing.sm,
        top: 2,
        bottom: 2,
      ),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            displayCombo(combo),
            style: TextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSecondaryContainer,
            ),
          ),
          if (onRemove != null) ...[
            SizedBox(width: 2),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  PhosphorIcons.x,
                  size: 12,
                  color: colorScheme.onSecondaryContainer
                      .withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TaxPercentField extends StatefulWidget {
  const _TaxPercentField();

  @override
  State<_TaxPercentField> createState() => _TaxPercentFieldState();
}

class _TaxPercentFieldState extends State<_TaxPercentField> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFromSettings();
  }

  void _syncFromSettings() {
    final pct = context.read<SettingsBloc>().state.settings.taxPercent.toString();
    if (_controller.text != pct) {
      _controller.text = pct;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.watch<SettingsBloc>().state.settings.languageCode;

    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: t.translate('taxPercent', languageCode: langCode),
        hintText: t.translate('taxPercentHint', languageCode: langCode),
        suffixText: '%',
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), () {
          final pct = int.tryParse(v.trim()) ?? 0;
          if (pct >= 0 && pct <= 100) {
            context.read<SettingsBloc>().add(
              TaxPercentChanged(pct.clamp(0, 100)),
            );
          }
        });
      },
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
