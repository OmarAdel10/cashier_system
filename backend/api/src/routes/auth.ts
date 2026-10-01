  app.post('/auth/login', async (c) => {
    const db = deps.getDb(c.env);
    const body = await c.req.json<{ tenant_id?: string; username?: string; password?: string }>();
    const tenantId = body.tenant_id?.trim() ?? '';
    const username = body.username?.trim() ?? '';
    const password = body.password ?? '';
    if (!tenantId || !username || !password) {
      return c.json({ ok: false, error: 'MISSING_FIELDS' }, 400);
    }

    // T17: throttle BEFORE the KDF and before touching auth_users. Either
    // dimension (IP or account) over budget → 429 with the exact wait. The
    // attempt is recorded only when admitted, so a rejected caller cannot
    // extend its own window.
    const ip = clientIp(c);
    const attemptAt = Date.now();
    const decision = await rateLimit(db, ip, tenantId, username, attemptAt);
    if (!decision.allowed) {
      return c.json(
        { ok: false, error: 'RATE_LIMITED', retry_after_ms: decision.retryAfterMs },
        429,
      );
    }

    // T40: Atomic reservation before password verification
    const reservationSuccess = await db.reserveLoginAttempt(tenantId, username);
    if (!reservationSuccess) {
      return c.json({ ok: false, error: 'LOGIN_LOCKED' }, 429);
    }

    await db.recordAuthAttempt(ip, tenantId, username, attemptAt);

    const user = await db.getAuthUser(tenantId, username);
    const now = Date.now();
    // T16: the KDF runs unconditionally — the derivation target is the real
    // stored hash when the account exists, otherwise a valid-shaped dummy.
    // Any early return that skipped it (unknown user, lockout, deactivated
    // account) would leak account existence through response timing.
    const derived = await verify(user?.password_hash ?? DUMMY_HASH, password);

    if (user && user.locked_until && user.locked_until > now) {
      // Reservation was made, but account is already locked - release reservation
      await db.releaseLoginAttempt(tenantId, username);
      return c.json({ ok: false, error: 'LOGIN_LOCKED', locked_until: user.locked_until }, 429);
    }

    // T16: an elapsed lock window restarts the counter. Without this reset the
    // stored failed_attempts (e.g. 30) carries into the next window and the
    // very next typo would re-lock immediately with the cap value.
    if (user && user.locked_until != null && user.locked_until <= now) {
      await db.resetAuthFailures(tenantId, username);
    }

    const passwordOk = user != null && user.is_active === 1 && derived;
    if (!passwordOk) {
      if (user) {
        // Convert reservation to failed attempt (SQL-side atomic)
        await db.convertReservationToFailure(tenantId, username);
      }
      // Reservation already released by convertReservationToFailure or will be released below
      return c.json({ ok: false, error: 'BAD_CREDENTIALS' }, 401);
    }

    // Dashboard logins are admin-role only (cashier accounts are POS-side).
    if (user.role !== 'admin') {
      await db.releaseLoginAttempt(tenantId, username);
      return c.json({ ok: false, error: 'DASHBOARD_ADMIN_ONLY' }, 403);
    }

    // 90-day owner re-auth gate (spec §1.3.2: expired > 3 months).
    // T11 + security-review fix: this gate is UNCONDITIONAL on /auth/login.
    // It is deliberately NOT suppressed by the existence of an unended session
    // row. An earlier revision skipped it when
    // getActiveSessionsForUsername(tenantId, username, 0) returned anything,
    // but that predicate is `ended_at IS NULL AND heartbeat_at > ?` with
    // since = 0, i.e. 'any unended row ever' — and web rows survive until an
    // explicit logout or the next login. Treating one as proof of an active
    // session therefore let a single gated login suppress owner re-auth
    // FOREVER: a bypass, not the intended policy.
    //
    // The product requirement (the periodic owner re-auth must never interrupt
    // an ACTIVE admin session) is satisfied by /auth/session/resume below.
    // A resumed session is proven active by the /auth/* middleware — a valid
    // unexpired token AND a live session row — and that route never applies
    // this gate. A client holding an active session calls resume on reload,
    // never login; login is only reached once no session is live, which is
    // precisely when this gate is supposed to fire.
    const owner = await db.getUser(tenantId);
    const ownerFresh =
      owner?.last_owner_login_at != null && 
      Date.now() - owner.last_owner_login_at <= OWNER_REAUTH_MS;
    if (!ownerFresh) {
      await db.releaseLoginAttempt(tenantId, username);
      return c.json({ ok: false, error: 'OWNER_REAUTH_REQUIRED' }, 401);
    }

    // Per-username single-session conflict core (spec §6.5). Stale
    // heartbeats (> 5 min) do not block login.
    const active = await db.getActiveSessionsForUsername(
      tenantId,
      username,
      Date.now() - HEARTBEAT_FRESH_MS,
    );
    if (active.length > 0) {
      await db.releaseLoginAttempt(tenantId, username);
      return c.json(
        { ok: false, error: 'SESSION_CONFLICT', conflict_session_id: active[0]!.id },
        409,
      );
    }

    await db.resetAuthFailures(tenantId, username);
    // Web-session hygiene (T06 QA F1): end prior unended web rows for this
    // username so dashboard rows never accumulate (each login replaces the
    // last) and never linger in device-limit/admin views.
    await db.endWebSessions(tenantId, username, now);
    const sessionId = crypto.randomUUID();
    // Atomic single-web-session admission (T12): if another login raced us and
    // wrote a live web row for this (tenant, username) first, the partial
    // unique index rejects this insert and rowsAffected is 0. Refuse to mint a
    // token for a row that was never written.
    const admitted = await db.insertSession({
      id: sessionId,
      tenant_id: tenantId,
      device_hwid: 'web',
      username,
      started_at: now,
      heartbeat_at: now,
      source: 'web',
    });
    if (!admitted) {
      await db.releaseLoginAttempt(tenantId, username);
      return c.json({ ok: false, error: 'SESSION_CONFLICT' }, 409);
    }
    const token = await mintSessionJwt(
      {
        tid: tenantId,
        usr: username,
        role: user.role,
        jti: sessionId,
        iat: Math.floor(now / 1000),
        exp: Math.floor(now / 1000) + SESSION_TTL_S,
      },
      c.env.ADMIN_JWT_SECRET,
    );
    return c.json({ ok: true, data: { token, session_id: sessionId, profile: owner } });
  });