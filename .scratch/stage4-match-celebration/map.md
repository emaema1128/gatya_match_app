## Destination

マッチが成立した相手を確認できる状態にする——「マッチしました!」演出画面と、マッチした相手の一覧画面を実装まで完了させる。対象は「自分の操作でその場でマッチが成立するケース」のみ(bloomバックエンドには、実ユーザー同士のマッチ成立を相手に知らせる通知経路が現状存在しないため、非同期に成立するケースの検知はStage6(プッシュ通知)に委ねる)。bloomバックエンドへの変更は一切不要(`getMatchList`等の既存APIのみで完結)なため、**このマップは決定+実装まで含む**(Stage0〜2と同じ方針、Stage3/auth-method-redesignとは異なる——ユーザー判断)。

## Notes

- サービス名: bloom。前提マップ: [stage0-foundation](../stage0-foundation/map.md)、[stage1-auth-screens](../stage1-auth-screens/map.md)、[stage2-profile-creation](../stage2-profile-creation/map.md)、[stage3-gacha-home](../stage3-gacha-home/map.md)(ガチャは決定のみで未実装)。
- bloomバックエンドの実ソース調査で判明した事実:
  - `getMatchList`(`Class_Matches.php`)は`SELECT m.*, u.*, ca.alias ...`で相手の`user`行をフルに返す。列名の重複により`system_id`キーは相手側の値で上書きされる。
  - `sendLike`のマッチ成立レスポンス(`status: 'match'`)には相手のプロフィール情報が含まれない(IDのみ)——別途`getMatchList`等で取得する必要がある。
  - `Notification::sendTypeLikeOrMatch`(`KEY_MATCH`)は`Class_Action.php`(サポーター/運営キャラクターのアクション自動化システム)からしか呼ばれておらず、実ユーザー同士の`sendLike`にはマッチ通知を送るコードが一切ない。
  - `fcm_device_token`は`registUser`/`login`に既に組み込まれ、`Class_PushNotification.php`という送信クラスも存在する——プッシュ通知の土台自体はバックエンドにあるが、実ユーザーのマッチには配線されていない(Stage6の対象)。
- 各チケットの解決には`/grilling`スキルを使った。
- **このマップは決定+実装まで含む**。チケットの解決 = 決定 + その場での実装、が期待値。

## Decisions so far

- [非同期マッチ検知のスコープ](issues/01-match-detection-scope.md) — Stage4は「自分の操作でその場で成立するケース」のみを扱う。アプリを閉じている間に相手が後からいいねを返して成立するケースの検知・通知は、プッシュ通知基盤を作るStage6に委ねる(ポーリングは作らない——Stage6で作り直しになるため)。
- [マッチ画面の設計と実装](issues/02-match-screens-implementation.md) — 実装完了。「マッチしました!」画面は`sendLike`のmatch応答からの遷移を前提に`matchedSystemId`を受け取り、`getMatchList`から該当データを探して表示する(演出はFlutter標準アニメーション)。次のアクションは「マッチ一覧を見る」ボタンのみ(チャット機能はStage5未着手のため保留)。マッチ一覧画面はホームシェルの3番目のタブとして追加、0件時は「ホームでガチャを回してみましょう」という空メッセージを表示。ポイント残高表示はStage3で決定済みの通りホーム画面限定とし、Stage4の画面には追加しない。

**これでstage4-match-celebrationマップの全チケットが解決し、destinationに到達した。**

## Not yet specified

- Stage6(プッシュ通知)側で、実ユーザー同士のマッチ成立時にbloomバックエンドから通知を送る配線(`Notification::sendTypeLikeOrMatch`を実ユーザーの`sendLike`フローにも組み込む等)。

**追記**: `MatchCelebrationRoute`への未接続は解消済み。[stage3-gacha-implementation/issues/06](../stage3-gacha-implementation/issues/06-connect-match-celebration.md)で、ガチャ結果カードの「いいね」ボタンから接続した。

## Out of scope

- 非同期に成立するマッチの検知・通知。理由: プッシュ通知基盤(Stage6)の関心事であり、今ポーリング等の繋ぎを作ると二度手間になるため。
- マッチ成立後のメッセージ送信導線。理由: bloomの「チャット」は実質的に既存の`sendMail`(旧来のメール型のやり取り)である可能性が高く、Stage5でその設計をきちんと詰める前に暫定実装を作ると作り直しになるため。
