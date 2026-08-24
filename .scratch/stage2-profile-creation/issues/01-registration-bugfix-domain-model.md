Type: task
Status: resolved

## Question

Stage1の新規登録画面(`registration_screen.dart`)/`AuthController.register()`が、確定済みチケット([stage1-auth-screens/01-bloom-api-spec-confirmation](../../stage1-auth-screens/issues/01-bloom-api-spec-confirmation.md))の決定内容(`registUser`はlogin_id+passwordのみ要求)と矛盾している。実際の実装は`sex`/`region`/`prefecture`/`city`/`comment`を送っており、login_id/passwordを一切送っていない——このため登録したユーザーはログイン画面から二度とログインできない(セッションが生きている間の自動ログインのみ機能する状態)。

`/wayfinder`でのStage2(Profile作成)マップのチャート中に判明。ユーザー判断: 実装済みの状態(sex/地域/自己紹介文をAccount作成時に収集する)を正として受け入れ、CONTEXT.mdのドメインモデルを更新する。あわせて、単純なバグ修正としてlogin_id/passwordを新規登録画面に追加する。

含めるべき論点:

1. 新規登録画面(`registration_screen.dart`)にlogin_id/passwordの入力欄を追加(バリデーション方針はログイン画面`login_screen.dart`に準拠)。
2. `AuthController.register()`の`registUser`呼び出しに`login_id`/`password`を追加。
3. `existsDeviceId`によるブロックと、login_id重複時のサーバーエラー(`result='2'`)の扱いの整理(エラーメッセージの出し分け)。
4. [CONTEXT.md](../../../CONTEXT.md)のProfile定義から`area`(地域)を外し、`sex`/`region`/`prefecture`/`city`/`comment`をAccount側の項目として明記——Registrationの説明文もこの実態に合わせて更新する。

決定と実装を両方この場で完了させる(このマップの実装込みの方針)。

## Answer

実装完了。

1. **登録画面へのフィールド追加**: `registration_screen.dart`の先頭(性別より前)に`ログインID`/`パスワード`のTextFieldを追加。バリデーションは`login_screen.dart`と同じ空欄チェックのみ、パスワードは`obscureText: true`。パスワード確認用の2つ目の入力欄は追加しない(このアプリ全体の「空欄チェックのみ」というシンプルさの方針に合わせた)。
2. **`AuthController.register()`**: `loginId`/`password`パラメータを追加し、`registUser`呼び出しに`login_id`/`password`キーとして含める(既存の`device_type`/`sex`/`region`等はそのまま維持)。
3. **`RegistrationController.submit()`**: `loginId`/`password`を追加し、そのまま`AuthController.register()`に橋渡し。
4. **重複login_idなどのサーバーエラー**: 新しい例外型は追加せず、既存の`BloomApiException`→`errorDetail`表示(ログイン画面と同じ汎用パターン)をそのまま流用。`existsDeviceId`によるブロック(`DeviceAlreadyRegisteredException`)は変更なし。
5. **ドメインモデル更新**: `/domain-modeling`スキルで[CONTEXT.md](../../../CONTEXT.md)を更新。Account定義に`registUser`が`login_id`/`password`と`sex`/`region`/`prefecture`/`city`/`comment`を収集する旨を追記。Profile定義から`area`/`sex`/自己紹介を外し、age/income/address/photosに絞った。境界決定の背景は[docs/adr/0001-account-collects-sex-area-comment.md](../../../docs/adr/0001-account-collects-sex-area-comment.md)にADRとして記録(可逆性が低く・驚きがあり・実際のトレードオフがあったため)。

**検証**: `dart analyze lib`はクリーン(既存の無関係な警告2件のみ、新規エラーなし)。実際の`registUser`本番API呼び出し(login_id/password込み)は未実行——有効なテストアカウントでの実機/エミュレータ確認をユーザー側で推奨する(特に、login_idの重複時に`result='2'`とどのような`error_detail`文言が返るかは未確認)。

### 追記: 上記1〜4(login_id/passwordフィールド追加)は誤りと判明、revert済み

ユーザーがbloomバックエンドの実ソース(`Class_UserApi.php`/`Class_User.php`/`Class_Profile.php`、`document/blooom関係/dream`配下)を共有してくれたことで判明: `registUser`は`$post_data['login_id']`/`$post_data['password']`を**一切読み取っていない**。`login_id`はサーバー側で`MAX(login_id)+1`として自動採番される整数、`password`は`tempRegist()`が`generateRandomPassword()`で自動生成する文字列——いずれもクライアントが選べる値ではなく、変更用のAPIもbloom全体を検索した限り存在しない。両方とも`getUserData`(`SELECT u.*`)経由で`registUser`のレスポンス`user_data`に生の値として含まれる。

このため上記1〜4で追加した`login_id`/`password`入力欄は、送信してもバックエンドに無視される実質無意味なUIだった。以下の通りrevertし、登録画面をticket着手前の状態(sex/地域/自己紹介文のみ)に戻した:

- `registration_screen.dart`: `_loginIdController`/`_passwordController`とそのTextField・バリデーション・`_submit()`引数を削除。
- `registration_controller.dart`: `submit()`から`loginId`/`password`パラメータを削除。
- `auth_controller.dart`: `register()`から`loginId`/`password`パラメータと`registUser`呼び出しへの付与を削除。
- [CONTEXT.md](../../../CONTEXT.md)のAccount定義を訂正: 「self-chosenなlogin_id/password」ではなく「サーバー自動発行のlogin_id/password(変更API無し)」と記載。
- [ADR 0001](../../../docs/adr/0001-account-collects-sex-area-comment.md)に本件の経緯を追記。

`login_id`/`password`(サーバー自動発行)をアプリがどう扱うか(セッション復旧への利用、LINE/Apple/Google/電話番号ログインの追加検討を含む)は、新規マップ「認証方式の再検討」で改めて決定する(ユーザー判断: 影響範囲が大きく`route_api.php`のバックエンド変更を伴う可能性もあるため、Stage2とは別マップとして切り出す)。

**検証(revert後)**: `dart analyze lib`はクリーン(既存の無関係な警告2件のみ、新規エラーなし)。
