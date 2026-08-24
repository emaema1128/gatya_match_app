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
