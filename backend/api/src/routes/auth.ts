/**
 * Auth routes — application-layer use cases.
 *
 * All business logic lives in application-layer use cases. Routes handle only
 * HTTP parsing, validation, delegation, and response formatting.
 *
 * Wiring precondition: identity fields (tenantId/sessionId/username/role) must
 * be sourced ONLY from verified middleware context (c.get('authUid') etc.),
 * never from request body/query/header. Authz (requireAuth, requireOwner) is
 * enforced by middleware before these handlers run.
 */
import type { Hono } from 'hono';
import type { Context } from 'hono';
import type { Env, Vars } from '../env';
import { verifySessionJwt } from '../../../shared/src/session_jwt';
import { requireAuth, requireOwner, type DbEnv, type VerifyTokenFn } from '../middleware/auth';
import {
  DashboardLoginUseCase,
} from '../application/use-cases/dashboard-login-use-case';
import {
  DashboardLogoutUseCase,
} from '../application/use-cases/dashboard-logout-use-case';
import {
  OwnerRefreshUseCase,
} from '../application/use-cases/owner-refresh-use-case';
import {
  AuthSessionResumeUseCase,
} from '../application/use-cases/auth-session-resume-use-case';
import {
  GetAuthProfileUseCase,
} from '../application/use-cases/get-auth-profile-use-case';
import {
  SyncFirebaseUserUseCase,
} from '../application/use-cases/sync-firebase-user-use-case';
import {
  IssueRealtimeTicketUseCase,
} from '../application/use-cases/issue-realtime-ticket-use-case';
import {
  ValidateRealtimeTicketUseCase,
} from '../application/use-cases/validate-realtime-ticket-use-case';
import type { LoginDto } from '../application/dtos/login.dto';
import type { LogoutDto } from '../application/dtos/logout.dto';
import type { OwnerRefreshDto } from '../application/dtos/owner-refresh.dto';
import type { SessionResumeDto } from '../application/dtos/session-resume.dto';
import type { MeDto } from '../application/dtos/me.dto';
import type { SyncUserDto } from '../application/dtos/sync-user.dto';
import type { TicketIssueDto } from '../application/dtos/ticket-issue.dto';
import type { TicketValidateDto } from '../application/dtos/ticket-validate.dto';

export function registerAuth(
  app: Hono<{ Bindings: Env; Variables: Vars }>,
  deps: {
    useCases: {
      dashboardLogin: DashboardLoginUseCase;
      dashboardLogout: DashboardLogoutUseCase;
      ownerRefresh: OwnerRefreshUseCase;
      sessionResume: AuthSessionResumeUseCase;
      getAuthProfile: GetAuthProfileUseCase;
      syncFirebaseUser: SyncFirebaseUserUseCase;
      issueRealtimeTicket: IssueRealtimeTicketUseCase;
      validateRealtimeTicket: ValidateRealtimeTicketUseCase;
    };
    verifyToken?: VerifyTokenFn;
    getDb: (env: DbEnv) => import('daftari-backend-shared/turso').TursoDb;
    verify?: (storedHash: string, password: string) => Promise<boolean>;
    rateLimit?: (tenantId: string, username: string, ip: string, at: number) => Promise<{ allowed: boolean; retryAfterMs?: number }>;
  },
): void {
  const {
    dashboardLogin,
    dashboardLogout,
    ownerRefresh,
    sessionResume,
    getAuthProfile,
    syncFirebaseUser,
    issueRealtimeTicket,
    validateRealtimeTicket,
  } = deps.useCases;

  // Public login — registered BEFORE the /auth/* middleware below (Hono applies
  // middleware in registration order; the route first = no auth required).
  app.post('/auth/login', async (c) => {
    const body = await c.req.json<{ tenant_id?: string; username?: string; password?: string }>();
    const dto: LoginDto = {
      tenantId: c.get('authUid') ?? body.tenant_id ?? '',
      username: c.get('authUsername') ?? body.username ?? '',
      password: body.password ?? '',
      ip: c.req.header('CF-Connecting-IP')?.trim() ?? c.req.header('X-Forwarded-For')?.split(',')[0]?.trim() ?? 'unknown',
    };

    const result = await dashboardLogin.execute(dto);

    if (!result.ok) {
      switch (result.error) {
        case 'MISSING_FIELDS': return c.json({ ok: false, error: 'MISSING_FIELDS' }, 400);
        case 'RATE_LIMITED': return c.json({ ok: false, error: 'RATE_LIMITED', retry_after_ms: (result as { retryAfterMs?: number }).retryAfterMs }, 429);
        case 'BAD_CREDENTIALS': return c.json({ ok: false, error: 'BAD_CREDENTIALS' }, 401);
        case 'ACCOUNT_DISABLED': return c.json({ ok: false, error: 'BAD_CREDENTIALS' }, 401);
        case 'DASHBOARD_ADMIN_ONLY': return c.json({ ok: false, error: 'DASHBOARD_ADMIN_ONLY' }, 403);
        case 'OWNER_REAUTH_REQUIRED': return c.json({ ok: false, error: 'OWNER_REAUTH_REQUIRED' }, 401);
        case 'SESSION_CONFLICT': return c.json({ ok: false, error: 'SESSION_CONFLICT', conflict_session_id: (result as { conflictSessionId?: string }).conflictSessionId }, 409);
        case 'NO_LICENSE': return c.json({ ok: false, error: 'NO_LICENSE' }, 401);
        case 'LICENSE_EXPIRED': return c.json({ ok: false, error: 'LICENSE_EXPIRED' }, 401);
        case 'SESSION_CREATION_FAILED': return c.json({ ok: false, error: 'SESSION_CREATION_FAILED' }, 500);
        case 'USER_PROFILE_NOT_FOUND': return c.json({ ok: false, error: 'USER_PROFILE_NOT_FOUND' }, 500);
        default: return c.json({ ok: false, error: 'INTERNAL_ERROR' }, 500);
      }
    }

    return c.json({
      ok: true,
      data: {
        token: result.data.token,
        session_id: result.data.sessionId,
        profile: result.data.profile ? {
          tenant_id: result.data.profile.tenantId,
          email: result.data.profile.email,
          role: result.data.profile.role,
          tier: result.data.profile.tier,
          display_name: result.data.profile.displayName,
          created_at: result.data.profile.createdAt,
          last_login_at: result.data.profile.lastLoginAt,
          last_owner_login_at: result.data.profile.lastOwnerLoginAt,
        } : null,
      },
    });
  });

  // Logout — registered BEFORE the /auth/* middleware so it stays idempotent
  // and can end a stale session. Bearer token verified inline; only the
  // session named by the bearer token's jti can be ended.
  app.post('/auth/logout', async (c) => {
    const authHeader = c.req.header('Authorization') ?? '';
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
    if (!token) return c.json({ ok: false, error: 'Missing bearer token' }, 401);
    const claims = await verifySessionJwt(token, c.env.ADMIN_JWT_SECRET);
    if (!claims) return c.json({ ok: false, error: 'Invalid session token' }, 401);

    const result = await dashboardLogout.execute({
      sessionId: claims.jti,
      tenantId: claims.tid,
    });
    return c.json({ ok: true });
  });

  // Middleware gate for all auth routes below this line.
  app.use('/auth/*', requireAuth({ verifyToken: deps.verifyToken, db: deps.getDb }));

  // Owner refresh — requires owner authorization (requireOwner middleware).
  app.post('/auth/owner-refresh', requireOwner(), async (c) => {
    const result = await ownerRefresh.execute({ tenantId: c.get('authUid') });
    return c.json({ ok: true });
  });

  // Session resume — registered AFTER the /auth/* liveness middleware. The
  // middleware has already verified the session, so the 90-day owner gate is
  // deliberately NOT re-applied here. Resuming re-mints the same session JWT
  // with a fresh expiry.
  app.post('/auth/session/resume', async (c) => {
    const tenantId = c.get('authUid');
    const sessionId = c.get('authSessionId');
    if (!sessionId) return c.json({ ok: false, error: 'SESSION_REVOKED' }, 401);

    const result = await sessionResume.execute({
      sessionId,
      tenantId,
      username: c.get('authUsername') ?? '',
      role: c.get('authRole') ?? 'admin',
    });

    if (!result.ok) return c.json({ ok: false, error: 'SESSION_REVOKED' }, 401);

    return c.json({
      ok: true,
      data: {
        token: result.data.token,
        session_id: result.data.sessionId,
        profile: result.data.profile ? {
          tenant_id: result.data.profile.tenantId,
          email: result.data.profile.email,
          role: result.data.profile.role,
          tier: result.data.profile.tier,
          display_name: result.data.profile.displayName,
          created_at: result.data.profile.createdAt,
          last_login_at: result.data.profile.lastLoginAt,
          last_owner_login_at: result.data.profile.lastOwnerLoginAt,
        } : null,
      },
    });
  });

  // Sync Firebase user — lazy profile sync; no DB write for missing users.
  app.post('/auth/sync-user', async (c) => {
    const result = await syncFirebaseUser.execute({
      tenantId: c.get('authUid'),
      email: c.get('authEmail'),
    });

    if (!result.ok) return c.json({ ok: false, error: 'USER_NOT_FOUND' }, 401);

    return c.json({
      ok: true,
      data: {
        profile: result.data.profile ? {
          tenant_id: result.data.profile.tenantId,
          email: result.data.profile.email,
          role: result.data.profile.role,
          tier: result.data.profile.tier,
          display_name: result.data.profile.displayName,
          created_at: result.data.profile.createdAt,
          last_login_at: result.data.profile.lastLoginAt,
          last_owner_login_at: result.data.profile.lastOwnerLoginAt,
        } : null,
        license: result.data.license ? {
          tenant_id: result.data.license.tenantId,
          device_hwid: result.data.license.deviceHwid,
          license_key: result.data.license.licenseKey,
          subscription_end: result.data.license.subscriptionEnd,
          billing_cycle: result.data.license.billingCycle,
          grace_end: result.data.license.graceEnd,
          status: result.data.license.status,
          created_at: result.data.license.createdAt,
        } : null,
      },
    });
  });

  // Get auth profile — nullable profile/license, 200 even when missing.
  app.get('/auth/me', async (c) => {
    const result = await getAuthProfile.execute({ tenantId: c.get('authUid') });

    if (!result.ok) return c.json({ ok: false, error: 'USER_NOT_FOUND' }, 401);

    return c.json({
      ok: true,
      data: {
        profile: result.data.profile ? {
          tenant_id: result.data.profile.tenantId,
          email: result.data.profile.email,
          role: result.data.profile.role,
          tier: result.data.profile.tier,
          display_name: result.data.profile.displayName,
          created_at: result.data.profile.createdAt,
          last_login_at: result.data.profile.lastLoginAt,
          last_owner_login_at: result.data.profile.lastOwnerLoginAt,
        } : null,
        license: result.data.license ? {
          tenant_id: result.data.license.tenantId,
          device_hwid: result.data.license.deviceHwid,
          license_key: result.data.license.licenseKey,
          subscription_end: result.data.license.subscriptionEnd,
          billing_cycle: result.data.license.billingCycle,
          grace_end: result.data.license.graceEnd,
          status: result.data.license.status,
          created_at: result.data.license.createdAt,
        } : null,
      },
    });
  });

  // Issue realtime ticket — short-lived single-use token for WebSocket auth.
  app.post('/auth/ticket', async (c) => {
    const result = await issueRealtimeTicket.execute({ tenantId: c.get('authUid') });

    if (!result.ok) {
      switch (result.error) {
        case 'USER_NOT_FOUND': return c.json({ ok: false, error: 'User not found' }, 401);
        case 'TICKET_CREATION_FAILED': return c.json({ ok: false, error: 'Ticket creation failed' }, 500);
        default: return c.json({ ok: false, error: 'Ticket creation failed' }, 500);
      }
    }

    return c.json({
      ok: true,
      data: {
        ticket: result.data.ticket,
      },
    });
  });

  // Validate realtime ticket — single-use, fail-closed atomic consume.
  app.get('/auth/ticket/validate', async (c) => {
    const ticket = c.req.query('ticket');
    if (!ticket) return c.json({ ok: false, error: 'Missing ticket' }, 400);

    const result = await validateRealtimeTicket.execute({ ticket });

    if (!result.ok) {
      switch (result.error) {
        case 'EXPIRED_TICKET': return c.json({ ok: false, error: 'Invalid or expired ticket' }, 400);
        case 'ALREADY_USED_TICKET': return c.json({ ok: false, error: 'Invalid or expired ticket' }, 400);
        case 'INVALID_TICKET': return c.json({ ok: false, error: 'Invalid or expired ticket' }, 400);
        default: return c.json({ ok: false, error: 'Invalid or expired ticket' }, 400);
      }
    }

    return c.json({ ok: true, data: { tenant_id: result.data.tenantId } });
  });
}
