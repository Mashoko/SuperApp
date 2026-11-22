# KYC Stage 1: App-User Sessions & Route Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give app users a real backend session (verified against Afri Com) and make every user-scoped backend route take identity from that session, so Stage 2 can enforce KYC on the server.

**Architecture:** The app posts its existing Afri Com SIP username/password to `POST /api/app-auth/session`; the backend verifies them with Afri Com's `AccountBalance` gRPC call, upserts an `AppUser`, and returns a JWT with `aud: "app"`. Staff JWTs get `aud: "admin"`. Two middlewares (`requireAdmin`, `requireAppUser`) check audience. User-scoped routes resolve the user from the token; the old `userId`-in-request path stays only behind `LEGACY_USERID_ROUTES=true` for one release.

**Tech Stack:** Node/Express 5, Mongoose 8, jsonwebtoken, Jest + supertest + mongodb-memory-server; `@grpc/grpc-js` + `@grpc/proto-loader` (new, owner approval required); Flutter `http` + `shared_preferences`.

**Spec:** `docs/superpowers/specs/2026-11-22-kyc-verification-design.md` (section 6.1)

## Global Constraints

- Existing data stays keyed by the SIP username string: the resolved user id for cart/orders/wishlist/addresses/posts is `AppUser.sipUsername`, never the Mongo `_id`. No data migration.
- Staff tokens: `aud: "admin"`, expiry `1d` (unchanged). App tokens: `aud: "app"`, `sub: <AppUser _id>`, `username: <sipUsername>`, expiry `7d`.
- App-token login is rate limited with the existing `authLimiter`.
- Never log passwords, tokens, or the Afri Com response body.
- Wrong credentials return `401 { message: "Phone number or password is incorrect." }` (no hint which).
- `LEGACY_USERID_ROUTES` defaults to `false` in tests and `.env.example`; production sets `true` for the transition release only.
- New env vars: `AFRICOM_GRPC_HOST` (default `wss.durihub.co.zw`), `AFRICOM_GRPC_PORT` (default `50000`), `AFRICOM_GRPC_SECURE` (default `false`), `AFRICOM_PACKAGE_ID` (default `org.duri.maswerasei`), `AFRICOM_DOMAIN` (default `localvoip.ai.co.zw`), `LEGACY_USERID_ROUTES`.
- No `console.log` added; errors go through the existing global handler.

## Review Focus

- Username with and without leading `+`: the Flutter code retries Afri Com without `+`. `/session` must try both and store the form that succeeded, or a user gets two AppUsers and loses their cart. Test in Task 3.
- Afri Com unreachable (timeout / connection refused): `/session` returns `503 { message: "Verification service unavailable. Try again shortly." }`, not 401, so the app doesn't tell a valid user their password is wrong. Test in Task 3.
- App token used on an admin route (e.g. `POST /api/products`): must be 401. Test in Task 1.
- Token present but body also carries a different `userId`: token wins, body ignored (no IDOR). Test in Task 4.
- Expired app token mid-session in Flutter: client re-creates the session once with stored credentials and retries the request once; no loop. Test in Task 5.

---

### Task 1: Token audiences, split middleware, lock staff registration

**Files:**
- Modify: `backend/middleware/auth.middleware.js` (replace default export)
- Modify: `backend/index.js:41` (import), `:137-149` (register), `:151-175` (login sign), every `auth` usage on admin routes
- Test: `backend/tests/auth.audience.test.js`

**Interfaces:**
- Produces: `const { requireAdmin, requireAppUser, signAdminToken, signAppToken } = require('./middleware/auth.middleware')`
  - `requireAdmin(roles?: string[]) => express middleware` — sets `req.user = { id, role, username }`; 401 if missing/invalid/`aud !== 'admin'`; 403 if `roles` given and role not in it.
  - `requireAppUser => express middleware` — sets `req.appUser = { id, username }`; 401 if missing/invalid/`aud !== 'app'`.
  - `signAdminToken(user) => string`, `signAppToken(appUser) => string`.

- [ ] **Step 1: Write failing tests** in `auth.audience.test.js` (same Mongo-memory setup as `posts.create.test.js`):
  - `admin token can create a product` → `POST /api/products` with admin token, expect not 401.
  - `app token is rejected on admin routes` → `signAppToken({_id, sipUsername:'263771234567'})` on `POST /api/products`, expect 401.
  - `legacy token without aud is rejected` → `jwt.sign({id, role:'super_admin'}, secret)`, expect 401.
  - `public staff registration is closed` → `POST /api/auth/register` without token, expect 401.
  - `super_admin can create staff` → with super_admin admin token, expect 201.
  - `staff cannot create staff` → with staff admin token, expect 403.
- [ ] **Step 2:** Run `cd backend && npx jest tests/auth.audience.test.js` — expect FAIL.
- [ ] **Step 3:** Implement the middleware module and wire it: register becomes `requireAdmin(['super_admin'])`; login uses `signAdminToken`; replace every `auth` on admin routes with `requireAdmin()`; `/api/upload` → `requireAdmin()`. Add `scripts/create-super-admin.js` (reads `ADMIN_USERNAME`/`ADMIN_PASSWORD` from env, upserts a super_admin) so the first admin can still be created.
- [ ] **Step 4:** Run the new test file and the full suite `npx jest` — expect PASS (existing tests unaffected).
- [ ] **Step 5:** Commit `Split admin and app token audiences; close public staff signup`.

Note for deploy: existing admin sessions are invalidated (no `aud`); staff log in again.

### Task 2: Afri Com credential verifier

**Gate:** owner approves `npm install @grpc/grpc-js @grpc/proto-loader` before this task.

**Files:**
- Create: `backend/protos/users.proto` (copy of repo-root `protos/users.proto`; backend deploys alone)
- Create: `backend/africom/verifier.js`
- Test: `backend/tests/africom.verifier.test.js`

**Interfaces:**
- Produces: `verifyCredentials(username: string, password: string) => Promise<{ ok: true, username: string } | { ok: false, reason: 'invalid' | 'unavailable' }>`
  - Tries `username`; if `invalid` and username starts with `+`, tries without `+`. Returns the form that succeeded.
  - Success = response `status === 'SUCCESS'` (enum 1). gRPC error codes `UNAVAILABLE`/`DEADLINE_EXCEEDED` → `unavailable`. Deadline 8 s.
  - `setVerifierForTests(fn)` export to swap the implementation in route tests.
- Consumes: env vars from Global Constraints.

- [ ] **Step 1: Write failing tests** with a fake gRPC server started in-test on a random port (using `@grpc/grpc-js` `Server` + the same proto):
  - `returns ok for SUCCESS status`
  - `returns invalid for ERROR status`
  - `retries without plus and returns stripped username` (fake accepts only `263771234567`, call with `+263771234567`, expect `{ok:true, username:'263771234567'}`)
  - `returns unavailable when server is down` (point at closed port)
- [ ] **Step 2:** Run — expect FAIL.
- [ ] **Step 3:** Implement with `protoLoader.loadSync` + `grpc.loadPackageDefinition`; request fields `username`, `password`, `package_id`, `domain` (proto field names).
- [ ] **Step 4:** Run — expect PASS.
- [ ] **Step 5:** Commit `Add Afri Com credential verifier`.

### Task 3: AppUser model and session endpoint

**Files:**
- Create: `backend/models/app_user.model.js`
- Create: `backend/routes/app_auth.routes.js` (mounted in `index.js` at `/api/app-auth`)
- Test: `backend/tests/app_auth.session.test.js`

**Interfaces:**
- Consumes: `verifyCredentials`, `signAppToken`, `authLimiter` (export it from index or move to `middleware/rate_limits.js`).
- Produces: `AppUser` model `{ sipUsername: String unique required, displayName: String, lastSessionAt: Date, timestamps }` (Stage 2 adds `kyc`).
  `POST /api/app-auth/session { username, password, displayName? }` → `200 { token, user: { id, username, displayName } }`.
  `GET /api/app-auth/me` (`requireAppUser`) → `200 { id, username, displayName }`.

- [ ] **Step 1: Write failing tests** (verifier stubbed via `setVerifierForTests`):
  - `creates AppUser and returns app token on valid credentials` — decode token, expect `aud:'app'`, `username:'263771234567'`.
  - `second session reuses the same AppUser`
  - `plus-prefixed login maps to existing stripped user` (stub returns stripped username) — one AppUser in DB.
  - `invalid credentials return 401 with generic message` — body `{ message: 'Phone number or password is incorrect.' }`.
  - `verifier unavailable returns 503`
  - `missing fields return 400`
  - `GET /me with app token returns user; with admin token returns 401`
- [ ] **Step 2:** Run — expect FAIL.
- [ ] **Step 3:** Implement. Upsert by verified `username`; update `lastSessionAt`.
- [ ] **Step 4:** Run file + full suite — PASS.
- [ ] **Step 5:** Commit `Add app-user session endpoint backed by Afri Com`.

### Task 4: Resolve user identity from token on user-scoped routes

**Files:**
- Create: `backend/middleware/resolve_user.middleware.js`
- Modify: `backend/index.js` routes: cart (all 5), orders (POST, GET), wishlist (3), shipping-addresses (3), `POST /api/payments/africom/superapp-pay`, posts (POST, like, DELETE), and `GET /api/products` if it reads `userId` (wishlist flags)
- Test: `backend/tests/resolve_user.test.js`, update existing `posts.*.test.js` to send app tokens

**Interfaces:**
- Consumes: `requireAppUser` internals (token verification).
- Produces: `resolveUser({ field, required = true }) => middleware` that sets `req.userId: string`:
  1. Valid app bearer token → `req.userId = token.username`; any `userId`/`user_id`/`authorUserId` in body/query is ignored.
  2. No token and `process.env.LEGACY_USERID_ROUTES === 'true'` → read from `req.body[field] ?? req.query[field]`.
  3. Otherwise 401 `{ message: 'Sign in required.' }`. Invalid token → 401 even in legacy mode.
  Routes then use `req.userId` instead of destructuring it. Stage 2 adds `requireKycAccess` right after this middleware.
  For `GET /api/products` use `required: false` (anonymous browsing keeps working).

- [ ] **Step 1: Write failing tests:**
  - `cart uses token identity` — add item with token for `A`; `GET /api/cart` with token for `A` returns it.
  - `token wins over body userId` — token `A`, body `userId: 'B'` → item lands in A's cart; B's cart empty.
  - `no token returns 401 when legacy off`
  - `no token with legacy on uses body userId`
  - `invalid token returns 401 even with legacy on`
  - `orders GET only returns caller's orders`
  - `post delete by non-author is 403` (author from token)
  - `product browse works anonymously`
- [ ] **Step 2:** Run — FAIL.
- [ ] **Step 3:** Implement middleware; apply to listed routes; update existing posts tests to authenticate.
- [ ] **Step 4:** `npx jest` full suite — PASS.
- [ ] **Step 5:** Commit `Take user identity from app session on user-scoped routes`.

### Task 5: Flutter backend session client

**Files:**
- Create: `lib/core/services/backend_session_service.dart`
- Create: `lib/core/services/authed_http_client.dart`
- Modify: `lib/core/di/inject.dart` (register both; pass `AuthedHttpClient` into `ShoppingService`, `PostsService`, `ShippingAddressService`, `AfricomPaymentService`)
- Modify: `lib/services/shipping_address_service.dart`, `lib/services/payment_service.dart` (accept injected `http.Client`, stop using top-level `http.get/post`)
- Test: `test/core/services/backend_session_service_test.dart`, `test/core/services/authed_http_client_test.dart`

**Interfaces:**
- Produces:
  - `class BackendSessionService { BackendSessionService(SharedPreferences prefs, {http.Client? client}); Future<String?> token(); Future<String?> refresh(); Future<void> clear(); }` — `refresh()` reads `AppConstants.keyAuthUser`/`keyPassword`, posts to `/api/app-auth/session`, stores token under `backend_app_token`. Returns null on failure.
  - `class AuthedHttpClient extends http.BaseClient { AuthedHttpClient(BackendSessionService session, {http.Client? inner}); }` — adds `Authorization: Bearer`; on 401 calls `refresh()` once and retries once. To make any request replayable, `send` first buffers the body (`request.finalize().toBytes()`) and builds each attempt as a fresh `http.Request` with the same method, URL, headers and bytes (works for multipart too, since the content-type boundary header is copied).
  - `clear()` is called from the existing logout path in `OtpAuthService` (keyAuthUser removal at `otp_auth_service.dart:140`).
- Services keep sending `userId` for the transition release (legacy servers), the server ignores it when a token is present.

- [ ] **Step 1: Write failing tests** using `package:http/testing.dart` `MockClient`:
  - `token() returns stored token without network`
  - `refresh() posts stored credentials and stores token`
  - `refresh() returns null on 401 and does not store`
  - `AuthedHttpClient adds bearer header`
  - `AuthedHttpClient refreshes once on 401 then retries once` — count calls: 1 original + 1 session + 1 retry.
  - `AuthedHttpClient does not loop when retry also 401` — exactly 3 calls, returns 401.
- [ ] **Step 2:** `flutter test test/core/services/` — FAIL.
- [ ] **Step 3:** Implement and wire DI. Session is first created right after successful registration/login (call `refresh()` where `OtpAuthService` saves credentials).
- [ ] **Step 4:** `flutter test` and `flutter analyze` — PASS / no new issues.
- [ ] **Step 5:** Commit `Add backend session client and authenticated HTTP client`.

### Task 6: Config docs and live check

**Files:**
- Create: `backend/.env.example` (names only: `MONGO_URI`, `PORT`, `JWT_SECRET`, `ALLOWED_ORIGINS`, the Afri Com vars, `LEGACY_USERID_ROUTES`, `ADMIN_USERNAME`, `ADMIN_PASSWORD`)
- Create: `backend/docs/app-sessions.md` (rollout order: deploy backend with `LEGACY_USERID_ROUTES=true` → ship app → after adoption set `false`; create first super_admin; staff re-login)

- [ ] **Step 1:** Confirm `backend/.env` is gitignored (`git check-ignore backend/.env` prints the path).
- [ ] **Step 2:** Run backend locally and show real responses: `/api/app-auth/session` with wrong password (401), `POST /api/products` with an app token (401), `GET /api/cart` without token (401). Against real Afri Com, one valid-credential call (owner supplies a test account) — this is the `[VERIFY]` from the spec; if it fails due to network policy, stop and report.
- [ ] **Step 3:** Commit `Document app-session config and rollout`.

---

Stage 2 (KYC core) and Stage 3 (admin KYC page) get their own plans after this lands.
