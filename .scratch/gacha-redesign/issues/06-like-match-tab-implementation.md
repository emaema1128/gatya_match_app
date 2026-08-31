Type: task
Blocked by: 02
Status: resolved

## Question

[02-like-match-tab-split](02-like-match-tab-split.md)の決定を前提に、既存の「Like」タブ(`MatchesBranchData`/`MatchListScreen`)を「いいね」「マッチ」の2セグメントに分割実装する。

含めるべき論点:

1. `MatchListScreen`を、上部タブ/セグメントで「いいね」「マッチ」を切り替えられるUIに変更する。
2. 「いいね」セグメントは新規`getSendLikeList`呼び出し・新規コントローラ(`match_list_controller.dart`と同じパターン)で実装する。
3. `STATUS_REJECT=4`の扱い(いいねタブの表示から除外するかどうか、[02](02-like-match-tab-split.md)のAnswer末尾を参照)。
4. マッチ成立時にいいねタブ側のキャッシュが古いまま残らないか([stage3-gacha-implementation/issues/06](../../stage3-gacha-implementation/issues/06-connect-match-celebration.md)で見つかった`matchListControllerProvider`のキャッシュ古さ問題と同種の懸念——`ref.invalidate()`パターンを踏襲できるか確認する)。
5. 空状態メッセージ(いいねタブ・マッチタブそれぞれ)。

決定+実装(このマップの方針)。

## Answer

実装完了。バックエンド変更なし([02](02-like-match-tab-split.md)の決定通り既存`getSendLikeList`/`getMatchList`をそのまま使用)。

**Flutter**:
- `MatchData.fromSendLikeEntry`ファクトリを追加(`match_data.dart`)。`getSendLikeList`の1件は`SELECT l.*, u.*`(`likes`テーブルは`system_id`列を持たないため列重複なし)で、`fromMatchListEntry`と同じ形状——パース処理をそのまま共用。
- 新規`SendLikeListController`(`send_like_list_controller.dart`、`match_list_controller.dart`と同じ`@riverpod`パターン)を追加。`getSendLikeList`のレスポンスを取得し、`entry['status'] == 4`(`STATUS_REJECT`)の行を表示から除外してから`MatchData`へ変換する。
- `MatchListScreen`を`ConsumerStatefulWidget`化し、`SegmentedButton<_LikeMatchSegment>`(既存の性別選択などと同じ、アプリ内で使われているコンポーネント)で「いいね」「マッチ」を切り替えるUIに変更。ボトムナビの数・ルートは無変更。選択中セグメントはウィジェットのStateで保持するため、`StatefulShellRoute`の各ブランチNavigatorが保持される限りタブ往復後も選択状態を保つ。
- `_buildList`/`_buildEmptyState`/`_buildErrorState`は両セグメントで共通化(トップレベル関数化)し、空状態メッセージのみセグメントごとに出し分け。
- `GachaController.likeCandidate()`に`ref.invalidate(sendLikeListControllerProvider)`を追加(マッチの有無に関わらず、`sendLike`は常に`likes`行を追加/更新するため)。マッチ成立時は既存通り`matchListControllerProvider`も無効化——[stage3-gacha-implementation/issues/06](../../stage3-gacha-implementation/issues/06-connect-match-celebration.md)で見つかった`StatefulShellRoute`+`autoDispose`のキャッシュ古さ問題と同種の対策。

**検証**: `dart analyze lib`はクリーン(新規エラーなし、既存の無関係な指摘5件のみ——stage3-gacha-implementation/issues/05・gacha-redesign/issues/05と同じ既知の5件)。`flutter test`のウィジェットテスト(一時ファイル、確認後削除)で、`bloomApiClientProvider`をフェイクに差し替え、①いいねタブが`STATUS_REJECT=4`の行を除外して表示、②マッチセグメントへの切り替えで`getMatchList`の結果に切り替わる、③セグメントを往復しても表示内容が正しく保たれる、の3シナリオを確認。本番APIへの実疎通は未確認(bloomにステージング環境がないため、他チケットと同様に実機での確認を推奨)。

**副次的に見つかった未解決の論点**: マップのDestinationは「ガチャ結果カード・**一覧**のカードをタップ」してプロフィール閲覧できることを求めているが、`MatchProfileCard`(いいね/マッチタブで使う共通カード)には現状タップハンドラがなく、一覧側からのプロフィール閲覧導線は未実装(ガチャ排出画面側は[issue05](05-gacha-home-screen-revamp-implementation.md)でボトムシート方式により実装済み)。ボトムシートを流用するか独立画面にするかは未決定のため、[issue07](07-list-card-profile-view-navigation.md)として切り出した。

## 訂正

[issue02](02-like-match-tab-split.md)の前提([訂正](02-like-match-tab-split.md#訂正)参照)が「いいねタブ=送信済み」から「いいねタブ=受け取った」に覆ったため、上記実装をユーザーからの直接指示で修正した。

- `MatchData.fromSendLikeEntry` → `MatchData.fromReceivedLikeEntry`にリネーム(`getReceivedLikeList`の1件も`SELECT l.*, u.*, ca.alias`で列重複なし、形状は実質同一)。
- `SendLikeListController`(`send_like_list_controller.dart`) → `ReceivedLikeListController`(`received_like_list_controller.dart`)にリネームし、呼び出しAPIを`getSendLikeList`→`getReceivedLikeList`に変更。`getReceivedLikeList`のWHERE句は元から`status IN (1,2)`で`STATUS_REJECT=4`を含まないため、旧実装にあったクライアント側の除外フィルタは削除(発生しない条件のフィルタになるため)。
- `MatchListScreen`の`_LikeMatchSegment.sent` → `.received`にリネーム、`_SendLikeTab` → `_ReceivedLikeTab`にリネーム。空状態メッセージも「まだ送信済みのいいねがありません」→「まだいいねが届いていません。」に変更。
- `GachaController.likeCandidate()`の無効化ロジックを見直し。「受け取ったいいね」一覧は自分がいいねを送るだけでは変化しない(`getReceivedLikeList`は`to_system_id = 自分`が条件)——マッチ成立時のみ、相手の`likes`行がMATCHになりこの一覧から消えるため、`ref.invalidate(receivedLikeListControllerProvider)`は`matched`分岐の中に移動(旧実装の「毎回無効化」は不要になったため削除)。

**検証**: `dart analyze lib`は引き続きクリーン(同じ既知5件のみ)。一時ウィジェットテスト(確認後削除)で、いいねタブが`getReceivedLikeList`のレスポンスを表示すること、マッチセグメントとの切り替えが正しく動くことを再確認。
