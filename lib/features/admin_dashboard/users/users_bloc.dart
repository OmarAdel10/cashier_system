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

class UsersError extends UsersState {
  final String messageAr;
  const UsersError({required this.messageAr});
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

  Future<void> _onRequested(UsersEvent event, Emitter<UsersState> emit) async {
    final token = await _tokenProvider();
    if (token == null) {
      emit(const UsersError(messageAr: 'انتهت الجلسة. سجل الدخول من جديد.'));
      return;
    }
    try {
      final res = await _api.get('/admin/users', idToken: token);
      final body = res.fold((_) => null, (b) => b);
      final users = (body?['data']?['users'] as List?) ?? const [];
      emit(UsersLoaded(users: users.cast<Map<String, dynamic>>()));
    } catch (_) {
      emit(const UsersError(messageAr: 'فشل تحميل المستخدمين. حاول مجددًا.'));
    }
  }

  Future<void> _onCreated(UserCreated event, Emitter<UsersState> emit) async {
    final token = await _tokenProvider();
    if (token == null) {
      emit(const UsersError(messageAr: 'انتهت الجلسة. سجل الدخول من جديد.'));
      return;
    }
    try {
      final res = await _api.post('/admin/users', {
        'username': event.username,
        'password': event.password,
        'role': event.role,
        if (event.displayName != null) 'display_name': event.displayName,
      }, idToken: token);
      final body = res.fold((_) => null, (b) => b);
      if (body?['ok'] != true) {
        emit(UsersError(messageAr: _arabicFor(body?['error'] as String?)));
        return;
      }
      add(const UsersRequested()); // refresh the list
    } catch (_) {
      emit(const UsersError(messageAr: 'فشل إنشاء المستخدم. حاول مجددًا.'));
    }
  }

  Future<void> _onSaved(UserSaved event, Emitter<UsersState> emit) async {
    final token = await _tokenProvider();
    if (token == null) {
      emit(const UsersError(messageAr: 'انتهت الجلسة. سجل الدخول من جديد.'));
      return;
    }
    try {
      final res = await _api.patch('/admin/users/${event.username}', {
        if (event.password != null) 'password': event.password,
        if (event.displayName != null) 'display_name': event.displayName,
        if (event.isActive != null) 'is_active': event.isActive,
      }, idToken: token);
      final body = res.fold((_) => null, (b) => b);
      if (body?['ok'] != true) {
        emit(UsersError(messageAr: _arabicFor(body?['error'] as String?)));
        return;
      }
      add(const UsersRequested());
    } catch (_) {
      emit(const UsersError(messageAr: 'فشل حفظ التعديلات. حاول مجددًا.'));
    }
  }

  Future<void> _onDeleted(UserDeleted event, Emitter<UsersState> emit) async {
    final token = await _tokenProvider();
    if (token == null) {
      emit(const UsersError(messageAr: 'انتهت الجلسة. سجل الدخول من جديد.'));
      return;
    }
    try {
      final res = await _api.delete(
        '/admin/users/${event.username}',
        idToken: token,
      );
      final body = res.fold((_) => null, (b) => b);
      if (body?['ok'] != true) {
        emit(UsersError(messageAr: _arabicFor(body?['error'] as String?)));
        return;
      }
      add(const UsersRequested());
    } catch (_) {
      emit(const UsersError(messageAr: 'فشل حذف المستخدم. حاول مجددًا.'));
    }
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
