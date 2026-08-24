Type: grilling
Blocked by: 01
Status: resolved

## Question

新規登録(Registration)画面を新規に作り、bloomの`registUser` APIに実接続する実装方針を決め、その場で実装する。Registrationが作るのはAccount(認証情報)のみで、Profile(area/age/income/address等)は対象外([CONTEXT.md](../../../CONTEXT.md)参照)。含めるべき論点:

1. [01-bloom-api-spec-confirmation](01-bloom-api-spec-confirmation.md)で確定済み: `registUser`はログインID+パスワードのみ要求(Profile項目は不要)。このシンプルな2フィールド構成でのフォームとバリデーションを決める。
2. `existsDeviceId`/`existsAdjustId`(01で「呼ぶ必要がある」と確定、登録フローでの利用が濃厚)を登録フローのどのタイミングで呼ぶか(フォーム送信前の事前チェックか、`registUser`と合わせて呼ぶか)、`device_id`の取得方法(端末識別子の取得手段)を決める。
3. 利用規約・プライバシーポリシー等への同意チェックボックスが必要か(bloomの既存Webサービス側の登録フローに前例があるか、ユーザーに確認)。
4. 登録成功後の遷移 — `registUser`のレスポンスから得た`system_id`/`app_access_token`をそのまま`TokenStorage`へ保存し自動ログイン扱いにするか、改めてログイン画面へ誘導するか。
5. エラー表示方針(バリデーションエラー vs `result='2'`のサーバーエラー、例: ログインID重複)。
6. ログイン画面(`login_screen.dart`)からの導線(「新規登録はこちら」リンク等)とルーティング(`app_router.dart`/`app_routes.dart`への新規ルート追加)。

決定と実装を両方この場で完了させる(このマップの実装込みの方針)。

## Answer

`/grilling`で決定・実装完了。

1. **フォーム**: ログインID+パスワードのみ、空欄チェック(login screenと同様)。
2. **device_id**: 当初はUUID方式(`uuid`パッケージでランダムID生成→`flutter_secure_storage`に永続化)を採用したが、「アプリのインストール」ではなく「物理端末」を識別したいというユーザー要望により**device_info_plus方式に変更**(詳細は本ファイル末尾の追記を参照)。最終的に: iOSは`device_info_plus`の`identifierForVendor`、Androidは専用パッケージ`android_id`(`Settings.Secure.ANDROID_ID`)を併用(`DeviceIdProvider`、`lib/core/storage/device_id_provider.dart`)。値は非永続化(OSが毎回同じ値を返すため)。`adjust_id`はAdjust SDK未導入のためnull送信(fcm_device_tokenと同じ扱い)。**呼び出しタイミング**: `registUser`より前に`existsDeviceId`を呼び、`status: 'exists'`なら`registUser`を呼ばずに登録をブロックしてエラー案内(`DeviceAlreadyRegisteredException`という専用の例外型を新設——`existsDeviceId`自体は常に`result: '1'`を返すため`BloomApiException`にはならない)。
3. **利用規約同意**: チェックボックス必須(bloom Web版に前例あり、とのこと)。実URLは未定なのでプレースホルダー(`https://bloom-developer.com/terms (仮)`、TODOコメント付き)を表示。チェックが入るまで送信ボタンは無効。
4. **登録成功後**: 自動ログイン扱いでホームへ。`registUser`のレスポンスは`login`と同じ`user_data`形状(`system_id`+`app_access_token`)なので、`AuthController`内に共通処理`_completeSession()`を新設し、`logIn()`と`register()`の両方から呼ぶ形にリファクタリング。`verificationAfterLoginProcess`も登録時に同じくブロッキングで呼び、失敗時はセッションをロールバック。
5. **エラー表示**: ログイン画面と同じフォーム下インラインテキスト方式を踏襲。`DeviceAlreadyRegisteredException`は専用メッセージ(「この端末では既に登録済みです。ログインをお試しください。」)、`BloomApiException`は`errorDetail`をそのまま表示。
6. **導線**: ログイン画面に「新規登録はこちら」ボタンを追加(`RegistrationRoute`へ`go`)。新規登録画面にも「すでにアカウントをお持ちの方はこちら」で`LoginRoute`へ戻れるボタンを追加。`app_routes.dart`に`RegistrationRoute`(`/registration`)を追加し、`app_router.dart`の`_redirect`を拡張(`isLoggingIn`単体の判定を`isLoggingIn || isRegistering`の`isAuthScreen`に一般化——未ログイン時はどちらの画面にも留まれ、ログイン済みなら両方からホームへ弾かれる)。

**実装ファイル(新規、初版)**: `lib/core/storage/device_id_storage.dart`(→後日`device_id_provider.dart`に置換、下記追記参照)、`lib/features/auth/application/registration_controller.dart`、`lib/features/auth/presentation/registration_screen.dart`。
**実装ファイル(変更)**: `lib/core/auth/auth_controller.dart`(`register()`新設、`_completeSession()`への共通化、`DeviceAlreadyRegisteredException`定義)、`lib/core/router/app_routes.dart`(`RegistrationRoute`追加)、`lib/core/router/app_router.dart`(リダイレクト拡張)、`lib/features/auth/presentation/login_screen.dart`(登録画面へのリンク追加)。

**検証**: `dart analyze lib`は問題なし、`dart run build_runner build`も成功。Flutter web-server + Playwrightでログイン画面→「新規登録はこちら」→新規登録画面への遷移、フォーム入力、チェックボックスON/OFFによる送信ボタンの有効/無効切り替えを画面キャプチャで確認済み(コンソールエラーなし)。実際の`registUser`/`existsDeviceId`呼び出し(本番bloom API)は未実行——有効なテストアカウント・端末での実機確認をユーザー側で行うことを推奨する。

### 追記: device_id取得方法をdevice_info_plus方式へ変更

初版のUUID方式(アプリインストール単位の識別)から、ユーザー要望により物理端末単位の識別へ変更。調査の結果、`device_info_plus`単体ではAndroidの実端末識別子は取得できないと判明(`AndroidDeviceInfo.id`はOSビルドのchangelist番号、`fingerprint`もビルド単位の識別子であり、いずれも端末個体を識別しない——`Settings.Secure.ANDROID_ID`はこのパッケージのAPIに含まれない)。このためiOSは`device_info_plus`の`identifierForVendor`(nullable、端末再起動直後は`nil`になりうるため1回リトライ)、Androidは専用の軽量パッケージ`android_id`(`Settings.Secure.ANDROID_ID`)を併用する方針にした。

`uuid`パッケージを削除し`device_info_plus`・`android_id`を追加。`lib/core/storage/device_id_storage.dart`(`DeviceIdStorage.readOrCreate()`)を`lib/core/storage/device_id_provider.dart`(`DeviceIdProvider.resolve()`)に置き換え——値を永続化する必要がなくなった(OSが毎回同じ値を返す)ため、クラス名・メソッド名も実態に合わせて変更。取得失敗時(iOSでリトライ後もnil等)は新設の`DeviceIdUnavailableException`を投げ、登録画面でユーザーへ案内表示する。`dart analyze`はクリーン。**device_info_plus/android_idはいずれもiOS/Android専用のため、この開発環境(Web専用)では実際のID解決ロジックを検証できていない——実機/シミュレータでの確認をユーザー側にお願いする。**
