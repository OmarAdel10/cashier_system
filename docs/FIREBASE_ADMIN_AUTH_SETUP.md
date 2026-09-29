# Firebase Console Setup — Admin Dashboard Google Sign-In

Plane item: **DAFTARI-90** (Plan Task 42, bundle C5).
Audience: the operator who holds Firebase console access to project `daftari-pos`.
Scope: the console-side work that makes the admin dashboard's Stage-1
"Sign in with Google" popup complete, plus the exact origins the admin host's
Content-Security-Policy now permits and why.

> **Status.** The console steps in this runbook have **not** been performed.
> The authoring environment has no Firebase console access and no credentials,
> so nothing here has been clicked, and no live configuration has been read or
> changed. Everything that could be checked against the repository has been
> (each claim carries a `path:line` citation); console-only behaviour is marked
> `[console]` and is standard Firebase behaviour, not a repository fact.

---

## 1. Project and origin facts (verified in the repo)

| Fact | Value | Evidence |
|---|---|---|
| Firebase project id | `daftari-pos` | `lib/core/config/env_config.dart:93`, `:107`, `:121` |
| Firebase `authDomain` | `daftari-pos.firebaseapp.com` | `lib/core/config/env_config.dart:55` |
| Development admin origin | `https://admin-dev.daftariapp.workers.dev` | `lib/core/config/env_config.dart:94` |
| Staging admin origin | `https://admin-staging.daftariapp.workers.dev` | `lib/core/config/env_config.dart:108` |
| Production admin origin | `https://admin.daftariapp.workers.dev` | `lib/core/config/env_config.dart:122` |
| Worker names for those origins | `admin-dev`, `admin-staging`, `admin` | `backend/admin_host/wrangler.toml:1`, `:16`, `:22` |
| Firebase web config source of truth | `EnvConfig.firebaseWebAuthDomain` etc. | `lib/core/config/env_config.dart:37`, `:55`, `:74` |
| Firebase initialized with that authDomain | `FirebaseOptions(authDomain: EnvConfig.firebaseWebAuthDomain)` | `lib/main_admin.dart:29-37` |
| Local dev entry command | `flutter run -d chrome -t lib/main_admin.dart --dart-define=FLAVOR=admin --dart-define=ENV=development` | `lib/main_admin.dart:5-7` |
| Magic-link continue URL | `${EnvConfig.adminOrigin}/finish-login` | `lib/core/backend/auth/firebase_auth_service.dart:73` |

The admin host is a Cloudflare Worker that serves the Flutter WASM build **and**
attaches the security headers from the same `fetch` handler
(`backend/admin_host/src/index.ts:25-45` calls `withHeaders`;
`:57-91` sets the headers). The headers and the client assets are
therefore versioned together by one `wrangler deploy`.

---

## 2. Console-side vs code-side

The distinction matters: most of the popup machinery is already in code, and
editing code cannot fix a console-side gap (nor can console clicks fix a header
gap).

| Concern | Where it lives | What to touch |
|---|---|---|
| Google provider enabled for the project | Firebase console | Authentication → Sign-in method → Google |
| Which origins may start OAuth | Firebase console | Authentication → Settings → Authorized domains |
| Email-link template text | Firebase console | Authentication → Templates (the email-link / email-address-verification template; the exact label varies by console version) |
| `signInWithPopup(GoogleAuthProvider())` call | Code | `lib/core/backend/auth/firebase_auth_service.dart:47-62` |
| `authDomain` used for the auth iframe | Code | `lib/main_admin.dart:35`, value at `env_config.dart:55` |
| CSP `script-src` / `frame-src` / `connect-src` origins | Code (deployed by CI) | `backend/admin_host/src/index.ts:75-85` |
| COOP popup allowance | Code (deployed by CI) | `backend/admin_host/src/index.ts:66` |
| ID-token provider allowlist | Code | `backend/api/src/middleware/auth.ts:32` |

---

## 3. Step 1 — Enable the Google sign-in provider `[console]`

1. Open the Firebase console for project `daftari-pos`.
2. Go to **Authentication → Sign-in method**.
3. Open **Google**, toggle **Enable**, choose a **project support email** and a
   **project public-facing name**, then **Save**.
4. **Do not enable Email/Password.** The code expects Email/Password to stay
   off: the dashboard removed its Email/Password methods —
   "Email/Password is DISABLED" (`lib/core/backend/auth/firebase_auth_service.dart:13-15`) —
   and the api worker allowlist currently accepts only `google.com` and
   `emailLink`, rejecting password-provider tokens even if the console toggle
   were flipped (`backend/api/src/middleware/auth.ts:6`, `:32`).
5. Leave **Email link (passwordless sign-in)** enabled — the magic-link fallback
   needs it (`lib/core/backend/auth/firebase_auth_service.dart:68-89`;
   `lib/features/admin_dashboard/login/login_screen.dart:244-247`).

Once Google is enabled, the button labeled
`المتابعة عبر جوجل — Sign in with Google`
(`lib/features/admin_dashboard/login/login_screen.dart:229-233`) can start the
popup. Nothing in the repository reads or sets the provider enablement; it is
purely console-side, and the client cannot detect its absence until the popup
is attempted.

---

## 4. Step 2 — Authorized domains `[console]`

Firebase only allows OAuth operations from origins listed under
**Authentication → Settings → Authorized domains**. Entries are **hostnames**
(no scheme, no path, no trailing slash).

### Must be listed (or already present)

| Domain | Why | Evidence |
|---|---|---|
| `admin-dev.daftariapp.workers.dev` | Development dashboard origin | `lib/core/config/env_config.dart:94` |
| `admin-staging.daftariapp.workers.dev` | Staging dashboard origin | `lib/core/config/env_config.dart:108` |
| `admin.daftariapp.workers.dev` | Production dashboard origin | `lib/core/config/env_config.dart:122` |
| `localhost` | `flutter run -d chrome` serves the dashboard from `http://localhost:<port>` | `lib/main_admin.dart:5-7` |

`daftari-pos.firebaseapp.com` and `daftari-pos.web.app` are normally
pre-populated by Firebase `[console]` and must stay listed —
`daftari-pos.firebaseapp.com`
is the `authDomain` the SDK uses (`env_config.dart:55`). Do not remove them.

`localhost` is authorized by default in Firebase projects `[console]`; verify it
is still present rather than assuming it.

### What a missing domain looks like

Firebase rejects the OAuth operation with the error code
`auth/unauthorized-domain`. The dashboard surfaces the real code: the service
carries the `FirebaseAuthException.code` in the failure
(`lib/core/backend/auth/firebase_auth_service.dart:51-58`), the bloc emits it as
`AuthError.code` (`lib/features/admin_dashboard/login/admin_auth_bloc.dart:447-452`),
and the Arabic fallback banner appends the code in parentheses
(`lib/features/admin_dashboard/login/admin_auth_bloc.dart:484`). So the operator
literally sees a banner ending in `(auth/unauthorized-domain)`.

The exact human-readable text Firebase attaches to that code is produced by the
Firebase SDK and is not present in this repository `[console]`; treat the code
as the reliable signal.

### Note on local development

`--dart-define=ADMIN_ORIGIN=...` overrides only the magic-link `continueUrl`
target (`lib/core/config/env_config.dart:43-44`, `:77-80`). It does **not**
change which origins Firebase authorizes. If you run locally on a custom
hostname, that hostname still needs to be an authorized domain.

---

## 5. Step 3 — The CSP/COOP headers are what make the popup work

The console enables Google and authorizes the domain, but the popup returns its
credential to the dashboard page through `window.opener`. Two response headers
served by `backend/admin_host` control whether that return path is allowed.
They are **code**, deployed by the admin host, not console settings.

Current values (`backend/admin_host/src/index.ts:60-85`):

| Header | Value | Why it is required |
|---|---|---|
| `Cross-Origin-Opener-Policy` | `same-origin-allow-popups` | `signInWithPopup` returns the credential via `window.opener`; `same-origin` severs that link while Google/Firebase has already created the account (`index.ts:60-66`). The value keeps cross-origin opener protection while permitting the auth popup. |
| `Content-Security-Policy` | see below | `default-src 'self'` would otherwise block Firebase's script, its auth iframe, and its API calls. |

### Exact origins the CSP allows and why each is needed

From `backend/admin_host/src/index.ts:77-84`:

| Directive | Allowed origin | Why it is required |
|---|---|---|
| `script-src` | `'self'`, `'wasm-unsafe-eval'`, `https://apis.google.com` | `apis.google.com` is Firebase's gapi loader, injected before the popup opens (`index.ts:73-74`, `:78`). |
| `frame-src` | `'self'`, `https://*.firebaseapp.com` | Firebase hosts the auth iframe hub at `https://<authDomain>/__/auth/iframe`; with `authDomain = daftari-pos.firebaseapp.com` (`env_config.dart:55`) that is `https://daftari-pos.firebaseapp.com`. |
| `connect-src` | `'self'`, `https://*.daftariapp.workers.dev`, `wss://*.daftariapp.workers.dev` | The dashboard's own api/realtime workers (`index.ts:81`). |
| `connect-src` | `https://*.googleapis.com`, `https://*.firebaseio.com`, `wss://*.firebaseio.com` | Firebase Identity Toolkit / secure-token traffic and the SDK's realtime channel (`index.ts:81-82`). |
| `style-src`, `font-src`, `img-src` | `'self'`, plus `'unsafe-inline'` for styles and `data:` for fonts/images | No Firebase origin is needed here. |
| `frame-ancestors` | `'none'` | Protects the dashboard from being framed. This is the *opposite* direction from `frame-src`. |

Precision note: `frame-src` is the directive that decides which frames the
dashboard may **load**, so it is the one that matters for the Firebase auth
iframe. `X-Frame-Options: DENY` (`index.ts:68`) and `frame-ancestors 'none'`
govern pages framing the **dashboard**; they do not block the dashboard's own
auth iframe.

These are asserted by the admin host test suite:
`backend/admin_host/test/index.test.ts:66` checks COOP, and `:68-71` asserts the
CSP origins for `apis.google.com`, `firebaseapp.com`, and the workers.dev
origins.

---

## 6. Ordering: deploy the headers before/with the client

The CSP/COOP headers must be live on the admin host **before or together with**
the client build that uses them:

- The headers and the WASM assets are served by the same Worker
  (`backend/admin_host/src/index.ts:25-45`, `:57-91`), so a single
  `wrangler deploy` ships both.
- If a new client build is deployed while an **older** Worker version is still
  serving, the browser receives the old `script-src`/`frame-src`/COOP values and
  the popup fails even though the console is configured correctly.
- Therefore: deploy `backend/admin_host` first (or in the same release step as
  the client), and only then verify sign-in. A hard refresh is not enough —
  these are response headers, so the page must be re-fetched from the new
  Worker version.

This ordering is the documented root cause of the PR #39 Google sign-in bug:
the old header value `Cross-Origin-Opener-Policy: same-origin` severed
`window.opener`, and the account was created in Firebase while the dashboard
showed a failure
(`docs/superpowers/plans/2026-09-29-pr39-fixes-and-hardening.md:17`).

---

## 7. What the operator should see

The dashboard is a two-stage login
(`lib/features/admin_dashboard/login/login_screen.dart:9-10`):

1. **Stage 1 — Firebase card.** Google button plus the email field and magic-link
   button (`login_screen.dart:131-136`, `:214-250`).
2. Clicking Google opens the Firebase auth popup
   (`admin_auth_bloc.dart:275`). On success the bloc performs
   the owner refresh and checks the tenant's accounts
   (`admin_auth_bloc.dart:287-318`).
3. **Branch:**
   - **No admin accounts yet** → the owner is signed in directly
     ("تم تسجيل الدخول" card, `login_screen.dart:130`, `:292-310`) — first-admin
     bootstrap (`admin_auth_bloc.dart:320-332`).
   - **Admin accounts exist** → **Stage 2 — credentials card**
     (username/password, `login_screen.dart:137-141`, `:253-290`), which posts
     to the api worker's `/auth/login` (`admin_auth_service.dart:142-184`).

A failure at Stage 1 leaves the Firebase card on screen and shows an error
banner with the underlying code (`login_screen.dart:147-159`;
`admin_auth_bloc.dart:284`). In development builds, `EnvConfig.enableLogging` is
`true` (`env_config.dart:95`) so the console also prints
`[AdminAuth] Firebase sign-in failed: ...` (`admin_auth_bloc.dart:467-472`).

---

## 8. Troubleshooting by symptom

| Symptom | Likely cause | How to confirm | Fix |
|---|---|---|---|
| Popup opens, the account is chosen, the popup closes, and the dashboard reports failure | Stale COOP `same-origin` on the served page severs `window.opener`, so the credential never returns | Inspect the document response headers; `Cross-Origin-Opener-Policy` should be `same-origin-allow-popups` (`index.ts:66`). In dev, check the `[AdminAuth]` log and the code in the error banner (`admin_auth_bloc.dart:467-472`, `:484`) | Deploy the current `backend/admin_host` so the new headers are live (Section 6) |
| Browser console shows a **CSP violation naming `apis.google.com`** (`Refused to load the script ... script-src`) | The served `script-src` does not include `https://apis.google.com` — an old Worker version is still live | Check the `Content-Security-Policy` response header against `index.ts:78` | Redeploy `backend/admin_host`; confirm the header now contains `script-src 'self' 'wasm-unsafe-eval' https://apis.google.com` |
| The **auth iframe is blocked** (console shows a `frame-src` violation, or the request to `https://daftari-pos.firebaseapp.com/__/auth/iframe` is refused) | The served `frame-src` lacks `https://*.firebaseapp.com`, so `default-src 'self'` blocks it | Check the `Content-Security-Policy` response header against `index.ts:83`, and look for the `__/auth/iframe` request in the Network tab | Redeploy `backend/admin_host`; confirm `frame-src 'self' https://*.firebaseapp.com` |
| Dashboard reports `auth/unauthorized-domain` | The dashboard's origin hostname is not in **Authorized domains** | Read the code appended to the Arabic banner (`admin_auth_bloc.dart:474-485`); compare the browser origin to Section 4 | Add the hostname (no scheme/path) under Authentication → Settings → Authorized domains; keep `daftari-pos.firebaseapp.com` and `localhost` listed |
| Popup blocked before it opens; no CSP or OAuth error | Browser popup blocker, not Firebase | Look for the blocked-popup icon in the address bar | Allow popups for the admin origin, or use the magic-link fallback |

---

## 9. Email-link template (DAFTARI-90 Step 1) `[console]`

This is console-side and was **not** performed. The magic link lands on
`${EnvConfig.adminOrigin}/finish-login` and is completed by the client
(`lib/core/backend/auth/firebase_auth_service.dart:70-76`;
`lib/features/admin_dashboard/login/admin_auth_bloc.dart:166-175`), so the
template's action link is what the dashboard expects. The brief specifies:
sender name `Daftari`, subject and body in Arabic + English, and an action-link
label matching the dashboard. Customize it under
**Authentication → Templates** (the email-link / email-address-verification
template). No repository file encodes the template text, so there is nothing
further to verify in code.

---

## 10. References

- `lib/core/config/env_config.dart` — project id, authDomain, env admin origins.
- `lib/main_admin.dart` — Firebase initialization and local dev command.
- `lib/core/backend/auth/firebase_auth_service.dart` — popup and magic-link calls.
- `lib/features/admin_dashboard/login/login_screen.dart`, `admin_auth_bloc.dart`,
  `admin_auth_service.dart` — the two-stage flow and error surfacing.
- `backend/admin_host/src/index.ts` — COOP/COEP and the full CSP.
- `backend/admin_host/test/index.test.ts` — header assertions.
- `backend/admin_host/wrangler.toml` — worker names and envs.
- `backend/README.md` — backend services overview.
- `backend/api/src/middleware/auth.ts` — ID-token provider allowlist.
- `specs/DEVELOPMENT_ENVIRONMENT.md` §5i, §5h, §5b — admin flavor, build command,
  environment config.
- `docs/superpowers/plans/2026-09-29-pr39-fixes-and-hardening.md` — confirmed
  COOP root cause and the ordering requirement.
