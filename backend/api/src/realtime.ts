/**
 * Best-effort push to the realtime worker via the REALTIME service binding.
 *
 * The binding is absent in local/tests, stays inside Cloudflare, and a failed
 * broadcast must never fail the originating request — so this never rejects.
 */
import type { Env } from './env';

export const REALTIME_NOTIFY_URL = 'https://realtime/internal/notify';

export function notifyRealtime(
  env: Env,
  tenantId: string,
  event: string,
  data: Record<string, unknown>,
): Promise<void> {
  const realtime = env.REALTIME;
  if (!realtime) return Promise.resolve();

  return realtime
    .fetch(REALTIME_NOTIFY_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Internal-Secret': env.INTERNAL_NOTIFY_SECRET,
      },
      body: JSON.stringify({ tenantId, event, data }),
    })
    .then(() => undefined)
    .catch(() => undefined);
}
