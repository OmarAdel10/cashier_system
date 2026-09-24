/**
 * Per-isolate cached Turso client. Workers reuse isolates; caching avoids
 * re-creating the libSQL client per request.
 */
import { createTurso, type TursoDb } from '../../shared/src/turso';

let cached: TursoDb | null = null;
let cachedKey = '';

export function getDb(env: { TURSO_DATABASE_URL: string; TURSO_AUTH_TOKEN: string }): TursoDb {
  const key = `${env.TURSO_DATABASE_URL}|${env.TURSO_AUTH_TOKEN}`;
  if (!cached || cachedKey !== key) {
    cached = createTurso(env.TURSO_DATABASE_URL, env.TURSO_AUTH_TOKEN);
    cachedKey = key;
  }
  return cached;
}
