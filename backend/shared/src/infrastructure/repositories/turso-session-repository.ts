import { inject, injectable } from 'tsyringe';
import { TursoDb } from '../../turso';
import { SessionRepository } from '../../domain/repositories/session-repository';
import { Session } from '../../domain/entities/session';
import { SessionRecord } from '../../types';

@injectable()
export class TursoSessionRepository implements SessionRepository {
  constructor(
    @inject('TursoDb') private readonly db: TursoDb
  ) {}

  private toSession(record: SessionRecord): Session {
    const source =
      record.source === 'pos' || record.source === 'web' ? record.source : undefined;
    return {
      id: record.id,
      tenantId: record.tenant_id,
      deviceHwid: record.device_hwid,
      username: record.username,
      startedAt: record.started_at,
      heartbeatAt: record.heartbeat_at,
      endedAt: record.ended_at,
      source,
    };
  }

  async insert(session: Session): Promise<boolean> {
    const result = await this.db.insertSession({
      id: session.id,
      tenant_id: session.tenantId,
      device_hwid: session.deviceHwid,
      username: session.username,
      started_at: session.startedAt,
      heartbeat_at: session.heartbeatAt,
      ended_at: session.endedAt,
      source: session.source,
    });
    return result;
  }

  async admitPosSession(session: Session, limit: number): Promise<boolean> {
    const result = await this.db.admitPosSession({
      id: session.id,
      tenant_id: session.tenantId,
      device_hwid: session.deviceHwid,
      username: session.username,
      started_at: session.startedAt,
      heartbeat_at: session.heartbeatAt,
      ended_at: session.endedAt,
      source: session.source,
    }, limit);
    return result;
  }

  async heartbeat(sessionId: string, tenantId: string, at: number): Promise<boolean> {
    return await this.db.heartbeatSession(sessionId, tenantId, at);
  }

  async end(sessionId: string, tenantId: string, at: number): Promise<boolean> {
    return await this.db.endSession(sessionId, tenantId, at);
  }

  async endForTenant(sessionId: string, tenantId: string, at: number): Promise<void> {
    await this.db.endSessionForTenant(sessionId, tenantId, at);
  }

  async endForDevice(tenantId: string, deviceHwid: string, at: number): Promise<void> {
    await this.db.endSessionForDevice(tenantId, deviceHwid, at);
  }

  async getLiveWeb(tenantId: string, sessionId: string): Promise<Session | null> {
    const session = await this.db.getLiveWebSession(tenantId, sessionId);
    if (!session) return null;
    return this.toSession(session);
  }

  async getActive(tenantId: string): Promise<Session[]> {
    const sessions = await this.db.getActiveSessions(tenantId);
    return sessions.map(s => this.toSession(s));
  }

  async getActiveForUsername(tenantId: string, username: string, heartbeatSince: number): Promise<Session[]> {
    const sessions = await this.db.getActiveSessionsForUsername(tenantId, username, heartbeatSince);
    return sessions.map(s => this.toSession(s));
  }

  async getRecent(tenantId: string, limit: number): Promise<Session[]> {
    const sessions = await this.db.getRecentSessions(tenantId, limit);
    return sessions.map(s => this.toSession(s));
  }

  async endWebSessions(tenantId: string, username: string, at: number): Promise<void> {
    await this.db.endWebSessions(tenantId, username, at);
  }

  async getActivePos(tenantId: string): Promise<Session[]> {
    const sessions = await this.db.getActivePosSessions(tenantId);
    return sessions.map(s => this.toSession(s));
  }
}
