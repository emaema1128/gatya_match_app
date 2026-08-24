Type: grilling
Status: resolved

## Question

新しい認証方式が何であれ(このチケットは[05-choose-auth-methods](05-choose-auth-methods.md)の決定を待たずに着手できる)、現在サーバーが自動発行している`login_id`(自動採番の整数)/`password`(ランダム生成文字列)を、アプリ内部のセッション復旧用fallbackとしてどう運用するかを決定する(`/wayfinder`のグリリングで「内部fallbackとして残す」方針は確定済み)。

含めるべき論点:

1. `registUser`のレスポンス(`user_data`に含まれる`login_id`/`password`)をクライアントがいつ・どこに保存するか(`TokenStorage`への追加、キーの命名など)。
2. `app_access_token`によるセッションが無効になった場合(トークン失効・端末再インストール等)に、保存済みの`login_id`/`password`を使って`login`を自動的に(ユーザーに見せずに)呼ぶ復旧フローの設計。
3. この復旧フローが失敗した場合(保存されたlogin_id/passwordも無効、またはローカルストレージ自体が失われた場合)のフォールバック挙動(未ログイン状態に戻す、など)。
4. 現在の`login_screen.dart`(手入力のログイン画面)は、この内部fallback設計後も画面として残すか、削除するか——[07-registration-login-ux-flow](07-registration-login-ux-flow.md)側の決定と整合させる必要があるため、こちらは新方式のUI組み込みが決まってから最終確認する。

`/domain-modeling`スキルを使い、決定した内容をCONTEXT.mdの`Session`定義に反映する。決定のみ(実装はしない、このマップの方針)。

## Answer

事実確認: `route_api.php`の`login`ケース(`route_api.php:412-421`)は`UserApi::login()`成功後に`User::getUserData()`を呼んでおり、`app_access_token`を含む完全な`user_data`を返す(`UserApi::login()`自体はトークンを再発行しないが、その時点でDBに保存されている値がそのまま返る)。復旧フローが機能する前提が確認できた。

1. **発動タイミング**: `AuthController.build()`(アプリ起動時)のトークン検証が失敗した場合にのみ発動。通常API呼び出し中のトークン無効化への対応(汎用リトライ/インターセプタ層)はスコープ外——既存アーキテクチャにその仕組みがなく、次回起動時の復旧で実用上十分と判断。
2. **保存場所・キー**: 既存の`TokenStorage`(flutter_secure_storage)に新しいキー(`bloom_login_id`/`bloom_password`相当)を追加し、`app_access_token`/`system_id`と同じ扱いで管理する。
3. **保存タイミング**: 新規登録・ログイン成功時、未保存であれば保存する(「未保存なら保存」)。login_id/passwordは変更APIがなく不変のため毎回上書きする実用上のメリットはない。storageがリセットされた後も次回成功時に自己修復する設計にする。
4. **復旧失敗時の挙動**: 現在の`build()`のcatchブロック(`clearSession()`→`Unauthenticated`)と同じパターンを、復旧試行(`login`呼び出し)も失敗した場合に適用する。ローカルの認証情報をクリアし、[07-registration-login-ux-flow](07-registration-login-ux-flow.md)で決定した認証方式選択画面に戻す。
5. **`login_screen.dart`の扱い**: [07-registration-login-ux-flow](07-registration-login-ux-flow.md)で確定済み——UIから撤去し、login_id/passwordは完全に内部専用とする。

CONTEXT.mdの`Session`定義を更新(内部fallback用のlogin_id/password保持と、復旧試行を経てから初めてセッションが終了する旨を追記)。
