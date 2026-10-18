/**
 * Session Start Use Case
 *
 * Starts a new POS or web session for a tenant and mints a session JWT.
 *
 * Error arms: MISSING_FIELDS, USER_NOT_FOUND, ACCOUNT_DISABLED, NO_LICENSE,
 * LICENSE_EXPIRED, SESSION_CONFLICT, DEVICE_LIMIT_EXCEEDED,
 * SESSION_CREATION_FAILED.
 *
 * Wiring precondition (doc): identity fields (tenantId, deviceHwid, username,
 * source) must be sourced ONLY from verified middleware context at the wiring
 * phase - never from request body/query/header. Application layer trusts DTO
 * input by design; authz is a Phases 7-12 concern.
 *
 * Deviation note: the Phase 3 brief lists SessionConflictService and
 * RateLimiter as constructor deps, but neither exists as a shared application
 * service (session-conflict-service.ts is absent from shared). Web-session
 * conflict is therefore detected inline via
 * SessionRepository.getActiveForUsername; rate limiting is intentionally
 * omitted (no matching error arm in the contract).
 */
import type { SessionRepository } from 'daftari-backend-shared/domain/repositories/session-repository';
import type { DeviceRepository } from 'daftari-backend-shared/domain/repositories/device-repository';
import type { LicenseRepository } from 'daftari-backend-shared/domain/repositories/license-repository';
import type { AuthUserRepository } from 'daftari-backend-shared/domain/repositories/auth-user-repository';
import type { UserRepository } from 'daftari-backend-shared/domain/repositories/user-repository';
import type { SessionTokenService } from 'daftari-backend-shared/application/services/session-token-service';
import type { SessionStartDto, SessionStartResponse } from '../dtos/session-start.dto';

/** Dashboard session JWT lifetime (seconds — JWT convention). */
const SESSION_TTL_S = 12 * 3600;

/** Session considered fresh for conflict detection: 5 minutes. */
const HEARTBEAT_FRESH_MS = 5 * 60 * 1000;

export class SessionStartUseCase {
  constructor(
    private readonly sessionRepo: SessionRepository,
    private readonly deviceRepo: DeviceRepository,
    private readonly licenseRepo: LicenseRepository,
    private readonly authUserRepo: AuthUserRepository,
    private readonly userRepo: UserRepository,
    private readonly tokenService: SessionTokenService,
    private readonly jwtSecret: string,
  ) {}

  async execute(dto: SessionStartDto): Promise<SessionStartResponse> {
    const { tenantId, deviceHwid, username } = dto;
    const isNonEmptyString = (v: unknown): v is string =>
      typeof v === 'string' && v.trim().length > 0;
    if (!isNonEmptyString(tenantId) || !isNonEmptyString(deviceHwid) || !isNonEmptyString(username)) {
      return { ok: false, error: 'MISSING_FIELDS' };
    }
    if (dto.source !== 'pos' && dto.source !== 'web') {
      return { ok: false, error: 'MISSING_FIELDS' };
    }

    const now = Date.now();

    if (dto.source === 'web') {
      return this.startWeb(dto, now);
    }

    return this.startPos(dto, now);
  }

  private async startWeb(
    dto: SessionStartDto,
    now: number,
  ): Promise<SessionStartResponse> {
    const authUser = await this.authUserRepo.findByTenantAndUsername(
      dto.tenantId,
      dto.username,
    );
    if (!authUser) {
      return { ok: false, error: 'USER_NOT_FOUND' };
    }
    if (!authUser.isActive) {
      return { ok: false, error: 'ACCOUNT_DISABLED' };
    }

    const active = await this.sessionRepo.getActiveForUsername(
      dto.tenantId,
      dto.username,
      now - HEARTBEAT_FRESH_MS,
    );
    if (active.some((s) => s.source === 'web')) {
      return { ok: false, error: 'SESSION_CONFLICT' };
    }

    await this.sessionRepo.endWebSessions(dto.tenantId, dto.username, now);

    const sessionId = `sess_${crypto.randomUUID()}`;
    const inserted = await this.sessionRepo.insert({
      id: sessionId,
      tenantId: dto.tenantId,
      deviceHwid: dto.deviceHwid,
      username: dto.username,
      startedAt: now,
      heartbeatAt: now,
      source: 'web',
    });
    if (!inserted) {
      return { ok: false, error: 'SESSION_CREATION_FAILED' };
    }

    const token = await this.mintToken(dto.tenantId, dto.username, authUser.role, sessionId, now);
    return { ok: true, data: { sessionId, token } };
  }

  private async startPos(
    dto: SessionStartDto,
    now: number,
  ): Promise<SessionStartResponse> {
    const authUser = await this.authUserRepo.findByTenantAndUsername(
      dto.tenantId,
      dto.username,
    );
    if (!authUser) {
      return { ok: false, error: 'USER_NOT_FOUND' };
    }
    if (!authUser.isActive) {
      return { ok: false, error: 'ACCOUNT_DISABLED' };
    }

    const latestLicense = await this.licenseRepo.findLatestByTenant(dto.tenantId);
    if (!latestLicense) {
      return { ok: false, error: 'NO_LICENSE' };
    }
    if (await this.licenseRepo.isExpired(latestLicense.graceEnd, now)) {
      return { ok: false, error: 'LICENSE_EXPIRED' };
    }

    const tenantProfile = await this.userRepo.findByTenantId(dto.tenantId);
    const tier = tenantProfile?.tier ?? 'starter';
    const limit = this.licenseRepo.getDeviceLimit(tier);

    const activePos = await this.sessionRepo.getActivePos(dto.tenantId);
    if (activePos.length >= limit) {
      return { ok: false, error: 'DEVICE_LIMIT_EXCEEDED' };
    }

    await this.deviceRepo.upsert({
      tenantId: dto.tenantId,
      deviceHwid: dto.deviceHwid,
      firstSeenAt: now,
      lastSeenAt: now,
    });

    await this.sessionRepo.endForDevice(dto.tenantId, dto.deviceHwid, now);

    const sessionId = `sess_${crypto.randomUUID()}`;
    const admitted = await this.sessionRepo.admitPosSession(
      {
        id: sessionId,
        tenantId: dto.tenantId,
        deviceHwid: dto.deviceHwid,
        username: dto.username,
        startedAt: now,
        heartbeatAt: now,
        source: 'pos',
      },
      limit,
    );
    if (!admitted) {
      return { ok: false, error: 'SESSION_CREATION_FAILED' };
    }

    const token = await this.mintToken(dto.tenantId, dto.username, authUser.role, sessionId, now);
    return { ok: true, data: { sessionId, token } };
  }

  private async mintToken(
    tid: string,
    usr: string,
    role: string,
    jti: string,
    now: number,
  ): Promise<string> {
    return this.tokenService.mint(
      {
        tid,
        usr,
        role,
        jti,
        iat: Math.floor(now / 1000),
        exp: Math.floor(now / 1000) + SESSION_TTL_S,
      },
      this.jwtSecret,
    );
  }
}
