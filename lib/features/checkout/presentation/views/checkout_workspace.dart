import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/business/business_type.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_error.dart';
import '../../../inventory/domain/entities/product_entity.dart';
import '../../../receipts/presentation/bloc/receipts_bloc.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../domain/helpers/price_helper.dart';
import '../bloc/checkout_bloc.dart';
import '../bloc/checkout_event.dart';
import '../bloc/checkout_state.dart';
import '../widgets/cart_table_widget.dart';
import '../widgets/checkout_confirmation_dialog.dart';
import '../widgets/product_category_grid.dart';
import '../widgets/quick_tiles_grid.dart';

class CheckoutWorkspace extends StatefulWidget {
  const CheckoutWorkspace({super.key});

  @override
  State<CheckoutWorkspace> createState() => _CheckoutWorkspaceState();
}

class _CheckoutWorkspaceState extends State<CheckoutWorkspace> {
  final _gridFocusNode = FocusNode(debugLabel: 'checkoutGrid');
  final _gridKey = GlobalKey<ProductCategoryGridState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final businessType = BusinessType.fromId(
        context.read<SettingsBloc>().state.settings.businessType,
      );
      if (businessType.isGridMode && !businessType.isTimeBilling) {
        _gridFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _gridFocusNode.dispose();
    super.dispose();
  }

  void _onGridProductTap(ProductEntity product) {
    context.read<CheckoutBloc>().add(
      AddToCart(
        barcode: product.barcode,
        name: product.name,
        unitPricePiastres: PriceHelper.fromDouble(product.price),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.select<SettingsBloc, String>(
      (s) => s.state.settings.languageCode,
    );
    final businessType = BusinessType.fromId(
      context.select<SettingsBloc, String>(
        (s) => s.state.settings.businessType,
      ),
    );

    return BlocListener<CheckoutBloc, CheckoutState>(
      listener: (context, state) {
        if (state.status == CheckoutStatus.confirmed) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => BlocProvider.value(
              value: context.read<ReceiptsBloc>(),
              child: const CheckoutConfirmationDialog(),
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
                      onAction: () {
                        context.read<CheckoutBloc>().add(const ClearCart());
                      },
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
              if (businessType.isGridMode && !businessType.isTimeBilling) {
                return _buildGridLayout(
                  context,
                  t: t,
                  langCode: langCode,
                  businessType: businessType,
                );
              }
              return _buildScannerLayout(
                context,
                t: t,
                langCode: langCode,
                state: state,
              );
          }
        },
      ),
    );
  }

  Widget _buildGridLayout(
    BuildContext context, {
    required LocalizationService t,
    required String langCode,
    required BusinessType businessType,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 2,
          child: SectionCard(
            title: t.translate('checkout.cart', languageCode: langCode),
            padding: EdgeInsets.zero,
            mainAxisSize: MainAxisSize.max,
            childFit: FlexFit.loose,
            child: BlocBuilder<CheckoutBloc, CheckoutState>(
              builder: (context, state) {
                return CartTableWidget(
                  items: state.cart?.items ?? const [],
                  onQuantityChanged: (barcode, qty) {
                    context.read<CheckoutBloc>().add(
                      UpdateQuantity(barcode: barcode, quantity: qty),
                    );
                  },
                );
              },
            ),
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          flex: 5,
          child: _buildGridPane(context, businessType: businessType),
        ),
      ],
    );
  }

  Widget _buildGridPane(
    BuildContext context, {
    required BusinessType businessType,
  }) {
    final favoritesEnabled =
        businessType.favoritesEnabled &&
        context.select<SettingsBloc, bool>(
          (s) => s.state.settings.favoritesStripEnabled,
        );

    final shortcuts = <ShortcutActivator, Intent>{};
    if (favoritesEnabled) {
      shortcuts[const SingleActivator(LogicalKeyboardKey.digit1, alt: true)] =
          const _FavoritesSlotIntent(0);
      shortcuts[const SingleActivator(LogicalKeyboardKey.digit2, alt: true)] =
          const _FavoritesSlotIntent(1);
      shortcuts[const SingleActivator(LogicalKeyboardKey.digit3, alt: true)] =
          const _FavoritesSlotIntent(2);
      shortcuts[const SingleActivator(LogicalKeyboardKey.digit4, alt: true)] =
          const _FavoritesSlotIntent(3);
      shortcuts[const SingleActivator(LogicalKeyboardKey.digit5, alt: true)] =
          const _FavoritesSlotIntent(4);
      shortcuts[const SingleActivator(LogicalKeyboardKey.digit6, alt: true)] =
          const _FavoritesSlotIntent(5);
      shortcuts[const SingleActivator(LogicalKeyboardKey.digit7, alt: true)] =
          const _FavoritesSlotIntent(6);
      shortcuts[const SingleActivator(LogicalKeyboardKey.digit8, alt: true)] =
          const _FavoritesSlotIntent(7);
      shortcuts[const SingleActivator(LogicalKeyboardKey.digit9, alt: true)] =
          const _FavoritesSlotIntent(8);
      shortcuts[const SingleActivator(LogicalKeyboardKey.digit0, alt: true)] =
          const _FavoritesSlotIntent(9);
    }

    return FocusTraversalGroup(
      child: Shortcuts(
        shortcuts: shortcuts,
        child: Actions(
          actions: {
            _FavoritesSlotIntent: CallbackAction<_FavoritesSlotIntent>(
              onInvoke: (intent) {
                _gridKey.currentState?.focusIndexForAlt(
                  _gridFocusNode,
                  intent.slot,
                );
                return null;
              },
            ),
          },
          child: SectionCard(
            padding: EdgeInsets.zero,
            mainAxisSize: MainAxisSize.max,
            child: ProductCategoryGrid(
              key: _gridKey,
              businessType: businessType,
              onProductTap: _onGridProductTap,
              gridFocus: _gridFocusNode,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScannerLayout(
    BuildContext context, {
    required LocalizationService t,
    required String langCode,
    required CheckoutState state,
  }) {
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
            title: t.translate('checkout.cart', languageCode: langCode),
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
}

class _FavoritesSlotIntent extends Intent {
  final int slot;

  const _FavoritesSlotIntent(this.slot);
}
