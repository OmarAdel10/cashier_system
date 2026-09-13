import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cashier_system/core/backend/auth/firebase_auth_service.dart';
import 'package:cashier_system/core/backend/database/real_time_db.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/core/error/either.dart';

class MockDatabaseReference extends Mock implements DatabaseReference {}

class MockDataSnapshot extends Mock implements DataSnapshot {}

class MockDatabaseEvent extends Mock implements DatabaseEvent {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

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

  Map<String, Object?> sessionMap({
    String username = 'omar',
    String deviceId = 'device-1',
    bool isActive = true,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'username': username,
      'tenantId': tenantId,
      'deviceId': deviceId,
      'startedAt': now,
      'lastActiveAt': now,
      'isActive': isActive,
    };
  }

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

  test('createSession rejects invalid username format', () async {
    final db = makeDb();
    for (final bad in ['ab', 'a' * 31, 'bad-name!', 'with space', 'om@r']) {
      final result = await db.createSession(
        username: bad,
        deviceId: 'device-1',
      );
      expect(result, isA<Left<Failure, SessionData>>(), reason: bad);
      result.fold((failure) {
        expect(failure, isA<ValidationFailure>());
        expect((failure as ValidationFailure).reason, equals('invalid-format'));
      }, (r) => fail('Expected Left for $bad'));
    }
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

  test('updateSessionActivity happy path refreshes lastActiveAt', () async {
    final old = DateTime.now().subtract(const Duration(hours: 1));
    when(() => mockSnapshot.exists).thenReturn(true);
    when(() => mockSnapshot.value).thenReturn({
      'username': 'omar',
      'tenantId': tenantId,
      'deviceId': 'device-1',
      'startedAt': old.millisecondsSinceEpoch,
      'lastActiveAt': old.millisecondsSinceEpoch,
      'isActive': true,
    });
    when(() => mockRootRef.get()).thenAnswer((_) async => mockSnapshot);
    when(() => mockRootRef.update(any())).thenAnswer((_) async {});

    final db = makeDb();
    final result = await db.updateSessionActivity(
      username: 'omar',
      deviceId: 'device-1',
    );

    expect(result, isA<Right<Failure, SessionData>>());
    final updated = result.fold((l) => fail('Expected Right'), (r) => r);
    expect(updated.isActive, isTrue);
    expect(
      updated.lastActiveAt!.isAfter(old),
      isTrue,
      reason: 'lastActiveAt should refresh',
    );
    verify(() => mockRootRef.update(any())).called(1);
  });

  test('endSession happy path marks session inactive', () async {
    when(() => mockSnapshot.exists).thenReturn(true);
    when(() => mockSnapshot.value).thenReturn(
      sessionMap(username: 'omar', deviceId: 'device-1', isActive: true),
    );
    when(() => mockRootRef.get()).thenAnswer((_) async => mockSnapshot);
    when(() => mockRootRef.update(any())).thenAnswer((_) async {});

    final db = makeDb();
    final result = await db.endSession(username: 'omar', deviceId: 'device-1');

    expect(result, isA<Right<Failure, SessionData>>());
    final ended = result.fold((l) => fail('Expected Right'), (r) => r);
    expect(ended.isActive, isFalse);
    expect(ended.lastActiveAt, isNotNull);
    verify(() => mockRootRef.update(any())).called(1);
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

  test('getAllActiveSessions returns active sessions across users', () async {
    final userSnap = MockDataSnapshot();
    final activeDevice = MockDataSnapshot();
    final inactiveDevice = MockDataSnapshot();
    final corruptDevice = MockDataSnapshot();

    when(() => mockSnapshot.exists).thenReturn(true);
    when(() => mockSnapshot.children).thenReturn([userSnap]);
    when(
      () => userSnap.children,
    ).thenReturn([activeDevice, inactiveDevice, corruptDevice]);
    when(() => activeDevice.value).thenReturn(
      sessionMap(username: 'omar', deviceId: 'device-1', isActive: true),
    );
    when(() => inactiveDevice.value).thenReturn(
      sessionMap(username: 'omar', deviceId: 'device-2', isActive: false),
    );
    when(() => corruptDevice.value).thenReturn('not-a-map');
    when(() => mockRootRef.get()).thenAnswer((_) async => mockSnapshot);

    final db = makeDb();
    final result = await db.getAllActiveSessions();

    expect(result, isA<Right<Failure, List<SessionData>>>());
    final sessions = result.fold((l) => fail('Expected Right'), (r) => r);
    expect(sessions, hasLength(1));
    expect(sessions.first.deviceId, equals('device-1'));
  });

  test('watchActiveSessionsForUser emits active sessions only', () async {
    final event = MockDatabaseEvent();
    final eventSnap = MockDataSnapshot();
    final activeDevice = MockDataSnapshot();
    final inactiveDevice = MockDataSnapshot();

    when(() => event.snapshot).thenReturn(eventSnap);
    when(() => eventSnap.exists).thenReturn(true);
    when(() => eventSnap.children).thenReturn([activeDevice, inactiveDevice]);
    when(() => activeDevice.value).thenReturn(
      sessionMap(username: 'omar', deviceId: 'device-1', isActive: true),
    );
    when(() => inactiveDevice.value).thenReturn(
      sessionMap(username: 'omar', deviceId: 'device-2', isActive: false),
    );
    when(() => mockRootRef.onValue).thenAnswer((_) => Stream.value(event));

    final db = makeDb();
    final sessions = await db.watchActiveSessionsForUser('omar').first;

    expect(sessions, hasLength(1));
    expect(sessions.first.deviceId, equals('device-1'));
  });

  test('watchAllActiveSessions emits active sessions across users', () async {
    final event = MockDatabaseEvent();
    final eventSnap = MockDataSnapshot();
    final userSnap = MockDataSnapshot();
    final activeDevice = MockDataSnapshot();
    final corruptDevice = MockDataSnapshot();

    when(() => event.snapshot).thenReturn(eventSnap);
    when(() => eventSnap.exists).thenReturn(true);
    when(() => eventSnap.children).thenReturn([userSnap]);
    when(() => userSnap.children).thenReturn([activeDevice, corruptDevice]);
    when(() => activeDevice.value).thenReturn(
      sessionMap(username: 'omar', deviceId: 'device-1', isActive: true),
    );
    when(() => corruptDevice.value).thenReturn(42);
    when(() => mockRootRef.onValue).thenAnswer((_) => Stream.value(event));

    final db = makeDb();
    final sessions = await db.watchAllActiveSessions().first;

    expect(sessions, hasLength(1));
    expect(sessions.first.username, equals('omar'));
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

  test('SessionData.fromMap throws FormatException on missing keys', () {
    expect(
      () => SessionData.fromMap({'username': 'omar'}),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => SessionData.fromMap(const {}),
      throwsA(isA<FormatException>()),
    );
  });

  test('SessionData.fromMap throws FormatException on wrong types', () {
    expect(
      () => SessionData.fromMap({
        'username': 'omar',
        'tenantId': tenantId,
        'deviceId': 'device-1',
        'startedAt': 'not-an-int',
        'isActive': true,
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => SessionData.fromMap({
        'username': 'omar',
        'tenantId': tenantId,
        'deviceId': 'device-1',
        'startedAt': DateTime.now().millisecondsSinceEpoch,
        'isActive': 'yes',
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => SessionData.fromMap({
        'username': 'bad-name!',
        'tenantId': tenantId,
        'deviceId': 'device-1',
        'startedAt': DateTime.now().millisecondsSinceEpoch,
        'isActive': true,
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('fromAuth throws StateError when no user signed in', () {
    final mockAuth = MockFirebaseAuth();
    when(() => mockAuth.currentUser).thenReturn(null);
    final svc = FirebaseAuthService(auth: mockAuth);

    expect(
      () => RealTimeDb.fromAuth(database: mockRootRef, authService: svc),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'cleanupInactiveSessions removes only stale inactive sessions',
    () async {
      final userSnap = MockDataSnapshot();
      final staleDevice = MockDataSnapshot();
      final freshDevice = MockDataSnapshot();
      final activeDevice = MockDataSnapshot();
      final staleRef = MockDatabaseReference();
      final freshRef = MockDatabaseReference();
      final activeRef = MockDatabaseReference();

      final old = DateTime.now().subtract(const Duration(days: 30));
      final now = DateTime.now();
      Map<String, Object?> inactiveMap(String deviceId, DateTime lastActive) =>
          {
            'username': 'omar',
            'tenantId': tenantId,
            'deviceId': deviceId,
            'startedAt': old.millisecondsSinceEpoch,
            'lastActiveAt': lastActive.millisecondsSinceEpoch,
            'isActive': false,
          };

      when(() => mockSnapshot.exists).thenReturn(true);
      when(() => mockSnapshot.children).thenReturn([userSnap]);
      when(
        () => userSnap.children,
      ).thenReturn([staleDevice, freshDevice, activeDevice]);
      when(() => staleDevice.value).thenReturn(inactiveMap('old-device', old));
      when(() => staleDevice.ref).thenReturn(staleRef);
      when(
        () => freshDevice.value,
      ).thenReturn(inactiveMap('fresh-device', now));
      when(() => freshDevice.ref).thenReturn(freshRef);
      when(() => activeDevice.value).thenReturn(
        sessionMap(username: 'omar', deviceId: 'active-device', isActive: true),
      );
      when(() => activeDevice.ref).thenReturn(activeRef);
      when(() => staleRef.remove()).thenAnswer((_) async {});
      when(() => mockRootRef.get()).thenAnswer((_) async => mockSnapshot);

      final db = makeDb();
      final result = await db.cleanupInactiveSessions(
        maxAge: const Duration(days: 7),
      );

      expect(result, isA<Right<Failure, int>>());
      expect(result.fold((l) => fail('Expected Right'), (r) => r), equals(1));
      verify(() => staleRef.remove()).called(1);
      verifyNever(() => freshRef.remove());
      verifyNever(() => activeRef.remove());
    },
  );
}
