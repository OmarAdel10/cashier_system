import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cashier_system/core/theme/spacing.dart';
import 'package:cashier_system/core/theme/text_styles.dart';
import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_order_line.dart';
import 'package:cashier_system/features/checkout/domain/helpers/price_helper.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_event.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_state.dart';
import 'package:cashier_system/features/settings/data/services/localization_service.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';

/// F&B addon ordering for an active station session.
///
/// Lists inventory products, lets the cashier add/remove lines (with
/// quantity steppers) and saves the full line list onto the station.
class StationAddonDialog extends StatefulWidget {
  const StationAddonDialog({super.key, required this.station});

  final StationEntity station;

  @override
  State<StationAddonDialog> createState() => _StationAddonDialogState();
}

class _StationAddonDialogState extends State<StationAddonDialog> {
  late final List<TableOrderLine> _lines = [...widget.station.addonLines];
  String _query = '';

  void _addProduct(ProductEntity product) {
    setState(() {
      final index = _lines.indexWhere((l) => l.barcode == product.barcode);
      if (index >= 0) {
        final existing = _lines[index];
        final next = existing.quantity + 1;
        if (next > 999) return;
        _lines[index] = TableOrderLine(
          name: existing.name,
          barcode: existing.barcode,
          quantity: existing.quantity + 1,
          unitPricePiastres: existing.unitPricePiastres,
          prepCategory: existing.prepCategory,
        );
      } else {
        _lines.add(
          TableOrderLine(
            name: product.name,
            barcode: product.barcode,
            quantity: 1,
            unitPricePiastres: (product.price * 100).round(),
            prepCategory: product.prepCategory,
          ),
        );
      }
    });
  }

  void _changeQuantity(int index, int delta) {
    setState(() {
      final line = _lines[index];
      final next = line.quantity + delta;
      if (next <= 0) {
        _lines.removeAt(index);
      } else if (next <= 999) {
        _lines[index] = TableOrderLine(
          name: line.name,
          barcode: line.barcode,
          quantity: next,
          unitPricePiastres: line.unitPricePiastres,
          prepCategory: line.prepCategory,
        );
      }
    });
  }

  int get _totalPiastres {
    var total = 0;
    for (final line in _lines) {
      total += line.quantity * line.unitPricePiastres;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.select<SettingsBloc, String>(
      (s) => s.state.settings.languageCode,
    );

    return AlertDialog(
      title: Text(t.translate('station.addon.title', languageCode: langCode)),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: InputDecoration(
                hintText: t.translate(
                  'station.addon.search',
                  languageCode: langCode,
                ),
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Expanded(
              child: BlocBuilder<InventoryBloc, InventoryState>(
                builder: (context, state) {
                  final products =
                      state.inventoryMap.values
                          .where(
                            (p) =>
                                _query.isEmpty ||
                                p.name.toLowerCase().contains(
                                  _query.toLowerCase(),
                                ),
                          )
                          .toList()
                        ..sort((a, b) => a.name.compareTo(b.name));
                  if (products.isEmpty) {
                    return Center(
                      child: Text(
                        t.translate(
                          'station.addon.empty',
                          languageCode: langCode,
                        ),
                        style: TextStyles.body,
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return ListTile(
                        dense: true,
                        title: Text(product.name, style: TextStyles.body),
                        trailing: Text(
                          PriceHelper.format(
                            (product.price * 100).round(),
                            languageCode: langCode,
                          ),
                          style: TextStyles.caption,
                        ),
                        onTap: () => _addProduct(product),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(),
            if (_lines.isEmpty)
              Text(
                t.translate('station.addon.noLines', languageCode: langCode),
                style: TextStyles.body,
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _lines.length,
                  itemBuilder: (context, index) {
                    final line = _lines[index];
                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${line.name} ×${line.quantity}',
                            style: TextStyles.body,
                          ),
                        ),
                        Text(
                          PriceHelper.format(
                            line.quantity * line.unitPricePiastres,
                            languageCode: langCode,
                          ),
                          style: TextStyles.caption,
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => _changeQuantity(index, -1),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => _changeQuantity(index, 1),
                        ),
                      ],
                    );
                  },
                ),
              ),
            const SizedBox(height: Spacing.sm),
            Text(
              t.translate(
                'station.addon.total',
                languageCode: langCode,
                params: [
                  PriceHelper.format(_totalPiastres, languageCode: langCode),
                ],
              ),
              style: TextStyles.heading3.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.translate('cancel', languageCode: langCode)),
        ),
        FilledButton(
          onPressed: () {
            context.read<StationBloc>().add(
              SetStationAddons(stationId: widget.station.id, lines: _lines),
            );
            Navigator.pop(context);
          },
          child: Text(
            t.translate('station.addon.save', languageCode: langCode),
          ),
        ),
      ],
    );
  }
}
