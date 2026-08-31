## Destination

ホーム画面のガチャ体験を刷新する——ガチャボタンを画面中央に配置し、カプセルが転がって排出されるまでの演出を追加した上で、1回のスピンで3人を同時に排出し、比較して1人にだけいいねを送れるようにする(消費ポイントは変更しない、実質増量)。あわせて、ボトムナビ既存の「Like」タブ内に「いいね(受け取った・未マッチ)」「マッチ」の2セグメントを設け、マッチ成立時に自動的にいいねタブから消えてマッチタブに現れるようにする。ガチャ結果カード・一覧のカードをタップすると、そのお相手のプロフィールを閲覧できる新規画面を追加する。stage3-gacha-implementation等と同じ方針で、**このマップは決定+実装まで含む**。

## Notes

- サービス名: bloom。開発体制: 一人開発。
- 前提マップ: [stage3-gacha-home](../stage3-gacha-home/map.md)(ガチャの財布モデル・除外/クールダウンロジックの原案)、[stage3-gacha-implementation](../stage3-gacha-implementation/map.md)(現行の`spinGacha`/`GachaScreen`実装)、[stage4-match-celebration](../stage4-match-celebration/map.md)(現行の「Like」タブ=マッチ一覧画面)、[stage2-profile-creation](../stage2-profile-creation/map.md)(自分用`ProfileScreen`/`ProfileData`)。
- bloomバックエンド(`/Users/daichi/Documents/blooom関係/dream/`)調査で判明した事実:
  - `sendLike`は`likes`テーブルに片方向1行を`status`付きでINSERT(`STATUS_UNREAD=1`/`READ=2`/`MATCH=3`/`REJECT=4`)。マッチ成立時はこの行を`status=3`にUPDATEし、`matches`テーブルに双方向2行を新規INSERTする。
  - 既存の`Likes::getReceivedLikeList`が`status IN (1,2)`(マッチ済み=3を除く)で「自分が受け取った未マッチのいいね」をそのまま返す——新規API追加なしで「いいね」タブに使える(`getSendLikeList`は「自分が送った」側で、issue06実装中は一旦こちらを使ったが、ユーザーの直接指示により「受け取った」側の`getReceivedLikeList`に訂正——issue02/issue06参照)。
  - **[issue03の調査で判明]** `getUserList`/`search`/`getMatchList`/`spinGacha`/`getSendLikeList`/`getReceivedLikeList`は全て`SELECT u.*`でuserテーブルの全カラム(`income_id`/`img2`/`img3`含む)を既に返している。「img1のみ・income_idなし」は`MatchData.fromMatchListEntry`がパースし切れていないクライアント側の制約であり、バックエンドの制約ではない——他人プロフィール閲覧画面はバックエンド変更なしで実現できる。
  - `PayCost::VIEW_PROFILE`が実際に課金される箇所はレガシーPC Web(`profile/view.php`)のみで、モバイルAPI(`route_api.php`)のどこからも呼ばれていない。他人プロフィール閲覧画面への遷移で二重課金が起きるリスクはゼロ(新規に課金コードを書き加えない限り)。
  - **副次的な発見(未確認)**: `MatchData.comment`が読む`entry['comment']`キーは、DBの実カラム名`PR`と食い違っている疑いがあり、既存のガチャ結果カード等で自己紹介文が常に空文字になっているバグの可能性がある(issue05実装時に確認)。
- 各チケットの解決には`/grilling`と`/domain-modeling`を使うこと。プロトタイプ系は`/prototype`、research系は`/research`サブエージェントで解決し、成果物は`.scratch/gacha-redesign/research/<slug>.md`に保存する。
- **このマップは決定+実装まで含む**(今回の変更は新規テーブル等の大きなスキーマ変更を伴わない見込みのため、stage3-gacha-implementationのような「本番への安全なロールアウト戦略」の再検討チケットは今のところ不要と判断。実装が進んで見通しが変わればチケットを追加する)。
- **着手順の希望(ユーザー確認済み)**: UI/演出系(3人排出のスピン体験・プロフィール遷移)を先に、Like/Matchタブ分割は後で良い。ハードなブロッキングでは表現していないが、フロンティアから選ぶ際はこの順を優先すること(チケット番号もこの優先順に合わせて振ってある)。

## Decisions so far

- [3人排出の仕様](issues/01-three-candidate-spin-spec.md) — 消費ポイントは変えず同額で3人排出(実質増量)。選定・除外ロジック(いいね済み/マッチ済み永久除外、見ただけはクールダウン後再登場)は3人それぞれに独立適用。いいね送信は1スピンにつき1人まで。表示形態は後に[issue04](issues/04-capsule-animation-prototype.md)で上書き(下記参照)。
- [Like/Matchタブの構成方針](issues/02-like-match-tab-split.md) — ボトムナビの数は変えず、既存「Like」タブ内に「いいね」「マッチ」のセグメント切り替えを追加。「いいね」は既存`getReceivedLikeList`(**訂正**: 当初`getSendLikeList`=送信済みと決定したが、ユーザーの直接指示により受け取った側に変更)、「マッチ」は既存`getMatchList`をそのまま使い分けるだけで、マッチ成立時の自動移動も追加のバックエンド実装なしで実現できる見込み。
- [他人プロフィール閲覧画面で表示できるデータの調査](issues/03-other-profile-view-data-research.md) — バックエンドは既に候補一覧の生レスポンスにフル情報(income_id/img2/img3含む)を返している(クライアント側のパース不足だった)ため、新画面はバックエンド変更なしで実装可能。`VIEW_PROFILE`課金はモバイルAPIから一切呼ばれておらず二重課金リスクはゼロ。
- [カプセル演出のプロトタイプ](issues/04-capsule-animation-prototype.md) — 3案(同時ドロップ/転がって整列/震えてバースト)をFlutter標準アニメーションのみで試作し「震えてバースト」を採用。ChatGPTで生成したガチャ本体・カプセルの透過PNGイラストを`assets/images/`に追加。**issue01の「3人並べて表示」を上書き**——排出後は写真メイン+プロフィール情報のフルスクリーンスワイプカード(◀▶で移動、上スワイプでいいね、タップでボトムシート)に変更。
- [ホーム画面(ガチャ)刷新の実装](issues/05-gacha-home-screen-revamp-implementation.md) — バックエンド(`GachaApi::spin`、3人排出+`is_recycled`を候補ごとに付与)・クライアント(`GachaScreen`→`GachaRevealScreen`、`MatchData`拡張)ともに実装完了。副次的に見つかっていた`MatchData.comment`のパース漏れ(実カラム`PR`)も修正。
- [Like/Matchタブ分割の実装](issues/06-like-match-tab-implementation.md) — バックエンド変更なし。既存`getReceivedLikeList`/`getMatchList`を`SegmentedButton`で切り替える`MatchListScreen`に刷新、新規`ReceivedLikeListController`追加。マッチ成立時に`matchListControllerProvider`と`receivedLikeListControllerProvider`の両方を無効化。**訂正**: 実装当初は`getSendLikeList`(送信済み)+`STATUS_REJECT`除外フィルタで作ったが、ユーザーの直接指示により`getReceivedLikeList`(受け取った)方式に修正——受け取った側はWHERE句が元からREJECTを含まないためフィルタは不要になった。副次的に「一覧のカードタップでプロフィール閲覧」導線の未実装が判明し[issue07](issues/07-list-card-profile-view-navigation.md)へ切り出し。
- [一覧カードタップでのプロフィール閲覧導線](issues/07-list-card-profile-view-navigation.md) — 新規画面への遷移ではなく、ガチャ排出画面と同じボトムシート方式を採用(画面遷移なし)。`_ProfileDetailsSheet`を`ProfileDetailsSheet`として`features/matches/presentation/`に共通化し、`MatchProfileCard`(いいねタブ・マッチタブ・マッチ成立演出画面の3箇所すべてで共用)にタップハンドラを追加。3箇所とも同じ挙動でタップ可能(ユーザー確認済み)。課金なし。

## Not yet specified

- カプセル演出の細部の追加調整(音・ハプティクス等——今回はタイミング/機構/イラストまで実装したが、効果音・振動フィードバックは未着手)。
- Stage6(プッシュ通知)との連携(いいねを受け取った通知等)。
- `system_id`単体からプロフィールを再取得する必要が出た場合の新規APIケース追加(レガシーPC Webの`Chara::getCharaData`を`route_api.php`に移植する形。現時点では一覧経由のデータで足りるため不要と判断)。

## Out of scope

- ガチャの消費ポイント数そのものの改定・具体的な単価変更。理由: 今回は「同額で3人」と決定済み([issues/01](issues/01-three-candidate-spin-spec.md))で、単価自体のビジネス判断はstage3-gacha-homeの既定方針を継続するため。
- プッシュ通知連携。理由: Stage6の関心事のため。
- チャットへの導線・課金モデルの変更。理由: stage5-chatで決定済みの範囲のため。
