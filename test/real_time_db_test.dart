import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cashier_system/core/backend/database/real_time_db.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/core/error/either.dart';

class MockDatabaseReference extends Mock implements DatabaseReference {}

class MockDataSnapshot extends Mock implements DataSnapshot {}

void main() {
  late MockDatabaseReference mockRootRef;
  late MockDataSnapshot mockSnapshot;
  const tenantId = 'test-tenant-uid-123';

  setUpAll(() {
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    mockRootRef = MockDatabaseReference();
    mockSnapshot = MockDataSnapshot();
    // Every child() returns the same mock, so the leaf ref is mockRootRef.
    when(() => mockRootRef.child(any())).thenAnswer((_) => mockRootRef);
  });

  RealTimeDb makeDb() => RealTimeDb(database: mockRootRef, tenantId: tenantId);

  test('createSession stores session by username within tenant', () async {
    when(() => mockRootRef.set(any())).thenAnswer((_) async {});

    final db = makeDb();
    final result = await db.createSession(
      username: 'omar',
      deviceId: 'device-1',
    );

    expect(result, isA<Right<Failure, SessionData>>());
    final session = result.fold((l) => null, (r) => r)!;
    expect(session.username, equals('omar'));
    expect(session.tenantId, equals(tenantId));
    expect(session.deviceId, equals('device-1'));
    expect(session.isActive, isTrue);
    verify(() => mockRootRef.set(any())).called(1);
  });

  test('createSession rejects empty username', () async {
    final db = makeDb();
    final result = await db.createSession(username: '', deviceId: 'device-1');

    expect(result, isA<Left<Failure, SessionData>>());
    result.fold(
      (failure) => expect(failure, isA<ValidationFailure>()),
      (r) => fail('Expected Left'),
    );
  });

  test('createSession rejects empty deviceId', () async {
    final db = makeDb();
    final result = await db.createSession(username: 'omar', deviceId: '');

    expect(result, isA<Left<Failure, SessionData>>());
    result.fold(
      (failure) => expect(failure, isA<ValidationFailure>()),
      (r) => fail('Expected Left'),
    );
  });

  test('getSession returns null when session does not exist', () async {
    when(() => mockSnapshot.exists).thenReturn(false);
    when(() => mockRootRef.get()).thenAnswer((_) async => mockSnapshot);

    final db = makeDb();
    final result = await db.getSession(username: 'omar', deviceId: 'device-1');

    expect(result, isA<Right<Failure, SessionData?>>());
    expect(result.fold((l) => fail('Expected Right'), (r) => r), isNull);
  });

  test('getSession returns active session when it exists', () async {
    final now = DateTime.now();
    when(() => mockSnapshot.exists).thenReturn(true);
    when(() => mockSnapshot.value).thenReturn({
      'username': 'omar',
      'tenantId': tenantId,
      'deviceId': 'device-1',
      'startedAt': now.millisecondsSinceEpoch,
      'lastActiveAt': now.millisecondsSinceEpoch,
      'isActive': true,
    });
    when(() => mockRootRef.get()).thenAnswer((_) async => mockSnapshot);

    final db = makeDb();
    final result = await db.getSession(username: 'omar', deviceId: 'device-1');

    expect(result, isA<Right<Failure, SessionData?>>());
    final session = result.fold((l) => fail('Expected Right'), (r) => r)!;
    expect(session.username, equals('omar'));
    expect(session.isActive, isTrue);
  });

  test('endSession returns Left when session not found', () async {
    when(() => mockSnapshot.exists).thenReturn(false);
    when(() => mockRootRef.get()).thenAnswer((_) async => mockSnapshot);

    final db = makeDb();
    final result = await db.endSession(username: 'ghost', deviceId: 'device-9');

    expect(result, isA<Left<Failure, SessionData>>());
    result.fold(
      (failure) => expect(failure, isA<DatabaseFailure>()),
      (r) => fail('Expected Left'),
    );
  });

  test('getActiveSessionsForUser returns empty list when none', () async {
    when(() => mockSnapshot.exists).thenReturn(false);
    when(() => mockRootRef.get()).thenAnswer((_) async => mockSnapshot);

    final db = makeDb();
    final result = await db.getActiveSessionsForUser(username: 'omar');

    expect(result, isA<Right<Failure, List<SessionData>>>());
    expect(result.fold((l) => fail('Expected Right'), (r) => r), isEmpty);
  });

  test('SessionData toMap/fromMap roundtrip', () {
    final now = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().millisecondsSinceEpoch,
    );
    final original = SessionData(
      username: 'omar',
      tenantId: tenantId,
      deviceId: 'device-1',
      startedAt: now,
      lastActiveAt: now,
      isActive: true,
    );

    final restored = SessionData.fromMap(original.toMap());
    expect(restored, equals(original));
  });
}
