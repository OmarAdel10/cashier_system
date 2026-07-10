import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../inventory/domain/entities/product_entity.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';
import '../../../inventory/presentation/bloc/inventory_state.dart';
import '../../domain/helpers/price_helper.dart';
import '../bloc/checkout_bloc.dart';
import '../bloc/checkout_event.dart';

class QuickTilesGrid extends StatelessWidget {
  const QuickTilesGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryBloc, InventoryState>(
      builder: (context, state) {
        final tiles = state.quickTileList;
        if (tiles.isEmpty) {
          return const SizedBox.shrink();
        }

        return Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          alignment: WrapAlignment.spaceEvenly,
          children: tiles.map((product) => _QuickTile(product: product)).toList(),
        );
      },
    );
  }
}

class _QuickTile extends StatelessWidget {
  final ProductEntity product;

  const _QuickTile({required this.product});

  @override
  Widget build(BuildContext context) {
    final bgColor = product.tileColorHex != null
        ? Color(int.parse(product.tileColorHex!.replaceFirst('#', '0xFF')))
        : Theme.of(context).colorScheme.primaryContainer;

    return InkWell(
      onTap: () {
        context.read<CheckoutBloc>().add(AddToCart(
          barcode: product.barcode,
          name: product.name,
          unitPricePiastres: PriceHelper.fromDouble(product.price),
        ));
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              product.name,
              style: TextStyles.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              PriceHelper.format(PriceHelper.fromDouble(product.price)),
              style: TextStyles.caption.copyWith(fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}
