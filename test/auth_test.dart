import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cashier_system/core/backend/auth/firebase_auth_service.dart';
import 'package:cashier_system/core/config/env_config.dart';
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
    registerFallbackValue(GoogleAuthProvider());
    registerFallbackValue(ActionCodeSettings(url: 'https://x.co'));
    // sendMagicLink reads EnvConfig.adminOrigin (late final — once per
    // process; the established setUpAll pattern).
    EnvConfig.initializeFromEnv();
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

  test('signInWithGooglePopup returns Right on success', () async {
    when(
      () => mockFirebaseAuth.signInWithPopup(any()),
    ).thenAnswer((_) async => mockUserCredential);

    final auth = FirebaseAuthService(auth: mockFirebaseAuth);
    final result = await auth.signInWithGooglePopup();

    expect(result, isA<Right<Failure, UserCredential>>());
    expect(result.fold((l) => null, (r) => r), equals(mockUserCredential));
  });

  test('signInWithGooglePopup returns Left on FirebaseAuthException', () async {
    when(() => mockFirebaseAuth.signInWithPopup(any())).thenThrow(
      FirebaseAuthException(code: 'popup-closed', message: 'Popup closed'),
    );

    final auth = FirebaseAuthService(auth: mockFirebaseAuth);
    final result = await auth.signInWithGooglePopup();

    expect(result, isA<Left<Failure, UserCredential>>());
    result.fold(
      (failure) => expect(failure, isA<DatabaseFailure>()),
      (r) => fail('Expected Left'),
    );
  });

  test(
    'sendMagicLink sends the email-link with the dashboard origin',
    () async {
      when(
        () => mockFirebaseAuth.sendSignInLinkToEmail(
          email: any(named: 'email'),
          actionCodeSettings: any(named: 'actionCodeSettings'),
        ),
      ).thenAnswer((_) async {});

      final auth = FirebaseAuthService(auth: mockFirebaseAuth);
      final result = await auth.sendMagicLink(email: 'owner@daftari.co');

      expect(result, isA<Right<Failure, void>>());
      final settings =
          verify(
                () => mockFirebaseAuth.sendSignInLinkToEmail(
                  email: 'owner@daftari.co',
                  actionCodeSettings: captureAny(named: 'actionCodeSettings'),
                ),
              ).captured.single
              as ActionCodeSettings;
      expect(settings.handleCodeInApp, isTrue);
    },
  );

  test('sendMagicLink returns Left on FirebaseAuthException', () async {
    when(
      () => mockFirebaseAuth.sendSignInLinkToEmail(
        email: any(named: 'email'),
        actionCodeSettings: any(named: 'actionCodeSettings'),
      ),
    ).thenThrow(
      FirebaseAuthException(code: 'invalid-email', message: 'Bad email'),
    );

    final auth = FirebaseAuthService(auth: mockFirebaseAuth);
    final result = await auth.sendMagicLink(email: 'owner@daftari.co');

    expect(result, isA<Left<Failure, void>>());
    result.fold(
      (failure) => expect(failure, isA<DatabaseFailure>()),
      (r) => fail('Expected Left'),
    );
  });

  test('signInWithEmailLink returns Right on success', () async {
    when(
      () => mockFirebaseAuth.signInWithEmailLink(
        email: any(named: 'email'),
        emailLink: any(named: 'emailLink'),
      ),
    ).thenAnswer((_) async => mockUserCredential);

    final auth = FirebaseAuthService(auth: mockFirebaseAuth);
    final result = await auth.signInWithEmailLink(
      email: 'owner@daftari.co',
      link: 'https://link',
    );

    expect(result, isA<Right<Failure, UserCredential>>());
    expect(result.fold((l) => null, (r) => r), equals(mockUserCredential));
  });

  test('signInWithEmailLink returns Left on FirebaseAuthException', () async {
    when(
      () => mockFirebaseAuth.signInWithEmailLink(
        email: any(named: 'email'),
        emailLink: any(named: 'emailLink'),
      ),
    ).thenThrow(
      FirebaseAuthException(code: 'invalid-action-code', message: 'Bad link'),
    );

    final auth = FirebaseAuthService(auth: mockFirebaseAuth);
    final result = await auth.signInWithEmailLink(
      email: 'owner@daftari.co',
      link: 'https://link',
    );

    expect(result, isA<Left<Failure, UserCredential>>());
    result.fold(
      (failure) => expect(failure, isA<DatabaseFailure>()),
      (r) => fail('Expected Left'),
    );
  });

  test('currentIdToken returns the user token', () async {
    when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.getIdToken()).thenAnswer((_) async => 'id-token-123');

    final auth = FirebaseAuthService(auth: mockFirebaseAuth);
    expect(await auth.currentIdToken(), equals('id-token-123'));
  });

  test('currentIdToken returns null when not authenticated', () async {
    when(() => mockFirebaseAuth.currentUser).thenReturn(null);

    final auth = FirebaseAuthService(auth: mockFirebaseAuth);
    expect(await auth.currentIdToken(), isNull);
  });

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
}
