import 'package:cashier_system/core/theme/spacing.dart';
import 'package:cashier_system/features/inventory/domain/entities/prep_category.dart';
import 'package:cashier_system/features/settings/presentation/widgets/settings_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/localization_service.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';

class PrepCategoriesSection extends StatelessWidget {
  const PrepCategoriesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );
    final shownIds = context.select<SettingsBloc, List<String>>(
      (b) => b.state.settings.shownPrepCategoryIds,
    );
    final t = LocalizationService();

    final visibleCategories = PrepCategory.values;

    return SettingsSection(
      title: t.translate(
        'settings.tickets.prepCategories',
        languageCode: langCode,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            t.translate(
              'settings.tickets.prepCategories.subtitle',
              languageCode: langCode,
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Row(
          children: [
            ...visibleCategories.map((category) {
              return Row(
                children: [
                  _PrepCategoryChip(
                    category: category,
                    selected:
                        shownIds.isEmpty || shownIds.contains(category.id),
                    langCode: langCode,
                    onChanged: (v) {
                      final updatedIds = shownIds.isEmpty
                          ? PrepCategory.values.map((t) => t.id).toList()
                          : List<String>.from(shownIds);
                      if (v) {
                        if (!updatedIds.contains(category.id)) {
                          updatedIds.add(category.id);
                        }
                      } else {
                        updatedIds.remove(category.id);
                      }
                      if (updatedIds.isEmpty) {
                        updatedIds.add(PrepCategory.food.id);
                      }
                      context.read<SettingsBloc>().add(
                        PrepCategoryVisibilityChanged(updatedIds),
                      );
                    },
                  ),
                  const SizedBox(width: Spacing.sm),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }
}

class _PrepCategoryChip extends StatelessWidget {
  final PrepCategory category;
  final bool selected;
  final String langCode;
  final Function(bool) onChanged;

  const _PrepCategoryChip({
    required this.category,
    required this.selected,
    required this.langCode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final label = t.translate(
      'settings.tickets.prepCategory.${category.id}',
      languageCode: langCode,
    );
    final colorScheme = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onChanged,
      selectedColor: colorScheme.primaryContainer.withValues(alpha: 0.35),
      showCheckmark: true,
      side: selected
          ? BorderSide(color: colorScheme.primary, width: 2)
          : BorderSide(color: colorScheme.outlineVariant),
      labelStyle: selected
          ? TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            )
          : TextStyle(color: colorScheme.onSurface),
    );
  }
}
