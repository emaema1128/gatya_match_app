Type: research
Status: resolved

## Question

Googleログイン(Google Sign-In)をこのFlutterアプリ(iOS/Android)+bloomバックエンドに導入する場合の実現可能性を調査する。

含めるべき論点:

1. Flutter側の実装方法(`google_sign_in`パッケージ等)——iOS/Androidそれぞれでの対応状況、必要な設定(Google Cloud ConsoleでのOAuthクライアントID発行、iOSの`GoogleService-Info.plist`/Androidの設定など)。
2. Googleが返すid tokenの検証方法(Googleの公開鍵(JWKS)、audience/issuerのチェック、あるいはGoogleのtokeninfoエンドポイントを使う方法)——サーバー側(PHP)でどう実装するのが一般的か。
3. bloomバックエンド側に必要な追加実装の見積もり(新しい`execute_function`、Googleから取得できるユーザー情報、`system_id`との紐付け方針の選択肢)。
4. 既知の落とし穴・注意点(Google Sign-InのAndroid/iOS SDKの最近の変更(Credential Manager移行など)、トークンの有効期限・リフレッシュの扱い)。

一次情報源(Google公式ドキュメント、`google_sign_in`パッケージの公式ドキュメント/リポジトリ)にあたって調査すること。調査結果は`.scratch/auth-method-redesign/research/google-sign-in.md`に保存する。

## Answer

`/research`サブエージェントが調査完了。詳細は[research/google-sign-in.md](../research/google-sign-in.md)。要点は[05-choose-auth-methods](05-choose-auth-methods.md)の決定に反映済み(iOS/Android双方公式対応、小〜中コスト、バックエンド検証はWebクライアントIDをaudienceに使う点に注意)。
