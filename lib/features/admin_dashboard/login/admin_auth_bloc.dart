// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart' show UserCredential;
import 'package:flutter/foundation.dart' show VoidCallback, kIsWeb, debugPrint;
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

  /// Supplied by the login widget: the SESSION_CONFLICT dialog's retry. The
  /// callback is built from the widget's own controllers so the plaintext
  /// password never reaches bloc state (T27).
  final VoidCallback? onConflictRetry;
  const CredentialsSubmitted(
    this.username,
    this.password, {
    this.onConflictRetry,
  });
}

/// SESSION_CONFLICT resolution (spec §6.5): force-end the remote session,
/// then retry the credential login.
class ForceRevokeRequested extends AdminAuthEvent {
  final String username;
  final String password;
  final VoidCallback? onConflictRetry;
  const ForceRevokeRequested(
    this.username,
    this.password, {
    this.onConflictRetry,
  });
}

class LogoutRequested extends AdminAuthEvent {
  const LogoutRequested();
}

/// A dashboard request was rejected because the session is no longer usable
/// (401 / SESSION_EXPIRED / SESSION_REVOKED / SESSION_STALE /
/// OWNER_REAUTH_REQUIRED). The shell dispatches this from the failed
/// dashboard request so the admin lands on the Firebase re-auth card instead
/// of a dead screen (T28).
class SessionExpired extends AdminAuthEvent {
  const SessionExpired();
}

/// The browser's connectivity changed (DAFTARI-99). [isOffline] is true when
/// the platform reports no usable network.
class ConnectivityChanged extends AdminAuthEvent {
  final bool isOffline;
  const ConnectivityChanged(this.isOffline);
}

// ---- states ----

sealed class AdminAuthState {
  /// True when the browser has no usable network: the login screen renders the
  /// spec §6.4 `WEB_DASHBOARD_OFFLINE` banner and disables the sign-in actions
  /// (DAFTARI-99). Orthogonal to the auth stage, so it rides on every state.
  final bool isOffline;
  const AdminAuthState({this.isOffline = false});
}

class AdminAuthInitial extends AdminAuthState {
  const AdminAuthInitial({super.isOffline});
}

class AuthLoading extends AdminAuthState {
  const AuthLoading({super.isOffline});
}

/// Stage 1: Firebase (Google / magic link) — owner identity, periodic.
class FirebaseStage extends AdminAuthState {
  const FirebaseStage({super.isOffline});
}

/// Stage 2: username/password — the daily identity (admin accounts exist).
class CredentialsStage extends AdminAuthState {
  final bool tenantKnown;
  const CredentialsStage({required this.tenantKnown, super.isOffline});
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
    super.isOffline,
  });
}

/// The username has an active session elsewhere (spec §6.5).
///
/// Deliberately carries NO plaintext password: the dialog's retry is the
/// [retry] callback the login widget supplies from its own controllers.
class SessionConflict extends AdminAuthState {
  final String username;
  final String conflictSessionId;
  final VoidCallback retry;
  const SessionConflict({
    required this.username,
    required this.conflictSessionId,
    required this.retry,
    super.isOffline,
  });
}

/// The stored session could not be resumed for a TRANSIENT reason — a network
/// or transport failure, not a session rejection. The stored session is
/// intact, so the admin is NOT logged out: the credentials card (which would
/// present a logout as a normal sign-in prompt) is never shown, and the card
/// offers a retry that re-dispatches the session check. A genuinely offline
/// device is already covered by the offline banner (T37).
class ResumeFailed extends AdminAuthState {
  final VoidCallback retry;
  const ResumeFailed({required this.retry, super.isOffline});
}

class AuthError extends AdminAuthState {
  final String code;
  final String messageAr;
  const AuthError({
    required this.code,
    required this.messageAr,
    super.isOffline,
  });
}

/// The two-stage login state machine (auth-licensing spec §1.3.2):
/// Stage 1 (Firebase, owner, periodic) → Stage 2 (username/password, daily).
class AdminAuthBloc extends Bloc<AdminAuthEvent, AdminAuthState> {
  final FirebaseAuthService _firebase;
  final AdminAuthService _admin;

  /// The Stage-1 Firebase ID token, kept in memory as the force-revoke
  /// fallback (a fresh browser has no stored session JWT yet — T11 QA).
  String? _firebaseToken;

  /// The live connectivity feed (DAFTARI-99). Tests inject a controlled stream;
  /// production web uses `Connectivity().onConnectivityChanged`.
  final Stream<List<ConnectivityResult>>? _connectivityStream;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isOffline = false;

  AdminAuthBloc({
    required FirebaseAuthService firebase,
    required AdminAuthService admin,
    Stream<List<ConnectivityResult>>? connectivityStream,
  }) : _firebase = firebase,
       _admin = admin,
       _connectivityStream = connectivityStream,
       super(const AdminAuthInitial()) {
    on<CheckSessionRequested>(_onCheckSession);
    on<GoogleSignInRequested>(_onGoogleSignIn);
    on<MagicLinkRequested>(_onMagicLinkRequested);
    on<MagicLinkCompleted>(_onMagicLinkCompleted);
    on<CredentialsSubmitted>(_onCredentialsSubmitted);
    on<ForceRevokeRequested>(_onForceRevoke);
    on<LogoutRequested>(_onLogout);
    on<SessionExpired>(_onSessionExpired);
    on<ConnectivityChanged>(_onConnectivityChanged);
    _watchConnectivity();
  }

  /// Subscribes to the connectivity feed. Production is the web-only admin
  /// dashboard, so the real plugin is used on web (`kIsWeb`); on the VM the
  /// plugin's default EventChannel never answers, so `flutter test` stays
  /// hermetic and injects [connectivityStream] instead.
  void _watchConnectivity() {
    final stream =
        _connectivityStream ??
        (kIsWeb ? Connectivity().onConnectivityChanged : null);
    _connectivitySub = stream?.listen(
      (results) => add(
        ConnectivityChanged(
          results.isEmpty || results.every((r) => r == ConnectivityResult.none),
        ),
      ),
    );
  }

  void _onConnectivityChanged(
    ConnectivityChanged event,
    Emitter<AdminAuthState> emit,
  ) {
    if (_isOffline == event.isOffline) return;
    _isOffline = event.isOffline;
    // Emit a NEW state object: the `Emitter` drops a state identical to the
    // current one before `emit` below can stamp it.
    emit(_reemitWithOffline(state, event.isOffline));
  }

  /// Keeps [AdminAuthState.isOffline] consistent across every emission: the
  /// individual handlers emit plain stage states, so without this a stage
  /// transition (e.g. the initial session check) would silently drop the
  /// offline flag.
  @override
  void emit(AdminAuthState state) {
    // `super.emit` is marked @visibleForTesting; overriding it is the only hook
    // that keeps isOffline stamped onto every handler emission.
    // ignore: invalid_use_of_visible_for_testing_member
    super.emit(
      state.isOffline == _isOffline
          ? state
          : _reemitWithOffline(state, _isOffline),
    );
  }

  /// Offline is orthogonal to the auth stage: keep the current concrete state
  /// and re-emit it with the new connectivity flag.
  AdminAuthState _reemitWithOffline(AdminAuthState s, bool offline) =>
      switch (s) {
        AdminAuthInitial() => AdminAuthInitial(isOffline: offline),
        AuthLoading() => AuthLoading(isOffline: offline),
        FirebaseStage() => FirebaseStage(isOffline: offline),
        CredentialsStage(:final tenantKnown) => CredentialsStage(
          tenantKnown: tenantKnown,
          isOffline: offline,
        ),
        AuthAuthenticated(:final profile, :final token, :final isOwner) =>
          AuthAuthenticated(
            profile: profile,
            token: token,
            isOwner: isOwner,
            isOffline: offline,
          ),
        SessionConflict(
          :final username,
          :final conflictSessionId,
          :final retry,
        ) =>
          SessionConflict(
            username: username,
            conflictSessionId: conflictSessionId,
            retry: retry,
            isOffline: offline,
          ),
        AuthError(:final code, :final messageAr) => AuthError(
          code: code,
          messageAr: messageAr,
          isOffline: offline,
        ),
        ResumeFailed(:final retry) => ResumeFailed(
          retry: retry,
          isOffline: offline,
        ),
      };

  @override
  Future<void> close() async {
    await _connectivitySub?.cancel();
    return super.close();
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
    // A stored, unexpired session JWT is resumed in place: reloading the
    // dashboard must not bounce the admin to the credentials card (or raise
    // a bogus SESSION_CONFLICT against their own live session). The server
    // enforces the owner 90-day gate only when no live session exists.
    if (token != null) {
      final claims = decodeSession(token);
      final unexpired =
          claims != null &&
          claims.exp * 1000 > DateTime.now().millisecondsSinceEpoch + 60000;
      if (unexpired) {
        final resumed = await _admin.resumeSession(idToken: token);
        final failure = resumed.fold((f) => f, (_) => null);
        if (failure == null) {
          final session = resumed.fold((_) => null, (s) => s)!;
          emit(
            AuthAuthenticated(
              profile: session.profile,
              token: session.token,
              isOwner: false,
            ),
          );
          return;
        }
        final code = failure is AdminAuthFailure ? failure.code : 'UNKNOWN';
        if (_isSessionStageError(code)) {
          emit(AuthError(code: code, messageAr: _arabicFor(code)));
          return;
        }
        // TRANSIENT failure (transport / unknown): the stored session is kept
        // and a retry is offered. Falling through to the credentials card
        // here would log the admin out for a flaky network — a logout must
        // only ever follow a real session rejection.
        emit(ResumeFailed(retry: () => add(const CheckSessionRequested())));
        return;
      }
    }
    final tenant = await _admin.storedTenantId();
    if (token != null && tenant != null) {
      emit(const CredentialsStage(tenantKnown: true));
    } else {
      emit(const FirebaseStage());
    }
  }

  /// Session-resume failures that must route back to the Firebase (Stage-1)
  /// card — a credentials card would bounce the user straight back.
  bool _isSessionStageError(String code) => const {
    'OWNER_REAUTH_REQUIRED',
    'SESSION_STALE',
    'SESSION_REVOKED',
    'SESSION_EXPIRED',
  }.contains(code);

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
              conflictSessionId: f.conflictSessionId,
              retry: event.onConflictRetry ?? () {},
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
    add(
      CredentialsSubmitted(
        event.username,
        event.password,
        onConflictRetry: event.onConflictRetry,
      ),
    );
  }

  Future<void> _onLogout(
    LogoutRequested event,
    Emitter<AdminAuthState> emit,
  ) async {
    // End the server-side session FIRST (T10): after clearSession the JWT is
    // gone and the server can no longer identify the row, so a reload would
    // resume the session the user just logged out of.
    final stored = await _admin.storedToken();
    if (stored != null) {
      await _admin.logout(idToken: stored);
    }
    await _admin.clearSession();
    await _firebase.signOut();
    emit(const FirebaseStage());
  }

  /// A dashboard request rejected the session (T28): drop the now-useless
  /// stored JWT and route to the Firebase re-auth card via the standard
  /// `AuthError(code: 'SESSION_EXPIRED')` path (`_isFirebaseStageError`).
  Future<void> _onSessionExpired(
    SessionExpired event,
    Emitter<AdminAuthState> emit,
  ) async {
    await _admin.clearSession();
    emit(
      const AuthError(
        code: 'SESSION_EXPIRED',
        messageAr: 'انتهت الجلسة. سجل الدخول من جديد.',
      ),
    );
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
