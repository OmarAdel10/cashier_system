import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cashier_system/core/theme/spacing.dart';
import 'package:cashier_system/core/theme/text_styles.dart';
import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';
import 'package:cashier_system/features/checkout/domain/helpers/price_helper.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_event.dart';
import 'package:cashier_system/features/settings/data/services/localization_service.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';

/// Confirms ending the running session on [station], showing the running
/// total before the session is billed.
class EndSessionDialog extends StatelessWidget {
  const EndSessionDialog({super.key, required this.station});

  final StationEntity station;

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.select<SettingsBloc, String>(
      (s) => s.state.settings.languageCode,
    );
    final minutes = station.elapsedMinutes;
    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    return AlertDialog(
      title: Text(
        t.translate(
          'station.endSession.title',
          languageCode: langCode,
          params: [station.name],
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '⏱ ${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}',
            style: TextStyles.heading2.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            t.translate(
              station.sessionTier == PricingTier.multi
                  ? 'station.tierMulti'
                  : 'station.tierNormal',
              languageCode: langCode,
            ),
            style: TextStyles.body,
          ),
          const SizedBox(height: Spacing.md),
          Text(
            t.translate(
              'station.total',
              languageCode: langCode,
              params: [
                PriceHelper.format(
                  station.currentTotalPiastres,
                  languageCode: langCode,
                ),
              ],
            ),
            style: TextStyles.heading3.copyWith(fontWeight: FontWeight.bold),
          ),
          if (station.isFixedDuration &&
              station.fixedDurationMinutes != null) ...[
            const SizedBox(height: Spacing.sm),
            Text(
              t.translate(
                'station.endSession.booked',
                languageCode: langCode,
                params: [station.fixedDurationMinutes!.toString()],
              ),
              style: TextStyles.body,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.translate('cancel', languageCode: langCode)),
        ),
        FilledButton(
          onPressed: () {
            context.read<StationBloc>().add(EndSession(stationId: station.id));
            Navigator.pop(context);
          },
          child: Text(
            t.translate('station.endSession.confirm', languageCode: langCode),
          ),
        ),
      ],
    );
  }
}
