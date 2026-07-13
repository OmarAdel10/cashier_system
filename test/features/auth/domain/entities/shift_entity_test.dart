import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/auth/domain/entities/shift_entity.dart';

void main() {
  group('ShiftEntity', () {
    final now = DateTime.now();
    final shift = ShiftEntity(
      id: 'test-id',
      username: 'cashier1',
      startedAt: now,
    );

    test('should create with default openingFloat', () {
      expect(shift.openingFloat, 0);
      expect(shift.endedAt, isNull);
    });

    test('copyWith should override fields', () {
      final ended = now.add(const Duration(hours: 8));
      final modified = shift.copyWith(endedAt: ended, openingFloat: 500);
      expect(modified.endedAt, ended);
      expect(modified.openingFloat, 500);
      expect(modified.id, shift.id);
      expect(modified.username, shift.username);
    });

    test('equality should work', () {
      final same = ShiftEntity(
        id: 'test-id',
        username: 'cashier1',
        startedAt: now,
      );
      final different = ShiftEntity(
        id: 'other-id',
        username: 'cashier2',
        startedAt: now,
      );
      expect(same == shift, isTrue);
      expect(same.hashCode, shift.hashCode);
      expect(different == shift, isFalse);
    });
  });
}
