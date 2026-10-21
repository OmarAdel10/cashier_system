/**
 * Analytics routes: batched PostHog events. The Flutter client batches
 * locally; we forward at most 50 events per call to PostHog's /batch/.
 */
import type { Hono } from 'hono';
import type { Env, Vars } from '../env';
import { requireAuth } from '../middleware/auth';
import type { VerifyTokenFn } from '../middleware/auth';
import { postHogBatch } from '../../../shared/src/analytics';
import type { PostHogEvent } from '../../../shared/src/analytics';
import type { FetchFn } from '../../../shared/src/types';
import type { SessionRepository } from 'daftari-backend-shared/domain/repositories/session-repository';
import type { AuthUserRepository } from 'daftari-backend-shared/domain/repositories/auth-user-repository';
import type { UserRepository } from 'daftari-backend-shared/domain/repositories/user-repository';

const MAX_EVENTS = 50;

export function registerAnalytics(
  app: Hono<{ Bindings: Env; Variables: Vars }>,
  deps: {
    verifyToken?: VerifyTokenFn;
    sessionRepository: SessionRepository;
    authUserRepository: AuthUserRepository;
    userRepository: UserRepository;
    postHogFetch?: FetchFn;
  },
): void {
  app.use('/events', requireAuth({
    verifyToken: deps.verifyToken,
    sessionRepository: deps.sessionRepository,
    authUserRepository: deps.authUserRepository,
    userRepository: deps.userRepository,
  }));

  app.post('/events', async (c) => {
    const body = await c.req.json<{ events?: PostHogEvent[] }>();
    const events = body.events ?? [];
    if (events.length > MAX_EVENTS) {
      return c.json(
        { ok: false, error: `Too many events; max ${MAX_EVENTS}` },
        422,
      );
    }
    if (events.length === 0) {
      return c.json({ ok: true, data: { sent: 0 } });
    }
    const result = await postHogBatch(c.env.POSTHOG_API_KEY, events, deps.postHogFetch);
    if (!result.ok) {
      return c.json(
        { ok: false, error: 'PostHog rejected the batch' },
        result.retryable ? 503 : 422,
      );
    }
    return c.json({ ok: true, data: { sent: events.length } });
  });
}
