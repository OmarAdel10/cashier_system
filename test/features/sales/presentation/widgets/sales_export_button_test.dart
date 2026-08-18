import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/auth/domain/entities/shift_entity.dart';
import 'package:cashier_system/features/auth/domain/entities/user_entity.dart';
import 'package:cashier_system/features/auth/domain/entities/user_role.dart';
import 'package:cashier_system/features/auth/domain/repositories/i_shifts_repository.dart';
import 'package:cashier_system/features/sales/presentation/bloc/sales_bloc.dart';
import 'package:cashier_system/features/sales/presentation/bloc/sales_event.dart';
import 'package:cashier_system/features/sales/presentation/widgets/sales_export_button.dart';
import 'package:cashier_system/features/settings/data/services/localization_service.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';

import '../../../checkout/helpers/fake_session_record_repository.dart';
import '../../../receipts/helpers/fake_receipts_repository.dart';
import '../../../settings/helpers/fake_settings_repository.dart';

class _NoopShiftRepo implements IShiftsRepository {
  @override
  Future<Either<Failure, ShiftEntity?>> getActiveShift(String username) async =>
      const Right(null);

  @override
  Future<Either<Failure, List<ShiftEntity>>> getByMonth(
    int year,
    int month,
  ) async => const Right([]);

  @override
  Future<Either<Failure, void>> save(ShiftEntity shift) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> closeOpenShifts(String username) async =>
      const Right(null);
}

class _CapturingSalesBloc extends SalesBloc {
  final List<SalesEvent> capturedEvents = [];

  _CapturingSalesBloc()
    : super(
        receiptsRepo: FakeReceiptsRepository(),
        shiftsRepo: _NoopShiftRepo(),
        sessionRecordsRepo: FakeSessionRecordRepository(),
      );

  @override
  void add(SalesEvent event) {
    capturedEvents.add(event);
  }
}

final _adminUser = UserEntity(
  username: 'admin',
  passwordHash: '',
  mustChangePassword: false,
  role: UserRole.admin,
  createdAt: DateTime.now(),
);

final _cashierUser = UserEntity(
  username: 'cashier1',
  passwordHash: '',
  mustChangePassword: false,
  role: UserRole.cashier,
  createdAt: DateTime.now(),
);

void main() {
  const exportDirectory = r'C:\exports\sales';

  late SettingsBloc settingsBloc;
  late _CapturingSalesBloc salesBloc;

  Widget buildApp({required Widget button}) {
    return MaterialApp(
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<SettingsBloc>.value(value: settingsBloc),
            BlocProvider<SalesBloc>.value(value: salesBloc),
          ],
          child: button,
        ),
      ),
    );
  }

  setUp(() {
    settingsBloc = SettingsBloc(
      repository: FakeSettingsRepository(
        const AppSettingsEntity(exportDirectoryPath: exportDirectory),
      ),
    );
    settingsBloc.add(const LoadSettings());
    settingsBloc.add(const LanguageToggled('en'));
    salesBloc = _CapturingSalesBloc();
  });

  tearDown(() {
    settingsBloc.close();
    salesBloc.close();
  });

  group('SalesExportButton', () {
    testWidgets('is hidden for non-admin users', (tester) async {
      await tester.pumpWidget(
        buildApp(
          button: SalesExportButton(
            user: _cashierUser,
            t: LocalizationService(),
            langCode: 'en',
          ),
        ),
      );

      expect(find.byKey(const Key('salesExport')), findsNothing);
    });

    testWidgets('opens the export dialog with the configured directory', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(
          button: SalesExportButton(
            user: _adminUser,
            t: LocalizationService(),
            langCode: 'en',
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('salesExport')));
      await tester.pumpAndSettle();

      expect(find.text('Export Sales'), findsOneWidget);
      expect(find.text(exportDirectory), findsOneWidget);
    });
  });

  group('SalesExportDialog', () {
    Future<void> openDialog(WidgetTester tester) async {
      await tester.pumpWidget(
        buildApp(
          button: SalesExportButton(
            user: _adminUser,
            t: LocalizationService(),
            langCode: 'en',
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('salesExport')));
      await tester.pumpAndSettle();
    }

    Future<void> tapConfirm(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('salesExportConfirm')));
      await tester.pumpAndSettle();
    }

    testWidgets('does not dispatch and shows a snackbar without a directory', (
      tester,
    ) async {
      settingsBloc.close();
      settingsBloc = SettingsBloc(
        repository: FakeSettingsRepository(const AppSettingsEntity()),
      );
      settingsBloc.add(const LoadSettings());
      settingsBloc.add(const LanguageToggled('en'));

      await openDialog(tester);

      final confirm = tester.widget<FilledButton>(
        find.byKey(const Key('salesExportConfirm')),
      );
      expect(confirm.onPressed, isNull);

      salesBloc.capturedEvents.clear();
      await tapConfirm(tester);

      expect(salesBloc.capturedEvents, isEmpty);
      expect(
        find.text('Set the export directory in Settings first'),
        findsOneWidget,
      );
    });

    testWidgets('dispatches ExportByMonth with CSV by default', (tester) async {
      await openDialog(tester);
      await tapConfirm(tester);

      final now = DateTime.now();
      expect(salesBloc.capturedEvents, hasLength(1));
      final event = salesBloc.capturedEvents.single;
      expect(event, isA<ExportByMonth>());
      final export = event as ExportByMonth;
      expect(export.year, now.year);
      expect(export.month, now.month);
      expect(export.format, 'csv');
      expect(export.exportDirectoryPath, exportDirectory);
    });

    testWidgets(
      'dispatches ExportByDay with PDF when scope and format change',
      (tester) async {
        await openDialog(tester);

        await tester.tap(find.text('Today'));
        await tester.pump();
        await tester.tap(find.text('PDF'));
        await tester.pump();
        await tapConfirm(tester);

        final now = DateTime.now();
        expect(salesBloc.capturedEvents, hasLength(1));
        final event = salesBloc.capturedEvents.single;
        expect(event, isA<ExportByDay>());
        final export = event as ExportByDay;
        expect(export.year, now.year);
        expect(export.month, now.month);
        expect(export.day, now.day);
        expect(export.format, 'pdf');
        expect(export.exportDirectoryPath, exportDirectory);
      },
    );

    testWidgets('disables confirm for day range until a range is picked', (
      tester,
    ) async {
      await openDialog(tester);

      await tester.tap(find.text('Day Range'));
      await tester.pump();

      final confirm = tester.widget<FilledButton>(
        find.byKey(const Key('salesExportConfirm')),
      );
      expect(confirm.onPressed, isNull);
    });

    testWidgets('cancel closes the dialog without dispatching', (tester) async {
      await openDialog(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Export Sales'), findsNothing);
      expect(salesBloc.capturedEvents, isEmpty);
    });
  });
}
