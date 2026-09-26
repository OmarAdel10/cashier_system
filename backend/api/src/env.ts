/** Environment bindings + request-scoped variables for the api worker. */
export interface Env {
  ENVIRONMENT: string;
  FIREBASE_PROJECT_ID: string;
  TURSO_DATABASE_URL: string;
  TURSO_AUTH_TOKEN: string;
  POSTHOG_API_KEY: string;
  /** Signs/verifies dashboard session JWTs (shared with realtime worker). */
  ADMIN_JWT_SECRET: string;
  /** Service binding to daftari-realtime worker. */
  REALTIME?: {
    notify: (tenantId: string, event: Record<string, unknown>) => Promise<void>;
  };
  /** R2 bucket for tenant branding (logos). */
  LOGOS?: {
    put: (
      key: string,
      value: string | ArrayBuffer | ReadableStream,
      options?: { httpMetadata?: { contentType?: string } },
    ) => Promise<unknown>;
    get: (key: string) => Promise<{ body: ReadableStream } | null>;
  };
}

export interface Vars {
  authUid: string;
  authEmail?: string;
  /** Session-JWT path only: the admin account's username. */
  authUsername?: string;
  /** Session-JWT path only: the admin account's role. */
  authRole?: string;
  /** True only on the Firebase (owner) path. */
  authIsOwner: boolean;
}
