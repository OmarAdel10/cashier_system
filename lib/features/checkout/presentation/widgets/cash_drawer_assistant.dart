import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../domain/helpers/price_helper.dart';
import '../bloc/checkout_bloc.dart';
import '../bloc/checkout_event.dart';

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
            PriceHelper.format(subtotal),
            style: TextStyles.heading1,
          ),
          if (amountPaid != null) ...[
            const SizedBox(height: Spacing.xs),
            Text(
              '${t.translate('checkout.paid', languageCode: langCode)}: ${PriceHelper.format(amountPaid)}',
              style: TextStyles.body,
            ),
          ],
          const SizedBox(height: Spacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ..._denominations.map((denom) => Padding(
                  padding: const EdgeInsets.only(right: Spacing.sm),
                  child: _CashButton(
                    label: PriceHelper.format(denom),
                    onTap: () {
                      final current = context.read<CheckoutBloc>().state.amountPaidPiastres ?? 0;
                      context.read<CheckoutBloc>().add(SetAmountPaid(current + denom));
                    },
                  ),
                )),
                Padding(
                  padding: const EdgeInsets.only(right: Spacing.sm),
                  child: _CashButton(
                    label: 'C',
                    onTap: () {
                      context.read<CheckoutBloc>().add(const ClearAmountPaid());
                    },
                    isClear: true,
                  ),
                ),
              ],
            ),
          ),
          if (isPaid && change > 0) ...[
            const SizedBox(height: Spacing.md),
            Text(
              t.translate('checkout.change', languageCode: langCode),
              style: TextStyles.body,
            ),
            Text(
              PriceHelper.format(change),
              style: TextStyles.heading2,
            ),
          ],
          const SizedBox(height: Spacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isPaid && subtotal > 0
                  ? () => context.read<CheckoutBloc>().add(const ConfirmSale())
                  : null,
              child: Text(t.translate('checkout.confirmSale', languageCode: langCode)),
            ),
          ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.sm),
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
              ? TextStyles.bodySmall.copyWith(color: Theme.of(context).colorScheme.error)
              : TextStyles.bodySmall,
        ),
      ),
    );
  }
}
