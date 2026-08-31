Type: research
Status: resolved

## Question

bloomの`Class_Point.php`/`Class_Deposit.php`を調査し、プログラム側からユーザーにポイントを付与する(課金を経由しない)方法を明らかにする。[stage3-gacha-home](../../stage3-gacha-home/map.md)で決めた、①新規登録時の初期ポイント自動付与、②候補枯渇時のサービスポイント(`SERVICE_POINT`カテゴリ)付与、の両方の実装に必要。

含めるべき論点:

1. `route_api.php`の`addPoint`(課金購入)は`Deposit::addBalance`を呼んでいるが、課金を経由せずポイント残高を増やす関数は存在するか(`Class_Point.php`または`Class_Action.php`の`SERVICE_POINT`付与箇所を参考に)。
2. `mng/user/sub_point_update.php`(運営の手動付与画面)が使っている関数はどれか、それをAPI(`route_api.php`)側のコードから呼び出せるか。
3. ポイント付与に伴う副作用(通知が飛ぶ、ログに記録される等)はあるか。
4. `registUser`(`Class_UserApi.php`)の処理フローのどこに初期ポイント付与を差し込むのが自然か(`system_id`が確定した直後、等)。

調査結果は`.scratch/stage3-gacha-implementation/research/point-granting-mechanics.md`に保存する。

## Answer

`/research`サブエージェントが調査完了。詳細は[research/point-granting-mechanics.md](../research/point-granting-mechanics.md)。

**再利用すべき関数**: `Point::addBalance($system_id, $target_id, $pay_category, $add_point)`(`Class_Point.php:213-247`)。セッション/UI非依存の純粋な関数で、`free.php`/`Class_Plan.php`から既に直接呼ばれている実績あり。管理画面の手動付与(`mng/user/sub_point_update.php`)は別の通貨(`sub_point`)を操作するもので**参考にならない(赤ニシン)**。副作用は`point_log`行の記録のみ(通知・メール・オートメーション発火なし——課金時の`Deposit::addBalance`とは対照的)。

**⚠️ 重大な訂正: 「新規登録時はポイント0円」という前提が誤りだった**

[stage3-gacha-home/issues/01](../../stage3-gacha-home/issues/01-gacha-economy-model.md)の決定時、「`registUser`に初期ポイント付与ロジックは一切ない」と判断していましたが、これは調査不足による誤りでした。実際には`User::tempRegist`(`Class_User.php:475-496`)が、`user_balance`テーブルへの初期行挿入時に、**`general_config`テーブルの`initial_points`という設定(性別ごとに男性用/女性用の初期値をJSONで持つ)から金額を読み取り、登録直後のユーザーに自動的に初期残高を付与しています**。ただしこれは`point_log`に記録されない「サイレントな」付与です。

これにより、stage3-gacha-homeの以下の決定は前提が崩れています:
> 「新規登録時に無料の初期ポイントを自動付与する仕組みを新しく作る」

**この新事実を踏まえて、[stage3-gacha-home/issues/01](../../stage3-gacha-home/issues/01-gacha-economy-model.md)に訂正の追記を行った。** 既存の`initial_points`をそのまま「ガチャのウェルカムボーナス」として使うか、それとは別に`Point::addBalance`で追加のボーナスを上乗せするかは、ビジネス判断として改めてユーザーに確認が必要——[02-spin-endpoint-design](02-spin-endpoint-design.md)のグリリングで扱う。

**もう1つの用途(候補枯渇時のお詫びポイント)は前提に問題なし**: こちらは登録時ではなく利用中のイベントなので、同じ`Point::addBalance`をガチャの新規エンドポイントから呼べばよい。`$pay_category`は`SERVICE_POINT`(101)を流用してもよいが、管理画面の集計で区別したいなら新しい定数(例: `GACHA_RESURFACE_BONUS`)を追加することを推奨。
