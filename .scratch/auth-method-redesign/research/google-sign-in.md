Type: research

# Google Sign-In 導入の実現可能性調査

調査日: 2026-08-21
対象issue: [`02-google-sign-in-feasibility.md`](../issues/02-google-sign-in-feasibility.md)

一次情報源(Google公式ドキュメント `developers.google.com/identity`・`developer.android.com/identity`、`google_sign_in`パッケージの公式ページ・GitHubリポジトリ)にのみ基づく。二次情報(ブログ等)を根拠に使った箇所はその都度明記する。bloomバックエンドの実ソース(`/Users/daichi/Documents/blooom関係/dream/`)は3節のエンドポイント案の裏付けとして参照した。

## 結論(要約)

- **Flutter側**: 公式パッケージ`google_sign_in`(flutter.dev発行のverified publisher)がiOS/Android/macOS/Webを公式サポート。現行メジャーバージョンは7.x系で、v7でAPIが大きく刷新された(シングルトン化、`initialize()`必須呼び出し、認証と認可の分離)。Android側は内部実装がAndroidの新API「Credential Manager」に切り替わっている(旧Google Sign-In SDKは非推奨)。
- **サーバー側検証(PHP)**: Google公式ドキュメントは「JWKSを使ったローカル検証(本番推奨)」と「`tokeninfo`エンドポイント(デバッグ専用、本番非推奨=スロットリングされ得ると明記)」を提示。PHP向けにはGoogle公式のクライアントライブラリ`google/apiclient`があり、`Google_Client::verifyIdToken()`一発でaud/iss/exp/署名検証が完結する。
- **bloomバックエンド側の見積もり**: 新規`execute_function`を1つ(例: `loginWithGoogle`)、`user`テーブルへの列追加(例: `google_sub`)1つ、Composer依存追加1つ、というレベルの小さな変更で技術的には成立する。既存の`registUser`/`login`/`system_id=-1`バイパスの仕組み(`route_api.php`)にそのまま乗せられる。実装量として既存の他`execute_function`(数十行程度)と同等かやや大きい程度。
- **既知の落とし穴**: (a) AndroidのCredential Manager移行に対応した`google_sign_in_android` 7.0.0以降を使う必要がある、(b) OAuthクライアントIDはWeb/Android/iOSでそれぞれ別々に発行するが、バックエンド検証用のaudienceにはWeb用クライアントID(`serverClientId`)を共通で使うのが標準、(c) IDトークンは有効期限が短い(検証はログイン時の1回のみが前提の設計であり、bloomは元々自前の`app_access_token`で継続セッションを持つため「Googleトークンのリフレッシュ」自体を扱う必要がない)。

---

## 1. Flutter側の実装(`google_sign_in`パッケージ)

### 1.1 プラットフォーム対応状況

pub.devの公式パッケージページによると、`google_sign_in`(バージョン7.2.0時点)は以下をサポートしている。

| プラットフォーム | 要件 |
|---|---|
| Android | SDK 21+ |
| iOS | 12.0+ |
| macOS | 10.15+ |
| Web | any |

発行元は`flutter.dev`(verified publisher)、ライセンスはBSD-3-Clause。
出典: [google_sign_in \| pub.dev](https://pub.dev/packages/google_sign_in)

実体はフェデレーテッドプラグイン構成になっており、プラットフォームごとに実装パッケージが分かれている。
- Android実装: [`google_sign_in_android`](https://pub.dev/packages/google_sign_in_android)
- iOS/macOS実装: [`google_sign_in_ios`](https://pub.dev/packages/google_sign_in_ios)
- Web実装: `google_sign_in_web`(今回は対象外)

出典: [google_sign_in \| pub.dev](https://pub.dev/packages/google_sign_in), [google_sign_in API doc overview](https://pub.dev/documentation/google_sign_in/latest/)

### 1.2 v7系でのAPI設計(重要な前提知識)

`google_sign_in`はv7.0.0で破壊的変更を伴う大規模刷新を行っている。CHANGELOGおよびMIGRATION.mdによると:

- `GoogleSignIn`インスタンスは**シングルトン化**され、`GoogleSignIn.instance`でアクセスする。
- 他のどのメソッドを呼ぶより前に、**`initialize()`を一度だけ呼んでawaitする**ことが必須になった。
- **認証(サインイン=本人確認)と認可(スコープへのアクセス許可)が明確に分離**された。サインイン自体は`authenticate()`、追加スコープの許可は`authorizationClient`経由の`authorizeScopes`/`authorizationForScopes`で別に行う。
- 旧`signInSilently()`は`attemptLightweightAuthentication()`に置き換えられた(プラットフォームによってはFutureを返さず、`authenticationEvents`ストリームで結果を受け取る必要がある)。
- サーバー向けの認可コードが必要な場合は`authorizeServer`を別途呼ぶ。
- エラーは基本的に`GoogleSignInException`としてthrowされる(ユーザーによるキャンセルも`canceled`コードの例外として扱われる)。

出典: [google_sign_in changelog \| pub.dev](https://pub.dev/packages/google_sign_in/changelog), [MIGRATION.md (flutter/packages, GitHub)](https://github.com/flutter/packages/blob/main/packages/google_sign_in/google_sign_in/MIGRATION.md)

初期化の実例(READMEより):

```dart
final GoogleSignIn signIn = GoogleSignIn.instance;
unawaited(
  signIn.initialize(clientId: clientId, serverClientId: serverClientId)
    // ...
);
```

出典: [google_sign_in README (flutter/packages, GitHub)](https://raw.githubusercontent.com/flutter/packages/main/packages/google_sign_in/google_sign_in/README.md)

IDトークンは`authenticate()`成功後に`googleUser.authentication`から取得できる。一方`accessToken`は自動では返らず、必要なら`authorizationClient`経由で明示的にスコープをリクエストする必要がある(bloomの用途は「本人確認のみ」なので基本的に`accessToken`は不要で、`idToken`だけで足りる)。
出典: [google_sign_in README (flutter/packages, GitHub)](https://raw.githubusercontent.com/flutter/packages/main/packages/google_sign_in/google_sign_in/README.md)

### 1.3 必要なセットアップ

**Google Cloud Console側 (OAuthクライアントID発行)**

OAuth 2.0クライアントIDは「アプリケーションの種類」ごとに別々に発行する。Google Cloud Console (API Console) のヘルプページによると:

- **Android**: `AndroidManifest.xml`のパッケージ名と、署名証明書から`keytool`で生成したSHA-1フィンガープリントの2つが必要。
- **iOS**: `.plist`内のBundle IDが必要(App Store IDと10桁のTeam IDは任意)。
- **Web application**: JavaScript オリジンやリダイレクトURIを設定する種類。

出典: [Setting up OAuth 2.0 - API Console Help (support.google.com)](https://support.google.com/googleapi/answer/6158849?hl=en)

重要な点として、**バックエンドでIDトークンのaudience検証に使うクライアントIDは、Android/iOSそれぞれのネイティブクライアントIDではなく「Webアプリケーション」種別のクライアントID(＝`serverClientId`)を共通で使う**のが標準的な構成になっている。これは以下の一次情報源から確認できる。

- Android Credential Manager公式実装ガイドでは、`GetSignInWithGoogleOption`(あるいは`GetGoogleIdOption`)に`setServerClientId()`を設定し、これが「Googleが生成するIDトークンのaudienceとして使うサーバーのクライアントID」であると明記されている。
  出典: [GetGoogleIdOption.Builder \| Google for Developers](https://developers.google.com/identity/android-credential-manager/android/reference/com/google/android/libraries/identity/googleid/GetGoogleIdOption.Builder), [Implement Sign in with Google \| Android Developers](https://developer.android.com/identity/sign-in/credential-manager-siwg-implementation)
- iOS向けのバックエンド検証ガイドでも、コード例内で「アプリにアクセスするバックエンドのWEB_CLIENT_IDを指定する」と明記されている。
  出典: [Authenticate with a backend server \| Sign in with Google for iOS](https://developers.google.com/identity/sign-in/ios/backend-auth)
- `google_sign_in_android`パッケージのREADMEでも、`google-services.json`に`client_type: 3`(Web用)のOAuthクライアントエントリが含まれている必要があり、それがない場合は`serverClientId`として明示的にWebクライアントIDを渡す必要がある、と説明されている。
  出典: [google_sign_in_android \| pub.dev](https://pub.dev/packages/google_sign_in_android)
- `google_sign_in_ios`パッケージのREADMEでも、`Info.plist`に`GIDServerClientID`(任意、バックエンド認証が必要な場合)を設定する項目がある。
  出典: [google_sign_in_ios \| pub.dev](https://pub.dev/packages/google_sign_in_ios)

**Android側のFlutterプロジェクト設定**

`google_sign_in_android`のREADMEによると:
- FirebaseまたはGoogle Cloud Platformでアプリを登録する。
- `google-services.json`を使う場合、その中に`client_type: 3`のWeb OAuthクライアントエントリが含まれている必要がある(なければFirebaseコンソール上でWebアプリを追加して再ダウンロード)。
- 署名SHA-1がビルド設定(debug/release等)ごとにサーバー側の設定と一致している必要がある(不一致は設定エラーの典型的な原因)。
- Google People APIなど関連APIをGoogle Cloud Platformのコンソールで有効化する必要がある場合がある。

出典: [google_sign_in_android \| pub.dev](https://pub.dev/packages/google_sign_in_android)

**iOS側のFlutterプロジェクト設定**

`google_sign_in_ios`のREADMEによると:
- `GoogleService-Info.plist`をダウンロードするが、**このファイル自体をプロジェクトに含める必要はない**(値を抜き出して`Info.plist`に転記する)。
- `Info.plist`に`GIDClientID`(`CLIENT_ID`の値、必須)を設定。
- 任意で`GIDServerClientID`(バックエンド認証用、上記のWebクライアントID)を設定。
- `CFBundleURLTypes`にURLスキームとして`REVERSED_CLIENT_ID`の値(`com.googleusercontent.apps.<reversed-client-id>`形式)を設定する必要がある(必須)。
- 代替として、`Info.plist`を編集せずDart側で`GoogleSignIn.initialize(clientId:, serverClientId:)`に直接値を渡す方法もあるが、URLスキームの設定自体は省略できない。

出典: [google_sign_in_ios \| pub.dev](https://pub.dev/packages/google_sign_in_ios)

**OAuth同意画面と非機密スコープの扱い**

`email`/`profile`/`openid`スコープ(=Sign-Inに必要な最小構成)はGoogleの分類上「非機密スコープ(non-sensitive scopes)」であり、Googleによる本番アプリ審査(app verification)が不要な範囲に収まる。
出典: [Sensitive scope verification \| App verification to use Google Authorization APIs](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification)

一方でAndroidのCredential Manager経由の「Sign in with Google」は、コンセント画面にアプリ名を表示するために「ブランド確認(brand verification)」の完了が必要、との記載がある。
出典: [About Sign in with Google \| Android Developers](https://developer.android.com/identity/sign-in/credential-manager-siwg)

---

## 2. サーバー側(PHP)でのIDトークン検証方法

### 2.1 Googleが公式に提示する2つの方式

Google公式ドキュメント「Verify the Google ID token on your server side」は次のように述べている(要約・引用)。

> "Rather than writing your own code to perform these verification steps, we strongly recommend using a Google API client library for your platform, or a general-purpose JWT library."

出典: [Verify the Google ID token on your server side \| Web guides](https://developers.google.com/identity/gsi/web/guides/verify-google-id-token)

つまり公式に推奨される方式は次の2つ:

1. **Google API クライアントライブラリ(推奨・本番向け)**: Java/Node.js/PHP/Pythonに公式ライブラリがある。PHPの場合は`google/apiclient`(`Google_Client::verifyIdToken()`)。
2. **汎用JWTライブラリ + Googleの公開鍵(JWKS)によるローカル検証**: ライブラリ名は明示されていないが、Googleの公開鍵エンドポイントを使い自前でJWT署名検証を行う方式。

これとは別に、**開発・デバッグ専用**として`tokeninfo`エンドポイントが用意されているが、本番利用は明確に非推奨とされている。

> "For development and debugging, you can call our tokeninfo validation endpoint." / "It is not suitable for use in production code as requests may be throttled or otherwise subject to intermittent errors."

出典: [Verify the Google ID token on your server side](https://developers.google.com/identity/gsi/web/guides/verify-google-id-token), [Authenticate with a backend server (Android)](https://developers.google.com/identity/sign-in/android/backend-auth), [Authenticate with a backend server (iOS)](https://developers.google.com/identity/sign-in/ios/backend-auth), [OpenID Connect \| Google Identity](https://developers.google.com/identity/openid-connect/openid-connect)

### 2.2 検証すべきクレーム

Android/iOS双方のバックエンド認証ガイド、およびOpenID Connectガイドで共通して挙げられている検証項目:

| クレーム | 内容 |
|---|---|
| 署名 | GoogleのJWKS(公開鍵)で署名を検証する |
| `aud` | 自アプリのクライアントID(バックエンド検証用は前述の**Webクライアント/`serverClientId`**)のいずれかと一致すること |
| `iss` | `accounts.google.com` または `https://accounts.google.com` と一致すること(両者は等価として扱われる) |
| `exp` | 有効期限を過ぎていないこと |
| `sub` | ユーザーの一意識別子。**メールアドレスではなくこちらを主キーとして使うことが推奨される**(Googleアカウントはメールアドレスが変わり得るため) |
| `hd`(任意) | Google Workspace/Cloud Identity組織のドメイン検証に使う。個人向けdatingアプリのbloomでは通常不要 |

出典: [Authenticate with a backend server (Android)](https://developers.google.com/identity/sign-in/android/backend-auth), [Authenticate with a backend server (iOS)](https://developers.google.com/identity/sign-in/ios/backend-auth), [OpenID Connect \| Google Identity](https://developers.google.com/identity/openid-connect/openid-connect), [Best Practices for Implementing Sign in with Google](https://developers.google.com/identity/siwg/best-practices)

`sub`をユーザーの一意識別子として使うべきという点は、ベストプラクティスページでも重ねて強調されている。

> Google推奨: "Use `sub` within your application as the unique-identifier key for the user"(メールアドレスは変わりうるため主キーにしない)

出典: [OpenID Connect \| Google Identity](https://developers.google.com/identity/openid-connect/openid-connect), [Best Practices for Implementing Sign in with Google](https://developers.google.com/identity/siwg/best-practices)

### 2.3 公開鍵(JWKS)エンドポイントとOIDC Discovery

- JWK形式: `https://www.googleapis.com/oauth2/v3/certs`
- PEM形式: `https://www.googleapis.com/oauth2/v1/certs`
- OpenID Connect Discovery文書: `https://accounts.google.com/.well-known/openid-configuration`(この中に`jwks_uri`が含まれる)

鍵は定期的にローテーションされるため、レスポンスの`Cache-Control`ヘッダーを見て再取得タイミングを決めるようGoogleは案内している。Discovery文書のURI自体はハードコードし、HTTPキャッシュを活用することが推奨されている。

出典: [Authenticate with a backend server (Android)](https://developers.google.com/identity/sign-in/android/backend-auth), [OpenID Connect \| Google Identity](https://developers.google.com/identity/openid-connect/openid-connect)

### 2.4 `tokeninfo`エンドポイント(デバッグ専用)

```
https://oauth2.googleapis.com/tokeninfo?id_token=XYZ123
```

このエンドポイントはHTTP GETで叩くだけで検証結果(クレーム一式)を返してくれるため実装は最も簡単だが、Google公式ドキュメントが繰り返し「本番では非推奨、スロットリングされ得る」と明記している。
出典: [Verify the Google ID token on your server side](https://developers.google.com/identity/gsi/web/guides/verify-google-id-token), [OpenID Connect \| Google Identity](https://developers.google.com/identity/openid-connect/openid-connect)

**bloomの既存実装との整合性についての補足(調査で判明した事実、判断材料)**: bloomの既存LINEログイン実装(`Class_Line.php`)は、LINE側の`https://api.line.me/oauth2/v2.1/verify`という「リモートの検証エンドポイントを都度呼ぶ」方式を採用しており、ローカルJWKS検証は行っていない(該当ファイルを直接確認: `/Users/daichi/Documents/blooom関係/dream/Class_Line.php` 226〜338行目付近)。したがって`tokeninfo`方式は実装コストが低く既存パターンとも似ているが、Google公式が明確に本番非推奨としている点はトレードオフとして認識しておく必要がある(本番ではJWKSベースのローカル検証、もしくは`google/apiclient`の利用が公式推奨)。

### 2.5 PHPでの実装方法(公式クライアントライブラリ)

Googleは`google/apiclient`というPHP公式ライブラリ(GitHub: `googleapis/google-api-php-client`)を提供しており、`Client`クラスに`verifyIdToken()`メソッドがある。

```php
public function verifyIdToken($idToken = null)
```

内部で`Google\AccessToken\Verify`クラスを使い、署名・`aud`・`iss`・`exp`をまとめて検証し、成功時はペイロード(クレーム配列)を、失敗時は`false`を返す。

典型的な使い方:

```php
$client = new \Google\Client();
$client->setClientId('WEB_CLIENT_ID'); // Androidのserver client idと同じWebクライアントID
$payload = $client->verifyIdToken($idToken);
if ($payload) {
  $google_sub = $payload['sub'];
  $email = $payload['email'] ?? null;
  // ...
}
```

出典: [Client.php (googleapis/google-api-php-client, GitHub)](https://github.com/googleapis/google-api-php-client/blob/main/src/Client.php), [Authenticate with a backend server (iOS)](https://developers.google.com/identity/sign-in/ios/backend-auth)(PHPコード例あり)

導入コマンド: `composer require google/apiclient`
出典(Composerパッケージ名の確認): [google/apiclient \| Packagist](https://packagist.org/packages/google/apiclient)

**bloom側の現状(実ソース確認)**: `/Users/daichi/Documents/blooom関係/dream/composer.json`にはすでにComposerが導入済みで、`php-mime-mail-parser/php-mime-mail-parser`・`minishlink/web-push`・`aws/aws-sdk-php`の3つが依存として入っている。Google関連・JWT関連のライブラリはまだ入っていないため、`google/apiclient`(または軽量な代替としてJWKSを自前取得しJWTライブラリで検証する方式)は新規依存の追加になる。`google/apiclient`はGuzzle等を含むフル機能のGoogle APIクライアントであり、ID検証だけが目的なら依存が重い点は考慮材料(Googleドキュメントが代替として挙げる「汎用JWTライブラリ+JWKS手動検証」の方が依存が軽くなる可能性がある。ただしそちらは公式ライブラリではなくGoogleが名指しで推奨している特定の実装は無い点に注意)。

---

## 3. bloomバックエンド側の追加実装見積もり

### 3.1 現状のAPI構造の確認(実ソース)

`route_api.php`(`/Users/daichi/Documents/blooom関係/dream/app/api/route_api.php`)は単一エンドポイントで、POSTボディの`execute_function`フィールドで処理を分岐するswitch文になっている。認証は以下の通り:

- 全リクエストで`system_id`が必須(空なら`result: 2`エラー、22〜26行目)。
- `Authorization: Bearer <app_access_token>`ヘッダーを`User::access_token_verification()`で検証(33〜37行目)。
- **例外**: `system_id`が`-1`のときはこの検証をスキップする(「-1は登録前の通信」というコメントがコード中にある、32行目)。これは新規登録(`registUser`)など、まだ`app_access_token`を持たない状態の通信のために用意された仕組みで、Google Sign-Inの初回ログイン/新規登録にもそのまま流用できる。

`Class_UserApi.php`の`registUser()`は、`User::tempRegist()`でuserテーブルへINSERTし、`app_access_token`をサーバー側で生成(`bin2hex(random_bytes(32))`)して保存する。既存の`login()`は`login_id`+`password`でSELECTするのみのシンプルな実装。

出典(bloom実ソース): `/Users/daichi/Documents/blooom関係/dream/app/api/route_api.php`, `/Users/daichi/Documents/blooom関係/dream/app/api/Class_UserApi.php`, `/Users/daichi/Documents/blooom関係/dream/Class_User.php`(`tempRegist`: 334行目〜, `access_token_verification`: 984行目〜)

`user`テーブルの列は`tempRegist()`のINSERT文から次のものが既に存在するとわかる: `username`, `login_id`, `email`, `carrier`, `password`, `device_type`, `device_id`, `adjust_device_id`, `sex`, `area1_id/2/3`, `age_id`, `income_id`, `address_id`, `PR`, `PR_check`, `grade`, 各種rank/pay_cost/limit/add_point_group id, `adcode_id`, `temp_regist_date`, `line_regist_flag`, `fcm_device_token`, `app_access_token`。`line_regist_flag`のように、認証方式ごとのフラグ/識別列をuserテーブルに追加していく設計が既存であり、Google Sign-In用の列を追加するのは既存パターンの延長線上にある。

### 3.2 Googleから取得できるユーザー情報

IDトークンのペイロードに含まれる標準クレーム(2.2節で検証したものに加え、bloomが利用しうる属性情報):

| クレーム | 常時/条件付き | 内容 |
|---|---|---|
| `sub` | 常時 | Googleアカウントの一意識別子(未再利用) |
| `email` | 条件付き(emailスコープ指定時) | メールアドレス |
| `email_verified` | 条件付き | メール確認済みか |
| `name` | 条件付き | 表示名(フルネーム) |
| `given_name` / `family_name` | 条件付き | 名/姓 |
| `picture` | 条件付き | プロフィール画像URL |
| `locale` | 条件付き | BCP47ロケール |

出典: [OpenID Connect \| Google Identity](https://developers.google.com/identity/openid-connect/openid-connect)

bloom側では`username`(nameから初期値として利用可)、`email`、プロフィール画像(`picture`。ただし既存の`profile_img`は自前アップロード運用なので初期値程度の扱いが妥当)あたりが登録初期値として使える。現状`registUser`はメールアドレスをハードコードで`test@example.com`にしている(実ソース確認、`Class_UserApi.php` 23行目)ため、Google由来の実メールアドレスを`email`列に入れられるようになる点は既存実装からの改善にもなりうる。

### 3.3 想定エンドポイント案(あくまで技術的な形の一例。方式の可否そのものは別issueの判断に委ねる)

既存の`registUser`/`login`のパターンに倣うなら、以下のような形が自然:

**DBスキーマ変更**: `user`テーブルに`google_sub`列(VARCHAR、UNIQUE INDEX)を追加。将来Apple/LINEなど他方式も追加するなら`apple_sub`等も同様のパターンになる(このあたりのアカウント統合モデル自体は[06-account-linking-model](../issues/06-account-linking-model.md)の検討事項)。

**新規`execute_function`**: 例えば`loginWithGoogle`を追加。

```php
// route_api.php に追加するcase(イメージ)
case 'loginWithGoogle':
  $result = UserApi::loginWithGoogle($post_data); // id_tokenの検証込み
  if ($result) {
    $system_id = $result['system_id'];
    $user_data = User::getUserData($system_id, 'str');
    $return_data = json_encode(['result' => '1', 'data' => ['user_data' => $user_data]]);
  } else {
    $return_data = json_encode(['result' => '2', 'error_detail' => 'Google sign-in failed']);
  }
  break;
```

```php
// Class_UserApi.php に追加するメソッド(イメージ)
public static function loginWithGoogle($post_data) {
  $client = new \Google\Client();
  $client->setClientId(GOOGLE_WEB_CLIENT_ID); // Web用クライアントID = serverClientIdと同じ値
  $payload = $client->verifyIdToken($post_data['id_token']);
  if (!$payload) {
    return false; // 検証失敗
  }
  $google_sub = $payload['sub'];

  $dbh = DBconnect::Connect();
  $sql = "SELECT system_id FROM user WHERE google_sub = :google_sub";
  $stmt = $dbh->prepare($sql);
  $stmt->bindValue(':google_sub', $google_sub, PDO::PARAM_STR);
  $stmt->execute();
  $fetch = $stmt->fetch(PDO::FETCH_ASSOC);

  if ($fetch) {
    // 既存ユーザー: ログイン扱い
    return $fetch;
  } else {
    // 新規ユーザー: registUser相当の初期登録処理 + google_sub/emailの保存
    // (新規登録時に必要な他フィールド(sex/device_id等)をpost_dataから受け取る前提)
    // ...
  }
}
```

これは既存の`registUser`/`login`と同程度の複雑さで、新規性はGoogle IDトークンの検証部分のみ。返却レスポンスの形(`{result, data: {user_data}}`)も既存の他エンドポイントと完全に統一できる。

**未決定として残る論点(このticketのスコープ外、[06-account-linking-model](../issues/06-account-linking-model.md)で検討)**:
- 新規Googleユーザーが端末には既存アカウント(`device_id`一致)を持っていた場合にどう扱うか(自動リンク/確認UI/新規アカウント作成)。
- 既にログイン中(`app_access_token`保持)のユーザーが後からGoogleアカウントを連携する「アカウント統合」フロー(この場合は`system_id`が`-1`ではなく実際の値になり、既存の`app_access_token`検証を通したうえで`google_sub`を追記するだけの別`execute_function`になる可能性が高い)。

**規模感の見積もり**: 技術要素だけで見ると、新規列1つ+新規PHPメソッド1つ(50行未満)+`route_api.php`のcase追加(10行程度)+Composer依存追加+Google Cloud ConsoleでのOAuthクライアントID発行(Web/Android/iOSの3種)、という規模。他の`execute_function`(例: `sendLike`, `updateContactNg`など)と同程度かやや大きい程度の実装量で、bloomバックエンドの既存アーキテクチャに無理なく収まる。ただし上記の「アカウントリンクポリシー」次第で分岐が増える可能性がある。

---

## 4. 既知の落とし穴・注意点

### 4.1 AndroidのCredential Manager移行

- Googleは2023年以降、Android向けの認証APIを従来の`com.google.android.gms:play-services-auth`ベースの「Google Sign-In for Android」から、統合APIである**Credential Manager**(パスキー/パスワード/フェデレーテッドサインインを横断的に扱う)に段階的に移行させている。旧`GoogleSignInClient`は非推奨であり、「将来のリリースでGoogle Play services Auth SDKから削除される」と明記されているが、**具体的な削除時期(サンセット日)はドキュメント上明示されていない**。
  出典: [About the migration from legacy Google Sign-In \| Android Developers](https://developer.android.com/identity/sign-in/legacy-gsi-migration), [About Sign in with Google \| Android Developers](https://developer.android.com/identity/sign-in/credential-manager-siwg)
- Flutterの`google_sign_in_android`パッケージは**バージョン7.0.0**でこの移行に対応し、「Sign in with Google (CredentialManager) を基盤SDKとして採用し、非推奨のGoogle Sign In for Android SDKの使用を除去」した(CHANGELOGの記載)。したがって**`google_sign_in`のバージョンをv7以降(2026年8月時点の最新は7.2.0)に保つことが必須**——古いv6系のままだと将来的に非推奨SDKに依存し続けることになる。
  出典: [google_sign_in_android changelog \| pub.dev](https://pub.dev/packages/google_sign_in_android/changelog)
- 移行後の副作用として、`google_sign_in_android`のREADMEには「設定ミス(SHA-1不一致等)がCredential Manager経由だと`canceled`例外として返ってきてしまい、プラグイン側では『ユーザーによる本当のキャンセル』と区別がつかない」という既知の注意点が明記されている。デバッグ時に「サインインがキャンセルされる」という報告が来た場合、まずOAuthクライアント設定(パッケージ名・SHA-1)を疑う必要がある。
  出典: [google_sign_in_android \| pub.dev](https://pub.dev/packages/google_sign_in_android)

### 4.2 v7 API刷新に伴う実装上の注意

- `initialize()`を呼ばずに他メソッドを呼ぶと動作しない(1回だけ・アプリ起動時に呼ぶ設計が必須)。
- `signInSilently()`が`attemptLightweightAuthentication()`に置き換わっており、Web含む一部プラットフォームでは戻り値がFutureではなくストリームイベント経由になる。既存の「アプリ再起動時に自動サインイン状態を復元する」ような実装をする場合はこの非同期性の違いに注意。
出典: [google_sign_in changelog](https://pub.dev/packages/google_sign_in/changelog), [MIGRATION.md](https://github.com/flutter/packages/blob/main/packages/google_sign_in/google_sign_in/MIGRATION.md)

### 4.3 IDトークンの有効期限・「リフレッシュ」の考え方

- Google IDトークンは短命(JWTの`exp`クレームで規定される、一般的なOIDC実装同様に短時間で失効する設計)であり、**サーバー側での検証は「受け取った瞬間の1回」を前提**にしている。GoogleのベストプラクティスもIDトークンを継続的なセッショントークンとして扱うことは想定していない。
  出典: [Best Practices for Implementing Sign in with Google](https://developers.google.com/identity/siwg/best-practices), [OpenID Connect \| Google Identity](https://developers.google.com/identity/openid-connect/openid-connect)
- **bloomにとって重要な設計上の含意**: bloomは既に`app_access_token`という自前の長期間有効なBearerトークンでセッションを維持する仕組みを持っている(`Class_User.php`の`access_token_verification`、`Class_UserApi.php`の`generateToken()`)。したがって Google Sign-In の役割は「ログイン/新規登録の瞬間に本人確認をする」ことだけに限定でき、**Googleトークンの有効期限管理やリフレッシュをbloom側で扱う必要は基本的にない**。再ログインのたびにFlutter側で`google_sign_in`から新しいIDトークンを取得し、bloom側で毎回検証すればよく、Google由来のトークンをbloomのDBに保存し続ける必要もない(保存するのは`google_sub`という不変の識別子のみでよい)。
- 一方、`google_sign_in`パッケージ自体のWeb実装に関する注記として、pub.devのパッケージ概要には「Web版では`accessToken`は自動更新されなくなり、3600秒で失効する。アプリ側でのハンドリングが必要」との記載がある。ただしこれは**Web限定の`accessToken`(Google API呼び出し用)の話であり**、モバイル(iOS/Android)や、bloomが使う`idToken`の検証フローには直接関係しない。念のため今後Web対応や追加スコープ(Google Drive等)を検討する場合の注意点として記録しておく。
  出典: [google_sign_in \| pub.dev](https://pub.dev/packages/google_sign_in)

### 4.4 OAuthクライアントID設計のわかりにくさ

- Android/iOS/Webでそれぞれ別々のOAuthクライアントIDを発行する必要があるが(4.1節参照)、**バックエンドでのIDトークン検証時のaudience(`aud`)にはWebクライアントID(`serverClientId`)を使う**という点は直感的にわかりにくく、設定ミスの温床になりやすい。Android Credential Manager実装ガイド・iOSバックエンド認証ガイドの双方が明示的にこの点を案内している。
  出典: [Implement Sign in with Google \| Android Developers](https://developer.android.com/identity/sign-in/credential-manager-siwg-implementation), [Authenticate with a backend server (iOS)](https://developers.google.com/identity/sign-in/ios/backend-auth)
- Android向けには`google-services.json`にWebクライアントのエントリ(`client_type: 3`)が含まれている必要があり、含まれていない場合は明示的に`serverClientId`をコードで渡す必要がある(4.1節参照、`google_sign_in_android`のREADMEに明記)。

### 4.5 `tokeninfo`エンドポイントの誘惑

- `tokeninfo`はHTTP GET一発で検証できるため実装が最も簡単に見え、bloomの既存LINEログイン実装(リモート検証エンドポイント呼び出し方式)とも設計思想が似ているが、**Google公式ドキュメントは繰り返し「本番非推奨、スロットリングされ得る」と明記している**(2.4節参照)。開発初期のプロトタイプとしてはtokeninfoを使い、本番投入前にJWKSローカル検証(`google/apiclient`等)へ切り替える、という段階的な進め方も選択肢になる。

### 4.6 ブランド確認(brand verification)とOAuth同意画面

- Sign in with Googleのコンセント画面にアプリ名を表示するには「ブランド確認」の完了が必要、との記載がAndroid公式ドキュメントにある。個人開発でどの程度の審査期間・要件が発生するかは今回の一次情報だけでは詳細不明であり、実装着手前にGoogle Cloud ConsoleのOAuth同意画面設定画面で実際のフローを確認する必要がある。
  出典: [About Sign in with Google \| Android Developers](https://developer.android.com/identity/sign-in/credential-manager-siwg)
- 一方、`email`/`profile`/`openid`スコープのみを使う限りは「非機密スコープ」に分類され、Googleによる本番アプリ審査(sensitive/restricted scope向けの厳格な審査)は不要という点は明確(2.1節/1.3節参照)。ここは他のOAuth連携(例: Google Drive等の追加スコープ)と混同しないよう注意。
  出典: [Sensitive scope verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification)

---

## 参考情報源(一次情報)

**Google Identity公式ドキュメント**
- [Verify the Google ID token on your server side](https://developers.google.com/identity/gsi/web/guides/verify-google-id-token)
- [Authenticate with a backend server \| Sign in with Google for Android](https://developers.google.com/identity/sign-in/android/backend-auth)
- [Authenticate with a backend server \| Sign in with Google for iOS](https://developers.google.com/identity/sign-in/ios/backend-auth)
- [OpenID Connect \| Google Identity](https://developers.google.com/identity/openid-connect/openid-connect)
- [Best Practices for Implementing Sign in with Google](https://developers.google.com/identity/siwg/best-practices)
- [Sensitive scope verification \| App verification to use Google Authorization APIs](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification)
- [GetGoogleIdOption.Builder \| Google for Developers](https://developers.google.com/identity/android-credential-manager/android/reference/com/google/android/libraries/identity/googleid/GetGoogleIdOption.Builder)

**Android Developers公式ドキュメント**
- [About the migration from legacy Google Sign-In \| Identity \| Android Developers](https://developer.android.com/identity/sign-in/legacy-gsi-migration)
- [About Sign in with Google \| Identity \| Android Developers](https://developer.android.com/identity/sign-in/credential-manager-siwg)
- [Implement Sign in with Google \| Identity \| Android Developers](https://developer.android.com/identity/sign-in/credential-manager-siwg-implementation)

**Google Cloud Console / API Console ヘルプ(Google公式サポートページ)**
- [Setting up OAuth 2.0 - API Console Help](https://support.google.com/googleapi/answer/6158849?hl=en)

**`google_sign_in`パッケージ(pub.dev / GitHub, flutter.dev公式)**
- [google_sign_in \| pub.dev](https://pub.dev/packages/google_sign_in)
- [google_sign_in changelog \| pub.dev](https://pub.dev/packages/google_sign_in/changelog)
- [google_sign_in API doc overview \| pub.dev](https://pub.dev/documentation/google_sign_in/latest/)
- [google_sign_in_android \| pub.dev](https://pub.dev/packages/google_sign_in_android)
- [google_sign_in_android changelog \| pub.dev](https://pub.dev/packages/google_sign_in_android/changelog)
- [google_sign_in_ios \| pub.dev](https://pub.dev/packages/google_sign_in_ios)
- [google_sign_in README (flutter/packages, GitHub)](https://raw.githubusercontent.com/flutter/packages/main/packages/google_sign_in/google_sign_in/README.md)
- [MIGRATION.md (flutter/packages, GitHub)](https://github.com/flutter/packages/blob/main/packages/google_sign_in/google_sign_in/MIGRATION.md)

**PHP検証ライブラリ**
- [Client.php (googleapis/google-api-php-client, GitHub, Google公式)](https://github.com/googleapis/google-api-php-client/blob/main/src/Client.php)
- [google/apiclient \| Packagist](https://packagist.org/packages/google/apiclient)(Composerパッケージ名の確認用。Packagist自体はGoogle公式ではないパッケージレジストリだが、掲載内容はgoogleapis/google-api-php-clientリポジトリのミラー)

**bloomバックエンド実ソース(参考・grounding用)**
- `/Users/daichi/Documents/blooom関係/dream/app/api/route_api.php`
- `/Users/daichi/Documents/blooom関係/dream/app/api/Class_UserApi.php`
- `/Users/daichi/Documents/blooom関係/dream/Class_User.php`
- `/Users/daichi/Documents/blooom関係/dream/Class_Line.php`(既存LINE認証実装との比較用)
- `/Users/daichi/Documents/blooom関係/dream/composer.json`(既存Composer依存の確認用)

## 二次情報として参照した箇所(明記)

調査の初期段階でWebSearchのスニペット要約から得た「iOS発行のIDトークンはaudienceがiOSクライアントID、Android/Webはaudienceが常にWebクライアントIDになる」という趣旨の情報は、`dev.to`・`medium.com`記事のスニペットに由来する二次情報だったため、そのまま採用せず、Android公式実装ガイド(`developer.android.com/identity/sign-in/credential-manager-siwg-implementation`)およびiOSバックエンド認証ガイド(`developers.google.com/identity/sign-in/ios/backend-auth`)の一次情報で「バックエンド検証にはWebクライアントID(`serverClientId`)を使う」という趣旨を裏取りした上で1.3節・4.4節に記載している。それ以外の箇所は上記の一次情報源に直接基づく。
