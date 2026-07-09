import 'dart:math';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../domain/entities/product_entity.dart';

class ProductFormDialog extends StatefulWidget {
  final ProductEntity? product;
  const ProductFormDialog({super.key, this.product});

  @override State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  late final TextEditingController _barcodeCtrl, _nameCtrl, _priceCtrl, _stockCtrl;
  late bool _isQuickTile;
  late String? _tileColorHex;

  static const _colors = ['#007ACC', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6', '#EC4899', '#14B8A6', '#F97316'];

  String _genBarcode() {
    final r = Random();
    return '${r.nextInt(9) + 1}${List.generate(11, (_) => r.nextInt(10)).join()}';
  }

  @override void initState() {
    super.initState();
    final p = widget.product;
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? _genBarcode());
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _priceCtrl = TextEditingController(text: p != null ? p.price.toStringAsFixed(2) : '');
    _stockCtrl = TextEditingController(text: p != null ? p.stock.toString() : '');
    _isQuickTile = p?.isQuickTile ?? false;
    _tileColorHex = p?.tileColorHex;
  }

  @override void dispose() {
    _barcodeCtrl.dispose(); _nameCtrl.dispose(); _priceCtrl.dispose(); _stockCtrl.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    final editing = widget.product != null;
    return AlertDialog(
      title: Text(editing ? 'Edit Product' : 'New Product'),
      content: SingleChildScrollView(child: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_barcodeCtrl.text.length >= 6)
          Center(child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
            child: BarcodeWidget(barcode: Barcode.code128(), data: _barcodeCtrl.text, width: 200, height: 60))),
        const SizedBox(height: 16),
        TextField(controller: _barcodeCtrl, decoration: const InputDecoration(labelText: 'Barcode', prefixIcon: Icon(PhosphorIcons.barcode)), keyboardType: TextInputType.number, maxLength: 12),
        const SizedBox(height: 12),
        TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Product Name', prefixIcon: Icon(PhosphorIcons.tag))),
        const SizedBox(height: 12),
        TextField(controller: _priceCtrl, decoration: const InputDecoration(labelText: 'Price', prefixIcon: Icon(PhosphorIcons.coins)), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        const SizedBox(height: 12),
        TextField(controller: _stockCtrl, decoration: const InputDecoration(labelText: 'Stock', prefixIcon: Icon(PhosphorIcons.package)), keyboardType: TextInputType.number),
        const SizedBox(height: 16),
        SwitchListTile(title: const Text('Quick Tile'), subtitle: const Text('Show on quick-access grid'), value: _isQuickTile, onChanged: (v) => setState(() => _isQuickTile = v), contentPadding: EdgeInsets.zero),
        if (_isQuickTile) ...[
          const SizedBox(height: 12), const Text('Tile Color', style: TextStyle(fontSize: 14)), const SizedBox(height: 8),
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
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          final bc = _barcodeCtrl.text.trim(), nm = _nameCtrl.text.trim();
          final pr = double.tryParse(_priceCtrl.text) ?? 0.0, st = int.tryParse(_stockCtrl.text) ?? 0;
          if (bc.isEmpty || nm.isEmpty) return;
          Navigator.of(context).pop(ProductEntity(barcode: bc, name: nm, price: pr, stock: st, isQuickTile: _isQuickTile, tileColorHex: _tileColorHex));
        }, child: Text(editing ? 'Update' : 'Add')),
      ],
    );
  }
}
