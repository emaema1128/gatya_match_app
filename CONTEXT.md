# gatya_match_app

Flutter client for **bloom**, an existing production dating/matchmaking service. The client reuses bloom's backend (`route_api.php`) as-is by default; the user has deploy access to bloom's production backend, so backend changes are in scope where a specific effort decides they're needed (e.g. the auth-method-redesign map) — not a blanket rewrite.

## Language

**Account**:
The credentials + identity bloom issues at registration: a `system_id`, a server-assigned `login_id`/`password` (an auto-incrementing integer and a random string — not user-chosen, and bloom has no API to change either), and an `app_access_token`. Created via `registUser`, which also collects `sex`, region/prefecture/city, and a self-introduction comment — dating-relevant fields gathered at registration rather than deferred to Profile. Verified at login via `login`. Distinct from Profile — an Account can exist with no Profile data filled in yet.
_Avoid_: User (ambiguous with the Flutter-side widget/state layer), Member.

**Linked Identity**:
An external auth provider (LINE, Apple, Google) or a verified phone number connected to an Account, letting that provider authenticate the Account in place of — or alongside — its server-issued `login_id`/`password`. One Account may have several linked at once; each is a dedicated nullable column on the `user` row (`line_user_id`, `apple_user_id`, `google_sub`, verified phone number), not a separate table. If a login/registration call's identity matches an existing Linked Identity, it's a login (no device check); otherwise it's a new registration.
_Avoid_: Provider, social login (too generic — name the specific provider when possible).

**Profile**:
The dating-relevant data attached to an Account after registration — age, income, address, photos. (`getAgeList`/`getIncomeList`/`getAddressList` feed its editors, `updateProfile` saves it, `uploadProfileImg`/`deleteProfileImg` manage up to 3 photos.) Area, sex, and self-introduction are collected at Registration instead — see Account. Out of scope for Stage 1 (Account only); built out by Stage 2.
_Avoid_: User data, account data.

**Registration**:
Creating a new Account via `registUser`. Canonical English term for Stage 1 code/screens (e.g. `RegistrationScreen`).
_Avoid_: Sign up, enrollment, create account — pick Registration everywhere for consistency.

**Login**:
Authenticating an existing Account via `login`, recovering its `app_access_token`.
_Avoid_: Sign in.

**Session**:
The local, persisted proof that an Account is logged in on this device — an `app_access_token` paired with the `system_id` it was issued to, held by `TokenStorage` and reflected in `AuthState`. Also holds the Account's server-issued `login_id`/`password` purely as an internal recovery credential: if `app_access_token` is found invalid at app boot, the app silently retries via `login` before giving up. Ends (falls back to Unauthenticated) only if that recovery also fails, or on logout.
_Avoid_: Token (alone, when the pairing with `system_id` matters), credentials.

**Match**:
Two Accounts mutually Liking each other, via bloom's existing `sendLike`/`getMatchList`. Surfaced on Home's Gacha (mutual Like on the spot) and, once matched, in the Matches tab and the Match celebration screen (stage4-match-celebration map). Only the synchronous case — matching as a direct result of the current Account's own action — is covered so far: bloom has no notification path for the asynchronous case (the other party Liking back later while this Account is away), since `Notification::sendTypeLikeOrMatch`/`KEY_MATCH` is wired only into the supporter/staff-character automation system (`Class_Action.php`), not real Accounts' `sendLike`. Wiring that is left to a future push-notification effort.
Both the Matches tab's two segments (received Likes and Matches) and the Match celebration screen share one card widget, `MatchProfileCard`; tapping it opens `ProfileDetailsSheet` (photo gallery + age/address/income + full bio) in place, no navigation — the same sheet `GachaRevealScreen` already used, generalized into a shared widget (gacha-redesign/issues/07). Free to view; no `PayCost` category is charged from the mobile API for this.
_Avoid_: Mutual like (name the outcome, Match, not the mechanism).

**Gacha**:
The point-costing draw on Home that surfaces up to three dating candidates at a time (`GachaApi::SPIN_DRAW_COUNT`; fewer if the pool is thin — see below). Implemented (stage3-gacha-home decided the original single-candidate version, stage3-gacha-implementation built it, gacha-redesign map extended it to three): bloom endpoint `spinGacha` (`GachaApi::spin`) and Flutter's `GachaScreen` (center-tap button → capsule-machine reveal animation, `assets/images/gacha_machine.png`/`gacha_capsule.png`) → `GachaRevealScreen` (a full-screen swipeable card per candidate, tap for a photo-gallery/profile detail sheet, swipe up to Like). Not a bloom-native concept originally — it's a new spending model on a wallet basis (bloom has no stamina/daily-quota precedent), via a new `PayCost::GACHA_SPIN` category charged through the existing `Point::checkBalanceFree`/`usePointFree` (no `pay_cost` schema change) — one spin still costs a single `SPIN_COST`, regardless of how many candidates it surfaces. Revealing candidates doesn't send a Like — that's a separate, unpaid action via bloom's existing `sendLike`, capped at one Like per spin (`GachaRevealScreen` closes after the first Like, matched or not); a mutual Like routes to the Match celebration screen. Already-Liked/Matched candidates are permanently excluded from the draw; Seen-but-unliked candidates are excluded for a cooldown period, then re-enter the pool as a "recycled" pick (flagged per-candidate via `MatchData.isRecycled`, an on-screen disclosure on that candidate's card) with a `PayCost::SERVICE_POINT` bonus rather than an empty state. "Seen" isn't tracked in a dedicated table — it's derived from `point_log` (every spin's mandatory `pay_category = GACHA_SPIN` audit row already records who/when), reusing an existing side effect instead of a new schema. Duplicate picks within the same spin are prevented by excluding already-drawn candidates as the backend fills the three slots.
_Avoid_: Draw, Roll (use Gacha/Spin, the terms this project settled on), Search (Gacha's candidate query is bloom's own new SQL in `GachaApi`, not a rename of the existing `search`/`getUserList` browsing feature, even though the filtering logic is similar).

**Talk**:
A 1:1 message thread with a Match. Implemented as-is on top of bloom's existing Mail feature (`getMailListForMatching`/`getMailLog`/`sendMail`/`sendImgMail`/`sendAudioMail`) — no backend changes (stage5-chat map). Continues bloom's existing per-message billing (`Point::usePointMail` via `PayCost::SEND_MAIL`/`SEND_PHOTO`/`SEND_AUDIO`) rather than making Matches message for free. Flutter's `ChatTabScreen` (the talk list, `TalkListController`) and `ChatThreadScreen` (one thread, `ChatThreadController`, a family provider keyed by the partner's `system_id`). The thread screen polls `getMailLog` on a timer while open — bloom has no realtime push for messages, and building one is Stage6's concern, not this map's — and shows the point balance (extending Stage3's gacha-only balance display to this screen too). Image (`sendImgMail`) and voice (`sendAudioMail`, via the new `record`/`audioplayers` packages) messages are both supported: a received image/voice message stays gated (blurred placeholder / a locked play button) until tapped, which calls `lookImgMail`/`playAudioMail` to charge (bloom charges per `mail_id` only on the first open/play, tracked server-side in a table `getMailLog` never surfaces — so the client's own "already unlocked" memory only lasts as long as the thread stays open, not confirmed-free reopens across sessions, though no double charge either way).
_Avoid_: Mail (bloom's backend/DB term — keep it at the API call site, e.g. `sendMail`, not as a product-facing name), Conversation.
