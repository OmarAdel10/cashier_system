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

  static const _denominations = [1000, 2000, 5000, 10000, 20000];

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.watch<SettingsBloc>().state.settings.languageCode;
    final subtotal = context.watch<CheckoutBloc>().state.subtotalPiastres;
    final change = context.watch<CheckoutBloc>().state.changePiastres;
    final isPaid = context.watch<CheckoutBloc>().state.isPaid;

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
          const SizedBox(height: Spacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _denominations.map((denom) {
                final qty = subtotal > 0 ? (denom / subtotal).ceil() : 1;
                final suggested = denom * qty;
                return _CashButton(
                  label: PriceHelper.format(denom),
                  onTap: () {
                    context.read<CheckoutBloc>().add(SetAmountPaid(suggested));
                  },
                );
              }).toList(),
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

  const _CashButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.sm),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyles.bodySmall),
      ),
    );
  }
}
