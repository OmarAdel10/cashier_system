import 'package:flutter/material.dart';

import '../../../../core/printing/print_service.dart';

/// Dropdown for picking a locally installed printer, with a refresh button.
///
/// Loads the printer list from the PrintServer on mount; failures degrade to
/// an empty list with a "no printers found" hint.
class PrinterDropdownField extends StatefulWidget {
  final String label;
  final String helperText;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String loadingHint;
  final String emptyHint;
  final String selectHint;
  final String refreshTooltip;

  const PrinterDropdownField({
    super.key,
    required this.label,
    required this.helperText,
    required this.value,
    required this.onChanged,
    this.loadingHint = '...',
    this.emptyHint = 'No printers found',
    this.selectHint = 'Select printer',
    this.refreshTooltip = 'Refresh printers',
  });

  @override
  State<PrinterDropdownField> createState() => _PrinterDropdownFieldState();
}

class _PrinterDropdownFieldState extends State<PrinterDropdownField> {
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
    return ListenableBuilder(
      listenable: _loadingNotifier,
      builder: (context, _) {
        final loading = _loadingNotifier.value;
        return Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _printers.contains(widget.value)
                    ? widget.value
                    : null,
                decoration: InputDecoration(
                  labelText: widget.label,
                  helperText: widget.helperText,
                  border: const OutlineInputBorder(),
                ),
                items: _printers
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: widget.onChanged,
                hint: Text(
                  loading
                      ? widget.loadingHint
                      : _printers.isEmpty
                      ? widget.emptyHint
                      : widget.selectHint,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              onPressed: loading ? null : _loadPrinters,
              tooltip: widget.refreshTooltip,
            ),
          ],
        );
      },
    );
  }
}
