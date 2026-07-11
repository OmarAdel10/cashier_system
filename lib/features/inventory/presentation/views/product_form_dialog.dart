import 'dart:math';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/widgets/validated_field.dart';
import '../../../../features/settings/data/services/localization_service.dart';
import '../../../../features/settings/presentation/bloc/settings_bloc.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';
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
  late bool _isQuickTile;
  late String? _tileColorHex;
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
        Navigator.of(context).pop(ProductEntity(barcode: bc, name: nm, price: pr, stock: st, isQuickTile: _isQuickTile, tileColorHex: _tileColorHex));
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
    _isQuickTile = p?.isQuickTile ?? false;
    _tileColorHex = p?.tileColorHex;
    if (p == null || !p.isQuickTile) {
      _currentQuickTileCount = context.read<InventoryBloc>().state.quickTileList.length;
    }
  }

  @override void dispose() {
    _barcodeCtrl.dispose(); _nameCtrl.dispose(); _priceCtrl.dispose(); _stockCtrl.dispose();
    _barcodeFocus.dispose(); _nameFocus.dispose(); _priceFocus.dispose(); _stockFocus.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    final langCode = context.read<SettingsBloc>().state.settings.languageCode;
    final t = LocalizationService();
    final editing = widget.product != null;
    final canBeQuickTile = editing && (widget.product?.isQuickTile ?? false) || _currentQuickTileCount < 10;
    return AlertDialog(
      title: Text(editing ? t.translate('inventory.product.edit', languageCode: langCode) : t.translate('inventory.product.new', languageCode: langCode)),
      content: SingleChildScrollView(child: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_barcodeCtrl.text.length >= 6)
          Center(child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
            child: BarcodeWidget(barcode: Barcode.code128(), data: _barcodeCtrl.text, width: 200, height: 60))),
        const SizedBox(height: 16),
        ValidatedField(
          key: _barcodeKey,
          controller: _barcodeCtrl,
          focusNode: _barcodeFocus,
          label: t.translate('inventory.product.barcode', languageCode: langCode),
          hint: t.translate('validation.barcode.hint', languageCode: langCode),
          prefixIcon: const Icon(PhosphorIcons.barcode),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          rules: [
            ValidatedFieldRule(
              message: t.translate('validation.required', languageCode: langCode),
              isValid: (v) => v.trim().isNotEmpty,
            ),
            ValidatedFieldRule(
              message: t.translate('validation.barcode.length', languageCode: langCode),
              isValid: (v) {
                final digits = v.trim();
                return digits.length >= 6 && digits.length <= 12;
              },
            ),
            ValidatedFieldRule(
              message: t.translate('validation.barcode.numeric', languageCode: langCode),
              isValid: (v) => RegExp(r'^\d+$').hasMatch(v.trim()),
            ),
          ],
          onFieldSubmitted: () => _nameFocus.requestFocus(),
        ),
        const SizedBox(height: 12),
        ValidatedField(
          key: _nameKey,
          controller: _nameCtrl,
          focusNode: _nameFocus,
          label: t.translate('inventory.product.name', languageCode: langCode),
          hint: t.translate('validation.name.hint', languageCode: langCode),
          prefixIcon: const Icon(PhosphorIcons.tag),
          rules: [
            ValidatedFieldRule(
              message: t.translate('validation.required', languageCode: langCode),
              isValid: (v) => v.trim().isNotEmpty,
            ),
          ],
          onFieldSubmitted: () => _priceFocus.requestFocus(),
        ),
        const SizedBox(height: 12),
        ValidatedField(
          key: _priceKey,
          controller: _priceCtrl,
          focusNode: _priceFocus,
          label: t.translate('inventory.product.price', languageCode: langCode),
          hint: t.translate('validation.price.hint', languageCode: langCode),
          prefixIcon: const Icon(PhosphorIcons.coins),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          rules: [
            ValidatedFieldRule(
              message: t.translate('validation.required', languageCode: langCode),
              isValid: (v) => v.trim().isNotEmpty,
            ),
            ValidatedFieldRule(
              message: t.translate('validation.price.positive', languageCode: langCode),
              isValid: (v) {
                final price = double.tryParse(v.trim());
                return price != null && price > 0;
              },
            ),
          ],
          onFieldSubmitted: () => _stockFocus.requestFocus(),
        ),
        const SizedBox(height: 12),
        ValidatedField(
          key: _stockKey,
          controller: _stockCtrl,
          focusNode: _stockFocus,
          label: t.translate('inventory.product.stock', languageCode: langCode),
          hint: t.translate('validation.stock.hint', languageCode: langCode),
          prefixIcon: const Icon(PhosphorIcons.package),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          rules: [
            ValidatedFieldRule(
              message: t.translate('validation.required', languageCode: langCode),
              isValid: (v) => v.trim().isNotEmpty,
            ),
            ValidatedFieldRule(
              message: t.translate('validation.stock.negative', languageCode: langCode),
              isValid: (v) {
                final stock = int.tryParse(v.trim());
                return stock != null && stock >= 0;
              },
            ),
          ],
          isLast: true,
          onLastFieldSubmit: _submit,
          onFieldSubmitted: () => _stockFocus.requestFocus(),
        ),
        const SizedBox(height: 16),
        if (canBeQuickTile)
          SwitchListTile(title: Text(t.translate('inventory.product.quickTile', languageCode: langCode)), subtitle: Text(t.translate('inventory.product.quickTile.subtitle', languageCode: langCode)), value: _isQuickTile, onChanged: (v) => setState(() => _isQuickTile = v), contentPadding: EdgeInsets.zero),
        if (_isQuickTile) ...[
          const SizedBox(height: 12), Text(t.translate('inventory.product.tileColor', languageCode: langCode), style: const TextStyle(fontSize: 14)), const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: _colors.map((hex) {
            final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
            final sel = _tileColorHex == hex;
            return GestureDetector(onTap: () => setState(() => _tileColorHex = hex), child: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: sel ? Border.all(color: Colors.white, width: 3) : null,
                boxShadow: sel ? [BoxShadow(color: color.withAlpha(128), blurRadius: 8)] : null),
              child: sel ? const Icon(Icons.check, color: Colors.white, size: 18) : null));
          }).toList()),
        ],
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.translate('cancel', languageCode: langCode))),
        FilledButton(onPressed: _submit, child: Text(editing ? t.translate('inventory.product.update', languageCode: langCode) : t.translate('inventory.product.add', languageCode: langCode))),
      ],
    );
  }
}
