Type: task
Blocked by: 05
Status: resolved

## Question

[05-home-gacha-ui-implementation](05-home-gacha-ui-implementation.md)で実装したガチャのスピン結果が「マッチ成立」だった場合に、[stage4-match-celebration](../../stage4-match-celebration/map.md)で実装済みの`MatchCelebrationRoute`へ実際に遷移させる。stage4のmap.mdの「Not yet specified」に記載されていた未接続部分を解消する。

含めるべき論点:

1. スピンAPIのレスポンスから「マッチが成立したか」をどう判定するか(既存の`sendLike`の`status: 'match'`と同等の情報が返るか、[02](02-spin-endpoint-design.md)の設計次第)。
2. マッチ成立時、`MatchCelebrationRoute(matchedSystemId: ...)`への画面遷移のタイミング(演出アニメーションの後か、代わりか)。

決定+実装(このマップの方針)。

## Answer

実装完了。判定は当初想定通り**このエンドポイント(`spinGacha`)の範囲外**——`spinGacha`はマッチ情報を一切返さない。マッチ成立の判定は、結果カードの「いいね」ボタンが呼ぶ**既存の`sendLike`**のレスポンス(`status == 'match'`)で行う。

遷移タイミング: 演出アニメーションの**代わり**ではなく、いいねボタンを押した直後(`GachaController.likeCandidate()`の結果を見て、`GachaScreen`が`MatchCelebrationRoute(matchedSystemId: candidate.systemId).push(context)`を呼ぶ)。マッチしなかった場合は`SnackBar`で「いいねを送りました」と表示するのみ。

**実装中に見つかった副次的な修正点**: `MatchListController`は`keepAlive`指定なし(autoDispose)だが、ホームシェルは`StatefulShellRoute`のため、以前一度でもマッチタブを開いていると`matchListControllerProvider`が古いキャッシュを持ったまま生き続ける。ガチャ経由でマッチが成立した直後に`MatchCelebrationRoute`へ遷移しても、このキャッシュが古いままだと新しいマッチが見つからない可能性があった。`likeCandidate()`内でマッチ成立時に`ref.invalidate(matchListControllerProvider)`を呼ぶことでこれを解消した。

これでstage4-match-celebrationのmap.mdに残っていた「未接続」の注記が解消された。
