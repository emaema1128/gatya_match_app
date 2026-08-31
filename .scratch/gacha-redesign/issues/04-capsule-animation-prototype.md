Type: prototype
Status: resolved

## Question

ガチャボタン(画面中央配置)をタップしてから、カプセルが転がって3人が排出されるまでの一連の演出をプロトタイプする。[stage3-gacha-home](../../stage3-gacha-home/issues/03-ui-flow-design.md)では「Flutter標準アニメーション、Flame不使用」と決定済み——今回のカプセル演出もこの方針を維持できるか、素材(Lottie/Rive動画・画像スプライト等)の導入を検討すべきかを、実際に画面で触って判断する。

含めるべき論点:

1. カプセルが転がる/落ちてくる動きをFlutter標準の`Tween`/`AnimatedContainer`/`CustomPainter`だけでどこまで自然に作れるか。
2. 3人分のカプセルをどう見せるか(1個ずつ連続で転がる、3個同時に転がる等)。
3. 排出後、[01-three-candidate-spin-spec](01-three-candidate-spin-spec.md)で決定した「3人を同時に並べて表示」への繋ぎ方(演出→一覧表示への切り替わり方)。
4. 演出時間の目安(スピンのたびに待たされすぎない長さ)。

`/prototype`スキルで簡易版を作り、ユーザーと一緒に触って判断する。結論(採用する実装方針・素材の要不要)をこのチケットに記録する。

## Answer

3案(A: 同時ドロップ/B: 転がって整列/C: 震えてバースト)をFlutter標準アニメーションのみでプロトタイプし、**Cを採用**。素材(Lottie/Rive等)は不要と判明——Flutter標準の`AnimationController`+`CustomPainter`/`Transform`だけで十分な"ガチャ感"を再現できた。

**採用した演出(最終形)**:
1. ガチャ本体(ドーム+赤いボディ+クランク+排出口)のイラストをChatGPTで生成してもらい(`assets/images/gacha_machine.png`)、透過PNGとして`sips`で本体・カプセル(`gacha_capsule.png`)を切り出して同梱。テーマカラー(seedColor: `Colors.deepPurple`)に寄せた配色を指定。
2. タイムライン: 本体が押し込まれる(作動)→排出口からカプセルがせり出す→その場で震える→弾けて、候補の数(最大3、候補が少なければ1〜2)だけ小さいカプセルが弧を描いて飛び出す→着地してカードへ。
3. 排出後は**画面遷移**(3人を同じ画面に並べるのではなく)——写真メイン(カードの3/5)+プロフィール情報(2/5)のフルスクリーンスワイプカード画面([issue05](05-gacha-home-screen-revamp-implementation.md)で実装した`GachaRevealScreen`)へ自動遷移。◀▶(またはスワイプ)で候補間を移動、カードを上にスワイプ/フリックすると「いいね」(1スピンにつき1人まで、[issue01](01-three-candidate-spin-spec.md)の決定通り)。カードをタップすると画面遷移せずボトムシートで写真ギャラリー・フルのプロフィール情報を見られる。

**[issue01](01-three-candidate-spin-spec.md)の「表示形態」を上書き**: 当初決定していた「3人を同時に並べて表示」は、このプロトタイプでのユーザーフィードバックにより上記のスワイプカード方式に差し替えられた。
