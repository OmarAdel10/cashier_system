import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cashier_system/core/backend/auth/firebase_auth_service.dart';

class MockUser extends Mock implements User {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  late MockFirebaseAuth mockFirebaseAuth;
  late MockUser mockUser;

  setUpAll(() {
    registerFallbackValue(MockUser());
  });

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    mockUser = MockUser();
  });

  test('Firebase auth initializes with tenant ID model', () {
    when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('test-tenant-uid-123');

    final auth = FirebaseAuthService(auth: mockFirebaseAuth);
    expect(auth.getCurrentTenantId(), equals('test-tenant-uid-123'));
    expect(auth.isAuthenticated, isTrue);
  });

  test('Firebase auth returns empty tenant ID when not authenticated', () {
    when(() => mockFirebaseAuth.currentUser).thenReturn(null);

    final auth = FirebaseAuthService(auth: mockFirebaseAuth);
    expect(auth.getCurrentTenantId(), equals(''));
    expect(auth.isAuthenticated, isFalse);
  });
}
