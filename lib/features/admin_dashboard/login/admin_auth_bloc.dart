// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:firebase_auth/firebase_auth.dart' show UserCredential;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/backend/auth/firebase_auth_service.dart';
import '../../../core/config/env_config.dart';
import '../../../core/error/either.dart';
import '../../../core/error/failure.dart';
import 'admin_auth_service.dart';

// ---- events ----

sealed class AdminAuthEvent {
  const AdminAuthEvent();
}

/// App start: resolve pending magic link (web) → stored session → stage.
class CheckSessionRequested extends AdminAuthEvent {
  const CheckSessionRequested();
}

class GoogleSignInRequested extends AdminAuthEvent {
  const GoogleSignInRequested();
}

class MagicLinkRequested extends AdminAuthEvent {
  final String email;
  const MagicLinkRequested(this.email);
}

/// The emailed link was opened (web) — complete the sign-in.
class MagicLinkCompleted extends AdminAuthEvent {
  final String email;
  final String link;
  const MagicLinkCompleted(this.email, this.link);
}

class CredentialsSubmitted extends AdminAuthEvent {
  final String username;
  final String password;
  const CredentialsSubmitted(this.username, this.password);
}

/// SESSION_CONFLICT resolution (spec §6.5): force-end the remote session,
/// then retry the credential login.
class ForceRevokeRequested extends AdminAuthEvent {
  final String username;
  final String password;
  const ForceRevokeRequested(this.username, this.password);
}

class LogoutRequested extends AdminAuthEvent {
  const LogoutRequested();
}

// ---- states ----

sealed class AdminAuthState {
  const AdminAuthState();
}

class AdminAuthInitial extends AdminAuthState {
  const AdminAuthInitial();
}

class AuthLoading extends AdminAuthState {
  const AuthLoading();
}

/// Stage 1: Firebase (Google / magic link) — owner identity, periodic.
class FirebaseStage extends AdminAuthState {
  const FirebaseStage();
}

/// Stage 2: username/password — the daily identity (admin accounts exist).
class CredentialsStage extends AdminAuthState {
  final bool tenantKnown;
  const CredentialsStage({required this.tenantKnown});
}

/// Authenticated via EITHER path. [token] is the HS256 session JWT or the
/// Firebase ID token; [isOwner] is true only for the Firebase path.
class AuthAuthenticated extends AdminAuthState {
  final Map<String, dynamic> profile;
  final String token;
  final bool isOwner;
  const AuthAuthenticated({
    required this.profile,
    required this.token,
    required this.isOwner,
  });
}

/// The username has an active session elsewhere (spec §6.5).
class SessionConflict extends AdminAuthState {
  final String username;
  final String password;
  final String conflictSessionId;
  const SessionConflict({
    required this.username,
    required this.password,
    required this.conflictSessionId,
  });
}

class AuthError extends AdminAuthState {
  final String code;
  final String messageAr;
  const AuthError({required this.code, required this.messageAr});
}

/// The two-stage login state machine (auth-licensing spec §1.3.2):
/// Stage 1 (Firebase, owner, periodic) → Stage 2 (username/password, daily).
class AdminAuthBloc extends Bloc<AdminAuthEvent, AdminAuthState> {
  final FirebaseAuthService _firebase;
  final AdminAuthService _admin;

  /// The Stage-1 Firebase ID token, kept in memory as the force-revoke
  /// fallback (a fresh browser has no stored session JWT yet — T11 QA).
  String? _firebaseToken;

  AdminAuthBloc({
    required FirebaseAuthService firebase,
    required AdminAuthService admin,
  }) : _firebase = firebase,
       _admin = admin,
       super(const AdminAuthInitial()) {
    on<CheckSessionRequested>(_onCheckSession);
    on<GoogleSignInRequested>(_onGoogleSignIn);
    on<MagicLinkRequested>(_onMagicLinkRequested);
    on<MagicLinkCompleted>(_onMagicLinkCompleted);
    on<CredentialsSubmitted>(_onCredentialsSubmitted);
    on<ForceRevokeRequested>(_onForceRevoke);
    on<LogoutRequested>(_onLogout);
  }

  Future<void> _onCheckSession(
    CheckSessionRequested event,
    Emitter<AdminAuthState> emit,
  ) async {
    emit(const AuthLoading());
    // A persisted Firebase web session keeps its ID token available for the
    // force-revoke fallback (spec §6.5) even after a browser restart.
    _firebaseToken = await _firebase.currentIdToken();
    // Web: an opened email link completes the magic-link sign-in.
    if (kIsWeb) {
      final url = Uri.base.toString();
      if (_firebase.isSignInWithEmailLink(url)) {
        final email = await _admin.pendingMagicEmail();
        if (email != null) {
          await _completeFirebaseSignIn(emit, email: email, link: url);
          return;
        }
      }
    }
    final token = await _admin.storedToken();
    final tenant = await _admin.storedTenantId();
    if (token != null && tenant != null) {
      emit(const CredentialsStage(tenantKnown: true));
    } else {
      emit(const FirebaseStage());
    }
  }

  Future<void> _onGoogleSignIn(
    GoogleSignInRequested event,
    Emitter<AdminAuthState> emit,
  ) async {
    emit(const AuthLoading());
    await _completeFirebaseSignIn(emit);
  }

  Future<void> _onMagicLinkRequested(
    MagicLinkRequested event,
    Emitter<AdminAuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _firebase.sendMagicLink(email: event.email);
    final failed = result.fold((_) => true, (_) => false);
    if (failed) {
      emit(
        const AuthError(
          code: 'MAGIC_LINK_FAILED',
          messageAr: 'فشل إرسال الرابط. حاول مجددًا.',
        ),
      );
      return;
    }
    await _admin.savePendingEmail(event.email);
    emit(
      const AuthError(
        code: 'MAGIC_LINK_SENT',
        messageAr: 'تحقق من بريدك الإلكتروني واضغط الرابط لتسجيل الدخول.',
      ),
    );
  }

  Future<void> _onMagicLinkCompleted(
    MagicLinkCompleted event,
    Emitter<AdminAuthState> emit,
  ) async {
    emit(const AuthLoading());
    await _completeFirebaseSignIn(emit, email: event.email, link: event.link);
  }

  /// Firebase (Stage 1) success → stamp the owner refresh → decide: an
  /// EMPTY accounts list means first-admin bootstrap (owner proceeds
  /// directly with the Firebase session; T14 creates the first account);
  /// otherwise the daily credential stage.
  Future<void> _completeFirebaseSignIn(
    Emitter<AdminAuthState> emit, {
    String? email,
    String? link,
  }) async {
    final Either<Failure, UserCredential> signed = email == null
        ? await _firebase.signInWithGooglePopup()
        : await _firebase.signInWithEmailLink(email: email, link: link!);
    final outcome = signed.fold(
      (Failure f) => (failure: f, credential: null),
      (UserCredential c) => (failure: null, credential: c),
    );
    if (outcome.failure != null || outcome.credential == null) {
      final code = _firebaseCodeFor(outcome.failure);
      _logAuthFailure('Firebase sign-in', outcome.failure);
      emit(AuthError(code: code, messageAr: _arabicFor(code)));
      return;
    }
    final firebaseUser = outcome.credential!.user;
    final idToken = await _firebase.currentIdToken();
    if (idToken == null) {
      emit(
        const AuthError(
          code: 'FIREBASE_FAILED',
          messageAr: 'فشل تسجيل الدخول. حاول مجددًا.',
        ),
      );
      return;
    }
    _firebaseToken = idToken;
    // The Stage-1 login establishes the tenant — persist it so the daily
    // credential stage can complete (credentialLogin reads it back; T11 QA:
    // without this a fresh browser bounces Firebase ↔ credentials forever).
    final tenantId = _firebase.tenantId;
    if (tenantId.isNotEmpty) {
      await _admin.saveTenantId(tenantId);
    }
    // Best-effort owner stamp (resets the 90-day window) — T06 route.
    await _admin.refreshOwner(idToken: idToken);
    final accounts = await _admin.tenantAccounts(idToken: idToken);
    // null = the accounts REQUEST failed — not an empty list. Never
    // bootstrap on a failure: a transient error must not skip stage 2
    // (T11 QA — the old fold conflated failure with empty).
    final list = accounts.fold((_) => null, (u) => u);
    if (list == null) {
      final failure = accounts.fold((f) => f, (_) => null);
      final code = _accountsCodeFor(failure);
      _logAuthFailure('Accounts check', failure);
      emit(AuthError(code: code, messageAr: _arabicFor(code)));
      return;
    }
    if (list.isEmpty) {
      emit(
        AuthAuthenticated(
          profile: {
            'email': firebaseUser?.email ?? '',
            'tenant_id': _firebase.tenantId,
          },
          token: idToken,
          isOwner: true,
        ),
      );
      return;
    }
    emit(const CredentialsStage(tenantKnown: true));
  }

  Future<void> _onCredentialsSubmitted(
    CredentialsSubmitted event,
    Emitter<AdminAuthState> emit,
  ) async {
    emit(const AuthLoading());
    final tenant = await _admin.storedTenantId();
    if (tenant == null) {
      // No tenant known → the Firebase stage must run first (it stores it).
      emit(const FirebaseStage());
      return;
    }
    final result = await _admin.credentialLogin(
      tenantId: tenant,
      username: event.username,
      password: event.password,
    );
    result.fold(
      (f) {
        _logAuthFailure('Credential login', f);
        if (f is SessionConflictFailure) {
          emit(
            SessionConflict(
              username: event.username,
              password: event.password,
              conflictSessionId: f.conflictSessionId,
            ),
          );
        } else if (f is AdminAuthFailure) {
          emit(AuthError(code: f.code, messageAr: _arabicFor(f.code)));
        } else {
          emit(
            const AuthError(
              code: 'UNKNOWN',
              messageAr: 'فشل تسجيل الدخول. حاول مجددًا.',
            ),
          );
        }
      },
      (creds) => emit(
        AuthAuthenticated(
          profile: creds.profile,
          token: creds.token,
          isOwner: false,
        ),
      ),
    );
  }

  Future<void> _onForceRevoke(
    ForceRevokeRequested event,
    Emitter<AdminAuthState> emit,
  ) async {
    emit(const AuthLoading());
    var revoked = false;
    final stored = await _admin.storedToken();
    if (stored != null) {
      final result = await _admin.revokeSessions(
        username: event.username,
        idToken: stored,
      );
      revoked = result.fold((_) => false, (_) => true);
    }
    // Fresh browser: no stored session JWT — the Stage-1 Firebase token
    // (kept in memory) revokes own-tenant sessions (the server takes the
    // tenant from it). Without this fallback the conflict dialog loops
    // (T11 QA).
    if (!revoked && _firebaseToken != null) {
      final result = await _admin.revokeSessions(
        username: event.username,
        idToken: _firebaseToken!,
      );
      revoked = result.fold((_) => false, (_) => true);
    }
    if (!revoked) {
      emit(
        const AuthError(
          code: 'REVOKE_FAILED',
          messageAr: 'تعذر إلغاء الجلسة الأخرى. حاول مجددًا.',
        ),
      );
      return;
    }
    add(CredentialsSubmitted(event.username, event.password));
  }

  Future<void> _onLogout(
    LogoutRequested event,
    Emitter<AdminAuthState> emit,
  ) async {
    await _admin.clearSession();
    await _firebase.signOut();
    emit(const FirebaseStage());
  }

  /// The structural code for a Stage-1 Firebase failure: the
  /// `FirebaseAuthException.code` the service carried in `DatabaseFailure.detail`
  /// (`auth/popup-closed-by-user`, …), or the generic marker for a
  /// non-Firebase transport failure. Never parsed out of a message string.
  String _firebaseCodeFor(Failure? failure) {
    if (failure is DatabaseFailure && failure.detail != null) {
      return failure.detail!;
    }
    return 'FIREBASE_FAILED';
  }

  /// The accounts-check code: the server's machine code when it sent one
  /// (an [AdminAuthFailure]), else `ACCOUNTS_CHECK_FAILED` plus the
  /// transport detail when there is one.
  String _accountsCodeFor(Failure? failure) {
    if (failure is AdminAuthFailure) return failure.code;
    final detail = failure is DatabaseFailure ? failure.detail : null;
    return detail == null
        ? 'ACCOUNTS_CHECK_FAILED'
        : 'ACCOUNTS_CHECK_FAILED:$detail';
  }

  /// Console breadcrumb so the next auth outage is diagnosable (gated on
  /// [EnvConfig.enableLogging] — quiet in production).
  void _logAuthFailure(String stage, Failure? failure) {
    if (!EnvConfig.enableLogging) return;
    debugPrint(
      '[AdminAuth] $stage failed: ${failure?.toString() ?? 'unknown'}',
    );
  }

  String _arabicFor(String code) {
    return switch (code) {
      'BAD_CREDENTIALS' => 'بيانات الدخول غير صحيحة.',
      'OWNER_REAUTH_REQUIRED' =>
        'يلزم تسجيل دخول المالك عبر جوجل أو الرابط للمتابعة.',
      'DASHBOARD_ADMIN_ONLY' => 'حسابات الكاشير لا تدخل لوحة التحكم.',
      'LOGIN_LOCKED' =>
        'تم قفل الحساب مؤقتًا بسبب محاولات فاشلة متكررة. حاول بعد قليل.',
      'MAGIC_LINK_SENT' =>
        'تحقق من بريدك الإلكتروني واضغط الرابط لتسجيل الدخول.',
      _ => 'فشل تسجيل الدخول. حاول مجددًا. ($code)',
    };
  }
}
