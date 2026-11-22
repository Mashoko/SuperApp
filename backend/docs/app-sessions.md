# App-user sessions

## What changed and why

Previously the backend trusted a user id sent by the Flutter app on user-scoped routes (cart, orders, wishlist, shipping addresses, SuperApp Pay, posts), so anyone could act as any user. The app now exchanges its Afri Com phone number and password for a backend session token (`POST /api/app-auth/session`, 7 days, audience `app`), and those routes take the user identity from that token. Staff tokens now carry audience `admin` (1 day), so an app token cannot reach admin routes and vice versa. Public staff registration is closed; the first super_admin is created with a script. Existing staff tokens are invalid, so staff must log in again.

## Environment variables

| Variable | Purpose | Default |
|---|---|---|
| `MONGO_URI` | MongoDB connection string | none (required) |
| `PORT` | HTTP port | `5000` |
| `JWT_SECRET` | Signs staff and app JWTs | none (required) |
| `ALLOWED_ORIGINS` | Comma-separated CORS origins | none |
| `AFRICOM_GRPC_HOST` | Afri Com gRPC host | `wss.durihub.co.zw` |
| `AFRICOM_GRPC_PORT` | Afri Com gRPC port | `50000` |
| `AFRICOM_GRPC_SECURE` | Use TLS for Afri Com gRPC | `false` |
| `AFRICOM_PACKAGE_ID` | Package id sent to Afri Com | `org.duri.maswerasei` |
| `AFRICOM_DOMAIN` | Afri Com SIP domain | `localvoip.ai.co.zw` |
| `TRUST_PROXY` | Optional. Number of reverse-proxy hops to trust for the client IP (integer). Rate limits key on that IP | `1` on Render (detected via `RENDER`), otherwise off |
| `LEGACY_USERID_ROUTES` | `true` (exact string) allows tokenless requests to use the client-supplied user id | off |
| `ADMIN_USERNAME`, `ADMIN_PASSWORD` | Used only by `scripts/create-super-admin.js` | none |

## Rollout order

1. Deploy the backend with `LEGACY_USERID_ROUTES=true`. Security trade-off: while this is on, anyone can still act as any user by omitting the token and sending a user id, so the fix is not effective yet. Old app versions keep working only because of this flag. Keep this step short. Immediately after this deploy, run the canonical user id migration (see "Canonical user ids" below).
2. If no super_admin exists, run `ADMIN_USERNAME=... ADMIN_PASSWORD=... node scripts/create-super-admin.js` from `backend/`. Tell staff to log in again.
3. Ship the app update. It starts a session after OTP verification and after password login, before its first backend request whenever it has credentials but no token, and again on a 401. After a failed attempt it waits 60 seconds (or the server's `Retry-After`) before trying again.
4. Decide when to turn legacy mode off with `GET /api/admin/legacy-usage` (super_admin token). It returns `{ tokenRequests, legacyRequests, since }`: how many user-scoped requests were identified by a session token and how many by the legacy client-supplied id since `since`. The counters are in memory and reset on every deploy or restart, so read them after the service has been up long enough to be representative. Once `legacyRequests` is a small share of the total, set `LEGACY_USERID_ROUTES=false` (or remove it) and redeploy. Users still on old versions will get 401 until they update.

## Canonical user ids (run right after the step 1 deploy, and before step 4)

User ids are now stored as `+` followed by digits, so `263…` and `+263…` logins are the same user. From the step 1 deploy on, both session tokens and legacy requests use that canonical form, so data written earlier under another form (for example `263…`) is not visible to its owner until it is rewritten. Run the migration as soon as step 1 is live; the longer it waits, the more Cart and Wishlist conflicts appear.

From `backend/`, with `MONGO_URI` pointing at the production database:

1. `node scripts/migrate-canonical-userids.js` is a dry run. It writes nothing and prints, per collection, how many documents would be rewritten and how many conflicts would be skipped (counts only, never ids).
2. Review the counts.
3. `node scripts/migrate-canonical-userids.js --apply` performs the rewrites.

It covers `Cart.userId`, `Wishlist.userId`, `Order.user_id`, `ShippingAddress.userId`, `Post.authorUserId` and `Post.likedBy`. Cart and Wishlist hold one document per user: when a document already exists under the canonical id, the other one is not merged; it is counted as a conflict and left untouched for manual review. Running it again is safe.

## Open item: Afri Com must accept gRPC from the backend host

Reachability has been checked only from a development machine, not from the deployed host. From the deployed backend, run this with your own test account:

```
curl -i -X POST https://<BACKEND_HOST>/api/app-auth/session \
  -H 'Content-Type: application/json' \
  -d '{"username":"<PHONE>","password":"<PASSWORD>"}'
```

- `200` with `{token,user}`: Afri Com accepted the credentials and the backend can reach it. Done.
- `401` `Phone number or password is incorrect.`: Afri Com is reachable and rejected the credentials. Check the account; reachability is fine.
- `503` `Verification service unavailable. Try again shortly.`: the backend could not get an answer from Afri Com (network policy, firewall, wrong host or port, TLS setting). Ask Afri Com to allow the backend host's outbound IP and confirm the port and the `AFRICOM_GRPC_SECURE` setting. Do not proceed to step 4 until this returns 200 or 401.

## Known limitations

- Rate limits are in memory per process and reset on deploy. `POST /api/app-auth/session` allows 100 requests per 15 minutes per IP and 10 per 15 minutes per account (canonical phone number). Staff login and register share a separate 20 per 15 minutes per IP. Limits key on the client IP only when the proxy is trusted (see `TRUST_PROXY`).
- Stage 2: KYC enforcement requires `LEGACY_USERID_ROUTES=false`; legacy requests carry no verified identity (`req.auth.via === 'legacy'`), so any check that needs a proven user must reject them.
- Calls to Afri Com use plaintext on port 50000 unless `AFRICOM_GRPC_SECURE=true` is configured, so the phone number and password cross the network unencrypted. Confirm with Afri Com whether a TLS endpoint exists.
