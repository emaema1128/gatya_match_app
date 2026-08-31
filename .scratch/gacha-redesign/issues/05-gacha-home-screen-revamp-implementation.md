Type: task
Blocked by: 04
Status: resolved

## Question

[01-three-candidate-spin-spec](01-three-candidate-spin-spec.md)(3人排出の仕様)、[03-other-profile-view-data-research](03-other-profile-view-data-research.md)(プロフィール遷移で見せられるデータ)、[04-capsule-animation-prototype](04-capsule-animation-prototype.md)(カプセル演出の実装方針)の決定を前提に、ホーム画面(ガチャ)を刷新実装する。

含めるべき論点:

1. `GachaScreen`のレイアウトをガチャボタン中央配置に変更する。
2. `spinGacha`(バックエンド`GachaApi::spin`)を1人ではなく3人分の候補を返すように変更する(01の選定ロジックを3回分実行)。
3. 04で決めたカプセル演出を組み込む。
4. 3人を並べて表示し、それぞれタップでプロフィール閲覧画面へ遷移できるようにする。[03の調査](03-other-profile-view-data-research.md)の結論により、バックエンドは既に候補一覧の生レスポンスにフル情報(`income_id`/`img2`/`img3`含む)を含んでいるため、新規バックエンド呼び出しは不要——`MatchData`を拡張する(または新しい表示用モデルをentryから直接パースする)だけで実現できる。ついでに、`MatchData.comment`が実カラム`PR`ではなく`entry['comment']`を読んでいる疑いのあるバグ([03のAnswer](03-other-profile-view-data-research.md)参照)も、この実装のタイミングで実際のレスポンスを確認し必要なら直す。
5. いいねは1スピンにつき1人まで(01の決定通り)——UI上でどう表現するか(選択中のカードを強調する等)。
6. 候補プールが少なく3人揃わない場合の表示(マップの「Not yet specified」を参照、既存の空状態パターンを踏襲する想定)。

決定+実装(このマップの方針)。

## Answer

実装完了。バックエンド・クライアント双方を変更。

**バックエンド**(`Class_GachaApi.php`): `spin()`が`candidate`(単数)ではなく`candidates`(配列、最大`SPIN_DRAW_COUNT=3`)を返すよう変更。新設した`drawCandidates()`が新規候補を優先して埋め、足りない分はクールダウン中の再表示枠で埋める(同一スピン内での重複は`exclude_ids`で防止)。消費ポイントは単価そのまま1回分のみ(01の決定通り)。トップレベルの`status: 'recycled'`は廃止し、`is_recycled`をレスポンスの各候補行に付与する形に変更(3人のうち一部だけが再表示枠、というケースに対応するため)。`findFreshCandidate`/`findRecycledCandidate`は`$exclude_ids`引数を追加。

**Flutter**:
- `MatchData`(`match_data.dart`)を拡張——`photoUrls`(img1〜3のリスト)・`incomeId`・`isRecycled`を追加。**副次的に発覚していたバグを修正**: `comment`は実カラム`PR`を読んでいなかった(`entry['comment']`というキー自体がレスポンスに存在しないため常に空文字だった)。既存の`photoUrl`ゲッターは`photoUrls[0]`として後方互換を維持、`MatchProfileCard`等の既存利用箇所は無変更で動作。
- `GachaSpinStatus`から`recycled`を削除(`isRecycled`は候補ごとに持つため)。`GachaHomeState.candidate`→`candidates`(`List<MatchData>`)。
- `GachaController.spin()`が`candidates`配列をパースするよう変更。
- 新規ルート`GachaRevealRoute`(`/gacha/reveal`)を追加(`MatchCelebrationRoute`と同じく、候補データはURLに乗せず`gachaControllerProvider`の直近の状態を読む)。
- `GachaScreen`を全面刷新: 中央のガチャボタン→カプセル演出(04で採用したガチャ本体+震えてバースト、候補数に応じて1〜3個のカプセルが飛び出す)→完了で`GachaRevealRoute`へ自動遷移(1回のみ、pushから戻ってきた際は「もう一度ガチャを回す」ボタンに切り替わる)。空状態・ポイント不足・エラー時は既存踏襲のメッセージ+再試行ボタン。
- 新規`gacha_reveal_screen.dart`(`GachaRevealScreen`): 写真(カードの3/5)+プロフィール情報(2/5)のフルスクリーンスワイプカード。◀▶(またはスワイプ)で候補間を移動、上スワイプ/フリックで「いいね」送信(1スピンにつき1人まで——非マッチならスナックバー表示後に閉じてホームへ戻る、マッチなら`MatchCelebrationRoute`へ遷移)。カードをタップすると画面遷移せず`showModalBottomSheet`(`DraggableScrollableSheet`)で写真ギャラリー(`img1〜3`)+年齢/居住地/年収(既存の`ageOptionListProvider`等を再利用)+自己紹介全文を表示。
- 候補プールが少なく3人揃わない場合: バックエンドが実際に見つかった人数分だけ返し、クライアント側もその数に応じてカプセルの数・矢印ボタンの表示を動的に調整(1人なら◀▶とも非表示)。

**検証**: `dart analyze lib`はクリーン(新規エラーなし、既存の無関係な指摘5件のみ)。`flutter test`のウィジェットテスト(一時ファイル、確認後削除)で、実際の`GoRouter`+`bloomApiClientProvider`のフェイク実装を使い、①3人排出→演出→自動遷移→◀▶移動→タップでシート(画面遷移なし)→上スワイプいいね→ホームへ戻る、②候補1人の場合、③いいねがマッチに繋がり`MatchCelebrationRoute`へ遷移、の3シナリオを確認。本番APIへの実疎通(実際にガチャを回す)は、bloomにステージング環境がないため、有効な本番テストアカウントでの実機確認を推奨する(stage3-gacha-implementationの前例と同じ)。
