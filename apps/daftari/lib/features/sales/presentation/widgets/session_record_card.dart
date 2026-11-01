import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../checkout/domain/entities/session_record_entity.dart';
import '../../../checkout/domain/helpers/price_helper.dart';
import '../../../settings/data/services/localization_service.dart';

/// Compact tile describing one completed station session.
class SessionRecordCard extends StatelessWidget {
  final SessionRecordEntity record;
  final String langCode;
  final LocalizationService t;

  const SessionRecordCard({
    super.key,
    required this.record,
    required this.langCode,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final tierLabel = record.tier == SessionTier.multi
        ? t.translate('station.tierMulti', languageCode: langCode)
        : t.translate('station.tierNormal', languageCode: langCode);

    final durationLabel =
        record.wasFixedDuration && record.fixedDurationMinutes != null
        ? '${record.fixedDurationMinutes} ${t.translate('station.minutes', languageCode: langCode)}'
        : '${record.durationMinutes} ${t.translate('station.minutes', languageCode: langCode)}';

    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Row(
          children: [
            PhosphorIcon(
              record.tier == SessionTier.multi
                  ? PhosphorIcons.gameControllerDuotone
                  : PhosphorIcons.gameControllerLight,
              size: 28,
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.stationName,
                    style: TextStyles.heading3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    '$tierLabel • $durationLabel',
                    style: TextStyles.bodySmall,
                  ),
                  if (record.startTime != null) ...[
                    const SizedBox(height: Spacing.xs),
                    Text(
                      _formatTime(record.startTime!),
                      style: TextStyles.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Spacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  PriceHelper.format(
                    record.totalPiastres,
                    languageCode: langCode,
                  ),
                  style: TextStyles.heading3.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (record.username.isNotEmpty) ...[
                  const SizedBox(height: Spacing.xs),
                  Text(record.username, style: TextStyles.bodySmall),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
        ' ${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}';
  }
}
