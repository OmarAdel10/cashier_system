import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cashier_system/core/theme/spacing.dart';
import 'package:cashier_system/core/theme/text_styles.dart';
import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_event.dart';
import 'package:cashier_system/features/settings/data/services/localization_service.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';

/// Asks for the session options (tier, fixed duration) and starts a session
/// on the selected station.
class StartSessionDialog extends StatefulWidget {
  const StartSessionDialog({super.key, required this.station});

  final StationEntity station;

  @override
  State<StartSessionDialog> createState() => _StartSessionDialogState();
}

class _StartSessionDialogState extends State<StartSessionDialog> {
  PricingTier _selectedTier = PricingTier.normal;
  bool _isFixedDuration = false;
  int _fixedDurationMinutes = 120;

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.select<SettingsBloc, String>(
      (s) => s.state.settings.languageCode,
    );
    final isPlaystation = widget.station.stationType == StationType.playstation;

    return AlertDialog(
      title: Text(
        t.translate(
          'station.startSession',
          languageCode: langCode,
          params: [widget.station.name],
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPlaystation) ...[
            Text(
              t.translate('station.tier', languageCode: langCode),
              style: TextStyles.body,
            ),
            const SizedBox(height: Spacing.sm),
            SegmentedButton<PricingTier>(
              segments: [
                ButtonSegment(
                  value: PricingTier.normal,
                  label: Text(
                    t.translate('station.tierNormal', languageCode: langCode),
                  ),
                ),
                ButtonSegment(
                  value: PricingTier.multi,
                  label: Text(
                    t.translate('station.tierMulti', languageCode: langCode),
                  ),
                ),
              ],
              selected: {_selectedTier},
              onSelectionChanged: (selection) =>
                  setState(() => _selectedTier = selection.first),
            ),
          ],
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              Checkbox(
                value: _isFixedDuration,
                onChanged: (v) => setState(() => _isFixedDuration = v ?? false),
              ),
              Expanded(
                child: Text(
                  t.translate('station.fixedDuration', languageCode: langCode),
                ),
              ),
              if (_isFixedDuration) ...[
                const SizedBox(width: Spacing.md),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    initialValue: _fixedDurationMinutes.toString(),
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        _fixedDurationMinutes = int.tryParse(v) ?? 120,
                    decoration: InputDecoration(
                      labelText: t.translate(
                        'station.minutes',
                        languageCode: langCode,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.translate('cancel', languageCode: langCode)),
        ),
        FilledButton(
          onPressed: () {
            context.read<StationBloc>().add(
              StartSession(
                stationId: widget.station.id,
                tier: _selectedTier,
                isFixedDuration: _isFixedDuration,
                fixedDurationMinutes: _isFixedDuration
                    ? _fixedDurationMinutes
                    : null,
              ),
            );
            Navigator.pop(context);
          },
          child: Text(t.translate('confirm', languageCode: langCode)),
        ),
      ],
    );
  }
}
