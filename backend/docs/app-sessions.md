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
| `LEGACY_USERID_ROUTES` | `true` (exact string) allows tokenless requests to use the client-supplied user id | off |
| `ADMIN_USERNAME`, `ADMIN_PASSWORD` | Used only by `scripts/create-super-admin.js` | none |

## Rollout order

1. Deploy the backend with `LEGACY_USERID_ROUTES=true`. Security trade-off: while this is on, anyone can still act as any user by omitting the token and sending a user id, so the fix is not effective yet. Old app versions keep working only because of this flag. Keep this step short.
2. If no super_admin exists, run `ADMIN_USERNAME=... ADMIN_PASSWORD=... node scripts/create-super-admin.js` from `backend/`. Tell staff to log in again.
3. Ship the app update. It starts a session after OTP verification and after password login, and lazily on the first 401.
4. Once most active users are on the new app, set `LEGACY_USERID_ROUTES=false` (or remove it) and redeploy. Users still on old versions will get 401 until they update.

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

- The rate limiter `authLimiter` (20 requests per 15 minutes per IP) is shared by staff login, staff register and app sessions. Users behind one NAT, or heavy staff use, can exhaust it for each other.
- Calls to Afri Com use plaintext on port 50000 unless `AFRICOM_GRPC_SECURE=true` is configured, so the phone number and password cross the network unencrypted. Confirm with Afri Com whether a TLS endpoint exists.
