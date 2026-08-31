# Point-granting mechanics for non-purchase credits (bloom PHP backend)

Source checkout: `/Users/daichi/Documents/blooom関係/dream/`

## Summary

The reusable, non-purchase point-credit primitive is **`Point::addBalance($system_id, $target_id, $pay_category, $add_point)`**, defined in `Class_Point.php:213-247`. It is a plain static function with no session/UI coupling: it updates `user_balance.balance` and inserts one `point_log` row. It is already called directly from application code outside the admin UI (`free.php:366`, `Class_Plan.php:384`), so it is safe and idiomatic for a new feature (gacha) to call it too.

The admin manual-credit tool (`mng/user/sub_point_update.php` / `manage/user/sub_point_update.php`) does **not** actually call `Point::addBalance` — it's a red herring for the *main* balance. It credits a separate **`sub_point`** field (a different currency: `sub_point_number`) via raw SQL + `SubPoint::insertLog()`, using `SubPoint::SERVICE_POINT = 101`. That constant is unrelated to `PayCost::SERVICE_POINT`, which happens to also equal `101` but lives in a different class/table (`point_log` vs `sub_point_log`). **Do not use `SubPoint::insertLog`/the admin script's flow for gacha bonuses — use `Point::addBalance` with a `PayCost` category instead.**

`Point::addBalance` has **no side effects** beyond the balance update + log row: no email, no push notification, no `Automation::checkTrigger(...)` call. This is a deliberate contrast with the real-money path `Deposit::addBalance` (`Class_Deposit.php:16-160+`), which additionally writes a `deposit_log` row, fires `Automation::checkTrigger($system_id, Automation::TRIGGER_DEPOSIT)`, and sends a deposit confirmation email via `Notification::sendTypeDeposit(...)`. None of that fires for `Point::addBalance` — good for a low-ceremony welcome/sorry bonus, but also means nothing currently distinguishes a gacha bonus from any other `Point::addBalance` call in the log UI except the `pay_category` value you choose.

**Recommended call for both gacha use cases:**
```php
Point::addBalance($system_id, $target_id, $pay_category, $add_point);
```
- `$target_id`: pass `null` unless you want to record which gacha candidate/context triggered it (the column accepts `NULL`, see `Class_Point.php:272`).
- `$pay_category`: existing categories in `Class_PayCost.php` are `SERVICE_POINT = 101` ("サービスポイント追加", used for admin/manual and generic free-content grants) and `REWARD_POINT = 103` ("広告サービスポイント", used for the ad-watch reward callback). Neither is a perfect semantic match for "welcome bonus" or "gacha resurface sorry bonus" — **consider adding new `PayCost` constants** (e.g. `WELCOME_BONUS`, `GACHA_RESURFACE_BONUS`) so the admin point-log viewer (`mng/point/log.php` / `manage/point/log.php`) can label them distinctly instead of lumping them under the generic "サービスポイント追加" label. See Q2/Q4 below for details.

**Insertion point for the welcome bonus:** in `Class_UserApi.php::registUser`, right after `$system_id` comes back from `User::tempRegist(...)` (line 41) — see Q5. The `user_balance` row already exists by that point because `User::tempRegist` itself inserts it (`Class_User.php:478-496`), which is a hard prerequisite for `Point::addBalance` to work (it only `UPDATE`s an existing row, see Q3).

---

## Q1. `sub_point_update.php` — what does it actually call?

Both copies are functionally identical (`mng/user/sub_point_update.php:1-56` and `manage/user/sub_point_update.php:1-59`, differing only in template markup).

Flow (`mng/user/sub_point_update.php:19-38`):
```php
$dbh->beginTransaction();
$sql = "UPDATE user SET sub_point$sub_point_number = sub_point$sub_point_number + $add_sub_point_value WHERE system_id = :system_id";
$stmt = $dbh->prepare($sql);
$stmt->bindValue('system_id', (int)$system_id, PDO::PARAM_INT);
$stmt->execute();

$pay_category = SubPoint::SERVICE_POINT;
if (!SubPoint::insertLog($system_id, $add_sub_point_value, $sub_point_number, $pay_category)) {
  throw new Exception('サブポイントログ更新失敗');
}
$dbh->commit();
```
It directly runs an `UPDATE user SET sub_point{N} = sub_point{N} + :value` (a *sub-point*, a per-numbered-slot secondary currency stored as columns `sub_point1`, `sub_point2`, ... on the `user` table — **not** the main point balance used for gacha spins), then calls `SubPoint::insertLog()` (`Class_SubPoint.php:88-122`) to write a `sub_point_log` row.

Gating: it's guarded by `Staff::checkLoginAndPermission()` (line 8) and reads straight from `$_POST` (lines 10-17) — it is tightly coupled to the admin UI/session and to the sub-point system, and is **not the mechanism to reuse** for gacha's main-balance grants.

`SubPoint::insertLog` (`Class_SubPoint.php:88-122`) itself just re-reads the current sub-point value via `self::getPoint(...)`, then inserts a row into `sub_point_log(system_id, sub_point_number, pay_category, use_sub_point, sub_point_log, created_at)`. No transaction handling of its own, no side effects (no automation/notification).

## Q2. Is there a clean, reusable credit function?

Yes: **`Point::addBalance($system_id, $target_id, $pay_category, $add_point=null)`** — `Class_Point.php:213-247`:

```php
/**
 * ポイント追加処理
 * フリー領域以外からの呼出しでもこの関数を使えるようにした。
 * ポイント消費の関数は呼出し元がフリー領域とそれ以外で別の関数を使うようになっている（usePointとusePointFree）が、
 * ポイント追加は同じクラスで処理できるようにした。（統一性の観点でポイント消費と同じ仕様にしてもOK）
 */
public static function addBalance($system_id, $target_id, $pay_category, $add_point=null)
{
  $balance = self::getBalance($system_id); // 現在所持ポイントを取得
  $after_balance = $balance + $add_point;
  $pay_date = date("Y-m-d H:i:s");

  $dbh = DBconnect::Connect();
  try{
    $check_in_transaction = $dbh->inTransaction();
    if ($check_in_transaction === false) {
      $dbh->beginTransaction();
    }
    if(!self::insertLog($system_id, $pay_category, $add_point, $after_balance, $target_id, $pay_date)){
      throw new Exception('point_log挿入失敗');
    }
    if(!self::updateBalance($system_id,$after_balance)){
      throw new Exception('残高加算処理失敗');
    }

    if ($check_in_transaction === false) {
      $dbh->commit();
    }
    return true;
  }catch(Exception $e){
    if ($check_in_transaction === false) {
      $dbh->rollback();
    }
    $error_message = $e->getmessage();
    error_log("[Point::addBalance] $error_message [system_id: $system_id, pay_category: $pay_category, add_point: $add_point, after_balance: $after_balance]");
    return false;
  }
}
```
(`Class_Point.php:207-247`, doc comment included)

This is exactly the "just credits the balance" primitive the task describes:
- Takes `system_id`, `target_id` (nullable), a `pay_category` (any `PayCost::*` constant), and the amount.
- No session/UI coupling — pure data-layer function.
- **Transaction-reentrant**: it checks `$dbh->inTransaction()` and only opens/commits its own transaction if none is already open, so it's safe to call either standalone or from inside a caller's existing transaction (e.g. from inside `User::tempRegist`'s transaction, or wrapped in the gacha endpoint's own transaction).
- Already used directly by non-admin application code with arbitrary `pay_category` values, not just from a purchase flow:
  - `free.php:366` — grants "free area" viewing service points, `pay_category = PayCost::SERVICE_POINT_VIEW_FREE_AREA_PAGE_FREE/_CONTENT`.
  - `Class_Plan.php:384` (`refundPoints`, private) — refunds a cancelled plan, `pay_category = PayCost::CANCEL_JOINING_PLAN`.
  - `Class_SubPoint.php:63` (`exchangePoint`) — converts sub-points to main points, `pay_category = PayCost::EXCHANGE_SUB_POINT`.

So: **no admin-UI entanglement to work around** — `registUser` and a new gacha endpoint can call `Point::addBalance(...)` straight, the same way `free.php` and `Class_Plan.php` already do, just with a different `$pay_category`.

Contrast — `api/callback/recache.php:16-64` (an ad-network reward callback, `pay_category = PayCost::REWARD_POINT`) shows an *alternative, less clean* pattern: it hand-rolls the same `UPDATE user_balance` + `INSERT INTO point_log` SQL itself instead of calling `Point::addBalance`, and doesn't check whether the `user_balance` row exists. This duplicate/inline approach is not recommended — it's included here only because it's precedent for a non-purchase `REWARD_POINT` grant triggered by an external callback, similar in spirit to a gacha "sorry" bonus, but `Point::addBalance` is the better-encapsulated equivalent to call instead.

`PayCost` category constants relevant here (`Class_PayCost.php:31-37`):
```
const SERVICE_POINT = 101;   // "サービスポイント追加" (mng/point/log.php:132-134) — admin/manual + free-content grants
const PURCHASE_POINT = 102;  // "入金" — real IAP/deposit only (Deposit::addBalance)
const REWARD_POINT = 103;    // "広告サービスポイント" — ad-watch reward callback
const EXCHANGE_SUB_POINT = 104;
```
displayed/labeled in `mng/point/log.php:132-147` (and its `manage/` twin). Neither `SERVICE_POINT` nor `REWARD_POINT` says "welcome bonus" or "gacha resurface bonus" — worth adding dedicated `PayCost` constants for these two new grant reasons so they're distinguishable in the point log admin view, but functionally either existing constant works fine as `$pay_category`.

## Q3. `Class_Point.php` — crediting side (full read)

Read in full (`Class_Point.php:1-487`). Crediting-relevant pieces:

- `addBalance(...)` — `Class_Point.php:213-247` — covered above, the credit entry point.
- `insertLog($system_id, $pay_category, $use_point, $after_balance, $target_id, $pay_date)` — `Class_Point.php:249-278` — the shared log-writer used by both crediting and debiting paths (`use_point` holds the signed/unsigned delta amount depending on caller; for `addBalance` it's the amount added). Inserts into `point_log(system_id, pay_category, use_point, balance_log, target_id, pay_date)`. `target_id` binds as `PDO::PARAM_NULL` when empty (`Class_Point.php:272`), so passing `null` is fine.
- `updateBalance($systemid, $afterbalance)` — `Class_Point.php:445-455` — **`private`**, does `UPDATE user_balance SET balance = ? WHERE system_id = ?`. Since it's private, it can only be invoked through `addBalance`/`usePoint`/etc. within the `Point` class itself — confirms `Point::addBalance` really is the intended entry point, not something to bypass.
- `getBalance($systemid)` — `Class_Point.php:310-318` — `SELECT * FROM user_balance WHERE system_id = ?`, returns `(int)$result['balance']`. Note: if no `user_balance` row exists for the `system_id`, `$stmt->fetch()` returns `false`, so `$result['balance']` triggers a PHP warning and casts to `(int)false = 0`. This means **`addBalance` requires the `user_balance` row to already exist** — it computes `$after_balance = $balance(0) + $add_point` and then `UPDATE ... WHERE system_id = ?` silently affects 0 rows if the row is missing (no error is raised by `updateBalance`, which just checks `$stmt->execute()` succeeded, not row count). This is exactly why the welcome-bonus call must happen **after** `user_balance` is created (see Q5) — calling it earlier would silently no-op the balance update while still writing a misleading `point_log` row.
- Everything else in the file (`checkBalance`, `checkMinusBalance`, `usePoint*`, `getShortPoint*`, limit-related getters) is on the debit/checking side, explicitly out of scope per the task (covered by the parallel `PayCost`/balance-checking research task).

## Q4. Side effects of crediting via `Point::addBalance`

Confirmed by full read of `Class_Point.php:213-247` and its callees:
- **DB row**: one `point_log` insert per call (`Class_Point.php:249-278`) — this is the only persistent side effect.
- **Balance table**: `user_balance.balance` updated in place (`Class_Point.php:445-455`).
- **No notification/email**: no call to `Notification::*` anywhere in `addBalance` or `insertLog`/`updateBalance`.
- **No automation trigger**: unlike `usePoint`/`usePointPlan`/`usePointFree` (which call `Automation::checkTriggerBelowPoint(...)` after debiting, e.g. `Class_Point.php:127,166,197,305`), `addBalance` calls **no** `Automation::checkTrigger*` at all.
- **No UserLog update**: unlike the debit paths (`UserLog::insertUseLog`, `User::updateUseDate`), `addBalance` doesn't touch `UserLog`/`user.latest_...` fields.

For contrast, the *real-money* path `Deposit::addBalance` (`Class_Deposit.php:16-160+`) has substantially more side effects that `Point::addBalance` deliberately lacks:
- Inserts a `deposit_log` row (`Class_Deposit.php:81-140`).
- Fires `Automation::checkTrigger($system_id, Automation::TRIGGER_DEPOSIT)` (`Class_Deposit.php:155`).
- Sends an email via `Notification::sendTypeDeposit($system_id, Notification::KEY_DEPOSIT_OK, ...)` when `$notification_flag` is true (`Class_Deposit.php:158-160`).
- Updates `user.深... `/deposit-related timestamp via `User::depositAfterProcess(...)` (`Class_Deposit.php:150-152`).

None of that runs for `Point::addBalance`, so a gacha welcome/sorry bonus granted this way will be silent (no push/email) and won't fire any deposit-triggered automation — likely the desired behavior, but worth flagging in case product wants a "you got bonus points!" notification, which would need to be added explicitly by the new gacha code (not inherited for free).

## Q5. Insertion point in `registUser` / `tempRegist`

### `UserApi::registUser($post_data)` — `app/api/Class_UserApi.php:22-56`

```php
public static function registUser($post_data) {
  $email = 'test@example.com';
  $device_type = $post_data['device_type'];
  $device_id = $post_data['device_id'];
  $adjust_device_id = $post_data['adjust_id'];
  $sex = $post_data['sex'];
  $adcode_id = Adcode::getIdByAdcode($post_data['adcode']);
  $age_id = $post_data['age_id'] ?? null;
  $income_id = $post_data['income_id'] ?? null;
  $address_id = $post_data['address_id'] ?? null;
  $username = $post_data['user_name'] ?? 'ゲスト';
  $area1_id = $post_data['region'];
  $area2_id = $post_data['prefecture'];
  $area3_id = $post_data['city'];
  $PR = $post_data['comment'];
  $fcm_device_token = $post_data['fcm_device_token'];
  $app_access_token = self::generateToken();
  $basedir = '/var/www/html/';

  $system_id = User::tempRegist($email, $sex, $adcode_id, $username, null, $area1_id, $area2_id, $area3_id, null, $device_type, $device_id, $adjust_device_id, $PR, $age_id, $income_id, $address_id, $fcm_device_token, $app_access_token);
  User::setMemberStatus($system_id, User::MEMBER_STATUS_REGISTED);
  // <-- INSERT WELCOME-BONUS CALL HERE, e.g.:
  // Point::addBalance($system_id, null, PayCost::SERVICE_POINT /* or a new WELCOME_BONUS const */, $welcome_bonus_amount);

  $img_path = [];
  for ($i = 1; $i <= 3; $i++) {
    if (!empty($post_data["image_{$i}"])) {
      $img_path_str = File::saveBase64Image($post_data["image_{$i}"], $system_id, $basedir, 'profile_img');
      $img_path[$i] = ltrim($img_path_str, '/');
    }
  }
  ProfileApi::uploadProfileImg($system_id, $img_path, $basedir);

  Common::verificationAfterLoginProcess($system_id);
  $user_data = User::getUserData($system_id,'str');
  return $user_data;
}
```
(`app/api/Class_UserApi.php:22-56`, `require_once($basedir.'Class_Point.php')`/`Class_PayCost.php` is not currently included by this file — see note below)

**Exact insertion point**: right after line 42 (`User::setMemberStatus($system_id, User::MEMBER_STATUS_REGISTED);`), i.e. immediately after `$system_id` is confirmed via `User::tempRegist(...)` at line 41. By this point:
- `$system_id` is a real int (assuming `tempRegist` succeeded — see caveat below).
- The `user_balance` row already exists (inserted inside `tempRegist`, see next section), so `Point::addBalance` will actually find a row to `UPDATE` rather than silently no-op.

**Caveat already present in the code (pre-existing, not something to fix as part of this task, just be aware)**: `registUser` never checks whether `User::tempRegist(...)` returned `false` (its documented failure return, `Class_User.php:502-506`) before calling `User::setMemberStatus($system_id, ...)` with `$system_id === false`. A welcome-bonus call inserted here would inherit the same gap — worth guarding (`if ($system_id === false) { ... }`) when adding the new call, even though the surrounding code doesn't currently guard for it either.

**Include note**: `app/api/Class_UserApi.php` requires `Class_User.php` (line 6) but not `Class_Point.php`/`Class_PayCost.php` directly. `Class_Point.php` itself requires `Class_PayCost.php` (`Class_Point.php:3`), and `Class_User.php` requires `Class_Point.php`... — need to double check the require chain resolves `Point`/`PayCost` before use; if not already transitively loaded, add `require_once($basedir.'Class_Point.php');` alongside the existing requires at the top of `Class_UserApi.php:2-8`.

### `User::tempRegist(...)` — `Class_User.php:334-507`

The `user_balance` row is created **inside** `tempRegist`, not in `registUser`:

```php
$system_id = $dbh->lastInsertId();                                    // Class_User.php:475

// user_balance table
$sql_insert_balance = "INSERT INTO user_balance(system_id, balance) VALUES(:system_id, :balance)";
$stmt_insert_balance = $dbh->prepare($sql_insert_balance);
// 初期ポイントを取得
$sql_init_point =  'SELECT data->>\'$.man\' AS man,data->>\'$.woman\' AS woman
                    FROM general_config
                    WHERE name = \'initial_points\'';
$stmt_initial_point = $dbh->prepare($sql_init_point);
$stmt_initial_point->execute();
$initial_points = $stmt_initial_point->fetch(PDO::FETCH_ASSOC);

// 初期バランス設定
$sex_str = $sex == 1 ? 'woman' : 'man';
$init_balance = (int)$initial_points[$sex_str];

$stmt_insert_balance->bindValue(':system_id', (int)$system_id, PDO::PARAM_INT);
$stmt_insert_balance->bindValue(':balance', (int)$init_balance, PDO::PARAM_INT);
if (!$stmt_insert_balance->execute()) {
  throw new Exception('user_balance table insert fault.');
}

self::TempRegistAfterProcess($system_id);   // Class_User.php:498 — currently just UserLog::insertTempRegistLog($system_id)

$dbh->commit();
return (int)$system_id;
```
(`Class_User.php:475-501`)

**Important pre-existing behavior**: every new user already gets a non-zero starting `user_balance.balance` from `general_config`'s `initial_points` JSON (`{man: ..., woman: ...}`), inserted directly via raw SQL — **not** via `Point::addBalance`, and **no `point_log` row is written for it**. This is a *silent* initial grant baked into account creation, separate from and in addition to whatever "welcome bonus" the gacha feature adds. Two implications for the future design session:
1. If the product intent for the gacha welcome bonus is "on top of" the existing sex-based `initial_points`, calling `Point::addBalance` after `tempRegist` returns is correct and additive.
2. If instead the intent is to *replace/unify* with the existing initial-balance mechanism, that's a bigger change to `tempRegist` itself (and would break the "no `point_log` row" pattern that currently exists for the initial grant) — flagging this distinction since the task's welcome-bonus wording ("so a brand-new user isn't stuck at 0 balance") could describe either the pre-existing `initial_points` mechanism or a new explicit grant; per Q1-Q4 above, the *new, `point_log`-visible, easily-attributable* way to do it is `Point::addBalance(...)` called from `registUser`, not editing `tempRegist`'s raw INSERT.

`self::TempRegistAfterProcess($system_id)` (`Class_User.php:963-966`) is a smaller alternative insertion point *inside* `tempRegist`'s own transaction (it currently just calls `UserLog::insertTempRegistLog($system_id)`), reached at `Class_User.php:498`, after the `user_balance` row is inserted (line 494) and before `$dbh->commit()` (line 500). Calling `Point::addBalance` from inside here would also work correctly (it would join the already-open transaction, since `addBalance` checks `$dbh->inTransaction()` — `Class_Point.php:224`), but mixes account-creation concerns with gacha-specific bonus logic inside the generic `User` class. **Recommend the `registUser` insertion point** (`app/api/Class_UserApi.php`, after line 42) instead, since that keeps the "gacha welcome bonus" decision in the API/feature layer rather than the low-level user-creation routine, consistent with how `free.php`/`Class_Plan.php` call `Point::addBalance` from their own feature code rather than from `Class_User.php`/`Class_Point.php` themselves.

---

## For the gacha "sorry" bonus (case b)

No existing endpoint to model this on was found (gacha doesn't exist yet in this backend) — but the mechanism is identical to the welcome bonus: from wherever the new gacha-spin endpoint decides a resurfaced/already-seen candidate needs a "sorry" bonus, call:
```php
Point::addBalance($system_id, $target_id, $pay_category, $sorry_bonus_amount);
```
- `$target_id`: could carry the resurfaced candidate's `system_id` for traceability in `point_log`, since the column is a generic nullable target reference (`Class_Point.php:272`) used elsewhere to reference plan/content ids.
- Same caveats apply: must run only when a `user_balance` row exists (true for any already-registered user hitting a gacha endpoint), and gets no automation/notification side effects unless you add them explicitly.
