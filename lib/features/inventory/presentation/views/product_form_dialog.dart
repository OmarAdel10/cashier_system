import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/validated_field.dart';
import '../../../../features/settings/data/services/localization_service.dart';
import '../../../../features/settings/presentation/bloc/settings_bloc.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';
import '../widgets/product_form_body.dart';
import '../../domain/entities/product_entity.dart';

class ProductFormDialog extends StatefulWidget {
  final ProductEntity? product;
  const ProductFormDialog({super.key, this.product});

  @override State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  late final TextEditingController _barcodeCtrl, _nameCtrl, _priceCtrl, _stockCtrl;
  late final FocusNode _nameFocus, _priceFocus, _stockFocus, _barcodeFocus;
  late final GlobalKey<ValidatedFieldState> _barcodeKey, _nameKey, _priceKey, _stockKey;
  late final ValueNotifier<bool> _isQuickTileNotifier;
  late final ValueNotifier<String?> _tileColorHexNotifier;
  int _currentQuickTileCount = 0;

  static const _colors = ['#007ACC', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6', '#EC4899', '#14B8A6', '#F97316', '#E11D48', '#0284C7'];

  String _genBarcode() {
    final r = Random();
    return '${r.nextInt(9) + 1}${List.generate(11, (_) => r.nextInt(10)).join()}';
  }

  void _submit() {
    _barcodeKey.currentState?.validate();
    _nameKey.currentState?.validate();
    _priceKey.currentState?.validate();
    _stockKey.currentState?.validate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_barcodeKey.currentState?.isValid == true &&
          _nameKey.currentState?.isValid == true &&
          _priceKey.currentState?.isValid == true &&
          _stockKey.currentState?.isValid == true) {
        final bc = _barcodeCtrl.text.trim();
        final nm = _nameCtrl.text.trim();
        final pr = double.tryParse(_priceCtrl.text) ?? 0.0;
        final st = int.tryParse(_stockCtrl.text) ?? 0;
        Navigator.of(context).pop(ProductEntity(barcode: bc, name: nm, price: pr, stock: st, isQuickTile: _isQuickTileNotifier.value, tileColorHex: _tileColorHexNotifier.value));
      }
    });
  }

  @override void initState() {
    super.initState();
    final p = widget.product;
    _barcodeKey = GlobalKey();
    _nameKey = GlobalKey();
    _priceKey = GlobalKey();
    _stockKey = GlobalKey();
    _barcodeFocus = FocusNode();
    _nameFocus = FocusNode();
    _priceFocus = FocusNode();
    _stockFocus = FocusNode();
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? _genBarcode());
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _priceCtrl = TextEditingController(text: p != null ? p.price.toStringAsFixed(2) : '');
    _stockCtrl = TextEditingController(text: p != null ? p.stock.toString() : '');
    _isQuickTileNotifier = ValueNotifier(p?.isQuickTile ?? false);
    _tileColorHexNotifier = ValueNotifier<String?>(p?.tileColorHex);
    if (p == null) {
      final tiles = context.read<InventoryBloc>().state.quickTileList;
      for (final tile in tiles.reversed) {
        if (tile.tileColorHex != null) {
          final lastIdx = _colors.indexOf(tile.tileColorHex!);
          if (lastIdx != -1) {
            _tileColorHexNotifier.value = _colors[(lastIdx + 1) % _colors.length];
          }
          break;
        }
      }
    }
    if (p == null || !p.isQuickTile) {
      _currentQuickTileCount = context.read<InventoryBloc>().state.quickTileList.length;
    }
  }

  @override void dispose() {
    _isQuickTileNotifier.dispose();
    _tileColorHexNotifier.dispose();
    _barcodeCtrl.dispose(); _nameCtrl.dispose(); _priceCtrl.dispose(); _stockCtrl.dispose();
    _barcodeFocus.dispose(); _nameFocus.dispose(); _priceFocus.dispose(); _stockFocus.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    final langCode = context.select((SettingsBloc b) => b.state.settings.languageCode);
    final t = LocalizationService();
    final editing = widget.product != null;
    return AlertDialog(
      title: Text(editing ? t.translate('inventory.product.edit', languageCode: langCode) : t.translate('inventory.product.new', languageCode: langCode)),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 360,
          child: ProductFormBody(
            product: widget.product,
            barcodeCtrl: _barcodeCtrl,
            nameCtrl: _nameCtrl,
            priceCtrl: _priceCtrl,
            stockCtrl: _stockCtrl,
            barcodeFocus: _barcodeFocus,
            nameFocus: _nameFocus,
            priceFocus: _priceFocus,
            stockFocus: _stockFocus,
            barcodeKey: _barcodeKey,
            nameKey: _nameKey,
            priceKey: _priceKey,
            stockKey: _stockKey,
            isQuickTileNotifier: _isQuickTileNotifier,
            tileColorHexNotifier: _tileColorHexNotifier,
            currentQuickTileCount: _currentQuickTileCount,
            onSubmit: _submit,
            langCode: langCode,
            t: t,
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.translate('cancel', languageCode: langCode))),
        FilledButton(onPressed: _submit, child: Text(editing ? t.translate('inventory.product.update', languageCode: langCode) : t.translate('inventory.product.add', languageCode: langCode))),
      ],
    );
  }
}
