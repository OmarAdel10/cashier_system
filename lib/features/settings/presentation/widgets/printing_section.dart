import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/printing/print_service.dart';
import '../../data/services/localization_service.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import 'settings_section.dart';

class PrintingSection extends StatefulWidget {
  final bool showBarcodePrinter;
  final bool showReceiptPrinter;

  const PrintingSection({
    super.key,
    this.showBarcodePrinter = true,
    this.showReceiptPrinter = true,
  });

  @override
  State<PrintingSection> createState() => _PrintingSectionState();
}

class _PrintingSectionState extends State<PrintingSection> {
  final _printService = PrintService();
  List<String> _printers = [];
  final _loadingNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    _loadingNotifier.value = true;
    try {
      _printers = await _printService.getLocalPrinters();
    } catch (_) {
      _printers = [];
    }
    _loadingNotifier.value = false;
  }

  @override
  void dispose() {
    _printService.dispose();
    _loadingNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );
    final autoPrintEnabled = context.select<SettingsBloc, bool>(
      (b) => b.state.settings.autoPrintEnabled,
    );
    final saveReceiptAsImage = context.select<SettingsBloc, bool>(
      (b) => b.state.settings.saveReceiptAsImage,
    );
    final saveReceiptAsPdf = context.select<SettingsBloc, bool>(
      (b) => b.state.settings.saveReceiptAsPdf,
    );
    final receiptPrinter = context.select<SettingsBloc, String?>(
      (b) => b.state.settings.receiptPrinterName,
    );
    final barcodePrinter = context.select<SettingsBloc, String?>(
      (b) => b.state.settings.barcodePrinterName,
    );

    final t = LocalizationService();

    return SettingsSection(
      title: t.translate('printing', languageCode: langCode),
      children: [
        SwitchListTile(
          title: Text(t.translate('autoPrint', languageCode: langCode)),
          subtitle: Text(
            t.translate('autoPrintSubtitle', languageCode: langCode),
          ),
          value: autoPrintEnabled,
          onChanged: (v) {
            context.read<SettingsBloc>().add(AutoPrintToggled(v));
          },
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: Text(
            t.translate('saveReceiptAsImageSaveOnly', languageCode: langCode),
          ),
          subtitle: Text(
            t.translate(
              'saveReceiptAsImageSaveOnlySubtitle',
              languageCode: langCode,
            ),
          ),
          value: saveReceiptAsImage,
          onChanged: (v) {
            context.read<SettingsBloc>().add(SaveReceiptAsImageToggled(v));
          },
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: Text(t.translate('saveReceiptAsPdf', languageCode: langCode)),
          subtitle: Text(
            t.translate('saveReceiptAsPdfSubtitle', languageCode: langCode),
          ),
          value: saveReceiptAsPdf,
          onChanged: (v) {
            context.read<SettingsBloc>().add(SaveReceiptAsPdfToggled(v));
          },
        ),
        const SizedBox(height: 16),
        if (widget.showReceiptPrinter) ...[
          _printerDropdown(
            label: t.translate('receiptPrinter', languageCode: langCode),
            value: receiptPrinter,
            onChanged: (v) {
              context.read<SettingsBloc>().add(ReceiptPrinterNameChanged(v));
            },
            langCode: langCode,
            t: t,
          ),
          const SizedBox(height: 12),
        ],
        if (widget.showBarcodePrinter)
          _printerDropdown(
            label: t.translate('barcodePrinter', languageCode: langCode),
            value: barcodePrinter,
            onChanged: (v) {
              context.read<SettingsBloc>().add(BarcodePrinterNameChanged(v));
            },
            langCode: langCode,
            t: t,
          ),
      ],
    );
  }

  Widget _printerDropdown({
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
    required String langCode,
    required LocalizationService t,
  }) {
    return ListenableBuilder(
      listenable: _loadingNotifier,
      builder: (context, _) {
        return Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _printers.contains(value) ? value : null,
                decoration: InputDecoration(
                  labelText: label,
                  helperText:
                      label ==
                          t.translate('receiptPrinter', languageCode: langCode)
                      ? t.translate(
                          'receiptPrinter.subtitle',
                          languageCode: langCode,
                        )
                      : t.translate(
                          'barcodePrinter.subtitle',
                          languageCode: langCode,
                        ),
                  border: const OutlineInputBorder(),
                ),
                items: _printers
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: onChanged,
                hint: Text(
                  _loadingNotifier.value
                      ? '...'
                      : _printers.isEmpty
                      ? t.translate('noPrintersFound', languageCode: langCode)
                      : t.translate('selectPrinter', languageCode: langCode),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: _loadingNotifier.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              onPressed: _loadingNotifier.value ? null : _loadPrinters,
              tooltip: t.translate('refreshPrinters', languageCode: langCode),
            ),
          ],
        );
      },
    );
  }
}
