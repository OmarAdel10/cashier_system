import { Session } from '../entities/session';

export interface SessionRepository {
  insert(session: Session): Promise<boolean>;
  admitPosSession(session: Session, limit: number): Promise<boolean>;
  heartbeat(sessionId: string, tenantId: string, at: number): Promise<boolean>;
  end(sessionId: string, tenantId: string, at: number): Promise<boolean>;
  endForTenant(sessionId: string, tenantId: string, at: number): Promise<void>;
  endForDevice(tenantId: string, deviceHwid: string, at: number): Promise<void>;
  getLiveWeb(tenantId: string, sessionId: string): Promise<Session | null>;
  getActive(tenantId: string): Promise<Session[]>;
  getActiveForUsername(tenantId: string, username: string, heartbeatSince: number): Promise<Session[]>;
  getRecent(tenantId: string, limit: number): Promise<Session[]>;
  endWebSessions(tenantId: string, username: string, at: number): Promise<void>;
  getActivePos(tenantId: string): Promise<Session[]>;
}