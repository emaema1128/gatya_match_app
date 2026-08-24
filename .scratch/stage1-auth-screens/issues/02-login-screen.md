Type: grilling
Blocked by: 01
Status: resolved

## Question

ログイン画面(`lib/features/auth/presentation/login_screen.dart`)とその周辺(`login_controller.dart`, `core/auth/auth_controller.dart`, `core/auth/auth_state.dart`)を、Stage 0のスタブ(`submitStubLogin`/`completeStubLogin`)から実際のbloom `login` API呼び出しに置き換える実装方針を決め、その場で実装する。含めるべき論点:

1. フォーム構成とバリデーション(ログインID・パスワードの入力欄、必須チェック、送信可否の制御)。
2. `login` API呼び出しフロー — `login_id`/`password`を送信し、成功時に返る`user_data`から`system_id`と`app_access_token`を`TokenStorage`へ永続化する経路。失敗時(`result='2'`, 認証情報不正)のエラー表示方法。
3. [01-bloom-api-spec-confirmation](01-bloom-api-spec-confirmation.md)で確定済み: `verificationAfterLoginProcess`はログイン成功のたびに必須で呼ぶ(`app_version`/`app_build_number`も送るか判断)。`existsDeviceId`はログインフローでも呼ぶ必要があるか(登録フロー限定の可能性が高いとの見立てだが未確定)をこのチケットで最終確認する。
4. `AuthState`/`AuthController`のセッション表現をこのタイミングで拡張する必要があるか(現状は`Authenticated`/`Unauthenticated`のみで`system_id`等を保持していない)。stage0の`auth_controller.dart`のコメントは「起動時のトークン検証(サーバーとの往復)もStage1の作業」と示唆しているが、これをこのチケットに含めるか、対象外として明示的に見送るかを決める。
5. ローディング状態・多重送信防止。

決定と実装を両方この場で完了させる(このマップの実装込みの方針)。

## Answer

`/grilling`で決定・実装完了。

1. **フォームバリデーション**: 空欄チェックのみ。ログインID・パスワードの両方が非空になったら送信ボタンを有効化。
2. **`login` APIフロー**: `login_id`/`password`/`fcm_device_token: null`を送信。成功時、レスポンス`data.user_data`から`system_id`(数値/数値文字列どちらでも許容する`_asInt`ヘルパーでパース。`getUserData(..., 'str')`実装がヒントで型が揺れる可能性があるため)と`app_access_token`(キー名を実機確認済み)を取得し`TokenStorage.saveSession`で永続化。失敗時(`result='2'`)は`BloomApiException.errorDetail`をフォーム下にインラインテキスト表示。
3. **`verificationAfterLoginProcess`**: ログイン成功のたびに**ブロッキングで**呼ぶ(fire-and-forgetではなく、ログイン処理の一部として扱う)。失敗時はセッションをロールバック(`TokenStorage.clearSession()`)し、ログインエラーとして表示。`app_version`/`app_build_number`は今回送らない(`package_info_plus`未追加、任意項目のため見送り)。`existsDeviceId`/`existsAdjustId`はログインフローに含めない(登録フロー専用、ticket 03へ)。
4. **AuthState拡張**: `Authenticated`に`systemId`フィールドを追加(`Authenticated({required this.systemId})`)。`AuthController.build()`はローカルのトークン有無チェックだけでなく、`getUserData`を呼んでサーバー検証まで実装(route_api.phpはdispatch前にtokenを検証するため、これが実質的な検証エンドポイントとして機能する)。検証失敗時(トークン無効/`BloomApiException`、ネットワークエラー等どちらも区別せず)は`TokenStorage.clearSession()`してから`Unauthenticated`を返す。
5. **ローディング/多重送信防止**: Stage0のパターン(Riverpod `AsyncValue`の`isLoading`でボタンを非表示・入力欄を無効化)を踏襲。新規の決定は不要だった。

**実装ファイル**: `lib/core/auth/auth_state.dart`(`Authenticated`拡張)、`lib/core/auth/auth_controller.dart`(`build()`のサーバー検証化、`logIn()`新設、`completeStubLogin()`削除)、`lib/features/auth/application/login_controller.dart`(`submit()`に置き換え)、`lib/features/auth/presentation/login_screen.dart`(フォームUI全面書き換え)。`lib/core/router/app_router.dart`は変更不要(`Authenticated()`パターンはフィールド追加後も型チェックのみで動作、`dart analyze`で確認済み)。

**検証**: `dart analyze lib`は問題なし。`dart run build_runner build`でコード生成も成功。Flutter web-server + Playwrightで一度だけ起動確認に成功し、ログイン画面(ラベル・フィールド・無効化された送信ボタン)が意図通り描画され、コンソールエラーもゼロだった。ただしその後の再起動・再接続試行はこの環境のheadless Chromium側のWebGLコンテキストロス(`CONTEXT_LOST_WEBGL`)により毎回白画面になり、コード側の問題ではなく環境側の制約と判断して打ち切った。実際のbloom本番APIへのログイン成功/失敗パス(`login`・`verificationAfterLoginProcess`・起動時`getUserData`検証)は本番バックエンドしか存在しないため、有効なテストアカウントでの実機確認をユーザー側で行うことを推奨する。
