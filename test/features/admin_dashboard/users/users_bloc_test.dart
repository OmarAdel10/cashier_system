// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cashier_system/core/backend/workers/api_client.dart';
import 'package:cashier_system/core/config/env_config.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/admin_dashboard/users/users_bloc.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  setUpAll(() {
    EnvConfig.initializeFromEnv();
    registerFallbackValue(<String, String>{});
    registerFallbackValue(<String, dynamic>{});
  });

  late MockApiClient api;

  setUp(() {
    api = MockApiClient();
    when(
      () => api.get(
        any(),
        idToken: any(named: 'idToken'),
        query: any(named: 'query'),
      ),
    ).thenAnswer(
      (_) async => const Right(<String, dynamic>{
        'ok': true,
        'data': {
          'users': [
            {'username': 'boss', 'role': 'admin', 'is_active': 1},
          ],
        },
      }),
    );
    when(
      () => api.post(any(), any(), idToken: any(named: 'idToken')),
    ).thenAnswer((_) async => const Right(<String, dynamic>{'ok': true}));
    when(
      () => api.patch(any(), any(), idToken: any(named: 'idToken')),
    ).thenAnswer((_) async => const Right(<String, dynamic>{'ok': true}));
    when(
      () => api.delete(any(), idToken: any(named: 'idToken')),
    ).thenAnswer((_) async => const Right(<String, dynamic>{'ok': true}));
  });

  UsersBloc makeBloc() => UsersBloc(api: api, tokenProvider: () async => 'tok');

  group('UsersBloc', () {
    test('UsersRequested loads the list → UsersLoaded', () async {
      final bloc = makeBloc();
      final states = <UsersState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const UsersRequested());
      await bloc.stream.firstWhere((s) => s is UsersLoaded);
      final loaded = states.last as UsersLoaded;
      expect(loaded.users, hasLength(1));
      expect(loaded.users.first['username'], 'boss');
      await sub.cancel();
      await bloc.close();
    });

    test('UserCreated posts and refreshes the list', () async {
      final bloc = makeBloc();
      final states = <UsersState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const UserCreated('new1', 'pw12345678', 'cashier', 'N'));
      await bloc.stream.firstWhere((s) => s is UsersLoaded);
      final post = verify(
        () => api.post(
          captureAny(),
          captureAny(),
          idToken: any(named: 'idToken'),
        ),
      );
      expect(post.captured[0], '/admin/users');
      final body = post.captured[1] as Map<String, dynamic>;
      expect(body['username'], 'new1');
      expect(body['role'], 'cashier');
      expect(body['display_name'], 'N');
      await sub.cancel();
      await bloc.close();
    });

    test('UserCreated 409 → the Arabic USERNAME_TAKEN message', () async {
      when(
        () => api.post(any(), any(), idToken: any(named: 'idToken')),
      ).thenAnswer(
        (_) async => const Right(<String, dynamic>{
          'ok': false,
          'error': 'USERNAME_TAKEN',
        }),
      );
      final bloc = makeBloc();
      final states = <UsersState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const UserCreated('dup', 'pw12345678', 'cashier', null));
      await bloc.stream.firstWhere((s) => s is UsersError);
      expect(
        (states.last as UsersError).messageAr,
        'اسم المستخدم مستخدم بالفعل. اختر اسمًا آخر.',
      );
      await sub.cancel();
      await bloc.close();
    });

    test(
      'UserCreated 403 → the Arabic ADMIN_MANAGEMENT_OWNER_ONLY message',
      () async {
        when(
          () => api.post(any(), any(), idToken: any(named: 'idToken')),
        ).thenAnswer(
          (_) async => const Right(<String, dynamic>{
            'ok': false,
            'error': 'ADMIN_MANAGEMENT_OWNER_ONLY',
          }),
        );
        final bloc = makeBloc();
        final states = <UsersState>[];
        final sub = bloc.stream.listen(states.add);
        bloc.add(const UserCreated('mgr', 'pw12345678', 'admin', null));
        await bloc.stream.firstWhere((s) => s is UsersError);
        expect(
          (states.last as UsersError).messageAr,
          'إدارة الأدمن من صلاحيات المالك فقط.',
        );
        await sub.cancel();
        await bloc.close();
      },
    );

    test('UserSaved patches; UserDeleted deletes', () async {
      final bloc = makeBloc();
      final states = <UsersState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const UserSaved('boss', password: 'newpass123'));
      await bloc.stream.firstWhere((s) => s is UsersLoaded);
      final patch = verify(
        () => api.patch(
          captureAny(),
          captureAny(),
          idToken: any(named: 'idToken'),
        ),
      );
      expect(patch.captured[0], '/admin/users/boss');
      expect((patch.captured[1] as Map)['password'], 'newpass123');

      bloc.add(const UserDeleted('boss'));
      await bloc.stream.firstWhere((s) => s is UsersLoaded);
      verify(
        () => api.delete('/admin/users/boss', idToken: any(named: 'idToken')),
      ).called(1);
      await sub.cancel();
      await bloc.close();
    });

    test('UsersRequested Left → the Arabic load error', () async {
      final bloc = makeBloc();
      final states = <UsersState>[];
      final sub = bloc.stream.listen(states.add);

      // Left (network/format error) — must not render as an empty list.
      when(
        () => api.get(
          any(),
          idToken: any(named: 'idToken'),
          query: any(named: 'query'),
        ),
      ).thenAnswer((_) async => const Left(DatabaseFailure('GET failed')));
      bloc.add(const UsersRequested());
      await bloc.stream.firstWhere((s) => s is UsersError);
      expect(
        (states.last as UsersError).messageAr,
        'فشل تحميل المستخدمين. حاول مجددًا.',
      );

      await sub.cancel();
      await bloc.close();
    });

    // A fresh bloc per scenario: bloc v9's emit is a no-op when the new
    // state equals the current state and was already emitted once — two
    // identical const UsersError emits in one bloc would swallow the
    // second (no stream event, firstWhere would hang).
    test('UsersRequested ok:false → the same Arabic load error', () async {
      final bloc = makeBloc();
      final states = <UsersState>[];
      final sub = bloc.stream.listen(states.add);

      // A 5xx JSON body with ok:false — same error, no empty list.
      when(
        () => api.get(
          any(),
          idToken: any(named: 'idToken'),
          query: any(named: 'query'),
        ),
      ).thenAnswer((_) async => const Right(<String, dynamic>{'ok': false}));
      bloc.add(const UsersRequested());
      await bloc.stream.firstWhere((s) => s is UsersError);
      expect(
        (states.last as UsersError).messageAr,
        'فشل تحميل المستخدمين. حاول مجددًا.',
      );

      await sub.cancel();
      await bloc.close();
    });

    test('a null token → the session-expired error', () async {
      final bloc = UsersBloc(api: api, tokenProvider: () async => null);
      final states = <UsersState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const UsersRequested());
      await bloc.stream.firstWhere((s) => s is UsersError);
      expect((states.last as UsersError).messageAr, contains('انتهت الجلسة'));
      await sub.cancel();
      await bloc.close();
    });

    test(
      'UsersRequested with a throwing api → the Arabic load error',
      () async {
        // A thrown error (not a Left body) hits the catch — same surface.
        when(
          () => api.get(
            any(),
            idToken: any(named: 'idToken'),
            query: any(named: 'query'),
          ),
        ).thenThrow(StateError('down'));
        final bloc = makeBloc();
        final states = <UsersState>[];
        final sub = bloc.stream.listen(states.add);
        bloc.add(const UsersRequested());
        await bloc.stream.firstWhere((s) => s is UsersError);
        expect(
          (states.last as UsersError).messageAr,
          'فشل تحميل المستخدمين. حاول مجددًا.',
        );
        await sub.cancel();
        await bloc.close();
      },
    );

    test('UserCreated with a throwing api → the Arabic create error', () async {
      when(
        () => api.post(any(), any(), idToken: any(named: 'idToken')),
      ).thenThrow(StateError('down'));
      final bloc = makeBloc();
      final states = <UsersState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const UserCreated('new1', 'pw12345678', 'cashier', null));
      await bloc.stream.firstWhere((s) => s is UsersError);
      expect(
        (states.last as UsersError).messageAr,
        'فشل إنشاء المستخدم. حاول مجددًا.',
      );
      await sub.cancel();
      await bloc.close();
    });

    test('UserSaved patches the isActive + displayName variant', () async {
      final bloc = makeBloc();
      final states = <UsersState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const UserSaved('boss', displayName: 'Boss 2', isActive: 0));
      await bloc.stream.firstWhere((s) => s is UsersLoaded);
      final patch = verify(
        () => api.patch(
          captureAny(),
          captureAny(),
          idToken: any(named: 'idToken'),
        ),
      );
      expect(patch.captured[0], '/admin/users/boss');
      final body = patch.captured[1] as Map;
      expect(body['display_name'], 'Boss 2');
      expect(body['is_active'], 0);
      expect(body.containsKey('password'), isFalse); // null → key omitted
      await sub.cancel();
      await bloc.close();
    });

    test('UserSaved ok:false → the Arabic OWNER_ONLY message', () async {
      when(
        () => api.patch(any(), any(), idToken: any(named: 'idToken')),
      ).thenAnswer(
        (_) async =>
            const Right(<String, dynamic>{'ok': false, 'error': 'OWNER_ONLY'}),
      );
      final bloc = makeBloc();
      final states = <UsersState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const UserSaved('boss', password: 'pw12345678'));
      await bloc.stream.firstWhere((s) => s is UsersError);
      expect(
        (states.last as UsersError).messageAr,
        'هذه العملية من صلاحيات المالك فقط.',
      );
      await sub.cancel();
      await bloc.close();
    });

    test('UserDeleted ok:false → the Arabic USER_NOT_FOUND message', () async {
      when(() => api.delete(any(), idToken: any(named: 'idToken'))).thenAnswer(
        (_) async => const Right(<String, dynamic>{
          'ok': false,
          'error': 'USER_NOT_FOUND',
        }),
      );
      final bloc = makeBloc();
      final states = <UsersState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const UserDeleted('ghost'));
      await bloc.stream.firstWhere((s) => s is UsersError);
      expect((states.last as UsersError).messageAr, 'المستخدم غير موجود.');
      await sub.cancel();
      await bloc.close();
    });

    test('UserCreated ok:false → the Arabic INVALID_FIELDS message', () async {
      when(
        () => api.post(any(), any(), idToken: any(named: 'idToken')),
      ).thenAnswer(
        (_) async => const Right(<String, dynamic>{
          'ok': false,
          'error': 'INVALID_FIELDS',
        }),
      );
      final bloc = makeBloc();
      final states = <UsersState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const UserCreated('bad', 'pw12345678', 'cashier', null));
      await bloc.stream.firstWhere((s) => s is UsersError);
      expect((states.last as UsersError).messageAr, 'تحقق من الحقول المدخلة.');
      await sub.cancel();
      await bloc.close();
    });

    test('an unknown error code → the default Arabic message', () async {
      when(
        () => api.patch(any(), any(), idToken: any(named: 'idToken')),
      ).thenAnswer(
        (_) async => const Right(<String, dynamic>{
          'ok': false,
          'error': 'SOMETHING_ELSE',
        }),
      );
      final bloc = makeBloc();
      final states = <UsersState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const UserSaved('boss', password: 'pw12345678'));
      await bloc.stream.firstWhere((s) => s is UsersError);
      expect(
        (states.last as UsersError).messageAr,
        'فشلت العملية. حاول مجددًا.',
      );
      await sub.cancel();
      await bloc.close();
    });

    test(
      'a null token on create/save/delete → the session-expired error',
      () async {
        // The same session-expired guard guards every handler; only the
        // UsersRequested one is covered above.
        final events = <UsersEvent>[
          const UserCreated('new1', 'pw12345678', 'cashier', null),
          const UserSaved('boss', password: 'pw12345678'),
          const UserDeleted('boss'),
        ];
        for (final event in events) {
          final bloc = UsersBloc(api: api, tokenProvider: () async => null);
          final states = <UsersState>[];
          final sub = bloc.stream.listen(states.add);
          bloc.add(event);
          await bloc.stream.firstWhere((s) => s is UsersError);
          expect(
            (states.last as UsersError).messageAr,
            contains('انتهت الجلسة'),
          );
          await sub.cancel();
          await bloc.close();
        }
      },
    );
  });
}
