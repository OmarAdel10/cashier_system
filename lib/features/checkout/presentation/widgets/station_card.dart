import 'package:flutter/material.dart';
import 'package:cashier_system/core/theme/spacing.dart';
import 'package:cashier_system/core/theme/text_styles.dart';
import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';
import 'package:cashier_system/features/checkout/domain/helpers/price_helper.dart';
import 'package:cashier_system/features/settings/data/services/localization_service.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

class StationCard extends StatelessWidget {
  const StationCard({
    super.key,
    required this.station,
    required this.onTap,
    this.onOrderAddon,
  });

  final StationEntity station;
  final VoidCallback onTap;
  final VoidCallback? onOrderAddon;

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.select<SettingsBloc, String>(
      (s) => s.state.settings.languageCode,
    );
    final colorScheme = Theme.of(context).colorScheme;

    Color statusColor;
    String statusLabel;
    switch (station.status) {
      case StationStatus.available:
        statusColor = Colors.green;
        statusLabel = t.translate(
          'station.status.available',
          languageCode: langCode,
        );
        break;
      case StationStatus.active:
        statusColor = Colors.blue;
        statusLabel = t.translate(
          'station.status.active',
          languageCode: langCode,
        );
        break;
      case StationStatus.overtime:
        statusColor = Colors.orange;
        statusLabel = t.translate(
          'station.status.overtime',
          languageCode: langCode,
        );
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Spacing.md),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Spacing.md),
          border: Border.all(color: statusColor, width: 2),
          color: colorScheme.surfaceContainerHighest,
        ),
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    station.name,
                    style: TextStyles.heading3.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm,
                    vertical: Spacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              station.parentCategory,
              style: TextStyles.body.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            if (station.status == StationStatus.active ||
                station.status == StationStatus.overtime)
              _LiveTimer(station: station),
            if (station.status == StationStatus.active ||
                station.status == StationStatus.overtime)
              const SizedBox(height: Spacing.sm),
            if (station.status != StationStatus.available)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.translate(
                        'station.total',
                        languageCode: langCode,
                        params: [
                          PriceHelper.format(
                            station.combinedTotalPiastres,
                            languageCode: langCode,
                          ),
                        ],
                      ),
                      style: TextStyles.heading3.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (onOrderAddon != null)
                    IconButton(
                      tooltip: t.translate(
                        'station.addon.order',
                        languageCode: langCode,
                      ),
                      icon: const Icon(Icons.restaurant_menu),
                      onPressed: onOrderAddon,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _LiveTimer extends StatefulWidget {
  const _LiveTimer({required this.station});

  final StationEntity station;

  @override
  State<_LiveTimer> createState() => _LiveTimerState();
}

class _LiveTimerState extends State<_LiveTimer> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = widget.station.elapsedMinutes;
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return Text(
      '⏱ ${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}',
      style: TextStyles.heading2.copyWith(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
