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

  async insert(session: Session): Promise<boolean> {
    const result = await this.db.insertSession({
      id: session.id,
      tenant_id: session.tenantId,
      device_hwid: session.deviceHwid,
      username: session.username,
      started_at: session.startedAt,
      heartbeat_at: session.heartbeatAt,
      ended_at: session.endedAt,
      source: session.source
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
      source: session.source
    }, limit);
    return result;
  }

  async heartbeat(sessionId: string, tenantId: string, at: number): Promise<boolean> {
    const result = await this.db.heartbeatSession(sessionId, tenantId, at);
    return result;
  }

  async end(sessionId: string, tenantId: string, at: number): Promise<boolean> {
    const result = await this.db.endSession(sessionId, tenantId, at);
    return result;
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

    return {
      id: session.id,
      tenantId: session.tenant_id,
      deviceHwid: session.device_hwid,
      username: session.username,
      startedAt: session.started_at,
      heartbeatAt: session.heartbeat_at,
      endedAt: session.ended_at,
      source: session.source
    };
  }

  async getActive(tenantId: string): Promise<Session[]> {
    const sessions = await this.db.getActiveSessions(tenantId);
    return sessions.map(s => ({
      id: s.id,
      tenantId: s.tenant_id,
      deviceHwid: s.device_hwid,
      username: s.username,
      startedAt: s.started_at,
      heartbeatAt: s.heartbeat_at,
      endedAt: s.ended_at,
      source: s.source
    }));
  }

  async getActiveForUsername(tenantId: string, username: string, heartbeatSince: number): Promise<Session[]> {
    // This method needs to be implemented in TursoDb - for now we'll return empty array
    // TODO: Implement getActiveSessionsForUsername in TursoDb
    return [];
  }

  async getRecent(tenantId: string, limit: number): Promise<Session[]> {
    // This method needs to be implemented in TursoDb - for now we'll return empty array
    // TODO: Implement getRecentSessions in TursoDb
    return [];
  }

  async endWebSessions(tenantId: string, username: string, at: number): Promise<void> {
    await this.db.endWebSessions(tenantId, username, at);
  }

  async getActivePos(tenantId: string): Promise<Session[]> {
    // This method needs to be implemented in TursoDb - for now we'll return empty array
    // TODO: Implement getActivePosSessions in TursoDb
    return [];
  }
}