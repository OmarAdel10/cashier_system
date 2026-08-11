import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/spacing.dart';
import '../../data/services/localization_service.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import 'settings_section.dart';

class TaxSection extends StatelessWidget {
  const TaxSection({super.key});

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );
    final taxEnabled = context.select<SettingsBloc, bool>(
      (b) => b.state.settings.taxEnabled,
    );
    final t = LocalizationService();

    return SettingsSection(
      title: t.translate('tax', languageCode: langCode),
      children: [
        SwitchListTile(
          title: Text(t.translate('taxToggle', languageCode: langCode)),
          subtitle: Text(
            t.translate('taxToggleSubtitle', languageCode: langCode),
          ),
          value: taxEnabled,
          onChanged: (v) {
            context.read<SettingsBloc>().add(TaxToggled(v));
          },
        ),
        if (taxEnabled) ...[
          SizedBox(height: Spacing.sm),
          const _TaxPercentField(),
        ],
      ],
    );
  }
}

class _TaxPercentField extends StatefulWidget {
  const _TaxPercentField();

  @override
  State<_TaxPercentField> createState() => _TaxPercentFieldState();
}

class _TaxPercentFieldState extends State<_TaxPercentField> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _syncFromSettings();
  }

  void _syncFromSettings() {
    final pct = context
        .read<SettingsBloc>()
        .state
        .settings
        .taxPercent
        .toString();
    if (_controller.text != pct) {
      _controller.text = pct;
    }
  }

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
    final taxPercent = context.select<SettingsBloc, int>(
      (b) => b.state.settings.taxPercent,
    );

    final pctStr = taxPercent.toString();
    if (_controller.text != pctStr) {
      _controller.text = pctStr;
    }

    final t = LocalizationService();

    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: t.translate('taxPercent', languageCode: langCode),
        hintText: t.translate('taxPercentHint', languageCode: langCode),
        suffixText: '%',
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), () {
          final pct = int.tryParse(v.trim()) ?? 0;
          if (pct >= 0 && pct <= 100) {
            context.read<SettingsBloc>().add(
              TaxPercentChanged(pct.clamp(0, 100)),
            );
          }
        });
      },
    );
  }
}
