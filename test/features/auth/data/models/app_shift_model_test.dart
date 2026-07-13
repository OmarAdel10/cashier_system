import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/auth/data/models/app_shift_model.dart';
import 'package:cashier_system/features/auth/domain/entities/shift_entity.dart';

void main() {
  final now = DateTime(2026, 7, 13, 10, 30, 0);

  group('AppShiftModel', () {
    group('fromJson', () {
      test('should parse minimal json', () {
        final json = <String, dynamic>{
          'id': 'shift-1',
          'username': 'cashier1',
          'startedAt': now.toIso8601String(),
        };
        final model = AppShiftModel.fromJson(json);
        expect(model.id, 'shift-1');
        expect(model.username, 'cashier1');
        expect(model.startedAt, now);
        expect(model.endedAt, isNull);
        expect(model.openingFloat, 0);
      });

      test('should parse full json with endedAt and openingFloat', () {
        final ended = now.add(const Duration(hours: 8));
        final json = <String, dynamic>{
          'id': 'shift-2',
          'username': 'admin',
          'startedAt': now.toIso8601String(),
          'endedAt': ended.toIso8601String(),
          'openingFloat': 500,
        };
        final model = AppShiftModel.fromJson(json);
        expect(model.id, 'shift-2');
        expect(model.username, 'admin');
        expect(model.startedAt, now);
        expect(model.endedAt, ended);
        expect(model.openingFloat, 500);
      });

      test('should use defaults for missing fields', () {
        final json = <String, dynamic>{};
        final model = AppShiftModel.fromJson(json);
        expect(model.id, '');
        expect(model.username, '');
        expect(model.startedAt, isA<DateTime>());
        expect(model.endedAt, isNull);
        expect(model.openingFloat, 0);
      });
    });

    group('toJson', () {
      test('should serialize all fields', () {
        final ended = now.add(const Duration(hours: 8));
        final model = AppShiftModel(
          id: 's1',
          username: 'cashier1',
          startedAt: now,
          endedAt: ended,
          openingFloat: 1000,
        );
        final json = model.toJson();
        expect(json['id'], 's1');
        expect(json['username'], 'cashier1');
        expect(json['startedAt'], now.toIso8601String());
        expect(json['endedAt'], ended.toIso8601String());
        expect(json['openingFloat'], 1000);
      });

      test('should set endedAt to null when not provided', () {
        final model = AppShiftModel(
          id: 's2',
          username: 'cashier1',
          startedAt: now,
        );
        final json = model.toJson();
        expect(json['endedAt'], isNull);
      });
    });

    group('toEntity', () {
      test('should convert to ShiftEntity preserving all fields', () {
        final ended = now.add(const Duration(hours: 8));
        final model = AppShiftModel(
          id: 's1',
          username: 'cashier1',
          startedAt: now,
          endedAt: ended,
          openingFloat: 500,
        );
        final entity = model.toEntity();
        expect(entity, isA<ShiftEntity>());
        expect(entity.id, 's1');
        expect(entity.username, 'cashier1');
        expect(entity.startedAt, now);
        expect(entity.endedAt, ended);
        expect(entity.openingFloat, 500);
      });
    });

    group('round-trip', () {
      test('should serialize and deserialize correctly', () {
        final ended = now.add(const Duration(hours: 8));
        final original = AppShiftModel(
          id: 'rt-1',
          username: 'cashier2',
          startedAt: now,
          endedAt: ended,
          openingFloat: 1500,
        );
        final json = original.toJson();
        final decoded = AppShiftModel.fromJson(json);
        expect(decoded.id, original.id);
        expect(decoded.username, original.username);
        expect(decoded.startedAt, original.startedAt);
        expect(decoded.endedAt, original.endedAt);
        expect(decoded.openingFloat, original.openingFloat);
      });
    });
  });
}
