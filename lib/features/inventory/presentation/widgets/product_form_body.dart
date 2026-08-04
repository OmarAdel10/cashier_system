import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/widgets/validated_field.dart';
import '../../../../features/settings/data/services/localization_service.dart';
import '../../domain/entities/product_entity.dart';
import '../views/product_form_dialog.dart';
import 'barcode_label_template.dart';
import 'color_picker.dart';

class ProductFormBody extends StatelessWidget {
  final ProductEntity? product;
  final TextEditingController barcodeCtrl;
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController purchasePriceCtrl;
  final TextEditingController stockCtrl;
  final TextEditingController notesCtrl;
  final FocusNode barcodeFocus;
  final FocusNode nameFocus;
  final FocusNode priceFocus;
  final FocusNode purchasePriceFocus;
  final FocusNode stockFocus;
  final FocusNode notesFocus;
  final GlobalKey barcodeKey;
  final GlobalKey nameKey;
  final GlobalKey priceKey;
  final GlobalKey purchasePriceKey;
  final GlobalKey stockKey;
  final GlobalKey notesKey;
  final ValueNotifier<bool> isQuickTileNotifier;
  final ValueNotifier<String?> tileColorHexNotifier;
  final int currentQuickTileCount;
  final VoidCallback onSubmit;
  final String langCode;
  final LocalizationService t;
  final String storeName;
  final GlobalKey labelPreviewKey;
  final VoidCallback? onExportBarcode;
  final ValueNotifier<BarcodeAction>? barcodeActionNotifier;
  final List<String> colors;

  const ProductFormBody({
    super.key,
    required this.product,
    required this.barcodeCtrl,
    required this.nameCtrl,
    required this.priceCtrl,
    required this.purchasePriceCtrl,
    required this.stockCtrl,
    required this.notesCtrl,
    required this.barcodeFocus,
    required this.nameFocus,
    required this.priceFocus,
    required this.purchasePriceFocus,
    required this.stockFocus,
    required this.notesFocus,
    required this.barcodeKey,
    required this.nameKey,
    required this.priceKey,
    required this.purchasePriceKey,
    required this.stockKey,
    required this.notesKey,
    required this.isQuickTileNotifier,
    required this.tileColorHexNotifier,
    required this.currentQuickTileCount,
    required this.onSubmit,
    required this.langCode,
    required this.t,
    required this.storeName,
    required this.labelPreviewKey,
    this.onExportBarcode,
    this.barcodeActionNotifier,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final editing = product != null;
    final canBeQuickTile =
        editing && (product?.isQuickTile ?? false) ||
        currentQuickTileCount < 10;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListenableBuilder(
          listenable: Listenable.merge([
            barcodeCtrl,
            nameCtrl,
            priceCtrl,
            stockCtrl,
            notesCtrl,
          ]),
          builder: (context, _) {
            final showBarcode = barcodeCtrl.text.length >= 6;
            if (!showBarcode) return const SizedBox.shrink();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: RepaintBoundary(
                    key: labelPreviewKey,
                    child: BarcodeLabelTemplate(
                      product: ProductEntity(
                        barcode: barcodeCtrl.text,
                        name: nameCtrl.text,
                        price: double.tryParse(priceCtrl.text) ?? 0,
                        stock: int.tryParse(stockCtrl.text) ?? 0,
                        notes: notesCtrl.text,
                        isQuickTile: product?.isQuickTile ?? false,
                        tileColorHex: product?.tileColorHex,
                      ),
                      storeName: storeName,
                      langCode: langCode,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (onExportBarcode != null &&
                    barcodeActionNotifier != null) ...[
                  ValueListenableBuilder<BarcodeAction>(
                    valueListenable: barcodeActionNotifier!,
                    builder: (context, action, _) {
                      return Center(
                        child: SegmentedButton<BarcodeAction>(
                          segments: [
                            ButtonSegment(
                              value: BarcodeAction.savePng,
                              icon: Icon(
                                PhosphorIcons.downloadSimple,
                                size: 16,
                              ),
                              label: Text(
                                t.translate(
                                  'inventory.product.barcode.format.png',
                                  languageCode: langCode,
                                ),
                              ),
                            ),
                            ButtonSegment(
                              value: BarcodeAction.printDirect,
                              icon: Icon(PhosphorIcons.printer, size: 16),
                              label: Text(
                                  t.translate(
                                  'inventory.product.barcode.format.print',
                                  languageCode: langCode,
                                ),
                              ),
                            ),
                          ],
                          selected: {action},
                          onSelectionChanged: (selected) {
                            barcodeActionNotifier!.value = selected.first;
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: onExportBarcode,
                      icon: ValueListenableBuilder<BarcodeAction>(
                        valueListenable: barcodeActionNotifier!,
                        builder: (context, action, _) {
                          return Icon(
                            action == BarcodeAction.savePng
                                ? PhosphorIcons.downloadSimple
                                : PhosphorIcons.printer,
                            size: 16,
                          );
                        },
                      ),
                      label: ValueListenableBuilder<BarcodeAction>(
                        valueListenable: barcodeActionNotifier!,
                        builder: (context, action, _) {
                          return Text(
                            action == BarcodeAction.savePng
                                ? t.translate(
                                    'inventory.product.saveBarcode',
                                    languageCode: langCode,
                                  )
                                : t.translate(
                                    'inventory.product.printBarcode',
                                    languageCode: langCode,
                                  ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else if (onExportBarcode != null) ...[
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: onExportBarcode,
                      icon: const Icon(PhosphorIcons.downloadSimple, size: 16),
                      label: Text(
                        t.translate(
                          'inventory.product.saveBarcode',
                          languageCode: langCode,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            );
          },
        ),
        ValidatedField(
          autoValidate: editing,
          key: barcodeKey,
          controller: barcodeCtrl,
          focusNode: barcodeFocus,
          label: t.translate(
            'inventory.product.barcode',
            languageCode: langCode,
          ),
          hint: t.translate('validation.barcode.hint', languageCode: langCode),
          prefixIcon: const Icon(PhosphorIcons.barcode),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          rules: [
            ValidatedFieldRule(
              message: t.translate(
                'validation.required',
                languageCode: langCode,
              ),
              isValid: (v) => v.trim().isNotEmpty,
            ),
            ValidatedFieldRule(
              message: t.translate(
                'validation.barcode.length',
                languageCode: langCode,
              ),
              isValid: (v) {
                final digits = v.trim();
                return digits.length >= 6 && digits.length <= 12;
              },
            ),
            ValidatedFieldRule(
              message: t.translate(
                'validation.barcode.numeric',
                languageCode: langCode,
              ),
              isValid: (v) => RegExp(r'^\d+$').hasMatch(v.trim()),
            ),
          ],
          onFieldSubmitted: () => nameFocus.requestFocus(),
        ),
        const SizedBox(height: 12),
        ValidatedField(
          autoValidate: editing,
          key: nameKey,
          controller: nameCtrl,
          focusNode: nameFocus,
          label: t.translate('inventory.product.name', languageCode: langCode),
          hint: t.translate('validation.name.hint', languageCode: langCode),
          prefixIcon: const Icon(PhosphorIcons.tag),
          rules: [
            ValidatedFieldRule(
              message: t.translate(
                'validation.required',
                languageCode: langCode,
              ),
              isValid: (v) => v.trim().isNotEmpty,
            ),
          ],
          onFieldSubmitted: () => purchasePriceFocus.requestFocus(),
        ),
        const SizedBox(height: 12),
        ValidatedField(
          autoValidate: editing,
          key: purchasePriceKey,
          controller: purchasePriceCtrl,
          focusNode: purchasePriceFocus,
          label: t.translate(
            'inventory.product.purchasePrice',
            languageCode: langCode,
          ),
          hint: t.translate(
            'validation.purchasePrice.hint',
            languageCode: langCode,
          ),
          prefixIcon: const Icon(PhosphorIcons.wallet),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          rules: [
            ValidatedFieldRule(
              message: t.translate(
                'validation.required',
                languageCode: langCode,
              ),
              isValid: (v) => v.trim().isNotEmpty,
            ),
            ValidatedFieldRule(
              message: t.translate(
                'validation.purchasePrice.negative',
                languageCode: langCode,
              ),
              isValid: (v) {
                final purchasePrice = double.tryParse(v.trim());
                return purchasePrice != null && purchasePrice >= 0;
              },
            ),
          ],
          onFieldSubmitted: () => priceFocus.requestFocus(),
        ),
        const SizedBox(height: 12),
        ValidatedField(
          autoValidate: editing,
          key: priceKey,
          controller: priceCtrl,
          focusNode: priceFocus,
          label: t.translate('inventory.product.price', languageCode: langCode),
          hint: t.translate('validation.price.hint', languageCode: langCode),
          prefixIcon: const Icon(PhosphorIcons.coins),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          rules: [
            ValidatedFieldRule(
              message: t.translate(
                'validation.required',
                languageCode: langCode,
              ),
              isValid: (v) => v.trim().isNotEmpty,
            ),
            ValidatedFieldRule(
              message: t.translate(
                'validation.price.positive',
                languageCode: langCode,
              ),
              isValid: (v) {
                final price = double.tryParse(v.trim());
                return price != null && price > 0;
              },
            ),
          ],
          onFieldSubmitted: () => stockFocus.requestFocus(),
        ),
        const SizedBox(height: 12),
        ValidatedField(
          autoValidate: editing,
          key: stockKey,
          controller: stockCtrl,
          focusNode: stockFocus,
          label: t.translate('inventory.product.stock', languageCode: langCode),
          hint: t.translate('validation.stock.hint', languageCode: langCode),
          prefixIcon: const Icon(PhosphorIcons.package),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          rules: [
            ValidatedFieldRule(
              message: t.translate(
                'validation.required',
                languageCode: langCode,
              ),
              isValid: (v) => v.trim().isNotEmpty,
            ),
            ValidatedFieldRule(
              message: t.translate(
                'validation.stock.negative',
                languageCode: langCode,
              ),
              isValid: (v) {
                final stock = int.tryParse(v.trim());
                return stock != null && stock >= 0;
              },
            ),
          ],
          isLast: true,
          onLastFieldSubmit: onSubmit,
          onFieldSubmitted: () => stockFocus.requestFocus(),
        ),
        const SizedBox(height: 12),
        ValidatedField(
          autoValidate: editing,
          key: notesKey,
          controller: notesCtrl,
          focusNode: notesFocus,
          label: t.translate('inventory.product.notes', languageCode: langCode),
          hint: t.translate(
            'inventory.product.notes.hint',
            languageCode: langCode,
          ),
          prefixIcon: const Icon(PhosphorIcons.notePencil),
          rules: [],
          onFieldSubmitted: () => stockFocus.requestFocus(),
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<bool>(
          valueListenable: isQuickTileNotifier,
          builder: (context, isQuickTile, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (canBeQuickTile)
                  SwitchListTile(
                    title: Text(
                      t.translate(
                        'inventory.product.quickTile',
                        languageCode: langCode,
                      ),
                    ),
                    subtitle: Text(
                      t.translate(
                        'inventory.product.quickTile.subtitle',
                        languageCode: langCode,
                      ),
                    ),
                    value: isQuickTile,
                    onChanged: (v) => isQuickTileNotifier.value = v,
                    contentPadding: EdgeInsets.zero,
                  ),
                if (isQuickTile) ...[
                  const SizedBox(height: 12),
                  Text(
                    t.translate(
                      'inventory.product.tileColor',
                      languageCode: langCode,
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<String?>(
                    valueListenable: tileColorHexNotifier,
                    builder: (context, tileColorHex, _) {
                      return ColorPicker(
                        colors: colors,
                        selectedHex: tileColorHex,
                        onColorTap: (hex) => tileColorHexNotifier.value = hex,
                      );
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
