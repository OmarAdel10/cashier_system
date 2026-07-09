import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../domain/helpers/price_helper.dart';
import '../bloc/checkout_bloc.dart';
import '../bloc/checkout_state.dart';
import '../bloc/checkout_event.dart';
import 'cash_drawer_assistant.dart';

class CheckoutTowerPanel extends StatelessWidget {
  const CheckoutTowerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.watch<SettingsBloc>().state.settings.languageCode;
    final colorScheme = Theme.of(context).colorScheme;

    return BlocBuilder<CheckoutBloc, CheckoutState>(
      builder: (context, state) {
        return Container(
          color: colorScheme.surfaceContainerHighest,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
                child: Row(
                  children: [
                    PhosphorIcon(PhosphorIcons.receiptDuotone, size: 20, color: colorScheme.onSurface),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      t.translate('receiptTower', languageCode: langCode),
                      style: TextStyles.title,
                    ),
                    if (state.status == CheckoutStatus.confirmed) ...[
                      const Spacer(),
                      Icon(Icons.check_circle, size: 20, color: colorScheme.primary),
                    ],
                  ],
                ),
              ),
              if (state.cart != null && state.cart!.items.isNotEmpty)
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                    itemCount: state.cart!.items.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: colorScheme.outlineVariant),
                    itemBuilder: (context, index) {
                      final item = state.cart!.items[index];
                      return ListTile(
                        dense: true,
                        title: Text(item.name, style: TextStyles.bodySmall),
                        trailing: Text(
                          PriceHelper.format(item.totalPiastres),
                          style: TextStyles.bodySmall,
                        ),
                        subtitle: Text(
                          '${item.quantity} × ${PriceHelper.format(item.unitPricePiastres)}',
                          style: TextStyles.caption,
                        ),
                      );
                    },
                  ),
                )
              else
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PhosphorIcon(
                          PhosphorIcons.receiptDuotone,
                          size: 48,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: Spacing.md),
                        Text(
                          t.translate('receiptPlaceholder', languageCode: langCode),
                          style: TextStyles.body.copyWith(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              if (state.status == CheckoutStatus.confirmed)
                Padding(
                  padding: const EdgeInsets.all(Spacing.md),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.read<CheckoutBloc>().add(const ClearCart()),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(t.translate('checkout.newSale', languageCode: langCode)),
                    ),
                  ),
                )
              else
                const CashDrawerAssistant(),
            ],
          ),
        );
      },
    );
  }
}
