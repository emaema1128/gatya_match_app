Type: research
Status: resolved

## Question

Apple Sign-In(Sign in with Apple)をこのFlutterアプリ(iOS/Android)+bloomバックエンドに導入する場合の実現可能性を調査する。

含めるべき論点:

1. Flutter側の実装方法(`sign_in_with_apple`パッケージ等)——iOS/Androidそれぞれでの対応状況、必要な設定(Apple Developer側のCapability設定、Service ID等)。
2. Appleが返すidentity tokenの検証方法(Appleの公開鍵(JWKS)、audience/issuerのチェックなど)——サーバー側(PHP)でどう実装するのが一般的か。
3. bloomバックエンド側に必要な追加実装の見積もり(新しい`execute_function`、Apple側から取得できるユーザー情報(メールアドレス秘匿化の可能性等)、`system_id`との紐付け方針の選択肢)。
4. Apple Sign-Inに関するApp Store審査要件の実際の条件(「他のソーシャルログインを提供する場合に必須」という理解の正確な条件文言)。
5. 既知の落とし穴・注意点(メールアドレスがApple側でリレー/秘匿化される場合の扱い、初回ログイン時のみ氏名/メールが返る制約など)。

一次情報源(Apple公式ドキュメント、`sign_in_with_apple`パッケージの公式ドキュメント/リポジトリ)にあたって調査すること。調査結果は`.scratch/auth-method-redesign/research/apple-sign-in.md`に保存する。

## Answer

`/research`サブエージェントが調査完了。詳細は[research/apple-sign-in.md](../research/apple-sign-in.md)。要点は[05-choose-auth-methods](05-choose-auth-methods.md)の決定に反映済み(iOSはネイティブ、Androidは非ネイティブでbloomサーバーの中継が必要、App Store 4.8は主要ログイン手段として提供する場合のみ発動)。
