import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../core/theme/spacing.dart';
import '../core/theme/text_styles.dart';
import '../features/settings/data/services/localization_service.dart';
import '../features/settings/presentation/bloc/settings_bloc.dart';

import '../features/inventory/presentation/views/inventory_workspace.dart';
import '../features/settings/presentation/views/settings_workspace.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(3);

  @override
  Widget build(BuildContext context) {
    final langCode = context.watch<SettingsBloc>().state.settings.languageCode;
    final t = LocalizationService();

    return ValueListenableBuilder<int>(
      valueListenable: _selectedIndexNotifier,
      builder: (context, selectedIndex, child) {
        return Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _NavRail(
                selectedIndex: selectedIndex,
                onItemSelected: (index) =>
                    _selectedIndexNotifier.value = index,
                languageCode: langCode,
              ),
              Container(
                width: 1,
                color: Theme.of(context).dividerColor,
              ),
              Expanded(
            flex: selectedIndex == 0 ? 7 : 1,
            child: _buildWorkspace(selectedIndex, t, langCode),
          ),
          if (selectedIndex == 0) ...[
            Container(
              width: 1,
              color: Theme.of(context).dividerColor,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 360),
              child: _TowerPanel(languageCode: langCode),
            ),
          ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildWorkspace(int selectedIndex, LocalizationService t, String langCode) {
    if (selectedIndex == 1) return const InventoryWorkspace();
    if (selectedIndex == 3) return const SettingsWorkspace();

    final labels = [
      t.translate('navCheckout', languageCode: langCode),
      t.translate('navInventory', languageCode: langCode),
      t.translate('navSales', languageCode: langCode),
    ];

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            labels[selectedIndex],
            style: TextStyles.heading2,
          ),
          SizedBox(height: Spacing.sm),
          Text(
            t.translate('comingSoon', languageCode: langCode),
            style: TextStyles.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final String languageCode;

  const _NavRail({
    required this.selectedIndex,
    required this.onItemSelected,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();

    return SizedBox(
      width: 72,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < _navItems.length; i++)
            _NavRailItem(
              icon: _navItems[i].icon,
              label: t.translate(
                _navItems[i].labelKey,
                languageCode: languageCode,
              ),
              isSelected: i == selectedIndex,
              onTap: () => onItemSelected(i),
            ),
        ],
      ),
    );
  }
}

class _NavRailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavRailItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fgColor = isSelected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: Spacing.xs),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 56,
          padding: EdgeInsets.symmetric(vertical: Spacing.sm),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primaryContainer : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: fgColor),
              SizedBox(height: Spacing.xs),
              Text(
                label,
                style: TextStyles.caption.copyWith(color: fgColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TowerPanel extends StatelessWidget {
  final String languageCode;

  const _TowerPanel({required this.languageCode});

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Text(
              t.translate('receiptTower', languageCode: languageCode),
              style: TextStyles.title,
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(Spacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.receiptDuotone,
                      size: 48,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                    ),
                    SizedBox(height: Spacing.md),
                    Text(
                      t.translate(
                        'receiptPlaceholder',
                        languageCode: languageCode,
                      ),
                      style: TextStyles.body.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String labelKey;

  const _NavItem(this.icon, this.labelKey);
}

const _navItems = [
  _NavItem(PhosphorIcons.shoppingCartSimple, 'navCheckout'),
  _NavItem(PhosphorIcons.package, 'navInventory'),
  _NavItem(PhosphorIcons.chartBar, 'navSales'),
  _NavItem(PhosphorIcons.gearSix, 'navSettings'),
];
