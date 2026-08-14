import 'package:cashier_system/core/theme/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../checkout/domain/entities/payment_type.dart';
import '../../data/services/localization_service.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import 'settings_section.dart';

class PaymentTypesSection extends StatelessWidget {
  const PaymentTypesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );
    final shownIds = context.select<SettingsBloc, List<String>>(
      (b) => b.state.settings.shownPaymentTypeIds,
    );
    final t = LocalizationService();

    final visibleTypes = PaymentType.values;

    return SettingsSection(
      title: t.translate('settings.paymentTypes', languageCode: langCode),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            t.translate(
              'settings.paymentTypes.subtitle',
              languageCode: langCode,
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Row(
          children: [
            ...visibleTypes.map((type) {
              return Row(
                children: [
                  _PaymentTypeChip(
                    type: type,
                    selected: shownIds.isEmpty || shownIds.contains(type.id),
                    langCode: langCode,
                    onChanged: (v) {
                      final updatedIds = List<String>.from(shownIds);
                      if (v) {
                        if (!updatedIds.contains(type.id)) updatedIds.add(type.id);
                      } else {
                        updatedIds.remove(type.id);
                      }
                      if (updatedIds.isEmpty) updatedIds.add(PaymentType.cash.id);
                      context.read<SettingsBloc>().add(
                        PaymentTypeVisibilityChanged(updatedIds),
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

class _PaymentTypeChip extends StatelessWidget {
  final PaymentType type;
  final bool selected;
  final String langCode;
  final ValueChanged<bool> onChanged;

  const _PaymentTypeChip({
    required this.type,
    required this.selected,
    required this.langCode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final label = t.translate('paymentType.${type.id}', languageCode: langCode);
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
