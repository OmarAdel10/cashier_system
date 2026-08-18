import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../bloc/sales_bloc.dart';
import '../bloc/sales_event.dart';

enum _ExportScope {
  today,
  thisMonth,
  thisYear,
  allMonths,
  dayRange,
  monthRange,
}

/// Export button for the Sales history card. Opens a dialog where the admin
/// picks a scope (day / month / year / all / day range / month range) and a
/// format (CSV or PDF), then dispatches the corresponding export event.
class SalesExportButton extends StatelessWidget {
  final UserEntity user;
  final LocalizationService t;
  final String langCode;

  const SalesExportButton({
    super.key,
    required this.user,
    required this.t,
    required this.langCode,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = user.role == UserRole.admin;
    if (!isAdmin) return const SizedBox.shrink();
    return IconButton(
      key: const Key('salesExport'),
      icon: const Icon(PhosphorIcons.export, size: 20),
      tooltip: t.translate('sales.export', languageCode: langCode),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => SalesExportDialog(
          t: t,
          langCode: langCode,
          salesBloc: context.read<SalesBloc>(),
          exportDirectoryPath: context
              .read<SettingsBloc>()
              .state
              .settings
              .exportDirectoryPath
              .trim(),
        ),
      ),
    );
  }
}

class SalesExportDialog extends StatefulWidget {
  final LocalizationService t;
  final String langCode;
  final SalesBloc salesBloc;
  final String exportDirectoryPath;

  const SalesExportDialog({
    super.key,
    required this.t,
    required this.langCode,
    required this.salesBloc,
    required this.exportDirectoryPath,
  });

  @override
  State<SalesExportDialog> createState() => _SalesExportDialogState();
}

class _SalesExportDialogState extends State<SalesExportDialog> {
  String _format = 'csv';
  _ExportScope _scope = _ExportScope.thisMonth;
  DateTimeRange? _dayRange;
  DateTimeRange? _monthRange;

  String _tr(String key, {List<String> params = const []}) =>
      widget.t.translate(key, languageCode: widget.langCode, params: params);

  Future<void> _pickDayRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange:
          _dayRange ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
      helpText: _tr('sales.export.scope.dayRange'),
    );
    if (picked != null) setState(() => _dayRange = picked);
  }

  Future<void> _pickMonthRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange:
          _monthRange ??
          DateTimeRange(start: DateTime(now.year, 1, 1), end: now),
      helpText: _tr('sales.export.scope.monthRange'),
    );
    if (picked != null)
      setState(() {
        _monthRange = DateTimeRange(
          start: DateTime(picked.start.year, picked.start.month, 1),
          end: DateTime(picked.end.year, picked.end.month + 1, 0),
        );
      });
  }

  String _rangeLabel(DateTimeRange? range) {
    final r = range;
    if (r == null) return _tr('sales.export.noRange');
    return '${r.start.day}/${r.start.month}/${r.start.year} - '
        '${r.end.day}/${r.end.month}/${r.end.year}';
  }

  void _dispatch(BuildContext context) {
    final exportDirectoryPath = widget.exportDirectoryPath;
    if (exportDirectoryPath.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(_tr('sales.export.noDirectory'))),
        );
      return;
    }

    final bloc = widget.salesBloc;
    final now = DateTime.now();
    switch (_scope) {
      case _ExportScope.today:
        bloc.add(
          ExportByDay(
            year: now.year,
            month: now.month,
            day: now.day,
            format: _format,
            exportDirectoryPath: exportDirectoryPath,
          ),
        );
      case _ExportScope.thisMonth:
        bloc.add(
          ExportByMonth(
            year: now.year,
            month: now.month,
            format: _format,
            exportDirectoryPath: exportDirectoryPath,
          ),
        );
      case _ExportScope.thisYear:
        bloc.add(
          ExportByYear(
            year: now.year,
            format: _format,
            exportDirectoryPath: exportDirectoryPath,
          ),
        );
      case _ExportScope.allMonths:
        bloc.add(
          ExportAllMonths(
            format: _format,
            exportDirectoryPath: exportDirectoryPath,
          ),
        );
      case _ExportScope.dayRange:
        final r = _dayRange;
        if (r == null) return;
        bloc.add(
          ExportDayToDay(
            startYear: r.start.year,
            startMonth: r.start.month,
            startDay: r.start.day,
            endYear: r.end.year,
            endMonth: r.end.month,
            endDay: r.end.day,
            format: _format,
            exportDirectoryPath: exportDirectoryPath,
          ),
        );
      case _ExportScope.monthRange:
        final r = _monthRange;
        if (r == null) return;
        bloc.add(
          ExportMonthToMonth(
            startYear: r.start.year,
            startMonth: r.start.month,
            endYear: r.end.year,
            endMonth: r.end.month,
            format: _format,
            exportDirectoryPath: exportDirectoryPath,
          ),
        );
    }
    Navigator.of(context).pop();
  }

  Widget _scopeTile(_ExportScope scope, String label, Object icon) {
    return RadioListTile<_ExportScope>(
      dense: true,
      value: scope,
      activeColor: Theme.of(context).colorScheme.primary,
      secondary: PhosphorIcon(icon, size: 20),
      title: Text(label, style: TextStyles.body),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exportDirectoryPath = widget.exportDirectoryPath;
    final hasDirectory = exportDirectoryPath.isNotEmpty;
    final rangeInvalid =
        (_scope == _ExportScope.dayRange && _dayRange == null) ||
        (_scope == _ExportScope.monthRange && _monthRange == null);

    return AlertDialog(
      title: Row(
        children: [
          const PhosphorIcon(PhosphorIcons.export, size: 24),
          const SizedBox(width: Spacing.sm),
          Flexible(
            child: Text(
              _tr('sales.export.title'),
              style: TextStyles.heading3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_tr('sales.export.format'), style: TextStyles.body),
              const SizedBox(height: Spacing.xs),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'csv',
                    label: Text(_tr('sales.export.csv')),
                    icon: const Icon(PhosphorIcons.fileCsv),
                  ),
                  ButtonSegment(
                    value: 'pdf',
                    label: Text(_tr('sales.export.pdf')),
                    icon: const Icon(PhosphorIcons.filePdf),
                  ),
                ],
                selected: {_format},
                onSelectionChanged: (s) => setState(() => _format = s.first),
              ),
              const Divider(height: 24),
              RadioGroup<_ExportScope>(
                groupValue: _scope,
                onChanged: (v) => setState(() => _scope = v ?? _scope),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _scopeTile(
                      _ExportScope.today,
                      _tr('sales.export.scope.today'),
                      PhosphorIcons.calendarBlank,
                    ),
                    _scopeTile(
                      _ExportScope.thisMonth,
                      _tr('sales.export.scope.thisMonth'),
                      PhosphorIcons.calendar,
                    ),
                    _scopeTile(
                      _ExportScope.thisYear,
                      _tr('sales.export.scope.thisYear'),
                      PhosphorIcons.calendarX,
                    ),
                    _scopeTile(
                      _ExportScope.allMonths,
                      _tr('sales.export.scope.allMonths'),
                      PhosphorIcons.clockCounterClockwise,
                    ),
                    _scopeTile(
                      _ExportScope.dayRange,
                      _tr('sales.export.scope.dayRange'),
                      PhosphorIcons.calendarDots,
                    ),
                    if (_scope == _ExportScope.dayRange)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 8),
                        child: OutlinedButton.icon(
                          icon: const Icon(PhosphorIcons.calendarDots),
                          label: Text(_rangeLabel(_dayRange)),
                          onPressed: _pickDayRange,
                        ),
                      ),
                    _scopeTile(
                      _ExportScope.monthRange,
                      _tr('sales.export.scope.monthRange'),
                      PhosphorIcons.calendarCheck,
                    ),
                    if (_scope == _ExportScope.monthRange)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 8),
                        child: OutlinedButton.icon(
                          icon: const Icon(PhosphorIcons.calendarCheck),
                          label: Text(_rangeLabel(_monthRange)),
                          onPressed: _pickMonthRange,
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 24),
              Row(
                children: [
                  PhosphorIcon(
                    PhosphorIcons.folderOpen,
                    size: 18,
                    color: hasDirectory
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: Spacing.xs),
                  Expanded(
                    child: Text(
                      hasDirectory
                          ? exportDirectoryPath
                          : _tr('sales.export.noDirectory'),
                      style: TextStyles.caption.copyWith(
                        color: hasDirectory
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Theme.of(context).colorScheme.error,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_tr('cancel')),
        ),
        FilledButton.icon(
          key: const Key('salesExportConfirm'),
          icon: const Icon(PhosphorIcons.export, size: 18),
          label: Text('${_tr('sales.export')} (${_format.toUpperCase()})'),
          onPressed: hasDirectory && !rangeInvalid
              ? () => _dispatch(context)
              : null,
        ),
      ],
    );
  }
}
