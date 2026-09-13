import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cashier_system/core/backend/auth/firebase_auth_service.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/core/error/either.dart';

class MockUser extends Mock implements User {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUserCredential extends Mock implements UserCredential {}

void main() {
  late MockFirebaseAuth mockFirebaseAuth;
  late MockUser mockUser;
  late MockUserCredential mockUserCredential;

  setUpAll(() {
    registerFallbackValue(MockUser());
    registerFallbackValue(MockUserCredential());
  });

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockUserCredential = MockUserCredential();
  });

  test('Firebase auth initializes with tenant ID model', () {
    when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('test-tenant-uid-123');

    final auth = FirebaseAuthService(auth: mockFirebaseAuth);
    expect(auth.getCurrentTenantId(), equals('test-tenant-uid-123'));
    expect(auth.isAuthenticated, isTrue);
    expect(auth.tenantId, equals('test-tenant-uid-123'));
    expect(auth.currentUserUid, equals('test-tenant-uid-123'));
  });

  test('Firebase auth returns empty tenant ID when not authenticated', () {
    when(() => mockFirebaseAuth.currentUser).thenReturn(null);

    final auth = FirebaseAuthService(auth: mockFirebaseAuth);
    expect(auth.getCurrentTenantId(), equals(''));
    expect(auth.isAuthenticated, isFalse);
    expect(auth.tenantId, equals(''));
    expect(auth.currentUserUid, isNull);
  });

  test('Firebase auth tenantId is reactive to auth state changes', () {
    when(() => mockFirebaseAuth.currentUser).thenReturn(null);

    final auth = FirebaseAuthService(auth: mockFirebaseAuth);
    expect(auth.tenantId, equals(''));

    // Simulate user signing in
    when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('new-tenant-uid-456');

    expect(auth.tenantId, equals('new-tenant-uid-456'));
    expect(auth.isAuthenticated, isTrue);
  });

  test('Firebase auth exposes authStateChanges stream', () {
    final stream = Stream<User?>.value(mockUser);
    when(() => mockFirebaseAuth.authStateChanges()).thenAnswer((_) => stream);

    final auth = FirebaseAuthService(auth: mockFirebaseAuth);
    expect(auth.authStateChanges, equals(stream));
  });

  test('Firebase auth exposes idTokenChanges stream', () {
    final stream = Stream<User?>.value(mockUser);
    when(() => mockFirebaseAuth.idTokenChanges()).thenAnswer((_) => stream);

    final auth = FirebaseAuthService(auth: mockFirebaseAuth);
    expect(auth.idTokenChanges, equals(stream));
  });

  test('signInWithEmailAndPassword returns Right on success', () async {
    when(
      () => mockFirebaseAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      ),
    ).thenAnswer((_) async => mockUserCredential);

    final auth = FirebaseAuthService(auth: mockFirebaseAuth);
    final result = await auth.signInWithEmailAndPassword(
      email: 'test@example.com',
      password: 'password123',
    );

    expect(result, isA<Right<Failure, UserCredential>>());
    expect(result.fold((l) => null, (r) => r), equals(mockUserCredential));
  });

  test(
    'signInWithEmailAndPassword returns Left on FirebaseAuthException',
    () async {
      when(
        () => mockFirebaseAuth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        ),
      ).thenThrow(
        FirebaseAuthException(
          code: 'user-not-found',
          message: 'User not found',
        ),
      );

      final auth = FirebaseAuthService(auth: mockFirebaseAuth);
      final result = await auth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      );

      expect(result, isA<Left<Failure, UserCredential>>());
      result.fold(
        (failure) => expect(failure, isA<DatabaseFailure>()),
        (r) => fail('Expected Left'),
      );
    },
  );

  test('signOut returns Right on success', () async {
    when(() => mockFirebaseAuth.signOut()).thenAnswer((_) async {});

    final auth = FirebaseAuthService(auth: mockFirebaseAuth);
    final result = await auth.signOut();

    expect(result, isA<Right<Failure, void>>());
  });

  test('signOut returns Left on FirebaseAuthException', () async {
    when(() => mockFirebaseAuth.signOut()).thenThrow(
      FirebaseAuthException(code: 'network-error', message: 'Network error'),
    );

    final auth = FirebaseAuthService(auth: mockFirebaseAuth);
    final result = await auth.signOut();

    expect(result, isA<Left<Failure, void>>());
    result.fold(
      (failure) => expect(failure, isA<DatabaseFailure>()),
      (r) => fail('Expected Left'),
    );
  });

  test('createUserWithEmailAndPassword returns Right on success', () async {
    when(
      () => mockFirebaseAuth.createUserWithEmailAndPassword(
        email: 'new@example.com',
        password: 'password123',
      ),
    ).thenAnswer((_) async => mockUserCredential);

    final auth = FirebaseAuthService(auth: mockFirebaseAuth);
    final result = await auth.createUserWithEmailAndPassword(
      email: 'new@example.com',
      password: 'password123',
    );

    expect(result, isA<Right<Failure, UserCredential>>());
    expect(result.fold((l) => null, (r) => r), equals(mockUserCredential));
  });

  test('sendPasswordResetEmail returns Right on success', () async {
    when(
      () => mockFirebaseAuth.sendPasswordResetEmail(email: 'test@example.com'),
    ).thenAnswer((_) async {});

    final auth = FirebaseAuthService(auth: mockFirebaseAuth);
    final result = await auth.sendPasswordResetEmail(email: 'test@example.com');

    expect(result, isA<Right<Failure, void>>());
  });
}
