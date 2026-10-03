/**
 * Eventual consistency strategies for Daftari POS backend workers.
 *
 * This module provides configurable consistency strategies per worker type.
 * Each strategy defines how the worker handles stale data, conflict resolution,
 * and synchronization with other workers.
 *
 * @packageDocumentation
 */

/**
 * Consistency strategy types.
 */
export type ConsistencyStrategyType =
  | 'strong'           // Read-through, immediate consistency
  | 'bounded-staleness' // Acceptable staleness window
  | 'eventual'         // High staleness tolerance, batch sync
  | 'read-your-writes'; // Session-scoped consistency

/**
 * Configuration for a consistency strategy.
 */
export interface ConsistencyConfig {
  /** Strategy type */
  type: ConsistencyStrategyType;
  /** Maximum acceptable staleness in milliseconds (for bounded-staleness) */
  maxStalenessMs?: number;
  /** Whether to use read-through for critical operations */
  readThroughCritical?: boolean;
  /** Cache TTL in seconds (for caching strategies) */
  cacheTtlSeconds?: number;
  /** Conflict resolution strategy */
  conflictResolution?: 'last-write-wins' | 'merge' | 'application-specific' | 'manual';
  /** Whether to subscribe to change notifications */
  subscribeToChanges?: boolean;
  /** Tables to subscribe to for change notifications */
  subscribedTables?: string[];
}

/**
 * Default consistency configurations per worker type.
 */
export const WORKER_CONSISTENCY_CONFIGS: Record<string, ConsistencyConfig> = {
  /**
   * API Worker - Mixed read/write, user-facing
   * - Strong consistency for critical operations (login, license validation)
   * - Bounded staleness (30s) for reads (user profiles, device lists)
   * - Read-through for license/session validation
   * - Subscribe to license and session changes
   */
  api: {
    type: 'bounded-staleness',
    maxStalenessMs: 30_000, // 30 seconds
    readThroughCritical: true,
    cacheTtlSeconds: 30,
    conflictResolution: 'last-write-wins',
    subscribeToChanges: true,
    subscribedTables: ['licenses', 'sessions', 'auth_users', 'users']
  },

  /**
   * Realtime Worker - Read-heavy with real-time requirements
   * - Strong consistency for license validation (device limit enforcement)
   * - Bounded staleness (10s) for session/device data
   * - Subscribe to critical table changes via Turso replication
   * - Fresh DB reads for critical validations
   */
  realtime: {
    type: 'strong',
    maxStalenessMs: 10_000, // 10 seconds
    readThroughCritical: true,
    cacheTtlSeconds: 10,
    conflictResolution: 'application-specific',
    subscribeToChanges: true,
    subscribedTables: ['licenses', 'sessions', 'devices']
  },

  /**
   * Analytics Worker - Write-heavy, read-tolerant of staleness
   * - High staleness tolerance (5-15 minutes) for input data
   * - Batch processing for sales aggregation
   * - Eventual consistency acceptable for reporting
   * - No change subscriptions needed
   */
  analytics: {
    type: 'eventual',
    maxStalenessMs: 15 * 60_000, // 15 minutes
    readThroughCritical: false,
    cacheTtlSeconds: 300,
    conflictResolution: 'last-write-wins',
    subscribeToChanges: false
  },

  /**
   * Paymob Webhook Worker - Write-heavy, minimal reads
   * - Focus on reliable writes with idempotency
   * - Minimal reads to reduce consistency concerns
   * - Idempotency keys for duplicate handling
   */
  paymob_webhook: {
    type: 'eventual',
    maxStalenessMs: 5 * 60_000, // 5 minutes
    readThroughCritical: false,
    cacheTtlSeconds: 60,
    conflictResolution: 'last-write-wins',
    subscribeToChanges: false
  },

  /**
   * Admin Host - Read-heavy for dashboard, occasional writes
   * - Bounded staleness (1 min) for dashboard data
   * - Strong consistency for admin actions (user management)
   * - Read-through for critical admin operations
   */
  admin_host: {
    type: 'bounded-staleness',
    maxStalenessMs: 60_000, // 1 minute
    readThroughCritical: true,
    cacheTtlSeconds: 60,
    conflictResolution: 'application-specific',
    subscribeToChanges: true,
    subscribedTables: ['users', 'auth_users', 'licenses', 'devices']
  }
};

/**
 * Gets the consistency config for a worker type.
 *
 * @param workerType - Worker type identifier
 * @returns ConsistencyConfig for the worker
 */
export function getConsistencyConfig(workerType: string): ConsistencyConfig {
  return WORKER_CONSISTENCY_CONFIGS[workerType] ?? WORKER_CONSISTENCY_CONFIGS.api as ConsistencyConfig;
}

/**
 * Determines if a read operation should use strong consistency (bypass cache).
 *
 * @param workerType - Worker type
 * @param operation - Operation being performed
 * @param criticalTables - Tables considered critical for this operation
 * @returns true if strong consistency required
 */
export function requiresStrongConsistency(
  workerType: string,
  operation: string,
  criticalTables: string[] = []
): boolean {
  const config = getConsistencyConfig(workerType);

  // Always strong for critical operations
  if (config.readThroughCritical && criticalTables.length > 0) {
    return true;
  }

  // Strong consistency for specific operations
  const strongConsistencyOperations = [
    'login',
    'license-validation',
    'session-admit',
    'device-limit-check',
    'admin-action'
  ];

  return strongConsistencyOperations.includes(operation);
}

/**
 * Determines acceptable staleness for a read operation.
 *
 * @param workerType - Worker type
 * @param table - Table being read
 * @returns Maximum acceptable staleness in milliseconds
 */
export function getAcceptableStaleness(workerType: string, table: string): number {
  const config = getConsistencyConfig(workerType);

  // Critical tables always get lower staleness
  const criticalTables = ['licenses', 'sessions', 'auth_users'];
  if (criticalTables.includes(table)) {
    return Math.min(config.maxStalenessMs ?? 30_000, 10_000);
  }

  return config.maxStalenessMs ?? 30_000;
}

/**
 * Conflict resolution strategies for concurrent updates.
 */
export const ConflictResolution = {
  /**
   * Last write wins - simple, may lose updates
   */
  lastWriteWins: <T extends { updatedAt: number }>(a: T, b: T): T =>
    a.updatedAt >= b.updatedAt ? a : b,

  /**
   * Merge strategy - combine non-conflicting fields
   */
  merge: <T extends Record<string, any>>(a: T, b: T): T => ({
    ...a,
    ...b,
    updatedAt: Math.max(a.updatedAt ?? 0, b.updatedAt ?? 0)
  }),

  /**
   * Application-specific - delegate to domain service
   */
  applicationSpecific: <T>(a: T, b: T, resolver: (a: T, b: T) => T): T =>
    resolver(a, b)
};

/**
 * Read-through helper for critical operations.
 * Bypasses cache and reads directly from database.
 */
export interface ReadThroughRepository<T> {
  findById(id: string): Promise<T | null>;
  findByIds(ids: string[]): Promise<T[]>;
}

/**
 * Creates a read-through wrapper for a repository.
 * For critical operations, bypasses cache and reads fresh from DB.
 *
 * @param repository - Base repository with caching
 * @param config - Consistency config
 * @returns Repository with read-through for critical ops
 */
export function withReadThrough<T extends { findById?: (id: string) => Promise<any> }>(
  repository: T,
  config: ConsistencyConfig
): T {
  if (!config.readThroughCritical) {
    return repository;
  }

  // Return proxy that bypasses cache for critical methods
  return new Proxy(repository, {
    get(target, prop) {
      const value = target[prop as keyof T];
      if (typeof value === 'function' && prop.toString().startsWith('findBy')) {
        return async (...args: any[]) => {
          // For critical reads, add a header or flag to bypass cache
          // This is a conceptual implementation - actual implementation
          // would depend on the caching layer supporting bypass
          return value.apply(target, args);
        };
      }
      return value;
    }
  }) as T;
}