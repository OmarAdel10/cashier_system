import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cashier_system/features/checkout/data/models/app_session_record_model.dart';
import 'package:cashier_system/features/checkout/data/repositories/session_record_repository_impl.dart';
import 'package:cashier_system/features/checkout/domain/entities/session_record_entity.dart';

void main() {
  group('SessionRecordRepositoryImpl', () {
    late Box<AppSessionRecordModel> box;
    late SessionRecordRepositoryImpl repo;

    setUpAll(() async {
      Hive.init('test/_hive_test');
      if (!Hive.isAdapterRegistered(AppSessionRecordModelAdapter().typeId)) {
        Hive.registerAdapter(AppSessionRecordModelAdapter());
      }
    });

    setUp(() async {
      box = await Hive.openBox<AppSessionRecordModel>('test_session_records');
      await box.clear();
      repo = SessionRecordRepositoryImpl(box);
    });

    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk('test_session_records');
    });

    const record = SessionRecordEntity(
      id: 'SR-1',
      shiftId: 'SHIFT-1',
      stationId: 'PS4-1',
      stationName: 'PS4-1',
      parentCategory: 'PS4',
      tier: SessionTier.normal,
      durationMinutes: 60,
      hourlyRate: 50.0,
      minimumGameCost: 100,
      subtotalPiastres: 5000,
      totalPiastres: 5000,
    );

    test('save and get session record', () async {
      await repo.saveSessionRecord(record);
      final result = await repo.getSessionRecord('SR-1');
      final saved = result.fold(
        (failure) => fail('unexpected failure: $failure'),
        (value) => value,
      );
      expect(saved?.id, 'SR-1');
      expect(saved?.stationName, 'PS4-1');
      expect(saved?.totalPiastres, 5000);
    });

    test('get all session records', () async {
      const r1 = SessionRecordEntity(
        id: 'SR-1',
        shiftId: 'SHIFT-1',
        stationId: 'PS4-1',
        stationName: 'PS4-1',
        parentCategory: 'PS4',
        tier: SessionTier.normal,
        totalPiastres: 5000,
      );
      const r2 = SessionRecordEntity(
        id: 'SR-2',
        shiftId: 'SHIFT-1',
        stationId: 'PS5-1',
        stationName: 'PS5-1',
        parentCategory: 'PS5',
        tier: SessionTier.multi,
        totalPiastres: 9000,
      );
      await repo.saveSessionRecord(r1);
      await repo.saveSessionRecord(r2);
      final result = await repo.getSessionRecords();
      final records = result.fold(
        (failure) => fail('unexpected failure: $failure'),
        (value) => value,
      );
      expect(records.length, 2);
    });

    test('delete session record', () async {
      await repo.saveSessionRecord(record);
      await repo.deleteSessionRecord('SR-1');
      final result = await repo.getSessionRecord('SR-1');
      final saved = result.fold(
        (failure) => fail('unexpected failure: $failure'),
        (value) => value,
      );
      expect(saved, isNull);
    });
  });
}
