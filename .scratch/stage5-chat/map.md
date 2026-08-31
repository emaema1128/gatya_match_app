## Destination

マッチした相手とのチャット機能(トーク一覧画面+個別チャット画面)を実装まで完了させる。bloomの既存メール機能(`getMailListForMatching`/`getMailLog`/`sendMail`/`sendImgMail`/`sendAudioMail`/`lookImgMail`/`playAudioMail`)をそのまま使い、**1通ごとに課金される既存のモデルをそのまま継承する**(無料チャットへの変更はしない、ユーザー判断)。バックエンドへの変更は一切不要——bloomの既存メール機能だけで完結する。

## Notes

- サービス名: bloom。前提マップ: [stage4-match-celebration](../stage4-match-celebration/map.md)(マッチ一覧・マッチ成立画面)、[stage3-gacha-implementation](../stage3-gacha-implementation/map.md)(ガチャ実装、ポイント経済の前例)。
- bloomバックエンドの実ソース調査で判明した事実:
  - `getMailListForMatching`(`Mail::getLatestMailDataForEachTargetForMatching`)は`matches`テーブル(status=マッチ済み)を起点に、まだ1通もやり取りがないマッチも一覧に含める(最新メッセージは空文字)——「トーク一覧」に必要な形が既にある。個別の履歴は`getMailLog`(`MailApi::getMailLogAsc`)、送信は`sendMail`/`sendImgMail`/`sendAudioMail`。
  - **`Mail::sendMail`は、テキスト/画像/音声いずれの送信でも例外なく`Point::usePointMail`を呼びポイントを消費する**(`PayCost::SEND_MAIL`/`SEND_PHOTO`/`SEND_AUDIO`)。無料でメッセージを送る仕組みはbloomに一切ない。
  - 受信した画像・音声を開く/再生するのも別途課金(`lookImgMail`/`playAudioMail`、`PayCost::MAIL_PHOTO`/`PLAY_AUDIO`)。ただし`mail_id`単位で「初回のみ課金」(`Mail::existImageDisplayLog`/`existAudioPlayLog`で判定)。
  - `sendMail`系のレスポンスは、残高不足時`result: '1'`のまま`data.error_detail: 'Insufficient points'`を返す(`bloom_api_client.dart`の既知のクセ、失敗として`result: '2'`にはならない)——呼び出し側が`error_detail`の有無を見て判定する必要がある。
  - リアルタイム通知の仕組みはない(Stage6で別途検討)。
  - `getMailListForMatching`は`unread_mail_count`をトーク単位で既に返す。
- 各チケットの解決には`/grilling`と`/domain-modeling`スキルを使うこと。
- **このマップは決定+実装まで含む**(Stage0〜2/4/stage3-gacha-implementationと同じ方針——バックエンド変更が不要なため、ステージング環境の懸念も無い)。

## Decisions so far

- [チャットの課金モデル](issues/01-chat-monetization-model.md) — 既存の「1通ごとに課金」モデルをそのまま継承する(無料化しない)。理由: bloomの既存ビジネスモデルと一致させ、バックエンド変更を最小限にするため。
- [Stage5のスコープ確定](issues/02-scope-decisions.md) — ①トーク画面表示中は新着メッセージをポーリングで取得する(Stage6のプッシュ通知を待たない)。②画像・音声メッセージも初期スコープに含める(テキストのみに絞らない)。③チャット画面にもポイント残高を表示する(Stage3の「ホーム画面限定」をチャットにも拡張)。④トーク一覧・ボトムナビの「チャット」タブに未読バッジを表示する。⑤特定のメッセージへの返信(reply_to)機能は含めない——常に会話全体の末尾に送信するフラットなチャットUIにする。
- [トーク一覧・テキストチャットスレッド実装](issues/03-talk-list-and-text-thread.md) — 実装完了。新規`lib/features/chat/`の`application`/`domain`層(`TalkListController`/`ChatThreadController`(familyプロバイダ)/`totalUnreadChatCountProvider`)と、プレースホルダーだった`ChatTabScreen`の置き換え+新規`ChatThreadScreen`/`ChatThreadRoute`(`MatchCelebrationRoute`と同じシェル外フルスクリーンルート)。スレッド表示中は3秒間隔でポーリング、送信は`sendMail`が返す最新`mail_log`/`user_data`をそのまま採用(ローカル楽観更新はしない)。ボトムナビの「チャット」アイコンとトーク一覧各行に未読バッジを表示。
- [画像メッセージの送受信](issues/04-image-messages.md) — 実装完了。送信は`ProfileController.uploadPhoto`と同じ`data:image/jpeg;base64,...`方式で`sendImgMail`へ即時送信。受信画像は`lookImgMail`(`mail_id`単位で初回のみ課金)を呼ぶまでぼかしプレースホルダーで隠す。「開いたか」はサーバーが返さないため、スレッドを開いている間だけ画面ローカルに記憶する割り切り(閉じて開き直すと表示は再びぼかしに戻るが、再課金はされない)。
- [音声メッセージの送受信](issues/05-audio-messages.md) — 実装完了。録音は新規パッケージ`record`、再生は`audioplayers`を採用(既存の`dependency_overrides`と衝突しないことを`--dry-run`で確認済み)。タップでトグルする単純な録音UI(press-and-hold方式は見送り)。受信音声は`playAudioMail`(`mail_id`単位で初回のみ課金)を呼んでから再生、画像と同じ「サーバーが既読/既再生状態を返さないためスレッド表示中だけローカル記憶」という割り切りを踏襲。共通の汎用URL変換処理として`resolveBloomPhotoUrl`を`resolveBloomAssetUrl`にリネームし画像/音声で共用。

**これでstage5-chatマップの全チケットが解決し、destinationに到達した。**

## Not yet specified

- 画像・音声メッセージのアップロード中の進捗表示など、細かいUX。
- 音声メッセージの再生位置の一時停止/再開(現状は再生/停止のトグルのみ——ボイスメッセージは短尺想定のため今回は見送った)。

## Out of scope

- チャットの無料化。理由: [01](issues/01-chat-monetization-model.md)で既存モデルを継承すると決定済み。
- リアルタイムプッシュ通知(新着メッセージ着信時に画面外でも気づける仕組み)。理由: Stage6(プッシュ通知)の関心事のため。
- 特定メッセージへの返信(引用返信)UI。理由: [02](issues/02-scope-decisions.md)でスコープ外と決定済み。
