Type: research
Status: resolved

## Question

LINEログインを、このFlutterアプリ(モバイル)向けに`route_api.php`のJSON API経由で使える形にする実現可能性を調査する。

背景: bloomのバックエンド(`/Users/daichi/Documents/blooom関係/dream/`)には既にLINEログインのOAuth2実装が存在する(`Class_Line.php`、`line/line_login/regist.php`)。ただしこれはPHPの`$_SESSION`とサーバーサイドリダイレクトを前提としたWeb向けの実装で、`route_api.php`には対応する`execute_function`が存在しない。

含めるべき論点:

1. `Class_Line.php`の既存実装(`GENERATE_ACCESS_TOKEN`/`ACCESS_TOKEN_VALIDITY_VERIFICATION`/`ID_TOKEN_VALIDITY_VERIFICATION`/`GET_USER_PROFILE`等の定数と対応するメソッド)を読み、モバイル向けJSON APIとしてどこまで再利用できるか(LINEとのHTTP通信ロジックはそのまま使えそうか、セッション依存部分だけ書き換えが必要かなど)。
2. Flutter側の実装方法(LINE公式のFlutter SDK `flutter_line_sdk`、またはLINE LoginのOAuth2フローを直接実装する方法)——モバイルネイティブのLINEログイン(アプリ切り替え型)とWebView経由の違い。
3. モバイルクライアントがLINEのaccess_token/id_tokenを取得した後、それをbloomサーバーへどう渡し、サーバー側でどう検証するのが妥当か(新しい`execute_function`の設計イメージ)。
4. `system_id`との紐付け方針の選択肢(LINEのユーザーID相当をどこに保存するか)。
5. 既知の落とし穴・注意点(LINE Developersコンソールでのチャネル設定、Universal Link/Custom URL Schemeの設定、審査の要否)。

一次情報源(LINE Developers公式ドキュメント、`flutter_line_sdk`の公式ドキュメント/リポジトリ)と、bloomの既存ソース(`Class_Line.php`、`line/line_login/regist.php`、関連する`line/`配下のファイル)の両方にあたって調査すること。調査結果は`.scratch/auth-method-redesign/research/line-login.md`に保存する。

## Answer

`/research`サブエージェントが調査完了。詳細は[research/line-login.md](../research/line-login.md)。要点は[05-choose-auth-methods](05-choose-auth-methods.md)/[06-account-linking-model](06-account-linking-model.md)の決定に反映済み(bloomの既存LINEインフラがほぼ再利用可能、4方式中最小コスト、`line_account_user_info`経由の変則設計は`user.line_user_id`直接参照に切り替える方針で決着)。
