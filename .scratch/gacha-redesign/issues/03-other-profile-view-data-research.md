Type: research
Status: resolved

## Question

排出されたガチャ候補・いいね一覧・マッチ一覧のカードをタップした時に見せる「他人のプロフィール閲覧画面」を新規に作る。現状、`MatchData`(`getMatchList`/`spinGacha`の候補行)は写真1枚(`img1`系)・`income_id`なしという抜粋情報しか持っていない。自分用の`ProfileData`は`income_id`・`img1〜3`全部を持つ。

他人のプロフィールをどこまで詳しく見せられるか、bloomバックエンドの実際のAPIを調査する。

含めるべき論点:

1. `getUserList`/`search`(`route_api.php`、既存の候補閲覧・検索API)は、`system_id`ごとにどこまでのフィールド(`income_id`、`img2`/`img3`等)を返すか。`getMatchList`/`spinGacha`より情報量が多いか。
2. 他人の`system_id`を指定してフルのプロフィール情報(自分用`getUserData`相当)を取得できる既存APIはあるか。なければ、既存の`getUserList`/`search`のSQLを少し拡張する程度で足りそうか、それとも新規API設計が必要な規模か。
3. `PayCost::VIEW_PROFILE`(既存の「プロフィール閲覧」課金カテゴリ)は、この新しい「カードタップでプロフィールを見る」導線にも課金が必要な設計になっているか(stage3-gacha-homeの決定「ガチャの消費ポイントにはプロフィール閲覧分も含み、二重課金はしない」との関係を確認する)。

調査結果は`.scratch/gacha-redesign/research/other-profile-view-data.md`に保存する。

## Answer

`/research`サブエージェントが調査完了。詳細は[research/other-profile-view-data.md](../research/other-profile-view-data.md)。

1. **バックエンドは既にフル情報を返している。** `getUserList`/`search`/`getMatchList`/`spinGacha`/`getSendLikeList`/`getReceivedLikeList`は全て`SELECT u.*`(userテーブル全カラム)で、`income_id`・`img2`・`img3`を含め既にレスポンスに含まれている。「img1のみ・income_idなし」はバックエンドの制約ではなく、Flutter側`MatchData.fromMatchListEntry`が一部フィールドしかパースしていないクライアント側の制約だった。**→ 新画面はバックエンド変更なしで実現できる。** `MatchData`を拡張する(または新しい`OtherProfileData`をentryから直接パースする)だけで済む。
2. `system_id`指定でフルプロフィールを取り直す専用モバイルAPIは存在しないが、一覧経由のレスポンスをそのまま使えば不要。将来ディープリンク等でsystem_id単体からの再取得が要る場合も、レガシーPC Web(`profile/view.php`)が使う`Chara::getCharaData`とほぼ同型のSQLを`route_api.php`に1ケース追加するだけで足りる規模(新規API設計ではない)。今回は不要と判断し、Not yet specifiedに送る。
3. `PayCost::VIEW_PROFILE`が実際に課金される箇所は、モバイルAPIを一切通らないレガシーPC Web(`profile/view.php`)の1箇所のみ。`route_api.php`・`GachaApi`・`Matches`・`Likes`のどこからも呼ばれておらず、**新画面への遷移で二重課金が起きるリスクはゼロ**(そもそも一度も呼ばれていない)。stage3-gacha-homeの「二重課金しない」方針は、この新画面に新規の課金コードを書き加えないことで自然に維持される。

**新たに浮上した副次的な発見**(このチケットの直接の対象外、マップのNot yet specifiedに記録):
- `MatchData.comment`が読む`entry['comment']`キーは、DBの実カラム名`PR`と食い違っている可能性が高く(未確認、実際のHTTPレスポンスは見ていない)、既存のガチャ結果カード・マッチ一覧で自己紹介文が常に空文字になっているバグの疑いがある。
- 「いいね一覧・マッチ一覧経由でのプロフィール閲覧に課金するか」は、既存のどの決定にも含まれない未決事項。調査の推奨は「無料のまま(新規の課金コードを追加しない)」——bloom全体で`sendLike`無料・スタミナ制なしという既存方針とも整合する。
