import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/localization_service.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import 'printer_dropdown_field.dart';
import 'settings_section.dart';

class PrintingSection extends StatelessWidget {
  final bool showBarcodePrinter;
  final bool showReceiptPrinter;
  final bool isSettingsSection;

  const PrintingSection({
    super.key,
    this.showBarcodePrinter = true,
    this.showReceiptPrinter = true,
    this.isSettingsSection = true,
  });

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

    final List<Widget> children = [
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
      if (showReceiptPrinter) ...[
        PrinterDropdownField(
          label: t.translate('receiptPrinter', languageCode: langCode),
          helperText: t.translate(
            'receiptPrinter.subtitle',
            languageCode: langCode,
          ),
          value: receiptPrinter,
          onChanged: (v) {
            context.read<SettingsBloc>().add(ReceiptPrinterNameChanged(v));
          },
          emptyHint: t.translate('noPrintersFound', languageCode: langCode),
          selectHint: t.translate('selectPrinter', languageCode: langCode),
          refreshTooltip: t.translate(
            'refreshPrinters',
            languageCode: langCode,
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (showBarcodePrinter)
        PrinterDropdownField(
          label: t.translate('barcodePrinter', languageCode: langCode),
          helperText: t.translate(
            'barcodePrinter.subtitle',
            languageCode: langCode,
          ),
          value: barcodePrinter,
          onChanged: (v) {
            context.read<SettingsBloc>().add(BarcodePrinterNameChanged(v));
          },
          emptyHint: t.translate('noPrintersFound', languageCode: langCode),
          selectHint: t.translate('selectPrinter', languageCode: langCode),
          refreshTooltip: t.translate(
            'refreshPrinters',
            languageCode: langCode,
          ),
        ),
    ];

    if (!isSettingsSection) {
      return Column(children: children);
    }

    return SettingsSection(
      title: t.translate('printing', languageCode: langCode),
      children: children,
    );
  }
}
