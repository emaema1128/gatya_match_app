Type: task
Blocked by: 03
Status: resolved

## Question

[03-talk-list-and-text-thread](03-talk-list-and-text-thread.md)のチャットスレッド画面に、音声メッセージの送信・再生を追加する。

含めるべき論点:

1. 録音UIに使うFlutterパッケージの選定(現在の`pubspec.yaml`には音声録音用パッケージが無い——map.mdの「Not yet specified」参照)。
2. 録音・送信(`sendAudioMail`)。
3. 受信した音声を再生する際の課金(`playAudioMail`、`mail_id`単位で初回のみ課金)。

決定+実装(このマップの方針)。

## Answer

実装完了。

**1. パッケージ選定**: 録音に`record`(7.1.1)、再生に`audioplayers`(6.8.1)を追加した。両方とも`flutter pub add --dry-run`で確認済みで、pubspec.yamlに既存の`dependency_overrides`(win32/win32_registry/device_info_plus/flutter_secure_storage_windows——analyzerバージョン互換のため固定)に一切影響しない(解決結果の上書き一覧が追加前後で変わらない)。`record`が既定で出力する`AudioEncoder.aacLc`(m4a)は、bloom側の`Class_File.php::saveBase64Audio`が許可する拡張子(`wav`/`m4a`/`mp3`)に含まれるためそのまま使える。録音の一時ファイル保存先には`path_provider`(既存の間接依存を直接依存に昇格)を使用。マイク権限は`record.hasPermission()`(既定で`request: true`のため許可ダイアログも兼ねる)、iOS側は`Info.plist`に`NSMicrophoneUsageDescription`を追加(Android側は`record_android`パッケージが自前でマニフェストに`RECORD_AUDIO`を宣言しており、アプリ側の`AndroidManifest.xml`への追記は不要と確認済み)。
**2. 録音・送信**: `ChatThreadScreen`の入力欄に録音(マイク)ボタンを追加。タップで即録音開始、コンポーザーが「録音中(経過時間表示)+キャンセル+送信」の専用レイアウトに切り替わる、という単純なトグル式(WhatsApp等のpress-and-hold方式ではない——スクロール中のリストと干渉しやすい割に、この段階でのメリットが薄いため見送った)。送信は`data:audio/m4a;base64,...`形式で`sendAudioMail`へ。`ChatThreadController.sendAudio()`を追加、既存の`_applySendResult()`を再利用。
**3. 受信音声の課金再生**: `ChatMessage`に`audioUrl`を追加。`resolveBloomPhotoUrl`は実装上ただの「相対パス→絶対URL変換」の汎用処理だったため`resolveBloomAssetUrl`にリネームして画像/音声の両方で共用(ユーザー確認済み)。再生ボタンをタップすると`playAudioMail`(`mail_id`単位で初回のみ課金——`lookImgMail`と同じ形状のレスポンスのため、`ChatThreadController`に`_chargeOnFirstOpen()`を切り出して`viewImage`/`playAudio`で共用)を呼んでから`AudioPlayer.play(UrlSource(...))`で再生。自分が送った音声は課金なしで常に再生可能。「初回課金済みか」は画像同様サーバーが返さないため、スレッドを開いている間だけローカルに憶えておく(同じ割り切り)。再生は一時停止/再開ではなく再生/停止のトグルのみ(ボイスメッセージは短尺想定のため、途中再開の位置保持は今回は実装しない)。

`dart analyze`はこのチケットに起因する新規のエラー・警告なし。iOSシミュレータ向け`flutter build ios --debug --simulator`、Android向け`flutter build apk --debug`の両方でビルド成功を確認(新規ネイティブプラグインの導入を含むため、両プラットフォームでのビルド確認まで実施)。

**余談**: このチケットの作業中、`lib/features/home/presentation/home_shell_screen.dart`の`NavigationDestination(icon: _buildChatIcon(), ...)`に不正な`const`が付与されコンパイルエラーになっているのを発見(このチケットの変更が原因ではない)。ユーザーに確認の上、`const`を削除して修正した。
