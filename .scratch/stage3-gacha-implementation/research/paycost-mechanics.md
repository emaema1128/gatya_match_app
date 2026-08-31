# bloom `PayCost` / `Point` mechanics — research for gacha spin cost

Source checked out at: `/Users/daichi/Documents/blooom関係/dream/`
(No files were modified — read-only investigation.)

## Summary (TL;DR for whoever builds the endpoint)

- `PayCost` constants are **not** row IDs in the `pay_cost` table. They are `pay_category` codes with two totally different meanings depending on range:
  - **1–41 (deduction/spend categories)**: some of these (VIEW_BOARD, SEND_MAIL, PLAY_AUDIO, USER_REQUEST, etc.) are also **column names** in the single-row `pay_cost` table and get their price via `PayCost::getPayCategoryCost()`. Others (VIEW_FREE_AREA_PAGE_*, JOIN_PLAN_*) are **not** looked up from `pay_cost` at all — their price is sourced from a different table/param and passed in directly. This second group is the correct template for a flat, hardcoded gacha-spin price.
  - **100+ (addition/credit categories)**: explicitly commented `// 100以上はポイント追加` (`Class_PayCost.php:30`) — used only as a label in `point_log` when points are being *added* to a balance (`Point::addBalance()`), never for deduction.
- There is a real `pay_cost` table, but it currently has **exactly one row** (`pay_cost_id = 1`, `'初期減算ポイント'`) — it's effectively a single global pricing profile users are joined to via `user.pay_cost_id`, plus an optional per-character override table `chara_special_pay_cost`. Each pricing "feature" is a hardcoded **column**, not a row you insert. Adding a new lookup-based cost category (like USER_REQUEST) means an `ALTER TABLE pay_cost ADD COLUMN ...` plus a new `case` in `getPayCategoryCost()` — real schema risk on a codebase with no staging.
- **Recommended path for gacha spin**: do NOT extend `pay_cost`/`getPayCategoryCost()`. Follow the `VIEW_FREE_AREA_PAGE_*` / `JOIN_PLAN_*` pattern instead — pick a new unused `pay_category` constant, hardcode the spin price as a PHP constant/param in your own gacha code, and call `Point::checkBalanceFree()` + `Point::usePointFree()` (or a new near-identical wrapper) passing that literal price. No DB schema change required at all; only a new `PayCost` class constant.
- Safe next available `pay_category` ID: **anything currently unused**. Highest used in the 1–99 "deduction" range is `USER_REQUEST = 41` (`Class_PayCost.php:28`); highest used in the 100+ "addition" range is `CANCEL_JOINING_PLAN = 123` (`Class_PayCost.php:37`). Gaps also exist at 18–20, 23–30, 33–40. A clean, unambiguous, forward-compatible pick is **42** (right after the last used deduction ID, still well clear of the 100+ addition block). Avoid anything ≥100 — that range is semantically reserved for point-*addition* logging, not spending.
- The actual balance decrement happens in `Point::updateBalance()` (`Class_Point.php:445`), called from the various `usePoint*`/`addBalance` wrapper methods — never call it directly; always go through a `usePoint*` wrapper so the `point_log` insert and balance update stay in the same transaction.
- Side effects of any point deduction: an audit row in `point_log` (mandatory — insert must succeed or the whole transaction rolls back), a row in `user_use_log` (`UserLog::insertUseLog`), an update to `user.latest_use_date`/`first_use_date` (`User::updateUseDate`), and a check against automation "below point" triggers (`Automation::checkTriggerBelowPoint`) which can fire marketing/notification automations. These all happen inside one DB transaction with the balance update.

---

## 1. What do the `PayCost` constants represent? Is there a numbering pattern?

Full constant list, `Class_PayCost.php:7-37`:

```php
const VIEW_BOARD = 1;
const VIEW_PROFILE = 2;
const SEND_MAIL = 3;
const WRITE_BOARD = 4;
const SEND_ADDRESS_MAIL = 5;
const VIEW_ADDRESS_MAIL = 6;
const VIEW_UNREAD_MAIL = 7;
const VIEW_READ_MAIL = 8;
const PROFILE_PHOTO = 9;
const MAIL_PHOTO = 10;
const PHOTO_UPLOAD = 11;
const PLAY_MOVIE = 12;
const SEND_DEDICATED_MAIL = 13;
const SEND_PHOTO = 14;
const SEND_AUDIO = 15;
const PLAY_AUDIO = 16;
const SEND_MATCHING_MAIL = 17;
const VIEW_FREE_AREA_PAGE_FREE = 21;
const VIEW_FREE_AREA_PAGE_CONTENT = 22;
const JOIN_PLAN_PER_CONTENT = 31;
const JOIN_PLAN_MONTHLY = 32;
const USER_REQUEST = 41;

// 100以上はポイント追加
const SERVICE_POINT = 101;
const PURCHASE_POINT = 102;
const REWARD_POINT = 103;
const EXCHANGE_SUB_POINT = 104;
const SERVICE_POINT_VIEW_FREE_AREA_PAGE_FREE = 121;
const SERVICE_POINT_VIEW_FREE_AREA_PAGE_CONTENT = 122;
const CANCEL_JOINING_PLAN = 123;
```

These are **`pay_category`** codes — they classify *why* a point transaction happened. They are stored verbatim in `point_log.pay_category` (see `Class_Point.php:113`, `269`, etc.) and, for a subset of them, are also used as a `switch` key inside `PayCost::getPayCategoryCost()` to decide which column of the `pay_cost` table to read a price from.

**Numbering pattern observed:**
- **1–17**: a contiguous block of one-off mail/board/profile/media actions (view board, send mail, upload photo, play audio, etc.). Each of these has a same-named column in the `pay_cost` table (`view_board`, `send_mail`, `play_audio`, ...) and is priced via `PayCost::getPayCategoryCost()`.
- **21–22**: "free area" content viewing — grouped with a gap left after 17 (18–20 unused), presumably as a reserved buffer for the block. These are looked up from `free_area`/content pricing elsewhere, NOT from `pay_cost` — see §2.
- **31–32**: "plan" joining (per-content vs monthly) — another new group starting on a round number, gap left at 23–30.
- **41**: `USER_REQUEST`, a single standalone item, gap left at 33–40. This one *is* wired into `getPayCategoryCost()`'s switch and has a `user_request` column in `pay_cost` (see §2).
- **100+, explicitly commented** `// 100以上はポイント追加` (`Class_PayCost.php:30`, "100 and above are for point *addition*"): these are used only when *crediting* points to a balance (service grants, purchases, rewards, sub-point exchange, plan cancellation refunds), via `Point::addBalance()`. They are never looked up against `pay_cost` — they're just audit labels.

So the convention is: **groups start on round-ish numbers (1, 21, 31, 41, 101, 121) with unused numbers left as a buffer for that group to grow**, and the 1–99 vs 100+ split is a hard semantic boundary between "spend" and "credit" categories — confirmed both by the comment and by every actual call site (`usePoint`/`usePointFree`/`usePointMail`/`usePointPlan` only ever pass sub-100 constants; `addBalance` is the only function that receives 100+ constants — see `mng`/`spt`/`support`/`manage` panel code, not shown here in full but consistent across all `PayCost::` grep hits).

## 2. Is there an actual `pay_cost` table? Does adding a cost type require a new row (with a price), or do constants alone suffice?

Yes, there is a real `pay_cost` table. Schema (`mysqldump/dream.sql:2821-2844`):

```sql
CREATE TABLE `pay_cost` (
  `pay_cost_id` int unsigned NOT NULL AUTO_INCREMENT,
  `pay_cost_name` varchar(255) NOT NULL,
  `view_board` int unsigned NOT NULL DEFAULT '0',
  `view_profile` int unsigned NOT NULL DEFAULT '0',
  `send_mail` int unsigned NOT NULL DEFAULT '0',
  ... (one column per 1–17/41-style pay_category) ...
  `user_request` int unsigned NOT NULL DEFAULT '0',
  `default_flag` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`pay_cost_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 ...;
```

Data: **exactly one row** —
```
INSERT INTO `pay_cost` VALUES (1,'初期減算ポイント',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1);
```
(`mysqldump/dream.sql:2853`). `AUTO_INCREMENT=2` confirms only ID 1 has ever been inserted.

Important: **`pay_cost_id` (the table's primary key) is a completely different ID space from the `PayCost` class constants** (which are `pay_category` values). `pay_cost_id` identifies a *pricing profile* — a user is assigned one via `user.pay_cost_id` (joined in `getPayCategoryCost()`, `Class_PayCost.php:87-91`), and there's also a per-character override profile table `chara_special_pay_cost` with an identical column set (`mysqldump/dream.sql:811-834`) joined via `support_memo.special_pay_cost_id`.

So a `pay_category` constant used inside `getPayCategoryCost()`'s `switch` (`Class_PayCost.php:97-137`) does **not** get its own row — it must instead be **a new column** on both `pay_cost` and (for full parity with existing categories) `chara_special_pay_cost`, plus a new `case` branch in the switch, e.g.:

```php
case self::VIEW_BOARD:
  return isset($cost['special_view_board']) ? $cost['special_view_board'] : $cost['view_board'];
```
(`Class_PayCost.php:99-100`)

**This is the risky path** — it's a schema migration (`ALTER TABLE pay_cost ADD COLUMN ...`, likewise for `chara_special_pay_cost`) plus a UPDATE to seed the new column's value into the existing single row, on a DB with no staging environment. Every category that IS priced this way (`VIEW_BOARD` ... `SEND_DEDICATED_MAIL`, `USER_REQUEST`) has a matching column — confirmed by cross-referencing the switch cases in `Class_PayCost.php:99-134` against the `CREATE TABLE pay_cost` column list.

**However, several `PayCost` constants are deliberately NOT in that switch and don't need a `pay_cost` column at all**: `VIEW_FREE_AREA_PAGE_FREE` (21), `VIEW_FREE_AREA_PAGE_CONTENT` (22), `JOIN_PLAN_PER_CONTENT` (31), `JOIN_PLAN_MONTHLY` (32). For these, the price is sourced from wherever that feature's own pricing lives (free-area content config, plan config) and is passed as a literal `$usepoint`/`$require_point` argument straight into `Point::checkBalanceFree()` / `Point::usePointFree()` / `Point::usePointPlan()` — the `pay_category` constant is used purely as an **audit label** written into `point_log.pay_category`, never as a DB lookup key. Example, `free.php:333-338`:

```php
$target_id = $freearea_group_id ?? $content_id;
$pay_type = !empty($freearea_group_id) ? PayCost::VIEW_FREE_AREA_PAGE_FREE : PayCost::VIEW_FREE_AREA_PAGE_CONTENT;

if (!Point::usePointFree($system_id, $target_id, $pay_type, $view_require_point)) {
  echo '[ERROR]ポイントの消費に失敗しました。';
  exit();
}
```
`$view_require_point` here is not looked up from `pay_cost` — it comes from the free-area content's own config earlier in `free.php`.

**Conclusion for gacha spin**: since the spin cost is meant to be a *fixed, non-configurable* number, do not add a `pay_cost` column. Mirror the `VIEW_FREE_AREA_PAGE_*`/`JOIN_PLAN_*` pattern: hardcode the spin price as a plain PHP constant (e.g. inside a new `GachaApi`/`Gacha` class), and call `Point::checkBalanceFree()` / `Point::usePointFree()` (or write a near-identical wrapper if you want a distinct method name) passing that literal price with a new `pay_category` constant used only as a label. This requires zero `pay_cost`/`chara_special_pay_cost` schema changes — only adding one new constant to `Class_PayCost.php` and, if you want it out of the free-area/plan-only helpers, optionally a small new `Point::usePointGacha(...)`-style wrapper (trivial copy of `usePointFree`, `Class_Point.php:102-135`).

## 3. Safe next available `pay_category` ID

All constant values found via full read of `Class_PayCost.php:7-37` (only file defining `PayCost` constants; confirmed no other `Class_PayCost*.php` or duplicate definitions exist in the tree):

**1–99 range (deduction/spend categories):**
1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 21, 22, 31, 32, 41

→ **Highest used: 41** (`USER_REQUEST`). Unused gaps: 18–20, 23–30, 33–40, 42–99.

**100+ range (addition/credit categories):**
101, 102, 103, 104, 121, 122, 123

→ **Highest used: 123** (`CANCEL_JOINING_PLAN`). Unused gaps: 105–120, 124+.

**Recommendation**: use **42** for the new gacha-spin `pay_category` constant (e.g. `const GACHA_SPIN = 42;`, added at `Class_PayCost.php:29`, right after `USER_REQUEST = 41`). It's the lowest unused ID, immediately continues the existing sequence with no ambiguity, and is unambiguously outside the 100+ "addition" range (do not use anything ≥100 for a spend/deduction category — every 100+ constant across the whole codebase is only ever passed to `Point::addBalance()`, never to `usePoint`/`usePointFree`/`checkBalance`/`checkMinusBalance`). Whatever number is picked, it must **not** collide with 1–17, 21, 22, 31, 32, 41 (spend) — collisions in the 100+ block are a separate (also-avoid) concern only if you also add a corresponding point-grant feature later.

## 4. `Point::checkBalance` / `Point::checkMinusBalance` — what they check, what they return, and where deduction actually happens

Both live in `Class_Point.php`, referenced from `MailApi::checkBalance` (`app/api/Class_MailApi.php:160-179`), which itself is called from the app API router (`app/api/route_api.php`, e.g. lines 170, 193, 214, 251, 272, 514, 626).

### `Point::checkBalance($systemid, $paycategory, $targetid, $other_pay_category = null)` — `Class_Point.php:12-27`

```php
public static function checkBalance($systemid,$paycategory,$targetid,$other_pay_category=null){
  $usepoint = PayCost::getPayCategoryCost($systemid,$paycategory,$targetid); // 消費ポイントを取得
  if (!empty($other_pay_category)) {
    $usepoint += PayCost::getPayCategoryCost($systemid,$other_pay_category,$targetid);
  }
  if( $usepoint == 0 ){
    return TRUE; // 消費ポイント0の場合は残高チェック無し
  }
  $balance = self::getBalance($systemid); // 現在所持ポイントを取得
  $afterbalance = $balance - $usepoint;
  if( $afterbalance >= 0 ){
    return TRUE; // 残高ＯＫ
  }else{
    return FALSE; // ポイント不足
  }
}
```

- **Purely read-only.** Looks up the cost via `PayCost::getPayCategoryCost()` (a DB `pay_cost`/`chara_special_pay_cost` lookup — meaning this specific function is unusable for a flat, un-columned cost like gacha unless you go the `getPayCategoryCost` route from §2), fetches the current balance via `self::getBalance($systemid)` (`Class_Point.php:310-318`, a plain `SELECT * FROM user_balance WHERE system_id = ?`), and returns a bool: `TRUE` if `balance - cost >= 0` (or if cost is 0 — no check performed), `FALSE` if insufficient. **No writes at all.**
- **Note for gacha**: because it calls `getPayCategoryCost()` internally, `checkBalance` cannot be reused as-is for a flat/hardcoded gacha price unless a `pay_cost` column is added (§2). The free-area equivalent, `checkBalanceFree($system_id, $use_point)` (`Class_Point.php:46-57`), takes the point cost as a plain parameter instead — that's the one to reuse/copy for gacha.

### `Point::checkMinusBalance($systemid, $paycategory, $targetid, $other_pay_category = null)` — `Class_Point.php:29-43`

```php
public static function checkMinusBalance($systemid,$paycategory,$targetid,$other_pay_category=null){
  $usepoint = PayCost::getPayCategoryCost($systemid,$paycategory,$targetid);
  if (!empty($other_pay_category)) {
    $usepoint += PayCost::getPayCategoryCost($systemid,$other_pay_category,$targetid);
  }
  $balance = self::getBalance($systemid);
  $minuslimitid = User::getUserLimitId($systemid);
  $minuslimit = self::getMinusLimit($minuslimitid);
  $afterbalance = $balance + $minuslimit - $usepoint;
  if( $afterbalance >= 0 ){
    return TRUE; // マイナス残高ＯＫ
  }else{
    return FALSE; // マイナスポイント不足
  }
}
```

- Also **read-only**. This is bloom's "allow spending into negative balance up to a limit" feature — it fetches a per-user "minus limit" (`User::getUserLimitId()` → `Point::getMinusLimit()`, a lookup into the `point_limit` table, `Class_Point.php:320-332`) and checks `balance + minuslimit - cost >= 0`. Used as a fallback when `checkBalance` fails, e.g. in `MailApi::checkBalance` (`app/api/Class_MailApi.php:162-166`):
  ```php
  if( !Point::checkBalance($system_id,$pay_cost,$target_id) ){
    if( !Point::checkMinusBalance($system_id,$pay_cost,$target_id) ){
      return false;
    }
  }
  return true;
  ```
  i.e. the site lets users go negative (up to a configured limit) rather than hard-blocking at zero balance. **This is a business-logic decision the gacha feature needs to explicitly make** — likely you do NOT want to let users spin into negative balance, so you'd only call the `checkBalanceFree`-equivalent, not the minus-balance fallback.

### Where deduction actually happens

`checkBalance`/`checkMinusBalance` never touch the balance. The actual decrement is done by **`Point::updateBalance($systemid, $afterbalance)`** — `Class_Point.php:445-455`:

```php
private function updateBalance($systemid,$afterbalance){
  $dbh = DBconnect::Connect();
  $sql = "UPDATE user_balance SET balance = ? WHERE system_id = ?";
  $stmt = $dbh->prepare($sql);
  $stmt->bindValue(1,(int)$afterbalance,PDO::PARAM_INT);
  $stmt->bindValue(2,(int)$systemid,PDO::PARAM_INT);
  if( !$stmt->execute() ){
    return FALSE;
  }
  return TRUE;
}
```

Note it's declared `private function` (no `static`!) — it is only ever called internally, from within `Class_Point.php` itself, by the various `usePoint*`/`addBalance` wrappers (never called directly from outside the class). **The wrapper functions are the actual public API for spending points**, each wrapping `insertLog()` + `updateBalance()` in one DB transaction:

- `Point::usePoint($system_id, $target_id, $pay_category)` — `Class_Point.php:179-205`. Looks up cost via `PayCost::getPayCategoryCost()` (DB-column-based pricing), then deducts. Used for e.g. `USER_REQUEST` (`app/api/Class_UserApi.php:316`), `VIEW_BOARD`/`WRITE_BOARD`/`VIEW_PROFILE`/`MAIL_PHOTO`/`PLAY_AUDIO`.
- `Point::usePointFree($systemid, $targetid, $paycategory, $usepoint)` — `Class_Point.php:102-135`. Takes the point cost **as a literal parameter**, no `pay_cost` lookup. This is the template to copy/reuse for gacha.
- `Point::usePointPlan(...)` — `Class_Point.php:138-177`. Same idea, plan-specific, cost passed in directly.
- `Point::usePointMail(...)` — `Class_Point.php:280-308`. Same idea but also stores a `mail_id` in `point_log`; note this one is NOT wrapped in `beginTransaction`/`commit`/`rollback` (only `usePointFree`/`usePointPlan`/`usePoint`/`addBalance` are) — looks like a pre-existing inconsistency in the codebase, not something to copy.
- `Point::addBalance($system_id, $target_id, $pay_category, $add_point = null)` — `Class_Point.php:213-247`. The credit-side counterpart (100+ categories), reuses/nests inside an existing transaction if one is already open (`$dbh->inTransaction()` check).

All of these follow the same shape: `beginTransaction()` → `insertLog()` (INSERT into `point_log`) → `updateBalance()` (UPDATE `user_balance`) → `UserLog::insertUseLog()` + `User::updateUseDate()` + `Automation::checkTriggerBelowPoint()` → `commit()`, with `rollback()` in the `catch`. **For gacha, the safest/most consistent implementation is a new method that's a near-copy of `usePointFree`** (same transactional shape, same side effects), called with the new `PayCost::GACHA_SPIN` (=42 suggested) constant and the hardcoded spin price — no `getPayCategoryCost()`/`pay_cost` table involvement.

## 5. Side effects of deducting points

Every spend wrapper (`usePoint`, `usePointFree`, `usePointPlan`, and — inconsistently — `usePointMail`) performs, inside one transaction (except `usePointMail`, see above):

1. **`point_log` INSERT** (`Point::insertLog()`, `Class_Point.php:249-278`) — an audit-trail row: `system_id`, `pay_category`, `use_point`, `balance_log` (balance *after* the spend), `target_id`, `pay_date`. Schema at `mysqldump/dream.sql:3105-3116`. This is mandatory — if the insert fails the whole transaction is rolled back (`throw new Exception('point_log挿入失敗')`, e.g. `Class_Point.php:118-120`, `188-190`). **Whatever `pay_category` you pick for gacha will show up here**, so admin-side point-log viewers (`mng/point/*`, `support/chara/point/*`, `manage/point/*` per earlier grep) will need to be able to render/label it — check whether those admin views hardcode a switch over known `pay_category` values that would need a new label added for the gacha category to display correctly (not confirmed in this pass; worth a follow-up read of `mng/point/list.php` / `PayCost::getPayCostName()` usage if the admin panel needs to show gacha spins nicely).
2. **Balance UPDATE** on `user_balance` (`Point::updateBalance()`, `Class_Point.php:445-455`).
3. **`user_use_log` INSERT** via `UserLog::insertUseLog($systemid)` (`Class_UserLog.php:44-54`) — just `INSERT INTO user_use_log(system_id) VALUES(...)`, an engagement/usage log, no extra params.
4. **`user.latest_use_date` / `user.first_use_date` UPDATE** via `User::updateUseDate($systemid)` (`Class_User.php:224-239`).
5. **Automation trigger check** via `Automation::checkTriggerBelowPoint($systemid, $balance, $afterbalance)` (`Class_Automation.php:479-...`) — queries `automation_group` for any enabled automation whose `trigger_point` falls between the before/after balance, and if matched, presumably fires some kind of notification/automation flow (e.g. "your balance dropped below X, here's a top-up prompt"). This means **spending points on a gacha spin can itself trigger existing low-balance marketing automations** — expected and probably desirable, but worth knowing since it's an implicit side effect, not something the gacha code needs to invoke itself.
6. `usePointPlan` additionally fires `Automation::checkTrigger($system_id, Automation::TRIGGER_PLAN_PURCHASE)` — plan-specific, not relevant to gacha unless you want an equivalent "gacha purchase" trigger type (would need a new `Automation::TRIGGER_*` constant and matching `automation_group.trigger_type` rows — out of scope unless explicitly desired).

No other side effects (no push notifications, emails, or webhook calls) were found directly inside `Class_Point.php`; any user-facing notification of "your points were spent" appears to be left to the caller (e.g. the API response returning updated `user_data`/balance, as seen in `app/api/route_api.php:283-284`: `$user_data = User::getUserData($system_id, 'str'); $return_data = json_encode(['result' => '1', 'data' => ['user_data' => $user_data]]);`).

## Concrete recommendation for the gacha spin endpoint

1. Add `const GACHA_SPIN = 42;` to `Class_PayCost.php` right after `USER_REQUEST = 41` (`Class_PayCost.php:28`) — a pure constant addition, no migration, no `switch` case needed (do NOT add it to `getPayCategoryCost()`'s switch).
2. Define the flat spin price as a literal constant in your own gacha PHP code (or wherever this codebase's convention puts feature-specific config) — do not source it from `pay_cost`.
3. Before spinning: call `Point::checkBalanceFree($system_id, $spin_cost)` (`Class_Point.php:46-57`) to verify sufficient balance (decide explicitly whether to also allow the `checkMinusBalanceFree` negative-balance fallback — recommend not, for a discretionary feature like gacha).
4. To deduct: call `Point::usePointFree($system_id, $target_id, PayCost::GACHA_SPIN, $spin_cost)` (`Class_Point.php:102-135`) — reuse as-is; `$target_id` can be `0`/null or repurposed to reference the spin/prize record if useful for the audit log, per how `target_id` is used elsewhere (nullable in `point_log`, `mysqldump/dream.sql:3111`).
5. This requires zero `pay_cost`/`chara_special_pay_cost` schema changes — the only production-facing change is one new PHP constant plus your new endpoint/method calling existing, already-battle-tested `Point` methods.
