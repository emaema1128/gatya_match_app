# Apple Sign-In (Sign in with Apple) — Feasibility Research

Scope: Flutter app (iOS + Android) backed by the custom PHP backend "bloom". Sources are Apple's official developer documentation (developer.apple.com) and the `sign_in_with_apple` package's own pub.dev page / GitHub repository, unless explicitly marked "(secondary)". Every non-obvious claim below is followed by its source URL.

Bloom backend context used for grounding (read directly, not published — paths under `/Users/daichi/Documents/blooom関係/dream/`):
- `app/api/route_api.php` — single JSON entrypoint, dispatches on `execute_function`, requires `system_id` in the POST body, and checks a bearer `app_access_token` header via `User::access_token_verification()` (skipped only when `system_id === -1`, which is the pre-registration state).
- `app/api/Class_UserApi.php` — holds the business logic called from `route_api.php` (`registUser`, `login`, `existsDeviceId`, etc.).
- `Class_User.php` — `tempRegist(...)` creates a user row and returns `system_id`; `setLineUserId($system_id, $line_user_id)` (line 695) already stores a third-party identity's user ID on the `user` table as a precedent for linking an external auth provider to `system_id`; `access_token_verification()` (line 984) checks the opaque `app_access_token` bearer token bloom already issues at registration.
- `composer.json` / `composer.lock` show bloom already pulls in `web-token/jwt-core`, `jwt-key-mgmt`, `jwt-signature`, `jwt-signature-algorithm-ecdsa`, `jwt-util-ecc` (v2.2.11) — transitively, as a dependency of `minishlink/web-push` for VAPID (ES256) signing, not currently used for any login flow. This is relevant below.

---

## 1. Flutter-side implementation: `sign_in_with_apple` package

Source: pub.dev package page (v8.1.0 as fetched) — https://pub.dev/packages/sign_in_with_apple — and its GitHub source, confirmed at https://github.com/aboutyou/dart_packages/tree/master/packages/sign_in_with_apple/sign_in_with_apple (monorepo; the package lives at `packages/sign_in_with_apple/sign_in_with_apple`).

**Platform support**
- **iOS & macOS**: native support via Apple's `AuthenticationServices` framework, configured as an Xcode capability. No custom UI is drawn by the OS button requirement (see App Store guideline notes below); the plugin returns an `AuthorizationCredentialAppleID` with `identityToken`, `authorizationCode`, `userIdentifier`, `email`, `givenName`, `familyName`.
- **Android**: **not native** — it drives a **web-based OAuth flow through Chrome Custom Tabs**, i.e. it opens Apple's hosted web sign-in page (the same flow "Sign in with Apple JS" / REST API uses for the web) and redirects back into the app. This means Android requires a server-reachable **redirect URI** and, critically, a **Service ID** configured in the Apple Developer Portal (see setup below) — there is no way to do Apple Sign-In on Android without a backend endpoint that Apple can redirect to.
- **Web**: supported via a companion package (`sign_in_with_apple_web`) using Apple's JS SDK.

**Android technical detail** (quoted from the package's own docs/README):
- Requires Android's V2 embedding.
- `launchMode` must be `singleTask` or `singleTop` so the browser redirect returns correctly to the app.
- The redirect activity must be registered in `AndroidManifest.xml`:
  ```xml
  <activity
      android:name="com.aboutyou.dart_packages.sign_in_with_apple.SignInWithAppleCallback"
      android:exported="true">
    <intent-filter>
      <action android:name="android.intent.action.VIEW" />
      <category android:name="android.intent.category.DEFAULT" />
      <category android:name="android.intent.category.BROWSABLE" />
      <data android:scheme="signinwithapple" />
      <data android:path="callback" />
    </intent-filter>
  </activity>
  ```
- On your **server's** callback for the configured `WebAuthenticationOptions.redirectUri`, you must redirect back into the app with:
  `intent://callback?${PARAMETERS FROM CALLBACK BODY}#Intent;package=YOUR.PACKAGE.IDENTIFIER;scheme=signinwithapple;end`
  — i.e. **bloom (or a thin redirect endpoint) has to receive Apple's POST callback and 302 back into the Android app**, not just accept a token from the Flutter client directly. This is the main asymmetry vs. iOS: on iOS the token comes straight to the Flutter app; on Android bloom's server is structurally in the middle of the redirect.
- Dart call shape (from search of the plugin's public API/examples, consistent with pub.dev docs):
  ```dart
  final credential = await SignInWithApple.getAppleIDCredential(
    scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
    webAuthenticationOptions: WebAuthenticationOptions(
      clientId: 'com.example.service', // the Service ID, NOT the app's bundle ID
      redirectUri: Uri.parse('https://your-bloom-domain/api/apple/callback'),
    ),
  );
  ```

**Required Apple Developer Portal setup** (from pub.dev README + confirmed against Apple's own "Configuring your environment for Sign in with Apple" doc — https://developer.apple.com/documentation/signinwithapple/configuring-your-environment-for-sign-in-with-apple):
1. Paid Apple Developer Program membership (Sign in with Apple is unavailable on free accounts) — pub.dev README, explicit quote: *"paid membership to the Apple Developer Program"* is mandatory.
2. Enable the **Sign in with Apple** capability on the app's **App ID** (in Xcode, or in Certificates, Identifiers & Profiles) — needed for iOS regardless of Android use.
3. Create a **Services ID** — a *separate* identifier from the App ID, used specifically as the OAuth `client_id` for the web/Android flow. Apple's doc: *"You must use a unique identifier — a Services ID — to register each web service that supports Sign in with Apple authentication."* Configure it with the registered domain(s) and **Return URLs** (redirect URIs) — each must be an absolute HTTPS URL with a real host (no IP/localhost). Domain and subdomain ownership must be verified.
4. Create a **private key** ("Sign in with Apple" key) under Certificates, Identifiers & Profiles → Keys. This key is what the *backend* uses to sign a `client_secret` JWT when talking to Apple's token endpoint (needed for Android's authorization-code exchange, and optionally for periodic refresh-token checks on iOS). Apple's doc: *"Each primary app can have a maximum of two private keys."* Compromise handling: revoke and rotate, never share outside the dev team.
5. Optional but relevant if handling private-relay email: register the sending domain and configure SPF for **Sign in with Apple for Email Communication** (Certificates, Identifiers & Profiles → More → "Sign in with Apple for Email Communication" → Configure) — see §5.

---

## 2. Server-side (PHP) verification of the identity token

Primary source: Apple's "Verifying a user" doc — https://developer.apple.com/documentation/signinwithapple/verifying-a-user — states the required checks **verbatim**:

> To verify the identity token, your app server must:
> - Verify the JWS E256 signature using the server's public key
> - Verify the `nonce` for the authentication
> - Verify that the `iss` field contains `https://appleid.apple.com`
> - Verify that the `aud` field is the developer's `client_id`
> - Verify that the time is earlier than the `exp` value of the token

Notes on that checklist:
- "JWS E256" in Apple's own text is essentially their shorthand/typo-prone phrasing; in practice the identity token is an RS256-signed JWT (RSA + SHA-256) — confirmed by the fact Apple's JWKS endpoint returns RSA keys with `"alg": "RS256"` (see below), and this is universally how every third-party implementation (including the ones cross-checked in this research) treats it. Treat "verify the signature" as: fetch Apple's JWKS, find the key by `kid` in the token header, verify RS256 signature.
- `nonce`: only meaningful if your client actually sent one in the authorization request; native Sign in with Apple on iOS lets you pass a nonce (hashed) to the authorization request, and the identity token then carries the raw/derived nonce claim to check against. If you don't pass one, there's nothing to check here — but Apple's checklist assumes you do, as a replay defense.
- `aud`: must equal **your `client_id`** — but note the App ID and the Services ID are different identifiers, so **the expected `aud` differs between the native iOS flow (App ID / bundle ID) and the Android/web flow (Services ID)**. Bloom's verification code needs to accept either, keyed off which flow issued the token.

**Fetching Apple's public keys (JWKS)**: Apple's REST API doc ("Fetch Apple's public key for verifying token signature", under `signinwithapplerestapi`) and the confirmed `JWKSet` object reference (https://developer.apple.com/documentation/signinwithapplerestapi/jwkset — *"A set of JSON Web Key objects"*, with a `keys` array of `JWKSet.Keys`) describe:
- `GET https://appleid.apple.com/auth/keys` returns a JSON Web Key Set. Each key has the standard JWK fields (`kty`, `kid`, `use`, `alg`, `n`, `e`). This matches the standard RFC 7517 JWKS shape used by every OIDC provider — nothing Apple-specific about the verification mechanics once you have the JWKS.
- Practical implementation note: keys should be cached (with a reasonable TTL / re-fetch on `kid` miss) rather than fetched on every request, since Apple rotates keys periodically and does not guarantee a fixed schedule.

**Client secret (needed for the token endpoint, i.e. Android's code exchange and optional refresh-token checks)**: Apple's "Creating a client secret" doc — https://developer.apple.com/documentation/accountorganizationaldatasharing/creating-a-client-secret — specifies the client_secret is itself a JWT that bloom's server must mint and sign:
- Header: `alg: ES256`, `kid: <10-char Sign in with Apple key ID>`.
- Claims: `iss` = 10-char Team ID, `iat`, `exp` (max 15,777,000 seconds / 6 months out), `aud: https://appleid.apple.com`, `sub` = the same `client_id` (App ID or Services ID) used elsewhere.
- Signing algorithm: **ECDSA P-256 + SHA-256 (ES256)**, using the private key downloaded when the "Sign in with Apple" key was created in the Developer Portal.
- **Grounding fact**: bloom's `vendor/web-token/*` (jwt-core, jwt-key-mgmt, jwt-signature, jwt-signature-algorithm-ecdsa, jwt-util-ecc, v2.2.11) already provides everything needed to sign an ES256 JWT — it's presently there only as a transitive dependency of `minishlink/web-push` for Web Push VAPID, but the same primitives apply directly to building the Apple `client_secret`. Nothing new needs to be pulled in for **signing** the client secret.
- **Gap**: that same `web-token` install only has the ECDSA algorithm component. **Verifying** Apple's RS256-signed identity token needs an RSA verifier, which isn't currently pulled in (`web-token/jwt-signature-algorithm-rsa` is not in `composer.lock`). Options: (a) add that one Composer package, which stays inside the same `web-token/jwt-framework` family already in use; or (b) use a smaller, purpose-built library such as `firebase/php-jwt` (the most commonly used PHP JWT library for exactly this verify-RS256-with-JWKS use case) — either is a small, self-contained addition, not a new dependency ecosystem.

Token endpoint for the authorization-code exchange (needed on Android, and for revocation/refresh checks): `POST https://appleid.apple.com/auth/token` with `client_id`, `client_secret`, `code`, `grant_type=authorization_code`, `redirect_uri` — documented at https://developer.apple.com/documentation/signinwithapplerestapi/generate-and-validate-tokens, response contains `access_token`, `id_token` (the identity token to verify), `refresh_token`, `expires_in`. A `refresh_token` grant variant exists for periodic re-validation (Apple explicitly rate-limits this to about once/day per user — see §5).

---

## 3. Backend work estimate on bloom's side

This is a rough sketch consistent with the existing `route_api.php` / `Class_UserApi.php` conventions observed directly in the codebase (see the "Bloom backend context" note at the top) — not a finished design.

### What Apple actually returns, and what that means for the payload shape

- **Native iOS flow**: the Flutter app gets an `identityToken` (JWT), `authorizationCode`, `userIdentifier` (`sub`), and — **only on the very first authorization** — `givenName`/`familyName` and (if the `email` scope was requested) an email address. See §5 for the precise first-time-only mechanics.
- **Android flow**: the redirect lands on bloom's own callback endpoint first (server-to-server-ish; Apple POSTs `code`, `id_token`, `state`, and optionally `user` — a JSON blob with name/email, first-time only — to the configured Services ID redirect URI), and bloom then has to 302 back into the Android app via the `intent://` scheme the plugin expects. So realistically bloom needs **two** new pieces: a callback endpoint that Apple can POST to directly (outside the normal `route_api.php` JSON contract, since it's a browser redirect, not a JSON POST from the app) and the actual login/register `execute_function` that the Flutter app calls afterward with the identity token.
- The `email` claim inside the identity token itself is present on *every* subsequent sign-in (not just the first) as long as the user granted the email scope — see §5. Only the *name* is a true one-time gift.
- Email may be a **private relay address** (`...@privaterelay.appleid.com`), which is opaque and stable per (developer team, user) but not a real inbox unless bloom also configures the relay-email SPF/domain registration (§5). If bloom's flows send transactional email (password reset, notifications) to `user.email`, sending to relay addresses needs that separate Apple Developer Portal config — otherwise those emails will simply not deliver.

### Sketch of the new endpoint(s)

Following the existing `switch ($post_data['execute_function'])` pattern in `route_api.php` and the `UserApi::` static-method convention in `Class_UserApi.php`:

```php
// route_api.php — new case, same shape as existing 'login' / 'registUser' cases
case 'loginWithApple':
    $apple_result = UserApi::loginOrRegisterWithApple($post_data);
    if ($apple_result) {
        $system_id = $apple_result['system_id'];
        $user_data = User::getUserData($system_id, 'str');
        $return_data = json_encode(['result' => '1', 'data' => [
            'user_data' => $user_data,
            'is_new_user' => $apple_result['is_new_user'],
        ]]);
    } else {
        $return_data = json_encode(['result' => '2', 'error_detail' => 'Apple identity token verification failed']);
    }
    break;
```

```php
// Class_UserApi.php — new method
public static function loginOrRegisterWithApple($post_data) {
    // 1. Verify $post_data['identity_token'] against Apple's JWKS (iss, aud, exp, sig) — new Class_AppleAuth.php or similar
    $claims = AppleAuth::verifyIdentityToken($post_data['identity_token'], $post_data['platform']); // platform picks expected aud (App ID vs Services ID)
    if (!$claims) return false;

    $apple_user_id = $claims['sub']; // stable per (Apple dev team, user) — the only durable identifier
    $email = $claims['email'] ?? null;
    $is_private_email = $claims['is_private_email'] ?? false;

    // 2. Look up by apple_user_id first (new column, same pattern as existing line_user_id)
    $existing = User::getUserByAppleUserId($apple_user_id);
    if ($existing) {
        // existing user: reissue app_access_token, update fcm token etc., same as UserApi::login()
        return ['system_id' => $existing['system_id'], 'is_new_user' => false];
    }

    // 3. No match: treat like a fresh signup. Either:
    //    (a) return a "not registered" signal so the client runs the existing registUser()
    //        profile-collection flow, passing apple_user_id + given/family name (first-auth only)
    //        through as prefill, or
    //    (b) auto-create via a User::tempRegist()-style call here, storing apple_user_id.
    return false; // or the tempRegist(...) path, depending on product decision
}
```

Concretely, the additions this implies:
- **New `user` table column**: `apple_user_id` (nullable, unique index), added the same way `line_user_id` already was — precedent exists (`Class_User.php:695`, `setLineUserId`). A companion lookup method (`getUserByAppleUserId`) mirroring existing `existsDeviceId`/`existsAdjustId` query patterns in `Class_UserApi.php`.
- **A small new class** (e.g. `Class_AppleAuth.php`) to encapsulate: JWKS fetch + cache, RS256 signature verification, claims validation (`iss`/`aud`/`exp`), and — for the Android path — client_secret (ES256) minting + the `POST /auth/token` code-exchange call. This is the one genuinely new piece of infrastructure; everything else (issuing bloom's own `app_access_token`, `getUserData`, the `execute_function` dispatch) reuses existing machinery already exercised by `registUser`/`login`.
- **A raw HTTP callback route outside `route_api.php`'s JSON contract**, for the Android redirect-back step (Apple POSTs form data, not the bloom JSON envelope, to the Services ID's registered Return URL). This is structurally different from every other endpoint in `route_api.php` and needs its own thin PHP script.
- **Decision needed** (out of scope for this research, flagged for the redesign ticket): auto-register on first Apple sign-in vs. funnel into the existing `registUser` profile-collection screens with name/email prefilled. Given bloom's registration flow collects a lot of dating-app-specific profile data (`sex`, `area`, `age_id`, `PR`, etc. — see `Class_UserApi.php::registUser`), a bare Apple identity token alone is nowhere near enough to satisfy `tempRegist()`'s required fields, so some UI flow to collect the rest is required either way — Apple sign-in only removes the password/email-verification step, not full registration.
- Effort is dominated by the Android callback plumbing and the new verification class; the actual `execute_function` wiring is small and mechanical relative to bloom's other endpoints.

---

## 4. App Store Review requirement — exact current wording

Fetched directly from Apple's official App Review Guidelines page: https://developer.apple.com/app-store/review/guidelines/ — this is guideline **4.8, currently titled "Login Services"** (not "Sign in with Apple" — Apple broadened the title/wording at some point to cover the general obligation, of which Apple's own service is one way to satisfy it). Full text, verbatim:

> **4.8 Login Services**
>
> Apps that use a third-party or social login service (such as Facebook Login, Google Sign-In, Log in with X, Sign In with LinkedIn, Login with Amazon, or WeChat Login) to set up or authenticate the user's primary account with the app must also offer as an equivalent option another login service with the following features:
> - the login service limits data collection to the user's name and email address;
> - the login service allows users to keep their email address private as part of setting up their account; and
> - the login service does not collect interactions with your app for advertising purposes without consent.
>
> A user's primary account is the account they establish with your app for the purposes of identifying themselves, signing in, and accessing your features and associated services.
>
> Another login service is not required if:
> - Your app exclusively uses your company's own account setup and sign-in systems.
> - Your app is an alternative app marketplace, or an app distributed from an alternative app marketplace, that uses a marketplace-specific login for account, download, and commerce features.
> - Your app is an education, enterprise, or business app that requires the user to sign in with an existing education or enterprise account.
> - Your app uses a government or industry-backed citizen identification system or electronic ID to authenticate users.
> - Your app is a client for a specific third-party service and users are required to sign in to their mail, social media, or other third-party account directly to access their content.

**Precise reading, correcting the common shorthand**: the trigger condition is not literally "you offer other social logins" in the abstract — it is that a third-party/social login is used **to set up or authenticate the user's *primary* account**. The guideline text doesn't name Apple's own service as automatically satisfying itself, but Sign in with Apple is Apple's own reference implementation of "another login service" that meets the three bullet conditions (name+email-only collection, private-email option, no non-consented ad tracking), so in practice it's the default way developers satisfy this guideline — but it is not the *only* way (bloom's own email/password login, if truly independent, already qualifies as the "exclusively your company's own account setup" exception, which is the first carve-out listed above).

**Grounding note for this decision**: bloom's backend has existing LINE-login-related code (`Class_Line.php`, `Class_LineLinkAccount.php`, `line_user_id` column) observed while reading the code for this research. Whether the **Flutter mobile app** itself exposes "Sign in with LINE" as a way to *create or authenticate the primary account* (vs. LINE being used purely for outbound messaging/marketing, e.g. rich menus and official-account pushes, unrelated to login) was not established here and should be confirmed — it directly determines whether guideline 4.8 is even triggered. If the app's only sign-in path is bloom's own `login_id`/`password` system (per `UserApi::login()`), the "exclusively your company's own account setup and sign-in systems" exception likely applies and Sign in with Apple would be **optional** rather than App-Review-mandated; if the app also offers LINE (or Google, etc.) login for primary account setup, Apple Sign-In becomes effectively mandatory to pass review.

Source: https://developer.apple.com/app-store/review/guidelines/ (fetched directly; anchor `#4.8-login-services` or nearby — Apple's guidelines page is a single long document, section numbering as quoted above).

---

## 5. Known pitfalls

1. **Name is one-time only; email is not.** Verbatim from Apple's "Authenticating users with Sign in with Apple" doc (https://developer.apple.com/documentation/signinwithapple/authenticating-users-with-sign-in-with-apple):
   > "The API collects this information and shares it with your app the first time the user logs in using Sign in with Apple."
   > "If the user then uses Sign in with Apple on another device, the API doesn't ask for the user's name or email again."
   > "It collects the information again only if the user stops using Sign in with Apple and later reconnects to your app."
   > "Although Apple provides the user's email address in the identity token on all subsequent API responses, it doesn't include other information about the user, such as their name."

   **This corrects a common misstatement**: it is the **full name** that is genuinely one-time-only (delivered via the native credential object / web callback, never inside the JWT at all, per the "Receiving a User's Identity Token" doc: *"the user's full name... is not included in the user's identity token"*). The **email claim persists in the identity token on every subsequent sign-in**, not just the first. Practical implication for bloom: **capture and persist `givenName`/`familyName` from the very first callback — there is no way to ever retrieve it again** if it's lost (e.g., a failed request mid-registration). Email, by contrast, can be safely re-read from the JWT on every login. Source: https://developer.apple.com/documentation/signinwithapple/receiving-a-users-identity-token

2. **Private email relay.** Source: https://developer.apple.com/documentation/signinwithapple/communicating-using-the-private-email-relay-service
   - Relay addresses end in `@privaterelay.appleid.com` (or occasionally route through `@icloud.com` reply transformation), are stable per (Apple developer team, user) across all of that team's apps, and remain active/receivable even when the user is signed out or the app is uninstalled.
   - To actually deliver mail to relay addresses, bloom must register its sending domain(s) and configure SPF specifically for "Sign in with Apple for Email Communication" in the Developer Portal — without this, mail to relay addresses may not deliver.
   - **Daily send limit of 100 emails** per relay address (covers both bloom→user and user's replies) — relevant if bloom's existing mail/notification volume per user could approach that.
   - `is_private_email` claim: present (true) when the user chose the relay; per Apple Developer Forum reports (secondary, community-sourced — https://developer.apple.com/forums/thread/808653), this claim can be **absent** in some cases even for real-email users, so treat its *absence* as "not private," not as an error condition, and don't hard-fail if it's missing.

3. **Managed Apple Accounts (education) may return no email at all.** Source: https://developer.apple.com/documentation/signinwithapple/receiving-a-users-identity-token — *"Alternatively, if the managed Apple Account is in Apple School Manager, the email claim may be empty."* Not likely relevant to a dating app's user base, but worth a defensive null-check.

4. **Always use `sub` (the Apple user identifier), never email, as the durable key.** Explicit in Apple's docs: *"Use the user identifier instead of an email address to identify the user. The user identifier remains unique and static for your developer team."* Matches this research's endpoint sketch in §3 (new `apple_user_id` column, not keying off email).

5. **`aud` differs by flow.** The identity token's `aud` claim is the **App ID** (bundle ID) for the native iOS flow but the **Services ID** for the Android/web flow — bloom's verification logic needs to know which flow issued a given token and check against the right expected `client_id`, or accept either registered identifier.

6. **Session/account changes and revocation are the app's responsibility to poll for, not push-notified by default in the basic flow.** Apple's "Verifying a user" doc: refresh-token re-validation is recommended **at most once a day** — *"Apple's servers may throttle your call if you attempt to verify a user's Apple Account more than once a day."* A user can revoke bloom's access from their Apple Account settings at any time; bloom won't know unless it periodically re-validates the refresh token (or implements the separate server-to-server "Processing changes for Sign in with Apple accounts" notification webhook, a further increment of work not covered by basic login).

7. **Android is structurally a web OAuth redirect, not a native SDK call.** This is the single biggest implementation-cost pitfall: it means Apple's callback lands on bloom's server first (via the Services ID's registered Return URL), and bloom must both (a) run the standard identity-token verification and (b) perform an `intent://` redirect back into the Android app. Testing this locally requires a real HTTPS-reachable redirect URI (no localhost), which slows down dev-loop iteration compared to the native iOS path. Source: pub.dev/GitHub README of `sign_in_with_apple`, §1 above.

8. **JWKS key rotation.** Apple doesn't publish a fixed rotation schedule for the keys at `https://appleid.apple.com/auth/keys`; verification code should look up by `kid` and refetch/cache-bust on a miss rather than hardcoding or infrequently-refreshing a single key. (General JWKS best practice, consistent with how the JWKSet is documented at https://developer.apple.com/documentation/signinwithapplerestapi/jwkset — no fixed-schedule guarantee is stated.)

9. **`client_secret` expiry ceiling.** The ES256 client-secret JWT bloom mints to talk to `/auth/token` cannot have `exp` more than 15,777,000 seconds (~6 months) in the future — if bloom generates this once and caches it, there needs to be a rotation/regeneration job before expiry, or (simpler) generate it fresh per request/short-lived. Source: https://developer.apple.com/documentation/accountorganizationaldatasharing/creating-a-client-secret

---

## Source list (primary, all developer.apple.com / pub.dev / GitHub unless marked secondary)

- Flutter package: https://pub.dev/packages/sign_in_with_apple (v8.1.0 as fetched)
- Package source repo: https://github.com/aboutyou/dart_packages (package at `packages/sign_in_with_apple/sign_in_with_apple`)
- App Review Guidelines (4.8 Login Services): https://developer.apple.com/app-store/review/guidelines/
- Configuring your environment for Sign in with Apple: https://developer.apple.com/documentation/signinwithapple/configuring-your-environment-for-sign-in-with-apple
- Authenticating users with Sign in with Apple: https://developer.apple.com/documentation/signinwithapple/authenticating-users-with-sign-in-with-apple
- Receiving a User's Identity Token: https://developer.apple.com/documentation/signinwithapple/receiving-a-users-identity-token
- Verifying a user: https://developer.apple.com/documentation/signinwithapple/verifying-a-user
- Communicating using the private email relay service: https://developer.apple.com/documentation/signinwithapple/communicating-using-the-private-email-relay-service
- Generate and validate tokens (Sign in with Apple REST API): https://developer.apple.com/documentation/signinwithapplerestapi/generate-and-validate-tokens
- Fetch Apple's public key for verifying token signature: https://developer.apple.com/documentation/signinwithapplerestapi/fetch_apple_s_public_key_for_verifying_token_signature
- JWKSet object reference: https://developer.apple.com/documentation/signinwithapplerestapi/jwkset
- TokenResponse object reference: https://developer.apple.com/documentation/signinwithapplerestapi/tokenresponse
- Creating a client secret: https://developer.apple.com/documentation/accountorganizationaldatasharing/creating-a-client-secret

Secondary sources cited explicitly where used (community-sourced, not Apple documentation):
- Apple Developer Forums thread on `is_private_email` sometimes absent: https://developer.apple.com/forums/thread/808653 (Apple-hosted forum, but user/community-generated content, not formal docs — used only to caveat a defensive-coding note, not as the basis for any claim about required behavior)

Bloom backend files read directly for grounding (not web sources, local repo):
- `/Users/daichi/Documents/blooom関係/dream/app/api/route_api.php`
- `/Users/daichi/Documents/blooom関係/dream/app/api/Class_UserApi.php`
- `/Users/daichi/Documents/blooom関係/dream/Class_User.php`
- `/Users/daichi/Documents/blooom関係/dream/composer.json`, `composer.lock`
- `/Users/daichi/Documents/blooom関係/dream/Class_QuickLogin.php` (checked, found unrelated to social auth — camo-URL based one-click login for LINE broadcast messages)
