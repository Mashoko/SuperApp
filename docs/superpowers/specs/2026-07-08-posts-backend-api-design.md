# Posts Backend API — Design Spec

Date: 2026-07-08
Status: Approved, pending implementation plan

## Context

The user asked for a social layer on top of the Explore discovery hub (stories,
a post composer, and a mixed-media feed), modeled on a reference mockup
(`explore_social_feed_redesign.html`). That request bundles several
independent pieces (stories with 24h expiry; posts/feed/composer; "live" feel
polish — a new-post pill, optimistic engagement) that need separate specs.

The user chose to build **Posts + Feed + Composer first**, with Stories and
the "live" polish deferred to later rounds.

A codebase check found this app is **not** client-only — `backend/` contains a
working Node/Express + MongoDB (Mongoose) API, deployed on Render, already
serving the shopping features (products, cart, wishlist, orders, banners,
vouchers) that the Flutter app calls over plain HTTP. This spec covers the
**backend half** of Posts + Feed + Composer: the `Post` model and REST API.
The Flutter half (composer sheet, feed cards, pagination, wiring into
`ExploreTab`) is a separate spec that consumes this API once it exists — the
two are split because Flutter cannot be built against an API that doesn't
exist yet, and the two halves use entirely different tech stacks and test
tooling.

Key finding that shapes this spec: the backend's only existing upload route
(`POST /api/upload`) requires admin JWT auth (the shop-management login) —
the app's actual end users authenticate via OTP/phone entirely client-side
and are unrecognized by this backend's `auth` middleware. They're already
served by a **different, unauthenticated convention**: cart, wishlist, and
orders all accept a plain `userId` string in the request body/query, trusting
whatever `OtpAuthService.getStoredCredentials()`'s `username` value the
Flutter client sends. This spec's new routes follow that same convention,
not the admin-JWT one.

## Goals

- A `Post` model and REST API supporting 4 post types (photo, video, text,
  audio), each with optional caption, matching the existing Mongoose/Express
  conventions in this backend (flat routes in `index.js`, one file per model
  under `backend/models/`, `{items, totalPages, currentPage, totalItems}`
  pagination shape matching `/api/products`).
- Real per-user like/unlike (not a fire-and-forget counter) — a post tracks
  which `userId`s have liked it, so a client can render "already liked" state
  and toggle it.
- Media upload extended to accept video and audio, not just images, via a
  new unauthenticated (userId-scoped) route — the existing admin-only
  `/api/upload` is untouched.
- Comment count is stored but static (no comment-creation endpoint this
  round) — display-only, per the user's explicit choice.
- Share has no backend component at all — it's a native OS share sheet
  invoked entirely client-side (Flutter spec's concern, not this one).
- Real backend tests: Jest + Supertest + `mongodb-memory-server`, replacing
  the backend's current lack of any test tooling.

## Non-goals

- Stories — separate future spec.
- Real comment threads — `commentCount` defaults to 0 and nothing increments
  it yet; the Flutter side routes the comment icon to a placeholder.
- Real-time/push updates — pull-based pagination only, no websockets.
- Admin-panel/moderation tooling for posts (reporting, takedown review).
- Video/audio transcoding, thumbnail generation, or CDN — files are served
  as-is from the existing `/uploads` static path, same as images today.
- Any Flutter code — that's the follow-up spec.

## File structure

- Create: `backend/models/post.model.js` — the `Post` Mongoose schema.
- Modify: `backend/index.js` — add the 4 new routes and a second `multer`
  config for photo/video/audio uploads (the existing image-only `upload`
  instance, used by `/api/upload`, is untouched).
- Create: `backend/package.json` — add `jest`, `supertest`,
  `mongodb-memory-server` as devDependencies; change `"test"` script from the
  placeholder `echo` to `jest`.
- Create: `backend/tests/posts.test.js` (or similar — exact path decided in
  the implementation plan) — the Jest/Supertest suite, using
  `mongodb-memory-server` so no real database connection is needed.

## Data model

`backend/models/post.model.js`:

```js
const postSchema = new mongoose.Schema({
    type: {
        type: String,
        enum: ['photo', 'video', 'text', 'audio'],
        required: true,
    },
    caption: { type: String, required: false },
    mediaUrl: { type: String, required: false }, // absent for text posts
    audioTitle: { type: String, required: false }, // only meaningful for type: 'audio'
    durationSeconds: { type: Number, required: false }, // video/audio playback length
    authorUserId: { type: String, required: true },
    authorName: { type: String, required: true },
    likedBy: { type: [String], default: [] },
    commentCount: { type: Number, default: 0 },
    isDeleted: { type: Boolean, default: false },
}, { timestamps: true });
```

## Endpoints

All follow the existing flat-route style in `backend/index.js` (no separate
router/controller files — matching how products/cart/banners are already
structured). None require the `auth` (admin JWT) middleware — all trust a
client-supplied `authorUserId`/`userId`, exactly like `/api/cart/add`.

### `GET /api/posts?page=&limit=`
Paginated feed, newest first (`isDeleted: false`), same shape as
`/api/products`:
```json
{ "posts": [...], "totalPages": 3, "currentPage": 1, "totalPosts": 27 }
```

### `POST /api/posts`
Multipart form data: `type` (required), `caption` (optional), `authorUserId`
(required), `authorName` (required), `audioTitle` (optional, audio only),
`media` file field (required for photo/video/audio, absent for text).
Validates `type` is one of the 4 enum values; for non-text types, validates a
file was actually uploaded. Returns the created post (201).

### `POST /api/posts/:id/like`
Body: `{ "userId": "..." }`. Toggles `userId`'s membership in `likedBy`
(removes if present, adds if absent). Returns:
```json
{ "liked": true, "likeCount": 25 }
```
404 if the post doesn't exist or `isDeleted`.

### `DELETE /api/posts/:id`
Body: `{ "authorUserId": "..." }`. Sets `isDeleted: true` (soft delete,
matching `product.model.js`'s convention) only if `authorUserId` matches the
post's stored author; otherwise 403. 404 if the post doesn't exist.

## Media upload extension

A second `multer` instance (`backend/index.js`, alongside the existing
image-only `upload` used by `/api/upload` — that instance and its route are
untouched) with a combined `fileFilter`:

```js
const POST_MIME_LIMITS = {
  'image/jpeg': 5 * 1024 * 1024, 'image/png': 5 * 1024 * 1024,
  'image/webp': 5 * 1024 * 1024, 'image/gif': 5 * 1024 * 1024,
  'video/mp4': 50 * 1024 * 1024, 'video/quicktime': 50 * 1024 * 1024,
  'audio/mpeg': 15 * 1024 * 1024, 'audio/mp4': 15 * 1024 * 1024,
  'audio/wav': 15 * 1024 * 1024,
};
```
`fileFilter` rejects unlisted mime types; the effective size cap is the
largest value in the table (50MB) since `multer`'s `limits.fileSize` is a
single global ceiling per instance — a per-mime-type check happens in the
route handler after upload (reject and delete the file if its actual size
exceeds its type's specific limit from the table above). Same `uploads/`
disk storage and static serving as the existing upload path.

## Error handling

Matches the existing per-route `try/catch` → `res.status(4xx/5xx).json({message})`
style, no shared error middleware beyond the existing generic one at the
bottom of `index.js`. Missing required fields → 400. Unsupported/oversized
media → 400 (multer's rejection is caught and turned into a 400 response,
same pattern as the existing `/api/upload` route's error handling). Post not
found → 404. Delete by non-author → 403. No additional rate-limiting (the
existing `authLimiter` is scoped to `/api/auth/*` only, and these routes
follow the un-rate-limited convention already used by products/cart/wishlist).

## Testing

Jest + Supertest against the Express `app` directly (no real network calls),
backed by `mongodb-memory-server` (no connection to the real deployed
database, no risk to production data). Coverage:
- Creating each of the 4 post types (photo/video/text/audio), including the
  text-type case where no `media` file is sent.
- Rejecting post creation with a missing required field.
- Rejecting an unsupported mime type and an oversized file.
- Pagination correctness (`page`/`limit`/`totalPages`/`totalPosts` match
  expected values across multiple seeded posts).
- Like-toggle: like → unlike → like again, and `likeCount` reflects
  `likedBy.length` at each step.
- Soft-delete: succeeds when `authorUserId` matches, 403 when it doesn't,
  404 for a nonexistent post, and a deleted post no longer appears in
  `GET /api/posts`.

## Open items deferred to later specs

- Stories.
- The Flutter side of this feature (composer, feed cards, pagination UI,
  wiring into `ExploreTab`) — separate spec, built after this one.
- Real comment threads.
- The "live" feel polish (new-post pill, optimistic engagement increments,
  folding other content types into the feed as badged cards).
- Real-time/push infrastructure.
