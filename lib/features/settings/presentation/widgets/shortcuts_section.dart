import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../features/shortcuts/default_bindings.dart';
import '../../../../features/shortcuts/helpers/key_binding_parser.dart';
import '../../../../features/shortcuts/presentation/widgets/key_capture_dialog.dart';
import '../../data/services/localization_service.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import 'settings_section.dart';

const Map<String, List<String>> _shortcutGroups = {
  'shortcuts.navigation': [
    'nav.checkout',
    'nav.inventory',
    'nav.sales',
    'nav.settings',
  ],
  'shortcuts.search': ['search.toggle', 'search.clear'],
  'shortcuts.cashDrawer': [
    'cart.amount.5eg',
    'cart.amount.10eg',
    'cart.amount.20eg',
    'cart.amount.50eg',
    'cart.amount.100eg',
    'cart.amount.200eg',
    'cart.amount.clear',
  ],
  'shortcuts.cart': [
    'cart.confirm',
    'cart.selected.up',
    'cart.selected.down',
    'cart.selected.delete',
    'cart.selected.edit',
    'cart.discount',
  ],
  'shortcuts.quickTiles': [
    'cart.quick.1',
    'cart.quick.2',
    'cart.quick.3',
    'cart.quick.4',
    'cart.quick.5',
    'cart.quick.6',
    'cart.quick.7',
    'cart.quick.8',
    'cart.quick.9',
    'cart.quick.10',
  ],
  'shortcuts.inventory': ['inventory.addProduct'],
};

class ShortcutsSection extends StatelessWidget {
  const ShortcutsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );
    final customBindings = context.select<SettingsBloc, Map<String, List<String>>>(
      (b) => b.state.settings.customBindings,
    );
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
      final custom = customBindings[actionToken];
      if (custom != null && custom.isNotEmpty) return custom;
      return defaultBindings[actionToken] ?? [];
    }

    return SettingsSection(
      title: t.translate('shortcuts', languageCode: langCode),
      children: [
        for (final groupEntry in _shortcutGroups.entries) ...[
          Padding(
            padding: EdgeInsets.only(
              top: Spacing.sm,
              bottom: Spacing.xs,
            ),
            child: Text(
              t.translate(groupEntry.key, languageCode: langCode),
              style: TextStyles.title.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final actionToken in groupEntry.value)
            _ShortcutRow(
              actionToken: actionToken,
              label: actionLabel(actionToken),
              combos: combosForAction(actionToken),
              isCustom: customBindings.containsKey(actionToken),
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
    );
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
                      ...combos.map(
                        (combo) => _ShortcutChip(
                          combo: combo,
                          onRemove: isCustom ? () => onRemove(combo) : null,
                          colorScheme: colorScheme,
                        ),
                      ),
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
                  color: colorScheme.onSecondaryContainer.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
