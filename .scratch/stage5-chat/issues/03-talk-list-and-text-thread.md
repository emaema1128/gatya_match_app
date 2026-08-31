Type: task
Blocked by: 02
Status: resolved

## Question

[02-scope-decisions](02-scope-decisions.md)の決定に基づき、トーク一覧画面と、テキストメッセージのみのチャットスレッド画面を実装する。

含めるべき論点:

1. トーク一覧画面(`getMailListForMatching`を使用、`lib/features/chat/`の`chat_tab_screen.dart`は現在プレースホルダー——これを置き換える)。未読バッジの表示。
2. チャットスレッド画面(`getMailLog`で履歴取得、ポーリングで再取得、`sendMail`でテキスト送信)。
3. 残高表示(常時)、送信失敗(`result: '1'`かつ`data.error_detail`が立っている「既知のクセ」)時のUI。
4. ボトムナビの「チャット」タブアイコンへの未読バッジ反映。

決定+実装(このマップの方針)。

## Answer

実装完了。bloomの実ソース(`app/api/Class_MailApi.php`/`route_api.php`)を調査し、以下の形状でクライアントを実装した。

- **ドメイン**: `lib/features/chat/domain/talk_summary.dart`(`getMailListForMatching`の1行——`target_id`/`target_name`/`target_alias`(運営の疑似キャラ用、優先表示)/`target_img_path`/`body`/`print_send_date`(サーバー側で整形済み文字列)/`unread_mail_count`)、`chat_message.dart`(`getMailLog`の1行)、`chat_thread_state.dart`(残高+メッセージ一覧)。
- **application**: `talk_list_controller.dart` — `TalkListController`(`getMailListForMatching`)に加え、ボトムナビ・トーク一覧共通で使う`totalUnreadChatCountProvider`(未読合計の導出プロバイダ)を同居させた。`chat_thread_controller.dart` — `ChatThreadController`(familyプロバイダ、引数`partnerId`)。`build()`で`setReadFlag`(既読化、失敗しても画面表示は継続)→`talkListControllerProvider`を`invalidate`→3秒間隔の`Timer.periodic`でポーリング開始(`ref.onDispose`でタイマー解除+`_disposed`フラグ、`Ref.mounted`はriverpod 2.6.1のpublic APIに無いため使わない)→`getUserData`(残高)+`getMailLog`(履歴)を並行取得。`sendMessage()`は`sendMail`のレスポンスに含まれる更新済み`mail_log`/`user_data`をそのまま採用(ローカルでの楽観的追記はしない——`spinGacha`と同じ「サーバーが返す最新状態をそのまま使う」方針)。KNOWN QUIRK(`result:'1'`+`data.error_detail`)は`BloomApiException`に変換して呼び出し元(画面)に投げる。
- **presentation**: `chat_tab_screen.dart`(プレースホルダーだった`ChatTabScreen`を置き換え——`match_list_screen.dart`と同じ構成: `RefreshIndicator`+一覧/空状態/エラー状態)。行タップで新設の`ChatThreadRoute`(`/chat/thread/:partnerId`、`MatchCelebrationRoute`と同じ「シェル外のフルスクリーンルート」パターン)へ`push`。`chat_thread_screen.dart`(新規)——相手の表示名は`ChatThreadScreen`が`talkListControllerProvider`のキャッシュ済み一覧から探す(`MatchCelebrationScreen`が`matchListControllerProvider`から探すのと同じ方針、追加の通信をしない)。メッセージは`fromId != partnerId`で自分/相手を判定(1:1スレッドなので相手のsystem_idさえ分かれば十分、自分のsystem_idを読む必要がない)。送信中は`GachaScreen._isLiking`と同じく画面ローカルな`_isSending`フラグでボタンを無効化するのみとし、メインの`AsyncValue`はローディングにしない(メッセージ一覧が一瞬消えるのを防ぐ)。
- **ルーティング**: `app_routes.dart`に`ChatThreadRoute`を追加。
- **未読バッジ**: `home_shell_screen.dart`の「チャット」タブアイコンを`Consumer`+`Badge`でラップし、`totalUnreadChatCountProvider`を表示。トーク一覧の各行にも件数バッジを表示。

`flutter pub run build_runner build`で`.g.dart`生成、`dart analyze lib`はこのチケットに起因する新規のエラー/警告なし(既存の`app_routes.g.dart`の`unnecessary_non_null_assertion`警告は`MatchCelebrationRoute`にも既に存在する生成コードの既知パターンで、今回のチケットが原因ではない)。iOSシミュレータ向け`flutter build ios --debug --simulator`のビルドも成功。実機/シミュレータでのログイン後の目視確認は、bloomが本番のみでステージング環境が無く実行にテストアカウントでのログインが要るため、ユーザー自身が後で行う方針とした(このセッションでは実施していない)。
