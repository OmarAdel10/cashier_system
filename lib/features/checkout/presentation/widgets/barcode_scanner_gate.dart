import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../domain/helpers/price_helper.dart';
import '../bloc/checkout_bloc.dart';
import '../bloc/checkout_event.dart';

class BarcodeScannerGate extends StatefulWidget {
  final Widget child;

  const BarcodeScannerGate({super.key, required this.child});

  @override
  State<BarcodeScannerGate> createState() => _BarcodeScannerGateState();
}

class _BarcodeScannerGateState extends State<BarcodeScannerGate> {
  final _buffer = StringBuffer();
  final _focusNode = FocusNode(debugLabel: 'barcodeScanner');
  DateTime _lastKeyTime = DateTime.now();
  Timer? _resetTimer;

  static const _interCharGap = Duration(milliseconds: 20);
  static const _resetTimeout = Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _processBuffer();
      return;
    }
    final char = event.character;
    if (char == null || char.isEmpty) return;

    final now = DateTime.now();
    final gap = now.difference(_lastKeyTime);
    _lastKeyTime = now;

    if (gap > _interCharGap && _buffer.isNotEmpty) {
      _buffer.clear();
    }

    _buffer.write(char);
    _resetTimer?.cancel();
    _resetTimer = Timer(_resetTimeout, _buffer.clear);
  }

  void _processBuffer() {
    _resetTimer?.cancel();
    final barcode = _buffer.toString().trim();
    _buffer.clear();

    if (barcode.isEmpty) return;

    final inventoryState = context.read<InventoryBloc>().state;
    final product = inventoryState.inventoryMap[barcode];

    if (product != null) {
      context.read<CheckoutBloc>().add(AddToCart(
        barcode: product.barcode,
        name: product.name,
        unitPricePiastres: PriceHelper.fromDouble(product.price),
      ));
    } else {
      final t = LocalizationService();
      final langCode = context.read<SettingsBloc>().state.settings.languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.translate('checkout.barcodeNotFound', languageCode: langCode, params: [barcode])),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        behavior: HitTestBehavior.translucent,
        child: widget.child,
      ),
    );
  }
}
