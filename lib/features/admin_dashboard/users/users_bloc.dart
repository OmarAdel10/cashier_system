// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/backend/workers/api_client.dart';

// ---- events ----

sealed class UsersEvent {
  const UsersEvent();
}

class UsersRequested extends UsersEvent {
  const UsersRequested();
}

class UserCreated extends UsersEvent {
  final String username;
  final String password;
  final String role;
  final String? displayName;
  const UserCreated(this.username, this.password, this.role, this.displayName);
}

class UserSaved extends UsersEvent {
  final String username;
  final String? password;
  final String? displayName;
  final int? isActive;
  const UserSaved(
    this.username, {
    this.password,
    this.displayName,
    this.isActive,
  });
}

class UserDeleted extends UsersEvent {
  final String username;
  const UserDeleted(this.username);
}

// ---- state ----

sealed class UsersState {
  const UsersState();
}

class UsersLoading extends UsersState {
  const UsersLoading();
}

class UsersLoaded extends UsersState {
  final List<Map<String, dynamic>> users;
  const UsersLoaded({required this.users});
}

/// The base for every user-screen failure; the two concrete subclasses are
/// what let the view tell a LOAD failure apart from a MUTATION failure.
sealed class UsersFailure extends UsersState {
  final String messageAr;
  const UsersFailure({required this.messageAr});
}

/// A LOAD failure: there is no usable list, so the view shows the error pane
/// (message + retry).
class UsersLoadError extends UsersFailure {
  const UsersLoadError({required super.messageAr});
}

/// A MUTATION failure: the previously loaded list is preserved, so the view
/// keeps rendering it and surfaces the message as a one-shot SnackBar. A
/// failed create/save/delete must never blank the screen.
class UsersMutationFailed extends UsersFailure {
  final List<Map<String, dynamic>> users;
  const UsersMutationFailed({required this.users, required super.messageAr});
}

/// The Users Management bloc (T14) — consumes the T07 routes.
class UsersBloc extends Bloc<UsersEvent, UsersState> {
  final ApiClient _api;
  final Future<String?> Function() _tokenProvider;

  UsersBloc({
    required ApiClient api,
    required Future<String?> Function() tokenProvider,
  }) : _api = api,
       _tokenProvider = tokenProvider,
       super(const UsersLoading()) {
    on<UsersRequested>(_onRequested);
    on<UserCreated>(_onCreated);
    on<UserSaved>(_onSaved);
    on<UserDeleted>(_onDeleted);
  }

  static const _sessionExpiredAr = 'انتهت الجلسة. سجل الدخول من جديد.';

  /// The list the screen is currently showing, so a failed mutation can
  /// re-emit it unchanged.
  List<Map<String, dynamic>> get _currentUsers => switch (state) {
    UsersLoaded(:final users) => users,
    UsersMutationFailed(:final users) => users,
    _ => const <Map<String, dynamic>>[],
  };

  void _failMutation(Emitter<UsersState> emit, String messageAr) {
    emit(UsersMutationFailed(users: _currentUsers, messageAr: messageAr));
  }

  Future<void> _onRequested(UsersEvent event, Emitter<UsersState> emit) async {
    try {
      // The token fetch is INSIDE the try (T25): a throwing provider is a
      // handled load failure, never an escaped async error.
      final token = await _tokenProvider();
      if (token == null) {
        emit(const UsersLoadError(messageAr: _sessionExpiredAr));
        return;
      }
      final res = await _api.get('/admin/users', idToken: token);
      final body = res.fold((_) => null, (b) => b);
      // Surface the load failure: a Left (network/format error) or an
      // ok:false body must not render as an empty list.
      if (body?['ok'] != true) {
        emit(
          const UsersLoadError(messageAr: 'فشل تحميل المستخدمين. حاول مجددًا.'),
        );
        return;
      }
      final users = _usersOf(body);
      // A malformed ELEMENT (e.g. data.users: [42]) is a load failure, not a
      // hang: cast is lazy, so a non-Map element throws a TypeError only when
      // iterated — an Error, which the on Exception clause cannot catch.
      if (users == null) {
        emit(
          const UsersLoadError(messageAr: 'فشل تحميل المستخدمين. حاول مجددًا.'),
        );
        return;
      }
      emit(UsersLoaded(users: users));
    } on Exception {
      emit(
        const UsersLoadError(messageAr: 'فشل تحميل المستخدمين. حاول مجددًا.'),
      );
    }
  }

  Future<void> _onCreated(UserCreated event, Emitter<UsersState> emit) async {
    try {
      final token = await _tokenProvider();
      if (token == null) {
        _failMutation(emit, _sessionExpiredAr);
        return;
      }
      final res = await _api.post('/admin/users', {
        'username': event.username,
        'password': event.password,
        'role': event.role,
        if (event.displayName != null) 'display_name': event.displayName,
      }, idToken: token);
      final body = res.fold((_) => null, (b) => b);
      if (body?['ok'] != true) {
        _failMutation(emit, _arabicFor(body?['error'] as String?));
        return;
      }
      add(const UsersRequested()); // refresh the list
    } on Exception {
      _failMutation(emit, 'فشل إنشاء المستخدم. حاول مجددًا.');
    }
  }

  Future<void> _onSaved(UserSaved event, Emitter<UsersState> emit) async {
    try {
      final token = await _tokenProvider();
      if (token == null) {
        _failMutation(emit, _sessionExpiredAr);
        return;
      }
      final res = await _api.patch('/admin/users/${event.username}', {
        if (event.password != null) 'password': event.password,
        if (event.displayName != null) 'display_name': event.displayName,
        if (event.isActive != null) 'is_active': event.isActive,
      }, idToken: token);
      final body = res.fold((_) => null, (b) => b);
      if (body?['ok'] != true) {
        _failMutation(emit, _arabicFor(body?['error'] as String?));
        return;
      }
      add(const UsersRequested());
    } on Exception {
      _failMutation(emit, 'فشل حفظ التعديلات. حاول مجددًا.');
    }
  }

  Future<void> _onDeleted(UserDeleted event, Emitter<UsersState> emit) async {
    try {
      final token = await _tokenProvider();
      if (token == null) {
        _failMutation(emit, _sessionExpiredAr);
        return;
      }
      final res = await _api.delete(
        '/admin/users/${event.username}',
        idToken: token,
      );
      final body = res.fold((_) => null, (b) => b);
      if (body?['ok'] != true) {
        _failMutation(emit, _arabicFor(body?['error'] as String?));
        return;
      }
      add(const UsersRequested());
    } on Exception {
      _failMutation(emit, 'فشل حذف المستخدم. حاول مجددًا.');
    }
  }

  /// `body.data.users` as an eagerly converted list of objects, or null when
  /// an element is malformed. A wrong outer shape stays empty data (as
  /// before); unlike `cast`, which is lazy and throws a TypeError only once
  /// iterated, this conversion is total so a malformed element is a load
  /// failure the bloc can surface, never a hang.
  List<Map<String, dynamic>>? _usersOf(Map<String, dynamic>? body) {
    final data = body?['data'];
    if (data is! Map<String, dynamic>) return const [];
    final value = data['users'];
    if (value is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final element in value) {
      if (element is Map<String, dynamic>) {
        out.add(element);
      } else {
        return null;
      }
    }
    return out;
  }

  String _arabicFor(String? code) => switch (code) {
    'USERNAME_TAKEN' => 'اسم المستخدم مستخدم بالفعل. اختر اسمًا آخر.',
    'ADMIN_MANAGEMENT_OWNER_ONLY' => 'إدارة الأدمن من صلاحيات المالك فقط.',
    'OWNER_ONLY' => 'هذه العملية من صلاحيات المالك فقط.',
    'USER_NOT_FOUND' => 'المستخدم غير موجود.',
    'INVALID_FIELDS' => 'تحقق من الحقول المدخلة.',
    _ => 'فشلت العملية. حاول مجددًا.',
  };
}
