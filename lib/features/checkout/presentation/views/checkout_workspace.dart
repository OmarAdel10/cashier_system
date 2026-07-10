import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_error.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../bloc/checkout_bloc.dart';
import '../bloc/checkout_event.dart';
import '../bloc/checkout_state.dart';
import '../widgets/cart_item_tile.dart';
import '../widgets/quick_tiles_grid.dart';

class CheckoutWorkspace extends StatelessWidget {
  const CheckoutWorkspace({super.key});

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.watch<SettingsBloc>().state.settings.languageCode;

    return BlocBuilder<CheckoutBloc, CheckoutState>(
      builder: (context, state) {
        switch (state.status) {
          case CheckoutStatus.initial:
          case CheckoutStatus.error:
            return state.status == CheckoutStatus.error
                ? AppError(
                    headline: t.translate('state.error.checkout', languageCode: langCode),
                    body: state.failure?.message ?? t.translate('state.error.checkout.body', languageCode: langCode),
                    actionLabel: t.translate('state.error.retry', languageCode: langCode),
                    onAction: () {},
                  )
                : AppEmpty(
                    headline: t.translate('state.empty.checkout', languageCode: langCode),
                    body: t.translate('state.empty.checkout.body', languageCode: langCode),
                  );
          case CheckoutStatus.ready:
          case CheckoutStatus.confirmed:
            final cart = state.cart;
            if (cart == null || cart.isEmpty) {
              return Column(
                children: [
                  Expanded(
                    child: AppEmpty(
                      headline: t.translate('state.empty.checkout', languageCode: langCode),
                      body: t.translate('state.empty.checkout.body', languageCode: langCode),
                    ),
                  ),
                  _tilesSection(context),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                  child: Text(
                    '${t.translate('checkout.cart', languageCode: langCode)} (${cart.items.length})',
                    style: TextStyles.title,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Expanded(
                  child: ListView.separated(
                    itemCount: cart.items.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: Theme.of(context).dividerColor),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return CartItemTile(
                        item: item,
                        onQuantityChanged: (qty) {
                          context.read<CheckoutBloc>().add(
                            UpdateQuantity(barcode: item.barcode, quantity: qty),
                          );
                        },
                        onRemove: () {
                          context.read<CheckoutBloc>().add(RemoveFromCart(item.barcode));
                        },
                      );
                    },
                  ),
                ),
                _tilesSection(context),
              ],
            );
        }
      },
    );
  }

  Widget _tilesSection(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
      ),
      child: const QuickTilesGrid(),
    );
  }
}
