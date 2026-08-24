Type: research (findings)
Answers: [issues/03-line-login-mobile-api-feasibility.md](../issues/03-line-login-mobile-api-feasibility.md)

# LINE Login as a mobile JSON API — feasibility research

## Bottom line

Adding LINE Login to the Flutter app as a `route_api.php` JSON endpoint is feasible and requires **no changes to the existing web LINE Login channel configuration** (same `channel_id`/`channel_secret` already in `LINE_CONFIG['line_login']`, just extra "App settings" in the LINE Developers Console). The recommended shape:

- **Flutter side**: use LINE's official `flutter_line_sdk` (native app-switch login), not a hand-rolled WebView OAuth2 flow — LINE's own docs explicitly discourage the latter for native apps (see §2).
- **bloom side**: about half of `Class_Line.php`'s LINE-communication code is directly reusable (the cURL wrapper and the access-token/ID-token verification + profile-fetch logic). The other half (`getRedirectUrl()`, `getLineLoginURL()`, the `line/*.php` controller scripts) is web-redirect/`$_SESSION`-specific and does not apply to the native-SDK flow at all — the new mobile flow needs a new, small `execute_function` that mirrors the existing `registUser`/`login` request/response shape rather than the existing `line/login.php`/`line/regist.php` page-rendering flow.
- **No LINE review/approval is required** to use LINE Login in production; publishing a channel is a self-service, one-way console toggle. Apply-for-email-permission is the one thing LINE does gate behind an application form, and bloom's channel already appears to have it (the existing web flow already requests `scope=...email`).

---

## 1. What bloom already has, and how much of it is reusable

### 1.1 The `Line` class in one picture

`/Users/daichi/Documents/blooom関係/dream/Class_Line.php` is a static-method "God class" for everything LINE-related: LINE Login OAuth2, LINE Notify, the Messaging API (push messages, rich menus), and friend-status bookkeeping. Only a slice of it is relevant to login.

Constants relevant to login, `Class_Line.php:16-19`:
```php
const GENERATE_ACCESS_TOKEN = 1;
const ACCESS_TOKEN_VALIDITY_VERIFICATION = 2;
const GET_USER_PROFILE = 3;
const ID_TOKEN_VALIDITY_VERIFICATION = 4;
```

Each constant is a "request type" fed into three lookup methods that build a cURL request, and one generic executor:

- `Line::getHttpRequest($request_type, $param)` — `Class_Line.php:219-271` — maps a request type to a LINE endpoint URL. For login: `GENERATE_ACCESS_TOKEN` → `https://api.line.me/oauth2/v2.1/token` (`:222`); `ACCESS_TOKEN_VALIDITY_VERIFICATION` → `https://api.line.me/oauth2/v2.1/verify?access_token=...` (`:226`); `GET_USER_PROFILE` → `https://api.line.me/v2/profile` (`:229`); `ID_TOKEN_VALIDITY_VERIFICATION` → `https://api.line.me/oauth2/v2.1/verify` (`:232`, POST body variant).
- `Line::getRequestHeader($request_type, $param)` — `Class_Line.php:273-322`.
- `Line::getRequestBody($request_type, $param)` — `Class_Line.php:324-401`. The `GENERATE_ACCESS_TOKEN` body (`:326-334`) embeds `LINE_CONFIG['line_login']['channel_id']` and `channel_secret` and calls `self::getRedirectUrl(...)` for `redirect_uri` — this is the one login-related body that is *not* reusable unmodified (see 1.3).
- `Line::httpRequest($request_type, $http_request_param)` — `Class_Line.php:87-201` — the generic cURL executor: builds the request from the three lookups above, executes it, logs it (`createLog`/`addAccessLog`/`addErrorLog`), and interprets success/failure per request type (`:164-198`). **This method has no `$_SESSION` dependency in its core logic** (its only session touch is indirect, through `getUserForLog()` for the log line, `:136-151` and `:660-675` — see 1.2).
- `Line::accessTokenValidityVerification($access_token)` — `Class_Line.php:426-457` — calls `httpRequest(ACCESS_TOKEN_VALIDITY_VERIFICATION, ...)` and additionally checks `client_id` matches `LINE_CONFIG['line_login']['channel_id']` (`:442`) and `expires_in > 0` (`:449`). This is exactly the server-side check LINE's own docs recommend (see §3/§5) and is directly reusable.

**Verdict: reusable as-is, regardless of which mobile flow is chosen** — `httpRequest()`, `getHttpRequest()`/`getRequestHeader()`/`getRequestBody()` for the three verification/lookup request types (`ACCESS_TOKEN_VALIDITY_VERIFICATION`, `GET_USER_PROFILE`, `ID_TOKEN_VALIDITY_VERIFICATION`), and `accessTokenValidityVerification()`. These are the calls a new mobile `execute_function` needs to verify a token the app already obtained and fetch the LINE profile — nothing here reads `$_SESSION` or does a server-side redirect.

### 1.2 What's `$_SESSION`/redirect-specific and not reusable for a JSON API

- `Line::getRedirectUrl($action)` — `Class_Line.php:62-85` — builds a redirect URL from `$_SERVER["HTTP_HOST"]` and a hardcoded path (`/line/login`, `/line/regist`, `/line/line_login/regist`, `/line/line_notify/regist`). This exists to satisfy LINE's requirement that `redirect_uri` in the token-exchange call match the one used in the authorize call — a concept that **only applies to the code-exchange OAuth2 flow**, not to the native-SDK flow (see 1.3).
- `Line::getLineLoginURL($action, $adcode, $target_url)` — `Class_Line.php:532-579` — builds the `https://access.line.me/oauth2/v2.1/authorize?...` URL, including a `state` parameter that packs `camo_adcode_id`/`target_url` via `base64urlEncode(json_encode(...))` (`:544-561`). This is the "start a web login" entry point; irrelevant if the app performs login via the native SDK (LINE's own SDK builds and opens this URL internally).
- `Line::getUserForLog()` — `Class_Line.php:660-675` — reads `$_SESSION['systemid']` for log labeling. Harmless if left as-is in a JSON API context (no session is started by `route_api.php`, so this just resolves to "user: unknown" or falls back to `$_SERVER['REMOTE_ADDR']`), but a new mobile flow should pass `system_id` explicitly into log calls for useful logs rather than relying on this.
- The three page-controller scripts under `line/`:
  - `line/login.php` — full read: reads `$_GET['code']`/`$_GET['state']`, decodes `state` for ad-code, calls `Line::httpRequest(GENERATE_ACCESS_TOKEN, ...)` then `GET_USER_PROFILE`, looks up the account via `Line::isExistsLineUserId()`, then calls `Common::verificationAfterLoginProcess($system_id)` (sets `$_SESSION['systemid']`, regenerates session ID) and does `header('Location: ...')` (`login.php:117,125`). 100% web-flow-shaped; not reusable as a function, only as a reference for *what checks to perform* in the new `execute_function`.
  - `line/regist.php` — same shape for new-user registration via LINE, ending in `User::tempRegist(...)` (`regist.php:141`) and Smarty template rendering (`:190-206`).
  - `line/line_login/regist.php` — the *account-linking* flow (link an existing logged-in web user's `system_id` to a LINE user ID), driven by `$_SESSION['systemid']` or a Redis-backed camouflage token (`:22-34`). Notably, its CSRF `state` check is **commented out** in the current source (`line/line_login/regist.php:47-52`) — worth knowing when using this file as a design reference, but out of scope to fix here.
- `Class_LineLinkAccount.php` (`registLineUserId()`, `:88-110`) — a Redis-token-based account-linking helper invoked from `line/link_account.php`, itself session-gated (`Common::getSystemId()` from a cookie session, `line/link_account.php:10-15`). Not reusable for the mobile JSON API's own auth handshake, though its underlying DB write (`Line::setLineUserID`) is (see 1.4).

### 1.3 Reusability depends on which Flutter option you pick — this is the key branch

**If the Flutter app uses the native `flutter_line_sdk` (recommended, see §2):** the SDK performs the entire OAuth2 code exchange *inside the native LINE SDK*, using LINE's own app-switch flow. The Flutter app never sees an authorization `code`, and bloom's server never needs to call the token endpoint. This means:
- `Line::GENERATE_ACCESS_TOKEN` / `getRedirectUrl()` / `getLineLoginURL()` are **not used at all** by the new mobile flow. `LINE_CONFIG['line_login']['channel_secret']` never needs to leave the server, and in fact never needs to touch this new code path either.
- Only `ACCESS_TOKEN_VALIDITY_VERIFICATION`, `GET_USER_PROFILE`, and `ID_TOKEN_VALIDITY_VERIFICATION` (i.e. `Line::accessTokenValidityVerification()` + two `httpRequest()` calls) are needed — this is a small, already-battle-tested surface.

**If instead you hand-roll a WebView-based OAuth2 flow:** the app opens `https://access.line.me/oauth2/v2.1/authorize?...` in a WebView, intercepts the redirect containing `code`, and must send that `code` to bloom's server (never exchange it client-side, since that would require embedding `channel_secret` in the app binary). In that case `Line::GENERATE_ACCESS_TOKEN` *is* reusable, but `getRedirectUrl()`/`getLineLoginURL()` need a new `$action` case that isn't built from `$_SERVER["HTTP_HOST"]` (a mobile redirect URI is typically a fixed HTTPS "bridge" URL or a registered custom scheme, not the requesting host), and the `state` CSRF check needs to be re-implemented without `$_SESSION` (e.g., server-issued short-lived nonce keyed by device, similar to the existing Redis-token pattern in `getDeliveryLineLoginURL()`, `Class_Line.php:605-626`, or `LineLinkAccount::generateURL()`, `Class_LineLinkAccount.php:69-83`).

Given LINE's own guidance against this second path for native apps (§2), the first branch is the one worth designing for.

### 1.4 Existing DB linkage this can reuse

- `user.line_user_id`, `user.linked_to_line_login_flag`, `user.line_regist_flag` columns (`mysqldump/dream.sql:4346` `CREATE TABLE user`, columns listed there) — set by `User::setLineUserId()` (`Class_User.php:695-705`) and `User::setLinkedToLineLoginFlag()` (`Class_User.php:684-693`). These are simple, denormalized "is this account LINE-linked" fields on `user`.
- `line_account_user_info` table (`system_id`, `line_user_id`, `account_id`, `friend_flag` — no unique constraint, just a `KEY` on `system_id`; schema at `mysqldump/dream.sql`) is where the *actual* login lookup happens: `Line::isExistsLineUserId($line_user_id, $account_id)` (`Class_Line.php:1052-1065`) and `Line::getSystemIdByLineUserId($line_user_id, $account_id)` (`Class_Line.php:1089-1102`) both query this table, and `line/login.php:91-104` uses exactly this to authenticate returning users. `account_id` here references a row in `line_account` (`Line::getLinkLineAccount()`, `Class_Line.php:872-881`, filtered by `link_flag = 1`; or `Line::getMainAccountData()`, `:859-870`, filtered by `account_type = ACCOUNT_TYPE_MAIN`).

  **Important distinction**: `line_account.account_id` rows are LINE **Official Accounts** used for the Messaging API/LINE Notify push-notification side of the app (each has its own `channel_id`/`channel_secret`/`channel_access_token`, `mysqldump/dream.sql` `CREATE TABLE line_account`) — a *different* "channel" from the single LINE **Login** channel in `LINE_CONFIG['line_login']`. bloom's existing login-lookup piggybacks on the official-account-linkage table rather than using `user.line_user_id` directly as the lookup key. This is a pre-existing modeling quirk (not something introduced by going mobile), and is worth flagging for [06-account-linking-model](../issues/06-account-linking-model.md), which is the ticket that should decide whether the mobile flow keeps reusing `line_account_user_info` as-is, switches to a direct `user.line_user_id` lookup, or introduces a dedicated identity table. See §4 for the concrete options.

---

## 2. Flutter-side implementation options

### Option A — `flutter_line_sdk` (official, native app-switch) — recommended

- Package: [`flutter_line_sdk` on pub.dev](https://pub.dev/packages/flutter_line_sdk), published by LINE (verified publisher `developers.line.biz`), Apache-2.0. Source: [github.com/line/flutter_line_sdk](https://github.com/line/flutter_line_sdk).
- It wraps LINE's native iOS Swift SDK and Android SDK; there is **no Flutter-web support** (not relevant here since the target is iOS+Android only).
- Requirements per the package's own README (`github.com/line/flutter_line_sdk`, `README.md`, fetched verbatim): Flutter 3.44+ (or the 2.x line for older Flutter), **iOS 15.0+ deployment target**, **Android `minSdkVersion` 24+** (Android 7.0+), and "[LINE Login channel linked to your app](https://developers.line.biz/en/docs/line-login/getting-started/)".
- Setup is entirely additive to bloom's **existing** LINE Login channel — no new channel needed. Per the SDK's README: *"To access your LINE Login channel from a mobile platform, you need some extra configuration. In the LINE Developers console, go to your LINE Login channel settings, and enter the below information on the App settings tab."* This is corroborated by the native iOS SDK docs: *"Linking your app to a LINE Login channel requires some configuration. On the LINE Developers Console, go to your LINE Login channel settings and complete the following fields on the LINE Login tab"* ([Setting up your project — LINE SDK for iOS Swift](https://developers.line.biz/en/docs/line-login-sdks/ios-sdk/swift/setting-up-project/#linking-app-to-channel)), and the Android docs: *"Linking your app to a LINE Login channel, enable **Mobile app** on the **LINE Login** tab of your channel settings"* ([Integrating LINE Login with your Android app](https://developers.line.biz/en/docs/line-login-sdks/android-sdk/integrate-line-login/)). So bloom's existing `LINE_CONFIG['line_login']['channel_id']`/`channel_secret` stay unchanged; you toggle "Mobile app" on and fill in bundle ID / package name in the console (see §5 for the exact fields).
- Dart usage (from the package README, quoted verbatim):
  ```dart
  void main() {
    WidgetsFlutterBinding.ensureInitialized();
    LineSDK.instance.setup("${your_channel_id}").then((_) {
      print("LineSDK Prepared");
    });
    runApp(App());
  }
  ```
  ```dart
  final result = await LineSDK.instance.login(scopes: ["profile", "openid", "email"]);
  // result.accessToken.value      -> access token string
  // result.accessToken.idTokenRaw -> raw JWT ID token string
  // result.accessToken.email      -> email, if idToken valid and "email" scope granted
  // result.userProfile?.userId / displayName / pictureUrl
  ```
  `AccessToken.idTokenRaw` (raw JWT) and `AccessToken.value` (access token) are exactly the two values bloom's server needs to receive and verify (see §3). Confirmed via the package's own API docs: [`AccessToken` class](https://pub.dev/documentation/flutter_line_sdk/latest/flutter_line_sdk/AccessToken-class.html).
- Trade-offs:
  - **Pro**: matches LINE's own explicit guidance for native apps (see below); handles app-switch to the LINE app (or its own in-app browser fallback when LINE isn't installed) entirely inside the SDK; manages token refresh; the `channel_secret` never has to exist on the client or in this new code path at all.
  - **Con**: adds a native dependency with iOS/Android minimum-version floors (iOS 15 / Android 7) and Xcode/Gradle configuration (Info.plist URL scheme, `minSdk` bump) — see §5. Requires per-platform console configuration (bundle ID, package name + signature).

### Option B — Hand-rolled WebView OAuth2 (authorization code flow)

- The app would open a `WKWebView`/`WebView` (e.g. via `webview_flutter` or `flutter_web_auth_2`) pointed at `https://access.line.me/oauth2/v2.1/authorize?...`, intercept the redirect back to a registered callback, extract `code`, and send it to the server for exchange.
- LINE's own documentation for the web-app OAuth2 flow **explicitly discourages this for native/mobile apps**. From [Integrating LINE Login with your web app](https://developers.line.biz/en/docs/line-login/integrate-line-login/) (quoted verbatim): *"We strongly recommend building your LINE Login integration with a LINE SDK if it's available for your development environment. **We don't recommend using the procedure described in this page for native apps.**"*
- Trade-offs if pursued anyway:
  - **Con**: loses LINE's native app-switch UX (no "already logged in to LINE app → instant login" auto-login — that's only reliably available through app-to-app switching, which a generic WebView doesn't get); loses built-in token refresh/secure storage; you must design your own CSRF (`state`) handling without `$_SESSION` server-side (bloom's existing pattern for this in a stateless context is the Redis-camouflage-token trick used elsewhere in `Class_Line.php`/`Class_LineLinkAccount.php`, §1.3); you must add a new server-side code-exchange endpoint (reusing `Line::GENERATE_ACCESS_TOKEN`, but with a new non-host-based `redirect_uri`).
  - **Pro**: no native SDK dependency, no Xcode/Gradle minimum-version bump — but this is a weak upside given the doc guidance above.

### Recommendation

Use `flutter_line_sdk`. It's the officially blessed path, keeps `channel_secret` off the client and out of this feature entirely, and the existing channel/config can be reused without changes other than console "App settings."

---

## 3. Sketch: passing the token to bloom and verifying it server-side

LINE has a dedicated design doc for exactly this scenario — native app + backend server — [Creating a secure login process between your app and server](https://developers.line.biz/en/docs/line-login/secure-login-process/). Key points, quoted/paraphrased from that page:

- ❌ Do not have the client send raw profile info or channel IDs to the server and trust them ("vulnerable to spoofing").
- ✅ The client sends **access token** and **ID token** to the server; *"these tokens enable your server to get reliable information directly from the LINE Platform."*
- Server-side, after verifying the access token: *"Make sure that these properties satisfy the following criteria before you use the access token: `client_id` — Same as the channel ID of the LINE Login channel linked to the native app; `expires_in` — Positive value."* — this is precisely what `Line::accessTokenValidityVerification()` already checks (`Class_Line.php:442,449`).
- For the ID token: verify via `POST https://api.line.me/oauth2/v2.1/verify` with `id_token` + `client_id` (LINE Login API reference: [Verify ID token](https://developers.line.biz/en/reference/line-login/#verify-id-token)), which returns the decoded claims (`sub` = LINE user ID, `email`, `name`, `picture`, ...) only if signature/`aud`/`exp` check out server-side. This is exactly `Line::httpRequest(Line::ID_TOKEN_VALIDITY_VERIFICATION, ...)`.

### Sketch of the new `execute_function`

Following the existing shape of `registUser`/`login`/`existsDeviceId` in `route_api.php:62-66,412-429`, and `UserApi::registUser()`/`UserApi::login()` in `app/api/Class_UserApi.php:22-79` (which generates `app_access_token` via `UserApi::generateToken()`, `:18-20`, and returns `User::getUserData($system_id, 'str')`, which includes `app_access_token`, `line_user_id`, `linked_to_line_login_flag` — all of `user.*`, per `Class_User.php:46-90`):

```php
// route_api.php — new case, alongside the existing 'login'/'registUser' cases
case 'lineLogin':
  // post_data: { line_access_token, line_id_token, device_id, device_type, adjust_id,
  //              fcm_device_token, sex?, region?, prefecture?, city?, comment?, adcode? }
  $line_login_result = UserApi::lineLogin($post_data);
  if ($line_login_result === false) {
    $return_data = json_encode(['result' => '2', 'error_detail' => 'LINE login verification failed']);
  } else {
    $system_id = $line_login_result['system_id'];
    $return_data = json_encode(['result' => '1', 'data' => ['user_data' => $line_login_result]]);
  }
  break;
```

```php
// app/api/Class_UserApi.php — new method (sketch, illustrative only)
public static function lineLogin($post_data) {
  // 1. Verify the access token belongs to *this* channel and isn't expired.
  //    Reuses Line::accessTokenValidityVerification() unmodified (Class_Line.php:426-457).
  if (!Line::accessTokenValidityVerification($post_data['line_access_token'])) {
    return false;
  }

  // 2. Get the LINE profile via the access token (reuses Line::GET_USER_PROFILE).
  $profile = Line::httpRequest(Line::GET_USER_PROFILE, [
    'request_header' => ['access_token' => $post_data['line_access_token']],
  ]);
  if (!$profile) { return false; }
  $line_user_id = $profile['userId'];

  // 3. Verify the ID token server-side and cross-check its `sub` matches the profile's userId
  //    (reuses Line::ID_TOKEN_VALIDITY_VERIFICATION).
  $id_token_claims = Line::httpRequest(Line::ID_TOKEN_VALIDITY_VERIFICATION, [
    'request_body' => ['id_token' => $post_data['line_id_token'], 'user_id' => $line_user_id],
  ]);
  if (!$id_token_claims || $id_token_claims['sub'] !== $line_user_id) { return false; }

  // 4. Look up an existing account by line_user_id (see §4 for which table/column),
  //    or register a new one (device-id dedup, temp-regist, etc., mirroring
  //    UserApi::registUser()/User::tempRegist()).
  $system_id = /* existing-user lookup, or new User::tempRegist(...) */;

  // 5. Mint/refresh this device's app_access_token, same as UserApi::registUser() does today.
  // 6. Return User::getUserData($system_id, 'str') so the client gets the same
  //    { system_id, app_access_token, ... } shape as 'login'/'registUser'.
}
```

Notes on this sketch:
- `line_access_token` / `line_id_token` are exactly `AccessToken.value` / `AccessToken.idTokenRaw` from `flutter_line_sdk` (§2).
- Steps 1–3 need no rewriting of `Class_Line.php` — they call existing public static methods.
- Step 3's `user_id` cross-check mirrors the pattern already used in `line/line_login/regist.php:90-91` and `line/regist.php:109-110` (both pass `user_id => $line_user_id` into `ID_TOKEN_VALIDITY_VERIFICATION`).
- This single `execute_function` doubles as both "login" and "register" (LINE tells you unambiguously via `sub`/`userId` whether this is a known `line_user_id`), matching how `registUser` currently needs profile fields (`sex`, `region`, etc. — `route_api.php:62-66`) that a first-time LINE signup would still need to collect from the user in the app (LINE Login profile scope doesn't give bloom's required `sex`/`region`/`prefecture`/`city`/`comment` fields — that's a [stage2-profile-creation](../../stage2-profile-creation/map.md)/[07-registration-login-ux-flow](../issues/07-registration-login-ux-flow.md) concern, not addressed further here).
- `route_api.php`'s existing top-level gate (`route_api.php:22-37`) requires `post_data['system_id']` to be present and either `-1` (pre-registration) or a valid `app_access_token` bearer header. A first-time `lineLogin` call (no bloom account yet) would go through the same `system_id = -1` bypass `registUser` already relies on: the Flutter client's `BloomApiClient.callApi()` defaults `system_id` to `-1` whenever no token is stored yet (`lib/core/network/bloom_api_client.dart:38`, `readSystemId() ?? -1`) — a new `lineLogin` call site would inherit this for free, no special-casing needed on the client.

---

## 4. Linking a LINE user ID to `system_id` — options

bloom already has a working (if slightly indirect) mechanism; the question for the mobile flow is whether to reuse it as-is or clean it up. This is squarely [06-account-linking-model](../issues/06-account-linking-model.md)'s call, not this ticket's — options laid out here for that decision:

1. **Reuse `line_account_user_info` as-is** (least new code): call `Line::isExistsLineUserId($line_user_id, $account_id)` (`Class_Line.php:1052-1065`) to look up an existing account, `Line::setLineUserID($system_id, $line_user_id, $account_id)` (`Class_Line.php:1067-1087`) to link a new one — exactly what `line/regist.php:150` and `line/line_login/regist.php:117` already do. Requires picking an `$account_id` (currently resolved via `Line::getLinkLineAccount()`, the `line_account` row with `link_flag = 1`, `Class_Line.php:872-881`). Downside: conflates LINE-Login identity with LINE-Official-Account/Messaging-API friend bookkeeping (§1.4); table has no unique constraint on `(line_user_id, account_id)`, so duplicate-prevention is purely application-level (the `isExistsLineUserId` check before insert — a TOCTOU race is theoretically possible under concurrent requests).
2. **Use `user.line_user_id` directly** (simpler mental model): query/update the `user` table's own `line_user_id` column (already populated redundantly today via `User::setLineUserId()`, `Class_User.php:695-705`) as the canonical lookup for mobile login, bypassing `line_account_user_info` entirely. Would need a new indexed lookup (`SELECT system_id FROM user WHERE line_user_id = :line_user_id`) and, ideally, a `UNIQUE` constraint added to that column — a schema change. Diverges from how the web flow currently authenticates (`line/login.php` uses `line_account_user_info`), so the two flows would use different sources of truth for "is this LINE user already registered" unless the web flow is also migrated.
3. **New dedicated external-identity table** (e.g. `external_identity(system_id, provider, provider_user_id)`), covering LINE now and Apple/Google/phone from sibling tickets 01/02/04 uniformly. Cleanest long-term, but is exactly the kind of decision [06-account-linking-model](../issues/06-account-linking-model.md) exists to make across all four providers at once — doing it here for LINE alone would preempt that ticket.

Whichever is chosen, the LINE user ID itself (`sub` in the ID token / `userId` from `GET /v2/profile`) is **stable per LINE Developers *provider*, not per channel**: *"A LINE user who uses services provided by developers is given a different user ID for each provider. User IDs can't be used to identify the same user across channels under different providers."* ([Getting started with LINE Login — Precautions for channel and provider linkage](https://developers.line.biz/en/docs/line-login/getting-started/#step-1-create-channel)). Practically: as long as the mobile app's LINE Login channel is the *same* channel (or, at minimum, a channel under the *same provider*) as bloom's existing web LINE Login channel, a user who is already linked via the web flow will present the identical `line_user_id` from the mobile app — no separate reconciliation needed. (§5 covers why it should in fact be the same channel.)

---

## 5. Known pitfalls / configuration checklist

- **No LINE staff review is required to go live.** A LINE Login channel starts in "Developing" status (only Admin/Tester console roles can use it) and is switched to "Published" via a single console toggle — no application/approval step. *"To make your app available to broader users, you must change the channel status to Published... once you change the status to 'Published', you can't change it back to 'Developing'"* ([Getting started with LINE Login — Step 6](https://developers.line.biz/en/docs/line-login/getting-started/#step-6-publish-your-channel-optional)). Treat "Publish" as a one-way door — verify mobile app-switch login works end-to-end (real device, not simulator per LINE's universal-link caveat below) before flipping it.
- **Email scope *is* gated behind an application form**, separate from Publish status: *"Before you can specify the email scope... you must first submit an application requesting access to users' email addresses"* — done once in the console (Basic settings → OpenID Connect → Apply, with a screenshot of the consent UI) ([Integrating LINE Login with your web app](https://developers.line.biz/en/docs/line-login/integrate-line-login/#applying-for-email-permission)). Since bloom's existing web flow already requests `scope=profile%20openid%20email` (`Class_Line.php:569`), this channel almost certainly already has that permission — worth confirming in the console rather than assuming, since if it's missing the `email` claim silently won't appear rather than erroring.
- **Reuse the existing channel — don't create a new one — unless there's a reason not to.** Per §2/§4, adding mobile support is done by enabling **Mobile app** and filling in bundle ID / package name on the *same* `LINE_CONFIG['line_login']` channel, in the **LINE Login** tab of channel settings. Required fields: iOS bundle ID, Android package name; optional but recommended: iOS **universal link**, Android **package signature**(s) and/or custom **URL scheme** ([iOS setup](https://developers.line.biz/en/docs/line-login-sdks/ios-sdk/swift/setting-up-project/#linking-app-to-channel), [Android setup](https://developers.line.biz/en/docs/line-login-sdks/android-sdk/integrate-line-login/#link-app-to-channel)).
- **iOS Universal Link setup is nontrivial and device-only to test.** It requires an `apple-app-site-association` file hosted on an HTTPS domain bloom controls (with the app's Team ID + bundle ID and a path like `/line-auth/*`), an Associated Domains entitlement in the Xcode project, registering the same URL in the LINE console, and passing it to `LoginManager.setup(channelID:universalLinkURL:)` — and LINE's own docs note *"you can test universal links only on a real iOS device"* ([Using universal links](https://developers.line.biz/en/docs/line-login-sdks/ios-sdk/swift/universal-links-support/)). It's **optional** — if skipped, LINE "falls back to a URL based on your iOS bundle ID" (the custom-scheme mechanism `flutter_line_sdk`'s README already wires up via `Info.plist`'s `line3rdp.$(PRODUCT_BUNDLE_IDENTIFIER)` scheme) — so it's reasonable to ship without it first and add it later for the extra phishing-resistance it buys.
- **Xcode/Gradle floors.** `flutter_line_sdk` needs iOS deployment target 15.0+ and Android `minSdkVersion` 24+ (README, `github.com/line/flutter_line_sdk`). Confirm these don't regress the app's current minimums before adopting.
- **Android package signature.** LINE recommends registering both the debug and release SHA-1 signatures in the console (`keytool -exportcert ... | openssl sha1`) — easy to forget the release signature until the first TestFlight/Play internal-track build fails to app-switch.
- **`client_secret` must never reach the client.** With the native-SDK flow this is moot (§1.3) — but worth stating as the reason *not* to fall back to a client-side WebView code-exchange under time pressure.
- **CSRF/`state` handling is irrelevant for the native SDK flow** (no browser redirect the app has to defend), but if Option B (WebView) is ever revisited, note that the existing `line/line_login/regist.php` reference implementation has its `state` check commented out (`line/line_login/regist.php:47-52`) and `line/login.php`'s `state` is never compared against a server-stored value at all — neither is a safe template to copy as-is.
- **`Line::httpRequest()`'s access-token verification treats a wrong `client_id` as failure** (`Class_Line.php:442-447`), which is exactly the protection against a token minted for a *different* LINE Login channel being replayed against bloom — keep this check in the new `execute_function` even though it's already inside `accessTokenValidityVerification()`.
- **LINE's own payload-shape disclaimer**: *"New or changed LINE Login functions may cause changes in the structure of the payload JSON object... Design your backend so that it can handle payload data objects with unexpected structures"* ([Integrating LINE Login with your web app — response note](https://developers.line.biz/en/docs/line-login/integrate-line-login/#get-access-token)) — worth keeping in mind since `Line::httpRequest()`'s error-detection logic (`Class_Line.php:164-198`) branches on exact response shape per request type.
- **`app_access_token` reissuance semantics aren't addressed by this research.** Today `registUser` mints a fresh `app_access_token` once at registration (`UserApi::registUser()`, `app/api/Class_UserApi.php:38`); `login` (password-based) does not mint or return a new one (`UserApi::login()`, `:58-79`) even though the Flutter client's `_completeSession()` expects `user_data['app_access_token']` on every login/register response (`lib/core/auth/auth_controller.dart:89-108`) — the new `lineLogin` function needs to decide (and this research doesn't) whether re-login via LINE reissues `app_access_token` (invalidating other devices' sessions) or returns the existing stored one; that's an implementation decision for whoever builds this, informed by whatever multi-device policy 06 lands on.

---

## Sources

**LINE Developers documentation (developers.line.biz), fetched directly, quoted verbatim where noted:**
- [LINE Login overview](https://developers.line.biz/en/docs/line-login/overview/)
- [Getting started with LINE Login](https://developers.line.biz/en/docs/line-login/getting-started/)
- [Integrating LINE Login with your web app](https://developers.line.biz/en/docs/line-login/integrate-line-login/)
- [Get profile information from ID tokens](https://developers.line.biz/en/docs/line-login/verify-id-token/)
- [Creating a secure login process between your app and server](https://developers.line.biz/en/docs/line-login/secure-login-process/)
- [LINE Login security checklist](https://developers.line.biz/en/docs/line-login/security-checklist/)
- [Managing access tokens](https://developers.line.biz/en/docs/line-login/managing-access-tokens/)
- [LINE Login v2.1 API reference](https://developers.line.biz/en/reference/line-login/)
- [Setting up your project — LINE SDK for iOS Swift](https://developers.line.biz/en/docs/line-login-sdks/ios-sdk/swift/setting-up-project/)
- [Using universal links — LINE SDK for iOS Swift](https://developers.line.biz/en/docs/line-login-sdks/ios-sdk/swift/universal-links-support/)
- [Integrating LINE Login with your Android app](https://developers.line.biz/en/docs/line-login-sdks/android-sdk/integrate-line-login/)

**`flutter_line_sdk` package, fetched directly:**
- [pub.dev/packages/flutter_line_sdk](https://pub.dev/packages/flutter_line_sdk)
- [github.com/line/flutter_line_sdk](https://github.com/line/flutter_line_sdk) — `README.md` fetched verbatim via `raw.githubusercontent.com`
- [`AccessToken` class docs](https://pub.dev/documentation/flutter_line_sdk/latest/flutter_line_sdk/AccessToken-class.html)

**bloom source (read-only reference, `/Users/daichi/Documents/blooom関係/dream/`):**
- `Class_Line.php` (full file read)
- `line/line_login/regist.php`, `line/login.php`, `line/regist.php`, `line/redirect.php`, `line/link_account.php`, `line/line_notify/regist.php` (full files read)
- `Class_LineLinkAccount.php`, `Class_QuickLogin.php` (full files read)
- `Class_User.php` (LINE-related sections, `access_token_verification`, `tempRegist`, `getUserData`)
- `app/api/route_api.php`, `app/api/Class_UserApi.php` (full files read)
- `config/config.php.default` (`LINE_CONFIG` definition)
- `mysqldump/dream.sql` (`user`, `line_account`, `line_account_user_info` table definitions)

No secondary/blog sources were used.
