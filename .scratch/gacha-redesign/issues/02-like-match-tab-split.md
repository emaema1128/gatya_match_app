Type: grilling
Status: resolved

## Question

現行のボトムナビ「Like」タブは中身が実質「マッチ一覧」(`MatchListScreen`)である。「いいねを送ったがまだマッチしていない相手」の一覧(いいねタブ)と「マッチ済みの相手」の一覧(マッチタブ)を分けたい。ナビ構造・バックエンドの実現方法を決定する。

含めるべき論点:

1. ボトムナビのタブ数を増やすか、既存の「Like」タブ内でセグメント分けするか。
2. 「いいね送信済み・未マッチ」の一覧を取得する方法がbloomバックエンドに既にあるか(要調査)。
3. マッチ成立時に、その相手がいいねタブから消えてマッチタブに現れる仕組みをどう実現するか。

## Answer

1. **ボトムナビの数は変えない。既存の「Like」タブの中に、上部タブ/セグメントで「いいね」「マッチ」の2つを切り替えられるようにする。**
2. bloomバックエンド調査(Exploreサブエージェントによる`Class_Likes.php`/`Class_Matches.php`/`route_api.php`調査)の結果、**既存の`Likes::getSendLikeList`がそのまま使える**と判明。`status IN (1,2,4)`(`STATUS_MATCH=3`を除く)で「自分が送った未マッチのいいね」を返すため、新規API追加は不要。
3. `sendLike`のマッチ成立処理は、既存の`likes`行を`status=3`(MATCH)にUPDATEするだけなので、**`getSendLikeList`(いいねタブ)と`getMatchList`(マッチタブ)を単純に切り替えて表示するだけで、マッチ成立時の自動移動が実現できる**見込み——追加のバックエンド実装は不要。

`STATUS_REJECT=4`は管理者専用の非表示フラグと推測される(通常のユーザーフローでは発生しない)。いいねタブの表示から除外するかどうかは[issue06](06-like-match-tab-implementation.md)の実装時に判断する。

## 訂正

上記2は**「いいねタブ=自分が送った未マッチのいいね」という前提が誤り**だったため覆った。ユーザーからの直接指示により、「いいね」タブは**自分が受け取った・未マッチのいいね**(`Likes::getReceivedLikeList`、`status IN (1,2)`)を表示する仕様に変更。`getReceivedLikeList`のWHERE句は元から`STATUS_REJECT=4`を含まないため、上記の「除外するかどうか」の論点自体が不要になった。[issue06](06-like-match-tab-implementation.md)で実装を修正済み。
