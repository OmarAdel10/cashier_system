import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/animated_counter.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../domain/helpers/price_helper.dart';
import '../bloc/checkout_bloc.dart';
import '../bloc/checkout_state.dart';
import 'cash_drawer_assistant.dart';

class CheckoutTowerPanel extends StatelessWidget {
  const CheckoutTowerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.watch<SettingsBloc>().state.settings.languageCode;
    final settings = context.watch<SettingsBloc>().state.settings;
    final colorScheme = Theme.of(context).colorScheme;

    return BlocBuilder<CheckoutBloc, CheckoutState>(
      builder: (context, state) {
        return Column(
          children: [
            Expanded(
              child: SectionCard(
                title: t.translate('receiptTower', languageCode: langCode),
                mainAxisSize: MainAxisSize.max,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(bottom: Spacing.md),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: colorScheme.outlineVariant),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (settings.storeName.isNotEmpty)
                            Text(
                              settings.storeName,
                              style: TextStyles.heading2,
                            ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              PhosphorIcon(
                                PhosphorIcons.receiptDuotone,
                                size: 20,
                              ),
                              const SizedBox(width: Spacing.sm),
                              Text(
                                t.translate(
                                  'receiptTower',
                                  languageCode: langCode,
                                ),
                                style: TextStyles.title,
                              ),
                              if (state.status == CheckoutStatus.confirmed) ...[
                                const Spacer(),
                                PhosphorIcon(
                                  PhosphorIcons.checkCircle,
                                  color: colorScheme.primary,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (state.cart != null && state.cart!.items.isNotEmpty)
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            vertical: Spacing.xs,
                          ),
                          itemCount: state.cart!.items.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            color: colorScheme.outlineVariant,
                          ),
                          itemBuilder: (context, index) {
                            final item = state.cart!.items[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: Spacing.xs,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '${index + 1}.',
                                    style: TextStyles.body.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: Spacing.sm),
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: TextStyles.body.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: Spacing.sm),
                                  Text(
                                    '${item.quantity} x ${PriceHelper.format(item.unitPricePiastres, languageCode: langCode)}',
                                    style: TextStyles.caption.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: Spacing.sm),
                                  AnimatedCounter(
                                    value: PriceHelper.format(
                                      item.totalPiastres,
                                      languageCode: langCode,
                                    ),
                                    style: TextStyles.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
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
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              const SizedBox(height: Spacing.md),
                              Text(
                                t.translate(
                                  'receiptPlaceholder',
                                  languageCode: langCode,
                                ),
                                style: TextStyles.body.copyWith(
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.6),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (state.cart != null && state.cart!.items.isNotEmpty) ...[
                      Divider(height: 1, color: colorScheme.outlineVariant),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: Spacing.sm,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Items: ${state.cart!.items.length}',
                              style: TextStyles.body.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            AnimatedCounter(
                              value: PriceHelper.format(
                                state.subtotalPiastres,
                                languageCode: langCode,
                              ),
                              style: TextStyles.title,
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (settings.receiptFootnote.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: Spacing.xs),
                        child: Text(
                          settings.receiptFootnote,
                          style: TextStyles.caption.copyWith(
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            SectionCard(
              title: t.translate('checkout.cashDrawer', languageCode: langCode),
              child: const CashDrawerAssistant(),
            ),
          ],
        );
      },
    );
  }
}
