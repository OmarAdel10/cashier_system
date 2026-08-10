import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/printing/print_service.dart';
import '../../../../core/theme/spacing.dart';
import '../../data/services/localization_service.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import 'settings_section.dart';

class FloorSection extends StatelessWidget {
  const FloorSection({super.key});

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );
    final roomsEnabled = context.select<SettingsBloc, bool>(
      (b) => b.state.settings.roomsEnabled,
    );
    final serviceChargeEnabled = context.select<SettingsBloc, bool>(
      (b) => b.state.settings.serviceChargeEnabled,
    );
    final minChargeEnabled = context.select<SettingsBloc, bool>(
      (b) => b.state.settings.minChargeEnabled,
    );
    final t = LocalizationService();

    return SettingsSection(
      title: t.translate('settings.floor', languageCode: langCode),
      children: [
        SwitchListTile(
          title: Text(
            t.translate('settings.floor.rooms', languageCode: langCode),
          ),
          subtitle: Text(
            t.translate(
              'settings.floor.rooms.subtitle',
              languageCode: langCode,
            ),
          ),
          value: roomsEnabled,
          onChanged: (v) {
            context.read<SettingsBloc>().add(RoomsToggled(v));
          },
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: Text(
            t.translate('settings.floor.serviceCharge', languageCode: langCode),
          ),
          subtitle: Text(
            t.translate(
              'settings.floor.serviceCharge.subtitle',
              languageCode: langCode,
            ),
          ),
          value: serviceChargeEnabled,
          onChanged: (v) {
            context.read<SettingsBloc>().add(ServiceChargeToggled(v));
          },
        ),
        if (serviceChargeEnabled) ...[
          const SizedBox(height: Spacing.sm),
          const _PercentField(),
        ],
        const SizedBox(height: 12),
        SwitchListTile(
          title: Text(
            t.translate('settings.floor.minCharge', languageCode: langCode),
          ),
          subtitle: Text(
            t.translate(
              'settings.floor.minCharge.subtitle',
              languageCode: langCode,
            ),
          ),
          value: minChargeEnabled,
          onChanged: (v) {
            context.read<SettingsBloc>().add(MinChargeToggled(v));
          },
        ),
        if (minChargeEnabled) ...[
          const SizedBox(height: Spacing.sm),
          const _AmountField(),
        ],
      ],
    );
  }
}

class _PercentField extends StatefulWidget {
  const _PercentField();

  @override
  State<_PercentField> createState() => _PercentFieldState();
}

class _PercentFieldState extends State<_PercentField> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );
    final percent = context.select<SettingsBloc, int>(
      (b) => b.state.settings.serviceChargePercent,
    );

    final str = percent.toString();
    if (_controller.text != str) _controller.text = str;

    final t = LocalizationService();

    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: t.translate(
          'settings.floor.serviceCharge.percent',
          languageCode: langCode,
        ),
        suffixText: '%',
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), () {
          final pct = int.tryParse(v.trim()) ?? 0;
          if (pct >= 0 && pct <= 100) {
            context.read<SettingsBloc>().add(
              ServiceChargePercentChanged(pct.clamp(0, 100)),
            );
          }
        });
      },
    );
  }
}

class _AmountField extends StatefulWidget {
  const _AmountField();

  @override
  State<_AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<_AmountField> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );
    final piastres = context.select<SettingsBloc, int>(
      (b) => b.state.settings.minChargePerTablePiastres,
    );

    final egp = (piastres / 100).toStringAsFixed(2);
    if (_controller.text != egp) _controller.text = egp;

    final t = LocalizationService();

    return TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      decoration: InputDecoration(
        labelText: t.translate(
          'settings.floor.minCharge.amount',
          languageCode: langCode,
        ),
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), () {
          final value = double.tryParse(v.trim());
          if (value != null && value >= 0) {
            context.read<SettingsBloc>().add(
              MinChargePerTableChanged((value * 100).round()),
            );
          }
        });
      },
    );
  }
}

class TicketsSection extends StatefulWidget {
  const TicketsSection({super.key});

  @override
  State<TicketsSection> createState() => _TicketsSectionState();
}

class _TicketsSectionState extends State<TicketsSection> {
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
    final t = LocalizationService();

    return SettingsSection(
      title: t.translate('settings.tickets', languageCode: langCode),
      children: [
        _ticketRow(
          label: t.translate(
            'settings.tickets.kitchen',
            languageCode: langCode,
          ),
          enabled: context.select<SettingsBloc, bool>(
            (b) => b.state.settings.kitchenTicketsEnabled,
          ),
          printer: context.select<SettingsBloc, String?>(
            (b) => b.state.settings.kitchenPrinterName,
          ),
          onToggle: (v) =>
              context.read<SettingsBloc>().add(KitchenTicketsToggled(v)),
          onPrinter: (v) =>
              context.read<SettingsBloc>().add(KitchenPrinterNameChanged(v)),
        ),
        const SizedBox(height: 12),
        _ticketRow(
          label: t.translate('settings.tickets.bar', languageCode: langCode),
          enabled: context.select<SettingsBloc, bool>(
            (b) => b.state.settings.barTicketsEnabled,
          ),
          printer: context.select<SettingsBloc, String?>(
            (b) => b.state.settings.barPrinterName,
          ),
          onToggle: (v) =>
              context.read<SettingsBloc>().add(BarTicketsToggled(v)),
          onPrinter: (v) =>
              context.read<SettingsBloc>().add(BarPrinterNameChanged(v)),
        ),
        const SizedBox(height: 12),
        _ticketRow(
          label: t.translate('settings.tickets.shisha', languageCode: langCode),
          enabled: context.select<SettingsBloc, bool>(
            (b) => b.state.settings.shishaTicketsEnabled,
          ),
          printer: context.select<SettingsBloc, String?>(
            (b) => b.state.settings.shishaPrinterName,
          ),
          onToggle: (v) =>
              context.read<SettingsBloc>().add(ShishaTicketsToggled(v)),
          onPrinter: (v) =>
              context.read<SettingsBloc>().add(ShishaPrinterNameChanged(v)),
        ),
      ],
    );
  }

  Widget _ticketRow({
    required String label,
    required bool enabled,
    required String? printer,
    required ValueChanged<bool> onToggle,
    required ValueChanged<String?> onPrinter,
  }) {
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );
    final t = LocalizationService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: enabled,
          onChanged: onToggle,
        ),
        if (enabled)
          _printerDropdown(
            value: printer,
            onChanged: onPrinter,
            langCode: langCode,
            t: t,
          ),
      ],
    );
  }

  Widget _printerDropdown({
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
                decoration: InputDecoration(border: const OutlineInputBorder()),
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
