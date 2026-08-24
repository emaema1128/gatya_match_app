Type: research
Status: resolved

## Question

電話番号(SMS認証、OTP)によるログイン/登録をこのFlutterアプリ+bloomバックエンドに導入する場合の実現可能性を調査する。

背景: bloomバックエンドには`keep_telnumber.php`という、素の`$_POST`で`tel_number`カラムに書き込むだけのスクリプトが存在するが、SMS送信・OTP発行・検証のロジックは一切ない。認証基盤としてはゼロから構築する必要がある。

含めるべき論点:

1. SMS OTP認証の一般的な実装パターン(OTPの生成・有効期限・再送制限・検証の設計)。
2. 日本向けSMS送信サービスの選択肢(例: Twilio、AWS SNS、その他日本の主要SMS APIプロバイダ)と、それぞれの大まかな料金感(1通あたりのコスト)・日本の携帯キャリア宛て送信の実績/信頼性。
3. Flutter側の実装方法(電話番号入力→OTP入力の2ステップUI、`firebase_auth`の電話番号認証機能を使う選択肢も含めて比較)。
4. Firebase Authentication(電話番号認証)を使う場合、bloomの既存`system_id`ベースの認証モデルとどう組み合わせるか(Firebaseを認証基盤として一部委譲する設計 vs bloom側で完全に自前実装する設計、それぞれの実装コスト差)。
5. 既知の落とし穴・注意点(SMS詐欺対策・reCAPTCHA等の不正利用対策の必要性、国際電話番号対応の要否)。

一次情報源(各SMSプロバイダの公式ドキュメント、Firebase Authentication公式ドキュメント)にあたって調査すること。調査結果は`.scratch/auth-method-redesign/research/phone-sms-auth.md`に保存する。

## Answer

`/research`サブエージェントが調査完了。詳細は[research/phone-sms-auth.md](../research/phone-sms-auth.md)。要点は[05-choose-auth-methods](05-choose-auth-methods.md)の決定に反映済み(4方式中最大コスト、ゼロからの構築が必要、Firebase委譲でも継続課金+PHP公式Admin SDK非対応という制約あり)。
