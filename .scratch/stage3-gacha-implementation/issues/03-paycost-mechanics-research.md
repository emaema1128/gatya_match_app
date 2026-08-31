Type: research
Status: resolved

## Question

`Class_PayCost.php`と`pay_cost`テーブルの仕組みを調査する。「ガチャ1回分」という新しいコストタイプを安全に追加するには何が必要かを明らかにする。

含めるべき論点:

1. `PayCost`クラスの定数(`VIEW_PROFILE = 2`等)と、`pay_cost`テーブルの行は何を表すか、両者はどう対応しているか。
2. 新しいコストタイプを追加するには、PHPの定数を増やすだけで足りるか、それとも`pay_cost`テーブルに新しい行(価格設定含む)を追加する必要があるか。
3. 既存のコストID(1〜41、101〜123等)と衝突しない、新規IDの採番方針。
4. `Point::checkBalance`/`checkMinusBalance`(残高チェック)の実装を読み、実際に「残高が足りるか」をどう判定しているか、残高が足りない場合の挙動(マイナス許容等)を確認する。
5. 実際にポイントを消費させる関数はどれか(`checkBalance`は判定のみで、消費自体は別の関数のはず)。

調査結果は`.scratch/stage3-gacha-implementation/research/paycost-mechanics.md`に保存する。

## Answer

`/research`サブエージェントが調査完了。詳細は[research/paycost-mechanics.md](../research/paycost-mechanics.md)。

**結論(スキーマ変更は不要)**: `PayCost`の定数は`pay_cost`テーブルの行IDではなく、`point_log`に記録される「なぜポイントが動いたか」の分類コード(`pay_category`)。1〜99が消費、100以上が付与という規約がある(`Class_PayCost.php:30`のコメントで明記)。`pay_cost`テーブルは実は1行しかない「価格プロファイル」テーブルで、`VIEW_PROFILE`等の一部カテゴリはこのテーブルの列を経由して価格を引くが、`VIEW_FREE_AREA_PAGE_*`/`JOIN_PLAN_*`のように**価格を直接パラメータで渡す**カテゴリも既に存在する(`Class_Point.php`の`checkBalanceFree`/`usePointFree`)。ガチャの消費は固定額なので後者のパターンを踏襲すればよく、**`pay_cost`テーブルへのカラム追加(スキーマ変更)は不要**。

**実装方針**:
1. `Class_PayCost.php`に`const GACHA_SPIN = 42;`を追加(41=`USER_REQUEST`の次、空いている番号)。スキーマ変更なし、定数追加のみ。
2. 消費額はガチャ側のコードにハードコードした定数として持つ(`pay_cost`テーブルには持たせない)。
3. 残高チェックは`Point::checkBalanceFree($system_id, $spin_cost)`(`Class_Point.php:46-57`)。マイナス残高許容(`checkMinusBalanceFree`)は使わない方針を推奨(ガチャは必須機能ではないため)。
4. 消費は`Point::usePointFree($system_id, $target_id, PayCost::GACHA_SPIN, $spin_cost)`(`Class_Point.php:102-135`)——既存の実績ある関数をそのまま再利用できる。
5. 副作用として`point_log`監査行・`user_use_log`・`latest_use_date`更新・低残高時の既存マーケティングオートメーション(`Automation::checkTriggerBelowPoint`)が自動的に発火する(ガチャ側で追加対応は不要)。

[02-spin-endpoint-design](02-spin-endpoint-design.md)はこの調査結果を前提に設計する。
