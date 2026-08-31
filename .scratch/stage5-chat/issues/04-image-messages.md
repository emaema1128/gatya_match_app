Type: task
Blocked by: 03
Status: resolved

## Question

[03-talk-list-and-text-thread](03-talk-list-and-text-thread.md)のチャットスレッド画面に、画像メッセージの送信・閲覧を追加する。

含めるべき論点:

1. 画像選択・送信(`sendImgMail`、既存の`image_picker`パッケージを再利用)。
2. 受信した画像を開く際の課金(`lookImgMail`、`mail_id`単位で初回のみ課金——2回目以降は無料で再表示できるようにする)。
3. 送信中/閲覧解除前のプレースホルダー表示。

決定+実装(このマップの方針)。

## Answer

実装完了。bloomの実ソース(`route_api.php`の`sendImgMail`/`lookImgMail`/`Class_File.php::saveBase64Image`)を調査し、以下の形状でクライアントを実装した。

1. **画像選択・送信**: `ChatThreadScreen`の入力欄横に画像アイコンボタンを追加。既存の`ProfileScreen._pickAndUploadPhoto`と同じ方式(`ImagePicker().pickImage(source: gallery, maxWidth/maxHeight: 1440, imageQuality: 85)` → bytes → `data:image/jpeg;base64,...`)で選択し、即座に`sendImgMail`へ送信(プレビュー/確認ステップは無し、プロフィール写真と同じ挙動)。`ChatThreadController.sendImage()`を追加、`sendMessage()`と共通のレスポンス処理(`mail_log`/`user_data`の反映、KNOWN QUIRKのerror_detailチェック)を`_applySendResult()`に切り出して共用。カメラ選択は追加していない(既存のプロフィール写真機能もgalleryのみ)。
2. **受信画像の課金閲覧**: `ChatMessage`に`imageUrl`(`img_path`を解決したもの)を追加——bloomは画像メッセージの`body`にサーバー側で固定文言("画像送信")を入れているため、表示時は`imageUrl`の有無を優先する。相手から届いた画像はぼかし用プレースホルダー(タップして表示)で覆い、タップで`ChatThreadController.viewImage(mailId)`(`lookImgMail`、初回のみ課金・2回目以降は無料——バックエンドの`Mail::existImageDisplayLog`が判定)を呼んでから実画像を表示する。自分が送った画像は無条件でそのまま表示(課金対象外)。
3. **プレースホルダー**: 送信中は画面ローカルの`_isSending`(テキスト送信と共用)で画像ボタン・送信ボタン・入力欄を無効化。閲覧解除前は上記のぼかしプレースホルダー、解除処理中はスピナー表示。

**既知の割り切り**: `lookImgMail`のレスポンスは残高更新のみを返し、「既に開いたか」はサーバーから返らない(既読ログが`mail_img_display_log`という別テーブルで、`getMailLog`のレスポンスに含まれないため)。そのためクライアント側では`_ChatThreadScreenState`のローカルなSetで「このスレッドを開いている間に閲覧解除した画像」のみを記憶しており、スレッドを閉じて開き直すと(課金は再発生しないものの)表示は再びぼかし状態に戻る。フォグの「細かいUX」の一部として許容する割り切り。

`flutter analyze`/`dart analyze`はこのチケットに起因する新規のエラー・警告なし。iOSシミュレータ向けビルド成功。実機での目視確認(bloom本番へのログインが必要)はユーザー側で実施する方針。
