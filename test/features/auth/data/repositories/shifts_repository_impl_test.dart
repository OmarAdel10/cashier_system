import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/auth/data/models/app_shift_model.dart';
import 'package:cashier_system/features/auth/data/repositories/shifts_repository_impl.dart';
import 'package:cashier_system/features/auth/domain/entities/shift_entity.dart';
import 'package:cashier_system/features/auth/domain/repositories/i_shifts_repository.dart';

void main() {
  late Box<AppShiftModel> box;
  late Box<String> activeBox;
  late IShiftsRepository repository;

  setUpAll(() async {
    Hive.init('test/_hive_test');
    Hive.registerAdapter(AppShiftModelAdapter());
  });

  setUp(() async {
    box = await Hive.openBox<AppShiftModel>('test_shifts');
    activeBox = await Hive.openBox<String>('test_active_shifts');
    repository = ShiftsRepositoryImpl(box: box, activeBox: activeBox);
  });

  tearDown(() async {
    await box.close();
    await activeBox.close();
    await Hive.deleteBoxFromDisk('test_shifts');
    await Hive.deleteBoxFromDisk('test_active_shifts');
  });

  group('getActiveShift', () {
    test('returns null when no shifts exist', () async {
      final result = await repository.getActiveShift('user1');
      final shift = result.fold(
        (failure) => throw failure,
        (s) => s,
      );
      expect(shift, isNull);
    });

    test('returns the shift without endedAt', () async {
      final now = DateTime.now();
      final entity = ShiftEntity(
        id: 'shift-1',
        username: 'user1',
        startedAt: now,
        openingFloat: 100,
      );
      final saveResult = await repository.save(entity);
      expect(saveResult, isA<Right<Failure, void>>());

      final result = await repository.getActiveShift('user1');
      final shift = result.fold(
        (failure) => throw failure,
        (s) => s,
      );
      expect(shift, isNotNull);
      expect(shift!.id, 'shift-1');
      expect(shift.username, 'user1');
      expect(shift.endedAt, isNull);
    });

    test('returns null when only ended shifts exist', () async {
      final now = DateTime.now();
      final entity = ShiftEntity(
        id: 'shift-2',
        username: 'user1',
        startedAt: now,
        endedAt: now.add(const Duration(hours: 8)),
        openingFloat: 100,
      );
      final saveResult = await repository.save(entity);
      expect(saveResult, isA<Right<Failure, void>>());

      final result = await repository.getActiveShift('user1');
      final shift = result.fold(
        (failure) => throw failure,
        (s) => s,
      );
      expect(shift, isNull);
    });
  });

  group('save', () {
    test('persists a new shift and returns it via getActiveShift', () async {
      final now = DateTime.now();
      final entity = ShiftEntity(
        id: 'shift-3',
        username: 'user2',
        startedAt: now,
        openingFloat: 200,
      );
      final saveResult = await repository.save(entity);
      expect(saveResult, isA<Right<Failure, void>>());

      final result = await repository.getActiveShift('user2');
      final shift = result.fold(
        (failure) => throw failure,
        (s) => s,
      );
      expect(shift, isNotNull);
      expect(shift!.id, 'shift-3');
      expect(shift.openingFloat, 200);
    });

    test('save with endedAt results in no active shift', () async {
      final now = DateTime.now();
      final entity = ShiftEntity(
        id: 'shift-4',
        username: 'user3',
        startedAt: now,
        endedAt: now.add(const Duration(hours: 8)),
        openingFloat: 150,
      );
      final saveResult = await repository.save(entity);
      expect(saveResult, isA<Right<Failure, void>>());

      final result = await repository.getActiveShift('user3');
      final shift = result.fold(
        (failure) => throw failure,
        (s) => s,
      );
      expect(shift, isNull);
    });
  });

  group('getByMonth', () {
    test('filters shifts by year and month', () async {
      final jan15 = DateTime(2025, 1, 15);
      final jan20 = DateTime(2025, 1, 20);
      final feb10 = DateTime(2025, 2, 10);

      await repository.save(ShiftEntity(id: 's1', username: 'u1', startedAt: jan15, openingFloat: 100));
      await repository.save(ShiftEntity(id: 's2', username: 'u1', startedAt: jan20, endedAt: jan20.add(const Duration(hours: 8)), openingFloat: 200));
      await repository.save(ShiftEntity(id: 's3', username: 'u1', startedAt: feb10, openingFloat: 300));

      final result = await repository.getByMonth(2025, 1);
      final shifts = result.fold(
        (failure) => throw failure,
        (list) => list,
      );

      expect(shifts.length, 2);
      expect(shifts.any((s) => s.id == 's1'), isTrue);
      expect(shifts.any((s) => s.id == 's2'), isTrue);
      expect(shifts.any((s) => s.id == 's3'), isFalse);
    });
  });
}
