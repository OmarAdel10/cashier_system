import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../domain/helpers/price_helper.dart';
import '../bloc/checkout_bloc.dart';
import '../bloc/checkout_event.dart';
import '../bloc/checkout_state.dart';

class CashDrawerAssistant extends StatelessWidget {
  const CashDrawerAssistant({super.key});

  static const _denominations = [500, 1000, 2000, 5000, 10000, 20000];

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.watch<SettingsBloc>().state.settings.languageCode;
    final state = context.watch<CheckoutBloc>().state;
    final subtotal = state.subtotalPiastres;
    final change = state.changePiastres;
    final isPaid = state.isPaid;
    final amountPaid = state.amountPaidPiastres;

    return Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t.translate('checkout.amountDue', languageCode: langCode),
            style: TextStyles.title,
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            PriceHelper.format(subtotal, languageCode: langCode),
            style: TextStyles.heading1,
          ),
          if (amountPaid != null) ...[
            const SizedBox(height: Spacing.xs),
            Text(
              '${t.translate('checkout.paid', languageCode: langCode)}: ${PriceHelper.format(amountPaid, languageCode: langCode)}',
              style: TextStyles.body,
            ),
          ],
          const SizedBox(height: Spacing.sm),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  ..._denominations
                      .sublist(0, 4)
                      .map(
                        (denom) => Expanded(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(
                              end: Spacing.xs,
                            ),
                            child: _CashButton(
                              label: PriceHelper.format(
                                denom,
                                languageCode: langCode,
                              ),
                              onTap: () {
                                final current =
                                    context
                                        .read<CheckoutBloc>()
                                        .state
                                        .amountPaidPiastres ??
                                    0;
                                context.read<CheckoutBloc>().add(
                                  SetAmountPaid(current + denom),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                ],
              ),
              const SizedBox(height: Spacing.xs),
              Row(
                children: [
                  ..._denominations
                      .sublist(4)
                      .map(
                        (denom) => Expanded(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(
                              end: Spacing.xs,
                            ),
                            child: _CashButton(
                              label: PriceHelper.format(
                                denom,
                                languageCode: langCode,
                              ),
                              onTap: () {
                                final current =
                                    context
                                        .read<CheckoutBloc>()
                                        .state
                                        .amountPaidPiastres ??
                                    0;
                                context.read<CheckoutBloc>().add(
                                  SetAmountPaid(current + denom),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                  Expanded(
                    child: _CashButton(
                      label: 'C',
                      onTap: () => context.read<CheckoutBloc>().add(
                        const ClearAmountPaid(),
                      ),
                      isClear: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (isPaid && change > 0) ...[
            const SizedBox(height: Spacing.md),
            Text(
              t.translate('checkout.change', languageCode: langCode),
              style: TextStyles.body,
            ),
            Text(
              PriceHelper.format(change, languageCode: langCode),
              style: TextStyles.heading2,
            ),
          ],
          const SizedBox(height: Spacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              clipBehavior: Clip.antiAlias,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
                alignment: Alignment.center,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Spacing.md),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              onPressed:
                  subtotal > 0 && state.status != CheckoutStatus.confirmed
                  ? () => context.read<CheckoutBloc>().add(const ConfirmSale())
                  : null,
              child: Text(
                t.translate('checkout.confirmSale', languageCode: langCode),
              ),
            ),
          ),
          // SizedBox(
          //   width: double.infinity,
          //   child: ElevatedButton(
          //     onPressed: subtotal > 0 && state.status != CheckoutStatus.confirmed
          //         ? () => context.read<CheckoutBloc>().add(const ConfirmSale())
          //         : null,
          //     child: Text(t.translate('checkout.confirmSale', languageCode: langCode)),
          //   ),
          // ),
        ],
      ),
    );
  }
}

class _CashButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isClear;

  const _CashButton({
    required this.label,
    required this.onTap,
    this.isClear = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(
                color: isClear
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: isClear
                  ? TextStyles.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    )
                  : TextStyles.bodySmall,
            ),
          ),
        ),
      ),
    );
  }
}
