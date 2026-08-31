## Destination

[stage3-gacha-home](../stage3-gacha-home/map.md)の決定(財布モデル・除外/クールダウンロジック・演出方針)に基づき、ホーム画面のガチャ機能をバックエンド(bloom本番PHP)+クライアント(Flutter)の両方で実装まで完了させる。bloomにはステージング環境が存在しないため、**本番への安全な変更・検証方法を決めることもこのマップのスコープに含む**(ユーザー判断: バックエンドとクライアントを分けず1つのマップで扱う)。

## Notes

- サービス名: bloom。開発体制: 一人開発。実ユーザーはまだ少ない。
- 前提マップ: [stage3-gacha-home](../stage3-gacha-home/map.md)(決定のみ、このマップが実装を引き継ぐ)、[stage4-match-celebration](../stage4-match-celebration/map.md)(`MatchCelebrationRoute`実装済みだが「未接続」——このマップの実装で接続する)。
- **重大な制約**: `lib/core/network/bloom_api_client.dart`のコメントに明記の通り、bloomにはステージング環境が存在しない(`// No staging environment exists for bloom`)。新しいバックエンドロジックの検証は本番データベースに対して行うことになる。
- bloomバックエンドの実ソース: `/Users/daichi/Documents/blooom関係/dream/`(ユーザー共有、都度参照)。
- 各チケットの解決には`/grilling`と`/domain-modeling`スキルを使うこと。research系チケットは`/research`スキルで解決し、成果物は`.scratch/stage3-gacha-implementation/research/<slug>.md`に保存する。
- **このマップは決定+実装まで含む**(Stage0〜2/4と同じ方針)。

## Decisions so far

- [バックエンド変更を本番に安全に進める方法](issues/01-safe-backend-rollout-strategy.md) — 実際の変更範囲が「新しいPHP定数1つ+新エンドポイント1つ」の追加のみに収まったためリスクは小さい(後にスキーマ変更自体が不要と判明し、さらにリスクが下がった)。新エンドポインはクライアントが呼ぶまで無害、検証は開発者のテストアカウントで本番に対して直接行う(Stage1/2/4と同じ方針)。
- [PayCostの仕組み調査](issues/03-paycost-mechanics-research.md) — ガチャの消費コストに`pay_cost`テーブルのスキーマ変更は不要と判明。`Class_PayCost.php`に新しい定数(`GACHA_SPIN = 42`)を1つ追加するだけで、既存の`Point::checkBalanceFree`/`usePointFree`(固定額パラメータ渡しパターン)をそのまま再利用できる。
- [ポイント付与の仕組み調査](issues/04-point-granting-mechanics-research.md) — お詫びボーナス付与には`Point::addBalance`(副作用なし、`free.php`等で既に使用実績あり)を再利用できる。**重要な訂正**: 「新規登録時はポイント0円」という stage3-gacha-home の前提が誤りと判明——`User::tempRegist`が`general_config.initial_points`(性別別)から既に初期残高をサイレント付与している。既存の仕組みをそのままウェルカムボーナスとして使うことに決定([02](issues/02-spin-endpoint-design.md)参照)。
- [spinGachaエンドポイントの設計](issues/02-spin-endpoint-design.md) — 新規`execute_function`として設計。課金より先に候補の有無を確認する処理順序(候補探索→残高チェック→消費→リサイクル時のみお詫びボーナス)。マッチ判定はこのエンドポイントの範囲外とし、結果カードの「いいね」ボタンから既存の`sendLike`を呼ぶ形に統一。**「見た」記録は新規テーブルを作らず、ポイント消費の副作用として既に書き込まれる`point_log`(`pay_category=GACHA_SPIN`)を流用する**方式に変更(検討の結果、専用テーブルは不要と判断)。`registUser`側の変更は不要になった。
- [ホーム画面ガチャUI実装](issues/05-home-gacha-ui-implementation.md) — 実装完了。新規`lib/features/gacha/`フィーチャーフォルダ。`MatchData`/`MatchProfileCard`(matches機能)を再利用し新規ドメインモデルの重複作成を回避。
- [マッチ成立演出への接続](issues/06-connect-match-celebration.md) — 実装完了。ガチャ結果カードの「いいね」ボタンが`sendLike`を呼び、`status: 'match'`なら`MatchCelebrationRoute`へ遷移。副次的に`matchListControllerProvider`のキャッシュ古さ問題(offstageタブでも状態が生き続ける)を発見し、`ref.invalidate()`で解消。stage4-match-celebrationの「未接続」を解消した。

**これでstage3-gacha-implementationマップの全チケットが解決し、destinationに到達した。**

## Not yet specified

- クライアント側の演出アニメーションの細部(色・タイミング等)——[stage3-gacha-home/issues/03](../stage3-gacha-home/issues/03-ui-flow-design.md)で「Flutter標準機能」とだけ決まっており、具体的な実装は着手時に詰める。
- Stage4への接続以降、実際にリリースするタイミング・ロールアウト方法(全員に一斉公開か、段階的か)——このマップは「動く状態にする」までが対象で、リリース運用は対象外(下記Out of scope参照)。

## Out of scope

- ガチャ1回あたりの具体的なポイント数、初期付与ポイント量、クールダウン期間の長さの決定。理由: [stage3-gacha-home](../stage3-gacha-home/map.md)で「ビジネス判断、後で決定」と既に整理済み。このマップでは設定可能な値として実装するに留め、具体的な数値はプレースホルダー/仮値を使う。
- 本番リリース後の運用(価格調整、異常検知、監視体制の構築)。理由: 「動く状態にする」ことがdestinationであり、運用はその先の関心事のため。
