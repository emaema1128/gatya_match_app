Type: grilling
Status: resolved

## Question

ガチャを回す操作を実現する、新しいbloom APIエンドポイント(`route_api.php`への新規`execute_function`、例: `spinGacha`)の入出力とサーバー内部の処理フローを設計する。[stage3-gacha-home](../../stage3-gacha-home/map.md)で決まった以下のロジックを、実際のAPI契約に落とし込む:

- 財布モデルでのポイント消費(残高不足ならエラー)。
- 候補選定: いいね済み・マッチ済みの相手を除外、見たがいいねしなかった相手はクールダウン期間中は除外。
- 通常候補が0人ならクールダウン中の「見ただけの人」を1人再表示し、通常通り消費+サービスポイント付与。
- 本当に候補が1人もいなければ空状態を返す。

含めるべき論点:

1. リクエストパラメータ(`system_id`以外に必要なものはあるか)。
2. レスポンスの形(候補のプロフィール情報をこのAPI自体で返すか、既存の`getUserList`的な形式を流用するか)。
3. サーバー内部の処理順序(残高チェック→候補選定→ポイント消費→「見た」記録の書き込み、の順序と、途中で失敗した場合のロールバック)。
4. [03-payCost調査](../research/paycost-mechanics.md)・[04-ポイント付与調査](../research/point-granting-mechanics.md)の調査結果を踏まえて、既存の`Point`/`PayCost`/`Deposit`クラスのどの関数を呼ぶか。

決定+実装(このマップの方針)。

## Answer

新規`execute_function`(`spinGacha`)として設計。

**リクエスト**: `system_id`のみ。他パラメータ不要——候補選定はサーバー側が全て行う。

**処理順序**(課金より先に「見せられる相手がいるか」を確認する):
1. 新規候補を探す(いいね済み/マッチ済み除外、クールダウン中の既出者も除外)
2. いなければ、クールダウン中の「見ただけの人」から1人選ぶ(リサイクル)
3. それもいなければ`status: 'empty'`を返す(課金なし)
4. 候補が見つかった場合、`Point::checkBalanceFree`で残高チェック
5. 不足していれば`status: 'insufficient_points'`を返す(課金なし、候補は見せない)
6. 残高があれば`Point::usePointFree`(`PayCost::GACHA_SPIN`)で消費——この時点で`point_log`に「見た記録」が自動的に残る(下記参照、明示的な記録処理は不要)
7. リサイクル候補だった場合のみ、`Point::addBalance`でお詫びボーナスを追加付与
8. 候補のプロフィール情報+statusを返す

**レスポンス形式**(既存の`sendLike`等に揃える):
```json
{"result": "1", "data": {"status": "revealed|recycled|empty|insufficient_points", "candidate": {...} | null, "user_data": {...}}}
```

**マッチ判定はこのエンドポイントの範囲外**: 「いいね」は別操作(既存の`sendLike`をそのまま呼ぶ)。マッチ成立の判定は結果カードの「いいね」ボタンが呼ぶ`sendLike`のレスポンスで行う——[06-connect-match-celebration](06-connect-match-celebration.md)の接続ポイント。

**訂正(実装時に変更): 新規テーブルは作らず、`point_log`を流用する。** 当初は「誰がいつ見たか」を記録する専用テーブル`gacha_seen`を新設する設計だったが、`Point::usePointFree`がポイント消費の副作用として`point_log`に`system_id`(自分)・`target_id`(見た相手)・`pay_date`(いつ)を既に記録している事実に気づき、これをそのまま「見た記録」として使う方針に変更した。`pay_category = GACHA_SPIN`で絞り込めば同じ情報が得られるため、**スキーマ変更が一切不要**になった(詳細は[Class_GachaApi.php](../../../../../../Documents/blooom関係/dream/app/api/Class_GachaApi.php)の`findFreshCandidate`/`findRecycledCandidate`実装を参照)。クールダウン判定は「`point_log`の該当行のうち、直近の`MAX(pay_date)`が◯日以内か」で行う(具体的な日数はビジネス判断、設定値として実装)。

**ウェルカムボーナス**: [stage3-gacha-home/issues/01の訂正](../../stage3-gacha-home/issues/01-gacha-economy-model.md)により、既存の`initial_points`(サイレント付与)をそのまま使うことに決定済み——このエンドポイント/`registUser`に新規実装は不要。
