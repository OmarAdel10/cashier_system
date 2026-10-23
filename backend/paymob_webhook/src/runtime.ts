/**
 * Paymob Webhook Worker runtime entry point.
 *
 * Wires the Turso-backed `WebhookEventRepository`, `HmacValidationService`,
 * `LicenseSigningService`, and the two application use cases
 * (`ProcessWebhookUseCase`, `IssueLicenseUseCase`) into a fully-wired Hono
 * app. Secrets (TURSO_DATABASE_URL, TURSO_AUTH_TOKEN, ED25519_PRIVATE_KEY,
 * PAYMOB_HMAC_SECRET, POSTHOG_API_KEY) come from the Worker environment via
 * wrangler secrets.
 */
import { createTurso } from '../../shared/src/turso';
import { TursoWebhookEventRepository } from './infrastructure/repositories/turso-webhook-event-repository';
import { PostHogAnalyticsService } from './infrastructure/external-services/posthog-analytics-service';
import { HmacValidationServiceImpl } from './domain/services/hmac-validation-service.impl';
import { LicenseSigningServiceImpl } from './domain/services/license-signing-service.impl';
import { ProcessWebhookUseCase } from './application/use-cases/process-webhook-use-case';
import { IssueLicenseUseCase } from './application/use-cases/issue-license-use-case';
import { createPaymobApp, type PaymobDeps, type Env } from './index';
import { signLicenseKey } from '../../shared/src/license';

/**
 * Build a fully-wired `createPaymobApp` from the Worker environment.
 *
 * Resolves the Turso database, constructs all infrastructure adapters and
 * domain services, then builds the two application use cases and returns a
 * pre-wired Hono app.
 *
 * @param env - Cloudflare Worker environment bindings
 *   (PAYMOB_HMAC_SECRET, ED25519_PRIVATE_KEY, ED25519_PUBLIC_KEY,
 *    FIREBASE_PROJECT_ID, TURSO_DATABASE_URL, TURSO_AUTH_TOKEN,
 *    POSTHOG_API_KEY)
 * @returns A Hono app with all routes wired to use cases
 */
export function createPaymobAppFromEnv(env: Env) {
  // Fail closed: required env vars must be present before constructing the app.
  if (
    !env.TURSO_DATABASE_URL ||
    !env.TURSO_AUTH_TOKEN
  ) {
    throw new Error(
      'Missing required env vars: TURSO_DATABASE_URL, TURSO_AUTH_TOKEN',
    );
  }

  const db = createTurso(env.TURSO_DATABASE_URL, env.TURSO_AUTH_TOKEN);
  const webhookEventRepo = new TursoWebhookEventRepository(db);
  const posthog = new PostHogAnalyticsService(fetch, env.POSTHOG_API_KEY);
  const hmacValidationService = new HmacValidationServiceImpl();
  const licenseSigningService = new LicenseSigningServiceImpl();

  const deps: PaymobDeps = {
    hmacValidationService,
    webhookEventRepo,
    licenseSigningService,
    signLicenseKey,
    posthog,
    db,
  };

  return createPaymobApp(deps);
}

const handler: ExportedHandler<Env> = {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const app = createPaymobAppFromEnv(env);
    return app.fetch(request, env, ctx);
  },
};

export default handler;
