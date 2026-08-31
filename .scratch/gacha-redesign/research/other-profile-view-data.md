Type: research
Status: resolved

# 他人プロフィール閲覧画面のためのbloomバックエンド調査

調査対象: `/Users/daichi/Documents/blooom関係/dream/`(bloom本番PHPバックエンド、読み取り専用で調査)。
関連チケット: `.scratch/gacha-redesign/issues/03-other-profile-view-data-research.md`。

## 要約(先に結論)

- **Q1**: `getUserList`/`search`のSQLは`SELECT u.*`(＋join列少々)で`user`テーブルの全カラムを返す。だが実は`getMatchList`/`spinGacha`(候補取得)・`getSendLikeList`/`getReceivedLikeList`も**全て同じく`SELECT u.*`(または`m.*, u.*`/`l.*, u.*`)で`user`テーブルの全カラムを返している**。つまり`income_id`・`img2`・`img3`は元々どの一覧APIのレスポンスにも既に含まれている。「`img1`のみ・`income_id`なし」という制約はバックエンドのSQLではなく、**Flutter側の`MatchData`クラスがパース時に一部フィールドしか取り出していないことによるクライアント側の制約**である。
- **Q2**: 「他人の`system_id`を指定してフルプロフィールを取る」ための専用モバイルAPI(`route_api.php`)は存在しない。ただし、`getUserData`とほぼ同一構造のSQLを任意の対象`system_id`に対して実行する関数(`Chara::getCharaData($chara_id, $systemid, 'str')`)は**既存コードとして存在する**。ただしこれは`route_api.php`(モバイルJSON API)からは呼ばれておらず、レガシーなPC向けWebページ`profile/view.php`からのみ呼ばれている。したがって、(a)Q1の発見の通りクライアントが既に持っている一覧レスポンスのフル情報を活用するだけで新規バックエンド変更なしに賄える可能性が高く、(b)万一system_id指定での取り直しAPIが必要になっても、`Chara::getCharaData`とほぼ同型のSQLを`route_api.php`に1ケース追加するだけで済む規模——新規API設計というほどの規模ではない。
- **Q3**: `PayCost::VIEW_PROFILE`が実際に課金される箇所は`profile/view.php`(レガシーPC向けWebのプロフィール閲覧ページ)の1箇所のみ。モバイルJSON API(`route_api.php`)およびそこから呼ばれる`UserApi`/`Matches`/`Likes`/`GachaApi`のどのメソッドも`PayCost::VIEW_PROFILE`を呼んでいない。`spinGacha`は独立した`PayCost::GACHA_SPIN`(固定額、`Point::usePointFree`経由)を消費するのみで、`VIEW_PROFILE`とは無関係。したがって現状、モバイルアプリの導線上で「他人プロフィール閲覧画面」に遷移しても`VIEW_PROFILE`が二重に課金されるリスクは**ゼロ**(そもそも一度も呼ばれていないため)。stage3-gacha-homeの決定(「ガチャの消費にはプロフィール閲覧分を含み二重課金しない」)は、将来この画面に`Point::usePoint(..., PayCost::VIEW_PROFILE)`を新規に呼び出すコードを書き加えてしまわないよう予防する方針として維持すればよい。一方、いいね一覧・マッチ一覧からの遷移は「既存の何らかの支払い」を経由していない導線なので、そちらで新たに課金するかどうかは別途の意思決定が必要な未決事項として残る(後述)。

---

## 1. `getUserList`/`search`は何を返すか、`getMatchList`/`spinGacha`より多いか

### 1-1. `getUserList`(`UserApi::getUserList`)

`/Users/daichi/Documents/blooom関係/dream/app/api/Class_UserApi.php:116-157`

```php
$sql = "SELECT u.*, ca.alias AS alias
        FROM user u
        LEFT JOIN support_memo sm ON u.system_id = sm.chara_id AND sm.system_id = :system_id
        LEFT JOIN chara_alias ca ON sm.alias_id = ca.alias_id
        WHERE sex = :sex 
          AND ((support_flag = 1 AND chara_search_enable = 1) OR (support_flag = 0 AND member_status = $member_status))
          AND chara_enable = 1
        $where_str ORDER BY latest_send_date DESC $limit_sql";
```

### 1-2. `search`(`UserApi::searchUser`)

`/Users/daichi/Documents/blooom関係/dream/app/api/Class_UserApi.php:159-223`

```php
$sql = "SELECT
          u.*,
          pa.*,
          ca.alias
        FROM user u
          LEFT JOIN profile_age pa ON u.age_id = pa.age_id
          LEFT JOIN support_memo sm ON u.system_id = sm.chara_id AND sm.system_id = :system_id
          LEFT JOIN chara_alias ca ON sm.alias_id = ca.alias_id
        WHERE ((support_flag = 1 AND chara_search_enable = 1) OR (support_flag = 0 AND member_status = 1))
          AND chara_enable = 1
          $where_str
        ORDER BY $order
        LIMIT 300";
```

どちらも`u.*`——`user`テーブルの全カラムをそのまま返す。`user`テーブルのDDL(`/Users/daichi/Documents/blooom関係/dream/mysqldump/dream.sql:4346`以下)には`income_id`・`img1_path`/`img1_check`/`img1_compress_path`・`img2_*`・`img3_*`・`address_id`・`age_id`・`PR`(自己紹介文相当のカラム名)・`username`・`sex`などが全て含まれる。`search`はさらに`profile_age`テーブル(`age_item`という人間可読な年齢帯文字列)をjoinしている点だけが`getUserList`との差分。

### 1-3. `getMatchList`/`spinGacha`(候補取得)も同じく`u.*`

`getMatchList`(`/Users/daichi/Documents/blooom関係/dream/Class_Matches.php:29-45`):

```php
$sql = "SELECT m.*, u.*, ca.alias AS alias
        FROM matches m
        LEFT JOIN user u ON m.match_system_id = u.system_id
        LEFT JOIN support_memo sm ON m.match_system_id = sm.chara_id AND sm.system_id = :system_id
        LEFT JOIN chara_alias ca ON sm.alias_id = ca.alias_id
        WHERE m.system_id = :system_id AND m.status = :status ORDER BY m.created_at DESC";
```

`spinGacha`の候補探索(`/Users/daichi/Documents/blooom関係/dream/app/api/Class_GachaApi.php:54-121`、`findFreshCandidate`/`findRecycledCandidate`)も両方とも:

```php
$sql = "SELECT u.* FROM user u
        WHERE u.sex = :sex
          AND u.chara_enable = 1
          ...";
```

参考までに、まだFlutter側に画面のない「いいね一覧」系も同様:

`Likes::getSendLikeList`/`Likes::getReceivedLikeList`(`/Users/daichi/Documents/blooom関係/dream/Class_Likes.php:90-120`)

```php
// getSendLikeList
$sql = "SELECT l.*, u.*
        FROM likes l
        JOIN user u ON l.to_system_id = u.system_id
        WHERE l.from_system_id = :system_id AND l.status IN (1,2,4)
        ORDER BY l.created_at DESC";

// getReceivedLikeList
$sql = "SELECT l.*, u.*, ca.alias AS alias
        FROM likes l
        JOIN user u ON l.from_system_id = u.system_id
        LEFT JOIN support_memo sm ON l.from_system_id = sm.chara_id AND sm.system_id = :system_id
        LEFT JOIN chara_alias ca ON sm.alias_id = ca.alias_id
        WHERE l.to_system_id = :system_id AND l.status IN (1,2)
        ORDER BY l.status ASC, l.created_at DESC";
```

### 1-4. 結論

バックエンドのSQLレベルでは、`getUserList`・`search`・`getMatchList`・`spinGacha`・`getSendLikeList`・`getReceivedLikeList`は**全て`user`テーブルの全カラム(`u.*`)を返しており、情報量に実質差はない**。`search`だけ`profile_age`のjoinで年齢の人間可読文字列(`age_item`)が1つ増える程度。

したがって、チケットの前提にあった「`getMatchList`/`spinGacha`はimg1系1枚のみ・income_idなし」は**バックエンドAPIの制約ではなく、Flutter側`MatchData`クラス(`/Users/daichi/app開発/flutter/gatya_match_app/lib/features/matches/domain/match_data.dart`)がレスポンスの一部フィールドしかパースしていないことによるクライアント側の制約**である。実際、`MatchData.fromMatchListEntry`は`entry['img1_compress_path'] ?? entry['img1_path']`だけを読み、`income_id`・`img2_*`・`img3_*`は一切参照していない(同ファイル29-40行目)。一方で自分用の`ProfileData.fromUserData`(`/Users/daichi/app開発/flutter/gatya_match_app/lib/features/profile/domain/profile_data.dart:26-41`)は`income_id`と`img1〜3`の3枚を全て読んでいる——これと同じ読み取りロジックを、`getMatchList`/`spinGacha`/(将来の)いいね一覧のレスポンスにも適用すれば、バックエンドを一切変更せずにフル情報を取り出せる可能性が高い。

**補足の発見(未確認点あり)**: `MatchData.fromMatchListEntry`は`entry['comment']`を読んでいるが(37行目)、`user`テーブルのDDLに`comment`という列名は存在せず、自己紹介文に相当する列は`PR`である(`registUser`時、クライアントが送る`comment`フィールドは`Class_UserApi.php:36` `$PR = $post_data['comment'];`で`PR`列に保存されている)。そのため`getMatchList`/`spinGacha`の生レスポンスには`comment`キーは存在せず`PR`キーとして入っているはずで、現状の`MatchData.comment`は常に空文字(`?? ''`のフォールバック)になっている可能性が高い。これは今回の3つの質問の直接の対象ではないが、新画面のデータ設計時に`PR`キーを見るよう合わせて直す価値がある副次的な発見として記載する(実際のHTTPレスポンス生データまでは今回確認していないため「未確認」)。

---

## 2. 他人の`system_id`でフルプロフィールを取得できる既存APIはあるか

### 2-1. モバイルJSON API(`route_api.php`)には存在しない

`route_api.php`の`getUserData`ケース(`/Users/daichi/Documents/blooom関係/dream/app/api/route_api.php:60-63`):

```php
case 'getUserData':
  $user_data = User::getUserData($system_id, 'str');
  $return_data = json_encode(['result' => '1', 'data' => ['user_data' => $user_data]]);
  break;
```

ここで使われる`$system_id`はリクエスト先頭の`$post_data['system_id']`であり、同ファイル35行目の`User::access_token_verification($headers, $system_id)`(実装: `/Users/daichi/Documents/blooom関係/dream/Class_User.php:984-1014`)によって「`app_access_token`が一致し、かつ`system_id`が一致する行がuserテーブルにあるか」で検証される。つまりこの`system_id`は**常に呼び出し本人のsystem_id**であり、他人の`system_id`を入れてもアクセストークン検証で弾かれる(他人のトークンを持っていない限り)。ゆえに`getUserData`は自分専用であり、他人のフルプロフィールを取る用途には使えない。

他の`target_id`ベースのケース(`getLikeData`・`getUserRequestData`・`sendMail`等)は`target_id`を別フィールドとして受け取るパターンだが、これらは「そのユーザーとの関係(いいね状態、申請状態、メール送信)」を扱うだけで、対象ユーザーの**フルプロフィール**を返すケースは`route_api.php`中に存在しない(全674行を確認済み)。

### 2-2. レガシーPC向けWebには「ほぼ同型」の実装がすでに存在する

`profile/view.php`(レガシーなPC向け一般公開Webページ、Smartyテンプレートで描画)は、任意の対象(`$_GET['targetid']`)のフルプロフィールを表示する既存機能であり、そこで使われているのが`Chara::getCharaData($targetid, $system_id, 'str')`である。

`/Users/daichi/Documents/blooom関係/dream/Class_Chara.php:7-53`:

```php
public static function getCharaData($chara_id,$systemid=NULL,$datatype=NULL){
  $dbh = DBconnect::connect();
  if( $datatype == "str"){
    $sql =
    "SELECT
       u.*
      ,pag.age_item
      ,pi.income_item
      ,pad.address_item
      ,ca.alias
      ,ct.chara_type_name
      ,cm.memo
      ,rc.receiver_count
    FROM user u
      LEFT JOIN profile_age pag ON u.age_id = pag.age_id
      LEFT JOIN profile_income pi ON u.income_id = pi.income_id
      LEFT JOIN profile_address pad ON u.address_id = pad.address_id
      LEFT JOIN support_memo sm ON u.system_id = sm.chara_id AND sm.system_id = :system_id
      LEFT JOIN chara_alias ca ON sm.alias_id = ca.alias_id
      LEFT JOIN chara_type ct ON u.chara_type_id = ct.chara_type_id
      LEFT JOIN chara_memo cm ON u.system_id = cm.chara_id
      LEFT JOIN (
        SELECT to_id, COUNT(DISTINCT from_id) AS receiver_count
        FROM mail
        WHERE to_id = :chara_id
        GROUP BY to_id
      )rc ON rc.to_id = u.system_id
    WHERE u.system_id = :chara_id
    LIMIT 1";
  }else{
    $sql = "SELECT * FROM user WHERE system_id = :chara_id AND support_flag = 1 LIMIT 1"; // int
  }
  ...
}
```

`'str'`指定時は`support_flag`による絞り込みが**ない**ため、サポートキャラクター(運営側の代理アカウント)に限らず一般ユーザーの`system_id`を渡しても機能する(`user`テーブルは実ユーザーとサポートキャラが同居しているため)。呼び出し元は`profile/view.php:103`の`Chara::getCharaData($targetid,$system_id,'str')`で、`User::getUserData`の自分専用版とほぼ同じ列構成(`u.*` + 年齢/収入/居住地の人間可読名 + alias)を、**任意の対象ID**に対して返す。つまり「他人のフルプロフィールを取得する」機能自体はバックエンドに既に存在するが、モバイルアプリが叩く`route_api.php`からは配線されていない、レガシーPC Web専用のコードパスである。

### 2-3. 見通し

- **Q1の発見(既存の一覧APIが元々`u.*`のフル行を返している)を踏まえると、まずはバックエンド変更なしでいける可能性が高い**。ガチャ結果カード・マッチ一覧のどちらも「タップ元の画面が直前に取得した一覧レスポンスの1行」を持っているはずなので、その行をそのまま新しい`OtherProfileData`的なDartモデルに渡せば、`income_id`・`img2`・`img3`を含むフル情報を表示できる。バックエンド変更もSQL拡張も不要。
- 唯一バックエンド側の対応が要るとすれば、「一覧経由ではなく`system_id`だけで再取得したい」ケース(ディープリンク、キャッシュ切れ後の再訪問、最新情報への更新等)。その場合でも、`Chara::getCharaData`とほぼ同型のSQL(`SELECT u.*, pag.age_item, pi.income_item, pad.address_item ... WHERE u.system_id = :target_id`)を`route_api.php`に1ケース追加するだけで足りる規模——**新規API設計というほどの規模ではなく、既存の`getUserData`/`Chara::getCharaData`パターンのコピー+`target_id`化**に近い。
- 唯一の注意点は認可: `route_api.php`のトップレベル`system_id`は常に呼び出し本人であり、対象は`target_id`のような別フィールドで渡す設計にする必要がある(既存の`getLikeData`・`getUserRequestData`等と同じパターンを踏襲すればよい)。またブロック関係(`contact_ng_charas`)のチェックを`getCharaData`は行っていない点も、新規追加時は`getUserList`等に倣ってWHERE句にNG考慮を入れるかどうかの検討が要る(現状`profile/view.php`側では`Chara::getCharaData`呼び出し前に`User::getContactNgCharas`で別途チェックしている——`/Users/daichi/Documents/blooom関係/dream/profile/view.php:41-45`)。

---

## 3. `PayCost::VIEW_PROFILE`は実際どこで課金されるか、新画面との関係

### 3-1. 定義

`/Users/daichi/Documents/blooom関係/dream/Class_PayCost.php:8`

```php
const VIEW_PROFILE = 2;
```

### 3-2. 実際に課金(`Point::usePoint`呼び出し)している箇所は1箇所のみ

リポジトリ全体を`VIEW_PROFILE`でgrepした結果:

```
Class_PayCost.php:8:      const VIEW_PROFILE = 2;
Class_PayCost.php:102:      case self::VIEW_PROFILE:              // ← コスト額を取得するswitch文(課金実行ではない)
mng/point/log.php:104:                case PayCost::VIEW_PROFILE:   // ← 管理画面のログ表示ラベル
profile/view.php:53,54,95                                          // ← 唯一の実課金箇所
manage/point/log.php:104:              case PayCost::VIEW_PROFILE:   // ← 管理画面のログ表示ラベル
manage/report/point_consume/report.php:11:  ...['label' => 'プロフィール閲覧'], // ← 管理画面の集計ラベル
```

実際に`Point::usePoint`/`Point::checkBalance`を呼んでいるのは`profile/view.php`のみ:

`/Users/daichi/Documents/blooom関係/dream/profile/view.php:53-98`

```php
// 残高チェック
if( !Point::checkBalance($system_id,PayCost::VIEW_PROFILE,$targetid) ){
  if( !Point::checkMinusBalance($system_id,PayCost::VIEW_PROFILE,$targetid) ){
    // マイナス残高NG（ポイント購入導線へ）
    ...
  }
  if( !Point::checkMinusAgree($system_id) ){
    // マイナス同意画面へ
    ...
  }
}
if( !Point::usePoint($system_id,$targetid,PayCost::VIEW_PROFILE) ){
  echo 'ポイントの消費に失敗しました。';
  exit();
}
```

`profile/view.php`は`$system_id = Common::getSystemId()`(PC Web側のセッションベース認証)で動く**レガシーなPC向けWebページ**であり、モバイルアプリが通信する`route_api.php`(JSON API)とは全く別のコードパスである。`mng/point/log.php`・`manage/point/log.php`・`manage/report/point_consume/report.php`はいずれも運営管理画面でのログ表示・集計ラベル出力のみで、課金トリガーではない。

`route_api.php`(全674行を確認済み)、`Class_UserApi.php`(`getUserList`/`searchUser`/`registUser`等)、`Class_Matches.php`(`getMatchList`)、`Class_Likes.php`(`sendLike`/`getSendLikeList`/`getReceivedLikeList`/`getLikeData`)、`Class_GachaApi.php`(`spin`)のいずれにも`PayCost::VIEW_PROFILE`の参照はない。`spinGacha`が消費するのは独立した定数`PayCost::GACHA_SPIN = 42`のみで(`/Users/daichi/Documents/blooom関係/dream/Class_PayCost.php:29`、コメントに`// ガチャ1回分の消費。getPayCategoryCost()のswitchには追加しない(pay_costテーブル不使用、固定額はGachaApi側で保持)`とある通り、`pay_cost`テーブル経由の`getPayCategoryCost`ルックアップを使わず`Point::usePointFree`で固定額を消費する別系統)、`VIEW_PROFILE`の値には一切依存しない。

補足: 現在のDBダンプ(`/Users/daichi/Documents/blooom関係/dream/mysqldump/dream.sql`、2026年8月21日時点)では`pay_cost`テーブルの唯一のレコード(`pay_cost_id=1`、`初期減算ポイント`)は`view_profile`列を含む全項目が`0`になっている。つまりこのダンプの時点では、たとえ`VIEW_PROFILE`を呼んでも実際の消費ポイントは0円という設定である(将来的に運営が別の`pay_cost_id`を設定・変更する可能性はあるため、これは「現時点の設定値」であり恒久的な保証ではない。本番の最新値そのものは未確認)。

### 3-3. stage3-gacha-homeの決定との関係、二重課金リスクの整理

stage3-gacha-homeの決定(`.scratch/stage3-gacha-home/map.md`、Decision 1): 「ガチャの消費ポイントにはプロフィール閲覧分も含み、既存の`PayCost::VIEW_PROFILE`との二重課金はしない」。

今回の調査結果を踏まえると:

1. **ガチャ結果カードからの遷移**: `spinGacha`は既に`PayCost::GACHA_SPIN`(固定額)を消費済みで、`VIEW_PROFILE`は元々どこにも呼ばれていない。したがって「他人プロフィール閲覧画面」に遷移する際に**新たに`Point::usePoint(..., PayCost::VIEW_PROFILE)`を呼び出すコードを書き加えない限り**、二重課金は物理的に起こり得ない。stage3-gacha-homeの決定は、実装時にこの新しい呼び出しを追加してしまわないための予防的な設計方針として維持すればよい——つまり「ガチャ結果カードタップ→プロフィール閲覧画面」の遷移は**追加課金なしの単純な画面遷移**として実装するのが一貫している。
2. **マッチ一覧からの遷移**: `getMatchList`・`sendLike`(マッチ成立含む)には元々一切のPayCost呼び出しがない(`Class_Matches.php`・`Class_Likes.php`を確認済み、grepでも無ヒット)。マッチ成立は「両想い」を意味するので、双方が既にお互いのプロフィールをある程度認識した上での関係であり、ここから「他人プロフィール閲覧画面」を開く行為に新たに課金するかどうかは、stage3-gacha-homeのどの決定にも含まれていない**未決事項**である。少なくとも「二重課金」という意味でのリスクは(元々何も課金されていないので)存在しないが、「マッチ相手のプロフィールを見るたびに新規で課金するのか、無料にするのか」は別途決めるべき論点として残る。
3. **いいね一覧からの遷移**: 同様に`getSendLikeList`・`getReceivedLikeList`にもPayCost呼び出しは一切ない。マッチ一覧と同じ構造の未決事項が残る(いいねをくれた相手のプロフィールを見る行為に課金するか)。なお現状Flutter側に「いいね一覧」のfeatureディレクトリ自体がまだ存在しない(`lib/features/`配下を確認、`matches`はあるが`likes`は未実装)ため、この導線はまだ実装前の想定段階である。
4. 全体として、**このバックエンドには「一覧・検索・マッチ・いいね・ガチャ、いずれの既存導線でも`VIEW_PROFILE`は使われていない」という一貫した実態がある**。`VIEW_PROFILE`はレガシーPC Web専用の枯れた課金カテゴリであり、モバイルアプリの新しい「他人プロフィール閲覧画面」に接続する必然性はない。二重課金を避ける最も単純な方針は、「新画面への遷移そのものには課金ロジックを一切追加しない(閲覧は無料)」とし、既存のガチャ・いいね・マッチという行為自体の消費ポイント(またはその無料方針)だけで完結させることである。これはstage3-gacha-homeで既に確認されている「`sendLike`は無料・回数制限なし」「スタミナ制の前例はbloom全体にない」という事実(map.md記載)とも整合する。

---

## 参照した主なファイル

- `/Users/daichi/Documents/blooom関係/dream/app/api/route_api.php`(674行、全文確認)
- `/Users/daichi/Documents/blooom関係/dream/app/api/Class_UserApi.php`(`getUserList`/`searchUser`/`registUser`/`login`等)
- `/Users/daichi/Documents/blooom関係/dream/app/api/Class_GachaApi.php`(`spin`/`findFreshCandidate`/`findRecycledCandidate`)
- `/Users/daichi/Documents/blooom関係/dream/Class_Matches.php`(`getMatchList`/`getMatchData`)
- `/Users/daichi/Documents/blooom関係/dream/Class_Likes.php`(`sendLike`/`getSendLikeList`/`getReceivedLikeList`/`getLikeData`)
- `/Users/daichi/Documents/blooom関係/dream/Class_User.php`(`getUserData`/`access_token_verification`)
- `/Users/daichi/Documents/blooom関係/dream/Class_Chara.php`(`getCharaData`)
- `/Users/daichi/Documents/blooom関係/dream/Class_Point.php`(`checkBalance`/`checkBalanceFree`/`usePoint`/`usePointFree`/`addBalance`)
- `/Users/daichi/Documents/blooom関係/dream/Class_PayCost.php`(定数定義・`getPayCategoryCost`)
- `/Users/daichi/Documents/blooom関係/dream/profile/view.php`(`VIEW_PROFILE`の唯一の実課金箇所、レガシーPC Web)
- `/Users/daichi/Documents/blooom関係/dream/mysqldump/dream.sql`(`user`テーブル・`pay_cost`テーブルのDDL/データ)
- `/Users/daichi/app開発/flutter/gatya_match_app/lib/features/matches/domain/match_data.dart`
- `/Users/daichi/app開発/flutter/gatya_match_app/lib/features/profile/domain/profile_data.dart`
- `/Users/daichi/app開発/flutter/gatya_match_app/.scratch/stage3-gacha-home/map.md`

## 未確認・要注意点まとめ

- `MatchData.comment`が読む`entry['comment']`キーは、バックエンドDDL上は`PR`列であり、生レスポンスに`comment`キーが存在するかは実際のHTTPレスポンスまでは確認していない(未確認)。もし存在しないなら現状`MatchData.comment`は常に空文字になっている可能性が高い。
- `pay_cost`テーブルの`view_profile`列が現在の本番で本当に0のままかどうかは、手元の`mysqldump/dream.sql`(2026年8月21日時点のダンプ)からの推測であり、最新の本番DB値そのものは未確認。
- `Chara::getCharaData`をベースに`route_api.php`へ新ケースを追加する場合、ブロック関係(`contact_ng_charas`)の考慮が同関数内には無い点は、追加実装時に別途手当てが必要(`profile/view.php`側で別途チェックしている点を踏襲する必要がある)。
