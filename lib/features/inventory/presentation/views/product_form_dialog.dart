import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/business/business_type.dart';
import '../../../../core/printing/print_service.dart';
import '../../../../core/widgets/validated_field.dart';
import '../../../../features/settings/data/services/localization_service.dart';
import '../../../../features/settings/presentation/bloc/settings_bloc.dart';
import '../../../../features/settings/presentation/bloc/settings_event.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';
import '../bloc/barcode_export_cubit.dart';
import '../../data/services/barcode_export_service.dart';
import '../widgets/product_form_body.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/helpers/barcode_generator.dart';

enum BarcodeAction { savePng, printDirect }

class ProductFormDialog extends StatefulWidget {
  final ProductEntity? product;
  const ProductFormDialog({super.key, this.product});

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  late final TextEditingController _barcodeCtrl,
      _nameCtrl,
      _priceCtrl,
      _purchasePriceCtrl,
      _stockCtrl,
      _notesCtrl;
  late final FocusNode _nameFocus,
      _priceFocus,
      _purchasePriceFocus,
      _stockFocus,
      _barcodeFocus,
      _notesFocus;
  late final GlobalKey<ValidatedFieldState> _barcodeKey,
      _nameKey,
      _priceKey,
      _purchasePriceKey,
      _stockKey,
      _notesKey;
  late final GlobalKey _labelPreviewKey;
  late final ValueNotifier<bool> _isQuickTileNotifier;
  late final ValueNotifier<String?> _tileColorHexNotifier;
  late final ValueNotifier<String?> _categoryNotifier;
  late final ValueNotifier<BarcodeAction> _barcodeActionNotifier;
  late final BarcodeExportCubit _exportCubit;
  int _currentQuickTileCount = 0;

  static const _colors = [
    '#007ACC',
    '#10B981',
    '#F59E0B',
    '#EF4444',
    '#8B5CF6',
    '#EC4899',
    '#14B8A6',
    '#F97316',
    '#E11D48',
    '#0284C7',
  ];

  String _genBarcode() {
    final r = Random();
    return '${r.nextInt(9) + 1}${List.generate(11, (_) => r.nextInt(10)).join()}';
  }

  void _submit() {
    final mode = BusinessType.fromId(
      context.read<SettingsBloc>().state.settings.businessType,
    );
    _nameKey.currentState?.validate();
    _purchasePriceKey.currentState?.validate();
    _priceKey.currentState?.validate();
    if (mode.barcodesEnabled) _barcodeKey.currentState?.validate();
    if (mode.stockEnabled) _stockKey.currentState?.validate();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final nameOk = _nameKey.currentState?.isValid == true;
      final purchasePriceOk = _purchasePriceKey.currentState?.isValid == true;
      final priceOk = _priceKey.currentState?.isValid == true;
      final barcodeOk =
          !mode.barcodesEnabled || _barcodeKey.currentState?.isValid == true;
      final stockOk =
          !mode.stockEnabled || _stockKey.currentState?.isValid == true;
      if (nameOk && purchasePriceOk && priceOk && barcodeOk && stockOk) {
        final bc = mode.barcodesEnabled
            ? _barcodeCtrl.text.trim()
            : widget.product?.barcode ?? generateAutoBarcode();
        final nm = _nameCtrl.text.trim();
        final pr = double.tryParse(_priceCtrl.text) ?? 0.0;
        final pp = double.tryParse(_purchasePriceCtrl.text) ?? 0.0;
        final st = mode.stockEnabled
            ? int.tryParse(_stockCtrl.text) ?? 0
            : widget.product?.stock ?? 0;
        final nt = _notesCtrl.text.trim();
        final ct = _categoryNotifier.value;
        if (pp > pr) {
          final t = LocalizationService();
          final langCode = context
              .read<SettingsBloc>()
              .state
              .settings
              .languageCode;
          final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(
                t.translate(
                  'inventory.product.purchasePriceWarningTitle',
                  languageCode: langCode,
                ),
              ),
              content: Text(
                t.translate(
                  'inventory.product.purchasePriceWarning',
                  languageCode: langCode,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(t.translate('cancel', languageCode: langCode)),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(
                    t.translate(
                      'inventory.product.purchasePriceWarning.proceed',
                      languageCode: langCode,
                    ),
                  ),
                ),
              ],
            ),
          );
          if (proceed != true || !mounted) return;
        }
        Navigator.of(context).pop(
          ProductEntity(
            barcode: bc,
            name: nm,
            price: pr,
            purchasePrice: pp,
            stock: st,
            isQuickTile: _isQuickTileNotifier.value,
            tileColorHex: _tileColorHexNotifier.value,
            category: ct == null || ct.isEmpty ? null : ct,
            notes: nt,
          ),
        );
      }
    });
  }

  void _handleBarcodeAction() {
    final action = _barcodeActionNotifier.value;
    if (action == BarcodeAction.savePng) {
      _exportBarcode();
    } else {
      _printBarcodeDirect();
    }
  }

  void _exportBarcode() {
    final downloadPath = context
        .read<SettingsBloc>()
        .state
        .settings
        .exportDirectoryPath;
    if (downloadPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService().translate(
              'barcodeDownloadPath.setFirst',
              languageCode: context
                  .read<SettingsBloc>()
                  .state
                  .settings
                  .languageCode,
            ),
          ),
        ),
      );
      return;
    }
    _exportCubit.export(
      repaintKey: _labelPreviewKey,
      barcode: _barcodeCtrl.text.trim(),
      downloadPath: downloadPath,
    );
  }

  void _printBarcodeDirect() {
    final settings = context.read<SettingsBloc>().state.settings;
    final t = LocalizationService();
    final langCode = settings.languageCode;
    final printService = PrintService();
    final payload = {
      'printer_name': settings.barcodePrinterName ?? '',
      'barcode': _barcodeCtrl.text.trim(),
      'product_name': _nameCtrl.text.trim(),
      'price': double.tryParse(_priceCtrl.text) ?? 0,
    };
    printService
        .printBarcode(payload)
        .then((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  t.translate(
                    'inventory.product.barcodePrinted',
                    languageCode: langCode,
                  ),
                ),
              ),
            );
          }
        })
        .catchError((error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  t.translate(
                    'inventory.product.barcodePrintFailed',
                    languageCode: langCode,
                    params: [error.toString()],
                  ),
                ),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        })
        .whenComplete(() => printService.dispose());
  }

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _barcodeKey = GlobalKey();
    _nameKey = GlobalKey();
    _priceKey = GlobalKey();
    _purchasePriceKey = GlobalKey();
    _stockKey = GlobalKey();
    _notesKey = GlobalKey();
    _labelPreviewKey = GlobalKey();
    _barcodeFocus = FocusNode();
    _nameFocus = FocusNode();
    _priceFocus = FocusNode();
    _purchasePriceFocus = FocusNode();
    _stockFocus = FocusNode();
    _notesFocus = FocusNode();
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? _genBarcode());
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _priceCtrl = TextEditingController(
      text: p != null ? p.price.toStringAsFixed(2) : '',
    );
    _purchasePriceCtrl = TextEditingController(
      text: p != null ? p.purchasePrice.toStringAsFixed(2) : '',
    );
    _stockCtrl = TextEditingController(
      text: p != null ? p.stock.toString() : '',
    );
    _notesCtrl = TextEditingController(text: p?.notes ?? '');
    _isQuickTileNotifier = ValueNotifier(p?.isQuickTile ?? false);
    _tileColorHexNotifier = ValueNotifier<String?>(p?.tileColorHex);
    _categoryNotifier = ValueNotifier<String?>(p?.category);
    final savedPref = context
        .read<SettingsBloc>()
        .state
        .settings
        .barcodeActionPreference;
    _barcodeActionNotifier = ValueNotifier(
      savedPref == 'savePng'
          ? BarcodeAction.savePng
          : BarcodeAction.printDirect,
    );
    _barcodeActionNotifier.addListener(_onBarcodeActionChanged);
    _exportCubit = BarcodeExportCubit(service: BarcodeExportService());
    if (p == null) {
      final tiles = context.read<InventoryBloc>().state.quickTileList;
      for (final tile in tiles.reversed) {
        if (tile.tileColorHex != null) {
          final lastIdx = _colors.indexOf(tile.tileColorHex!);
          if (lastIdx != -1) {
            _tileColorHexNotifier.value =
                _colors[(lastIdx + 1) % _colors.length];
          }
          break;
        }
      }
    }
    if (p == null || !p.isQuickTile) {
      _currentQuickTileCount = context
          .read<InventoryBloc>()
          .state
          .quickTileList
          .length;
    }
  }

  void _onBarcodeActionChanged() {
    if (!mounted) return;
    final value = _barcodeActionNotifier.value == BarcodeAction.savePng
        ? 'savePng'
        : 'printDirect';
    context.read<SettingsBloc>().add(BarcodeActionPreferenceChanged(value));
  }

  @override
  void dispose() {
    _barcodeActionNotifier.removeListener(_onBarcodeActionChanged);
    _isQuickTileNotifier.dispose();
    _tileColorHexNotifier.dispose();
    _categoryNotifier.dispose();
    _barcodeActionNotifier.dispose();
    _barcodeCtrl.dispose();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _stockCtrl.dispose();
    _notesCtrl.dispose();
    _barcodeFocus.dispose();
    _nameFocus.dispose();
    _priceFocus.dispose();
    _purchasePriceFocus.dispose();
    _stockFocus.dispose();
    _notesFocus.dispose();
    _exportCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.select(
      (SettingsBloc b) => b.state.settings.languageCode,
    );
    final storeName = context.select(
      (SettingsBloc b) => b.state.settings.storeName,
    );
    final t = LocalizationService();
    final editing = widget.product != null;
    final mode = BusinessType.fromId(
      context.read<SettingsBloc>().state.settings.businessType,
    );
    final barcodeValid = mode.barcodesEnabled && _barcodeCtrl.text.length >= 6;

    return BlocProvider.value(
      value: _exportCubit,
      child: AlertDialog(
        title: Text(
          editing
              ? t.translate('inventory.product.edit', languageCode: langCode)
              : t.translate('inventory.product.new', languageCode: langCode),
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 360,
            child: BlocListener<BarcodeExportCubit, BarcodeExportState>(
              listener: (context, state) {
                switch (state) {
                  case BarcodeExportSuccess s:
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          t
                              .translate(
                                'inventory.product.barcodeExported',
                                languageCode: langCode,
                              )
                              .replaceFirst('{0}', s.filePath),
                        ),
                      ),
                    );
                    _exportCubit.reset();
                  case BarcodeExportFailure f:
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(f.message)));
                    _exportCubit.reset();
                  default:
                    break;
                }
              },
              child: Stack(
                children: [
                  ProductFormBody(
                    product: widget.product,
                    barcodeCtrl: _barcodeCtrl,
                    nameCtrl: _nameCtrl,
                    priceCtrl: _priceCtrl,
                    purchasePriceCtrl: _purchasePriceCtrl,
                    stockCtrl: _stockCtrl,
                    notesCtrl: _notesCtrl,
                    barcodeFocus: _barcodeFocus,
                    nameFocus: _nameFocus,
                    priceFocus: _priceFocus,
                    purchasePriceFocus: _purchasePriceFocus,
                    stockFocus: _stockFocus,
                    notesFocus: _notesFocus,
                    barcodeKey: _barcodeKey,
                    nameKey: _nameKey,
                    priceKey: _priceKey,
                    purchasePriceKey: _purchasePriceKey,
                    stockKey: _stockKey,
                    notesKey: _notesKey,
                    isQuickTileNotifier: _isQuickTileNotifier,
                    tileColorHexNotifier: _tileColorHexNotifier,
                    categoryNotifier: _categoryNotifier,
                    currentQuickTileCount: _currentQuickTileCount,
                    onSubmit: _submit,
                    langCode: langCode,
                    t: t,
                    storeName: storeName,
                    labelPreviewKey: _labelPreviewKey,
                    onExportBarcode: barcodeValid ? _handleBarcodeAction : null,
                    barcodeActionNotifier: _barcodeActionNotifier,
                    colors: _colors,
                  ),
                  BlocBuilder<BarcodeExportCubit, BarcodeExportState>(
                    builder: (context, state) {
                      if (state is BarcodeExporting) {
                        return const Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: LinearProgressIndicator(),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.translate('cancel', languageCode: langCode)),
          ),
          FilledButton(
            onPressed: _submit,
            child: Text(
              editing
                  ? t.translate(
                      'inventory.product.update',
                      languageCode: langCode,
                    )
                  : t.translate(
                      'inventory.product.add',
                      languageCode: langCode,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
