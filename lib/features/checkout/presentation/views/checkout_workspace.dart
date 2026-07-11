import 'package:cashier_system/core/theme/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_error.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../bloc/checkout_bloc.dart';
import '../bloc/checkout_event.dart';
import '../bloc/checkout_state.dart';
import '../widgets/cart_table_widget.dart';
import '../widgets/checkout_confirmation_dialog.dart';
import '../widgets/quick_tiles_grid.dart';

class CheckoutWorkspace extends StatelessWidget {
  const CheckoutWorkspace({super.key});

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.watch<SettingsBloc>().state.settings.languageCode;

    return BlocListener<CheckoutBloc, CheckoutState>(
      listener: (context, state) {
        if (state.status == CheckoutStatus.confirmed) {
          final code = context.read<SettingsBloc>().state.settings.languageCode;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => CheckoutConfirmationDialog(
              isSuccess: true,
              message: t.translate(
                'checkout.saleConfirmed',
                languageCode: code,
              ),
            ),
          ).then((_) {
            if (context.mounted) {
              context.read<CheckoutBloc>().add(const ClearCart());
            }
          });
        }
      },
      child: BlocBuilder<CheckoutBloc, CheckoutState>(
        builder: (context, state) {
          switch (state.status) {
            case CheckoutStatus.initial:
            case CheckoutStatus.error:
              return state.status == CheckoutStatus.error
                  ? AppError(
                      headline: t.translate(
                        'state.error.checkout',
                        languageCode: langCode,
                      ),
                      body:
                          state.failure?.message ??
                          t.translate(
                            'state.error.checkout.body',
                            languageCode: langCode,
                          ),
                      actionLabel: t.translate(
                        'state.error.retry',
                        languageCode: langCode,
                      ),
                      onAction: () {},
                    )
                  : AppEmpty(
                      headline: t.translate(
                        'state.empty.checkout',
                        languageCode: langCode,
                      ),
                      body: t.translate(
                        'state.empty.checkout.body',
                        languageCode: langCode,
                      ),
                    );
            case CheckoutStatus.ready:
            case CheckoutStatus.confirmed:
              final cart = state.cart;
              if (cart == null || cart.isEmpty) {
                return Column(
                  children: [
                    Expanded(
                      child: AppEmpty(
                        headline: t.translate(
                          'state.empty.checkout',
                          languageCode: langCode,
                        ),
                        body: t.translate(
                          'state.empty.checkout.body',
                          languageCode: langCode,
                        ),
                      ),
                    ),
                    Center(child: const QuickTilesGrid()),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SectionCard(
                      title: t.translate(
                        'checkout.cart',
                        languageCode: langCode,
                      ),
                      padding: EdgeInsets.zero,
                      mainAxisSize: MainAxisSize.max,
                      childFit: FlexFit.loose,
                      child: CartTableWidget(
                        items: cart.items,
                        onQuantityChanged: (barcode, qty) {
                          context.read<CheckoutBloc>().add(
                            UpdateQuantity(barcode: barcode, quantity: qty),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  Center(child: const QuickTilesGrid()),
                ],
              );
          }
        },
      ),
    );
  }
}
