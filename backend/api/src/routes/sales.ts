/**
 * Sales routes: sync from cashiers + read for admin dashboard.
 * sale sync also notifies the realtime worker (service binding).
 */
import type { Hono } from 'hono';
import type { Env, Vars } from '../env';
import type { TursoDb } from '../../../shared/src/turso';
import type { DbEnv, VerifyTokenFn } from '../middleware/auth';
import { requireAuth } from '../middleware/auth';

export function registerSales(
  app: Hono<{ Bindings: Env; Variables: Vars }>,
  deps: { verifyToken?: VerifyTokenFn; getDb: (env: DbEnv) => TursoDb },
): void {
  app.use('/sales/*', requireAuth({ verifyToken: deps.verifyToken, db: deps.getDb }));

  app.post('/sales/sync', async (c) => {
    const uid = c.get('authUid');
    const db = deps.getDb(c.env);
    const body = await c.req.json<{
      sales?: Array<{
        id: string;
        receipt_json: string;
        total_piastres: number;
        created_at: number;
      }>;
    }>();
    const sales = body.sales ?? [];
    if (sales.length === 0) {
      return c.json({ ok: true, data: { synced: 0 } });
    }
    for (const sale of sales) {
      await db.insertSale({
        id: sale.id,
        tenant_id: uid,
        receipt_json: sale.receipt_json,
        total_piastres: sale.total_piastres,
        created_at: sale.created_at,
      });
    }

    // Notify the realtime worker (service binding) — fire & forget.
    const realtime = c.env.REALTIME;
    if (realtime) {
      const notifyPromise = realtime
        .notify(uid, { type: 'sale', count: sales.length, sales })
        .catch(() => undefined);
      // In Workers, executionCtx.waitUntil extends lifetime. In tests the
      // getter throws, so wrap it.
      try {
        c.executionCtx.waitUntil(notifyPromise);
      } catch {
        await notifyPromise;
      }
    }

    return c.json({ ok: true, data: { synced: sales.length } });
  });

  app.get('/sales', async (c) => {
    const uid = c.get('authUid');
    const db = deps.getDb(c.env);
    const sinceParam = c.req.query('since');
    const since = sinceParam ? Number(sinceParam) : 0;
    const sales = await db.listSales(uid, since);
    return c.json({ ok: true, data: { sales } });
  });
}
