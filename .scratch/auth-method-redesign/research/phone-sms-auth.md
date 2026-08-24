# 電話番号(SMS OTP)ログイン/登録の実現可能性調査

Type: research (resolves [issues/04-phone-sms-auth-feasibility.md](../issues/04-phone-sms-auth-feasibility.md))

## Scope / Method

一次情報源(各SMSプロバイダ公式ドキュメント、Firebase Authentication公式ドキュメント、NIST/OWASP)のみを参照。各主張の直後に出典URLを付す。secondary情報(ブログ等)を使った箇所は明示的に「(secondary)」と記載する。

bloom側の前提: `keep_telnumber.php`(`/Users/daichi/Documents/blooom関係/dream/keep_telnumber.php`)は`$_POST['tel']`を無検証で`user.tel_number`に`UPDATE`するだけで、OTP生成・送信・検証ロジックは一切存在しない。既存認証は自動採番`system_id`+ランダム`login_id`/`password`のみ(`registUser`/`login`)。SMS OTP認証は事実上ゼロから設計する前提で調査した。

---

## 1. SMS OTP認証の一般的な実装パターン

### 1.1 検証ライフサイクル(3ステップモデル)

業界標準的なOTP検証は概ね次の3ステップ:

1. 電話番号を受け取り、正規化(E.164形式)する
2. OTPコードを生成・送信し、サーバー側に(ハッシュ化した状態で)保存する。ステータスは「pending」
3. ユーザーが入力したコードを照合し、「approved」/失敗を返す

Twilio Verify APIはまさにこの3段階(Verification Service作成→Verification送信→VerificationCheck照合)をAPIとして提供している。
出典: [Verify API | Twilio](https://www.twilio.com/docs/verify/api)

### 1.2 コード長・有効期限・再送制御の具体的な数値(業界のリファレンス値)

Twilio公式のベストプラクティスページより:

- コード長: 4〜10桁、デフォルト6桁。「Longer codes offer more combinations and resist brute force attempts」
- 有効期限: 「Once generated, tokens are valid for 10 minutes.」有効期限内に再送要求された場合は同じトークンを再利用する
- 再送/レート制限: 「1 request / 30 seconds per phone number」を推奨し、exponential backoffを併用。目的は「spam, API rate limit violations, and toll fraud」の防止
- メッセージ長: SMSは1セグメント(GSM文字のみなら160文字、非GSM文字混在なら70文字)に収まるようOTPメッセージを設計すべき。超過すると複数セグメント課金される

出典: [Verification and two-factor authentication best practices | Twilio](https://www.twilio.com/docs/verify/developer-best-practices)

OWASP Forgot Password Cheat Sheetも近い設計指針を示す:

- SMS等の「側チャネル」で送るPINは6〜12桁の数字を推奨(読みやすさのため空白区切りも推奨)
- コードは「暗号学的に安全な乱数生成器で生成」「使用後は無効化」「特定ユーザーに紐付け」が必須
- 過度な自動送信への対策として、アカウント単位のレート制限・CAPTCHA等を要求

出典: [Forgot Password Cheat Sheet - OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html)

NIST SP 800-63B(Digital Identity Guidelines)は、PSTN(SMS含む)を使ったout-of-band認証について次を要求している(§5.1.3.2, §5.1.3.3):

- 「the authentication SHALL be considered invalid if not completed within 10 minutes」(10分の有効期限は業界のデファクトというより、NISTの規範的要求と一致)
- 「verifiers SHALL accept a given authentication secret only once during the validity period」(リプレイ防止・使い捨て)
- 「the verifier SHALL verify that the pre-registered telephone number being used is associated with a specific physical device」
- 「Verifiers SHOULD consider risk indicators such as device swap, SIM change, number porting, or other abnormal behavior before using the PSTN to deliver an out-of-band authentication secret.」
- PSTN(SMS)経由のOOB認証は「RESTRICTED」カテゴリに分類されている(第一級の認証手段としては非推奨、ただしリスクを許容した上での使用は可)

出典: [NIST Special Publication 800-63B](https://pages.nist.gov/800-63-3/sp800-63b.html) (§5.1.3.2 “Verifier Compromise Resistance”, §5.1.3.3 “Public Switched Telephone Network Authenticators”)

**bloomでの設計指針としてのまとめ**: 6桁数字OTP、有効期限10分、同一電話番号への送信は30秒に1回程度まで、5回程度の誤入力でロック、コードはハッシュ化してDB保存、使用後即時無効化——という組み合わせは、Twilio/OWASP/NISTいずれの一次情報とも矛盾しない一般的な設計。

---

## 2. 日本向けSMS送信プロバイダの選択肢

### 2.1 Twilio (Verify API / Programmable Messaging)

- Verify APIの料金: 「$0.05 per successful verification」(基本料金)+チャネル別料金。SMSチャネルは米国例で「+ $0.0083 per SMS (US)」だが、これは米国レートの例示であり、日本向けの正確なSMSチャネル単価はページ内に明示されていない(国際SMS料金ページへのリンクのみ)。
  出典: [Verify Pricing | Twilio](https://www.twilio.com/en-us/verify/pricing)
- 参考値として、Twilioの通常SMS(Programmable Messaging)の日本向け料金は「Long codes: $0.0890 per message」。Verify経由でも同水準のSMSチャネル料金が上乗せされると想定すると、日本向けVerify SMSは概算 **$0.05 + 約$0.089 ≒ $0.14/件(successful verification)** 程度になる可能性が高い(この合算は本調査での推定であり、Twilio公式ページがJP向けVerify SMS単価を明記しているわけではない点に注意)。
  出典: [SMS Pricing in Japan for Text Messaging | Twilio](https://www.twilio.com/en-us/sms/pricing/jp)
- **日本向け送信の技術的制約(重要)**: Twilioは日本向けSMSに国際ゲートウェイと国内ゲートウェイの2種類を持つ。
  - Alphanumeric Sender ID: 国際ゲートウェイでは「Not Supported」。国内ゲートウェイでは登録制で「5 weeks」のプロビジョニング期間が必要
  - Long code: 国際発信では登録不要でサポートされるが、国内ゲートウェイでは「Not Supported」(利用にはセールスチームへの問い合わせが必要)
  - Short code: 「Not supported」
  - KDDI(au)網向け: 5セグメントを超えるSMSは配信遅延の可能性があるとの注記あり。国際発信の数字Sender IDはKDDI網では自動的に「010」が前置される
  出典: [Japan: SMS Guidelines | Twilio](https://www.twilio.com/en-us/guidelines/jp/sms)
- Fraud Guard(不正利用対策、後述§5で詳述): デフォルトで全顧客に有効化されており、SMS pumping fraud等の疑わしいトラフィックを自動ブロックする。Basic/Standard/Maxの3段階で調整可能。
  出典: [Verify Fraud Guard | Twilio](https://www.twilio.com/docs/verify/preventing-toll-fraud/sms-fraud-guard)
- Programmable Rate Limits: 電話番号・IP・country code等を組み合わせた独自レート制限をAPI層でかけられ、制限超過時はHTTP 429を返す。「Rate Limits block requests at the API layer before any channel delivery occurs.」
  出典: [Programmable Rate Limits | Twilio](https://www.twilio.com/docs/verify/api/programmable-rate-limits)

**評価**: グローバルで実績豊富、Verify APIによりOTP生成・検証・不正対策が完成品として提供される点は開発コストを大きく下げる。ただし日本国内直通(国内ゲートウェイ)の利用には事前のセールス問い合わせ・登録が必要で、デフォルトの国際ゲートウェイ経由だとLong codeでの発信となり、KDDI網での長文SMS配信遅延など日本特有の注意点がある。

### 2.2 AWS SNS (Amazon Simple Notification Service) / AWS End User Messaging SMS

- AWS SNSは現在、SMS配信の実体を「AWS End User Messaging SMS」に統合している。
  出典: [Sending SMS messages using Amazon SNS](https://docs.aws.amazon.com/sns/latest/dg/sms_sending-overview.html)
- 料金: 「AWS Worldwide SMS Pricing」ページは「The price for sending SMS messages varies between countries, regions...The prices...are provided for guidance only, and change frequently」とのみ記載し、コンテンツ取得の制約により本調査ではJP向け具体的な$/messageの数値を直接確認できなかった(ページの料金表がツールの取得時に展開されなかった)。正確な単価は実装時にAWSコンソールまたは日次使用状況レポートで確認する必要がある。
  出典: [Amazon SNS SMS Pricing](https://aws.amazon.com/sns/sms-pricing/)
- **日本向けサポート状況(Supported countries and regionsの一次表より確認)**: Japan (JP, dialing code 81) は
  - Short codes: **Yes**
  - Long codes: **No**
  - Sender IDs: **Yes**(他の多くの国と異なり「Registration required」の脚注が付いていない=事前登録不要と読める)
  - Two-way SMS: **Yes**
  - International sending: **Yes**
  出典: [Supported countries and regions for SMS messaging with AWS End User Messaging SMS](https://docs.aws.amazon.com/sms-voice/latest/userguide/phone-numbers-sms-by-country.html)
- メッセージタイプは`Transactional`(OTP等のクリティカルな用途、デフォルト)と`Promotional`を選択でき、OTP送信には`Transactional`を使うことが明記されている。
  出典: [Sending SMS messages using Amazon SNS](https://docs.aws.amazon.com/sns/latest/dg/sms_sending-overview.html)
- 新規AWSアカウントは「SMS sandbox」状態から始まり、検証済み宛先にしか送信できない。本番送信にはサンドボックス脱却の申請が必要。
  出典: [Sending SMS messages using Amazon SNS](https://docs.aws.amazon.com/sns/latest/dg/sms_sending-overview.html)
- ベストプラクティスページには法規制の一覧があり、日本については「Japan: The Act on Regulation of Transmission of Specific Electronic Mail may apply to certain types of SMS messages」と明記(特定電子メール法)。
  出典: [Best practices for Amazon SNS SMS messaging](https://docs.aws.amazon.com/sns/latest/dg/channels-sms-best-practices.html) / [法令原文(日本語訳)](https://www.japaneselawtranslation.go.jp/en/laws/view/3767/en)

**評価**: 既にAWSを使っていない場合は導入コストが相対的に高い(SNS単体ではなくAWS End User Messaging SMSの学習コストも発生)。日本はLong code非対応でShort code/Sender ID中心という制約があり、単純な「電話番号宛にAPIを叩けば届く」というシンプルさはTwilioよりやや劣る可能性がある。

### 2.3 日本国内SMS配信サービス(NTT Com / KDDI)

- **NTTドコモビジネス(旧NTTコム オンライン)「空電プッシュ」/ NTT CPaaS SMS API**: 到達率「99.99%※」(2025年10月〜2026年3月の6か月測定、圏外・切電等除く)を謳う。料金は個別見積もり制で、ページ上に固定の円/通単価は明記されていない(要問い合わせ)。
  出典: [空電プッシュ | NTTドコモビジネスX](https://www.karaden.jp/)
  (別検索で「1通8円〜」という言及もあったが、これはWebSearchの要約結果であり、`karaden.jp`本体ページの直接取得では確認できなかったため、secondary情報として扱う)
- **KDDI Message Cast**: 初期費用・月額固定費なしの従量課金制。「1通あたりの費用 9.35円(税込)〜」、条件により単価変動。配信成功時のみ課金(unsuccessfulな配信は課金されない)。国内キャリア直収のため到達率が高いことをアピールしている。
  出典: [料金 - SMS送信サービス「KDDIメッセージキャスト」](https://kddimessagecast.jp/price/)

**評価**: 国内キャリア直収型のサービスは、Twilioの「国内ゲートウェイは要問い合わせ」という制約を最初から回避でき、日本語のサポート・請求書対応も含めて一人開発には運用しやすい可能性がある。ただし料金は要問い合わせ制のところが多く、事前に正確な費用感を得るには営業接触が必要。KDDI Message Castは1通9.35円〜であり、Twilioの$0.089(≈13円前後、為替次第)+Verify基本料$0.05(≈7円)と比べても大差ない水準。

### 2.4 価格感のまとめ(概算、実装前に必ず最新情報を確認すること)

| プロバイダ | 概算単価 | 備考 |
|---|---|---|
| Twilio Verify (SMS, JP) | 約$0.14/successful verification (概算、$0.05基本料+JP SMS料金$0.089を合算した推定値) | 国内ゲートウェイ利用は要セールス問い合わせ |
| Twilio Programmable SMS (JP, long code) | $0.0890/message | Verify不使用、自前でOTPロジックを組む場合の生SMS単価 |
| AWS SNS/End User Messaging SMS (JP) | 本調査では正確な単価を一次情報から確認できず | Short code/Sender ID中心、Long code非対応 |
| KDDI Message Cast | 9.35円〜/通(税込) | 国内キャリア直収、配信成功時のみ課金 |
| NTT Com (空電プッシュ/NTT CPaaS) | 要問い合わせ | 到達率99.99%を公称 |
| Firebase Authentication Phone Auth | 不明(§4参照) | 一次情報からJP単価を確認できず |

---

## 3. Flutter側の実装

### 3.1 二段階UI(電話番号入力→OTP入力)の一般形

どのプロバイダを使うにしても、Flutter側のUIは基本的に「電話番号入力→コード送信→OTP入力→検証」の2画面構成になる。E.164形式への正規化(国番号+電話番号)はTwilio/AWS SNS双方の一次ドキュメントで明示的に要求されている。
出典: [Sending SMS messages using Amazon SNS](https://docs.aws.amazon.com/sns/latest/dg/sms_sending-overview.html)(「you specify the phone number using the E.164 format」)

### 3.2 firebase_auth (Firebase Authentication) を使う場合

Flutter公式のFirebaseFire統合(`firebase_auth`パッケージ)には、電話番号認証専用のFlutter向けドキュメントページが存在する。

- APIは`FirebaseAuth.instance.verifyPhoneNumber()`で、4つのコールバックを持つ:
  - `verificationCompleted`: 「This handler will only be called on Android devices which support automatic SMS code resolution.」(Android限定の自動読み取り)
  - `verificationFailed`: 無効な電話番号・SMSクォータ超過等のエラーハンドリング
  - `codeSent`: SMS送信完了時に`verificationId`と(Android限定の)`resendToken`を受け取る
  - `codeAutoRetrievalTimeout`: Android自動読み取りのタイムアウト(デフォルト30秒、`timeout`引数でカスタマイズ可)
- サインインは`PhoneAuthProvider.credential(verificationId:, smsCode:)`で`PhoneAuthCredential`を作り、`signInWithCredential()`を呼ぶだけ
- プラットフォーム別の追加設定:
  - iOS: プッシュ通知の有効化、APNs認証キーのFirebase Console登録、Background Modesの設定が必要
  - Android: SHA-1(および後述のPlay Integrity用にSHA-256)フィンガープリントをFirebase Consoleに登録
  - Web: `signInWithPhoneNumber()`はGoogle reCAPTCHAウィジェットを内部で管理する

出典: [Authenticate with Firebase using phone numbers on Flutter](https://firebase.google.com/docs/auth/flutter/phone-auth)

**プリビルドUIの有無**: 公式の`firebase_ui_auth`パッケージ(FlutterFire UI)は`PhoneAuthProvider`を含む複数のサインイン方式のプリビルドウィジェットを提供しており、電話番号入力→OTP入力の2画面フローを自前で組む必要がなくなる。プラットフォーム対応表ではAndroid/iOS/Webが対応(macOS/Windows/Linuxは非対応)。
出典: [firebase_ui_auth | Flutter package](https://pub.dev/packages/firebase_ui_auth)

### 3.3 「firebase_authでFirebaseに任せる」vs「生SMSプロバイダに対して完全自前実装」の比較

| 観点 | Firebase Authentication (`firebase_auth`) | 完全自前(Twilio/AWS/国内SMS API直叩き) |
|---|---|---|
| OTP生成・保存・検証ロジック | Firebase側が完全に内包(自前実装不要) | 自前でOTP生成・ハッシュ化保存・有効期限・照合ロジックを実装する必要あり |
| 不正利用対策(bot/toll fraud) | Android: Play Integrity API(端末の正当性検証)、失敗時reCAPTCHAにフォールバック。iOS: サイレントAPNsプッシュ通知、失敗時reCAPTCHAにフォールバック。いずれもGoogle側が実装・維持 | 自前でレート制限・CAPTCHA相当・異常検知を実装する必要がある(Twilio Verifyを使わずSMS APIを直叩きする場合は特に) |
| Flutter側UI実装コスト | `firebase_ui_auth`のプリビルドウィジェットで大幅短縮可能、自前実装でも`verifyPhoneNumber`の4コールバックに沿うだけで済む | フォームバリデーション・エラーハンドリング・再送UI等をすべて自前設計 |
| 料金体系 | Blazeプラン(従量課金)限定。SMS送信数に応じた課金(§4で詳述) | 選定プロバイダの従量課金(§2参照) |
| プラットフォーム追加設定 | iOS: APNs認証キー・Push設定必須。Android: SHA-1/SHA-256フィンガープリント登録必須 | プロバイダ側の追加設定は基本的に不要(APIキーのみ) |
| bloomとのデータ統合 | Firebase側にユーザーレコードが作られる(UID)。bloomの`system_id`と紐付ける追加設計が必要(§4) | bloomのDBに直接OTP検証結果を書き込めるため、既存の`system_id`モデルにそのまま統合しやすい |

出典(不正利用対策の詳細): [Authenticate Using Phone Numbers on Android](https://firebase.google.com/docs/auth/android/phone-auth), [Authenticate Using Phone Numbers on iOS](https://firebase.google.com/docs/auth/ios/phone-auth)

---

## 4. Firebase Authenticationを使う場合のbloom `system_id` モデルとの統合設計

### 4.1 想定される統合パターン

**パターンA: 「Firebaseは電話番号の検証のみを担当し、アカウントの実体(system_id)はbloomが所有し続ける」**

1. FlutterアプリがFirebase Authenticationで電話番号のSMS OTP検証を完了し、Firebase ID Token(JWT)を取得する
2. Flutterアプリがそのid TokenをbloomのAPI(例: `keep_telnumber.php`を置き換える新エンドポイント)に送信する
3. bloomのPHPバックエンドがそのJWTを検証する。Firebaseは検証手順を一次ドキュメントとして公開している:
   - ヘッダの`alg`が`RS256`であること、`kid`がGoogleの公開鍵のいずれかと一致すること
   - ペイロードの`exp`(未来であること)、`iat`(過去であること)、`aud`(Firebaseプロジェクトidと一致)、`iss`(`https://securetoken.google.com/<projectId>`と一致)、`sub`(空でないuid文字列)、`auth_time`(過去であること)
   - 署名がGoogleの公開鍵(`https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com`から取得)で検証できること
   出典: [Verify ID Tokens](https://firebase.google.com/docs/auth/admin/verify-id-tokens)
4. 検証に成功したJWTのペイロードには検証済み電話番号のクレームが含まれるため、bloomはその電話番号を信頼できる値として`user.tel_number`に書き込み、既存の`system_id`ベースのアカウントに紐付け(または新規`system_id`発行)できる

**Admin SDKの言語サポート**: Firebase公式ドキュメントのコード例はNode.js/Java/Python/Go/C#のみで、**PHPは公式Admin SDK対応言語に含まれていない**。したがってbloom(PHP)側では、Admin SDKを使わずJWT検証を手実装(またはRS256対応の汎用JWTライブラリを利用)する必要がある。
出典: [Verify ID Tokens](https://firebase.google.com/docs/auth/admin/verify-id-tokens)

**パターンB: 完全自前実装** — bloomのPHPバックエンドがOTP生成・SMS送信API呼び出し・検証・レート制限をすべて内製する。Firebaseは一切関与しない。

### 4.2 実装コストの大まかな比較

| 実装項目 | パターンA (Firebase委譲) | パターンB (完全自前) |
|---|---|---|
| Flutter側 | `firebase_auth`/`firebase_ui_auth`導入、iOS/Android追加設定(APNs, SHA fingerprint) | 電話番号/OTP入力の2画面自前実装、SMS API呼び出し用のHTTPクライアント実装 |
| バックエンド(bloom, PHP) | 新規: JWT検証ロジック(RS256署名検証+クレームチェック、公開鍵取得・キャッシュ)。1エンドポイント程度の追加実装規模 | 新規: OTPテーブル設計・生成・ハッシュ化保存・有効期限管理・レート制限(電話番号単位/IP単位)・SMSプロバイダAPI呼び出し・再送制御・不正利用検知をすべて設計実装 |
| 不正利用対策 | Google側が実装済み(Play Integrity/silent push/reCAPTCHA)。bloom側での追加実装は基本不要 | reCAPTCHA相当の仕組み、レート制限、異常検知をすべて自前で設計・実装・運用する必要あり |
| SMS到達性・キャリア対応 | Googleが世界中のキャリアとの関係を管理(bloom側は関知不要) | 選定プロバイダ次第。日本キャリア(docomo/au/SoftBank/楽天モバイル)固有の制約(§2.1のKDDI segment遅延など)をアプリ側で意識する必要が出る場合がある |
| 運用・監視 | Firebase Consoleでの監視、Google側のインフラに依存 | 独自の監視・アラート・ログ基盤が必要 |
| ランニングコスト | Blazeプラン従量課金(§4.3) | 選定SMSプロバイダの従量課金(§2.4) |

**総評**: 一人開発でバックエンドの保守負担を最小化したい場合、パターンA(Firebase委譲)は「OTP生成・送信・不正対策」という最もリスクの高い部分を丸ごとGoogleに委譲でき、bloom側の新規実装はJWT検証(比較的小さいコード量)に限定できる点で実装コストが低い。ただしFirebase ID TokenのPHP側検証は公式Admin SDKがないため手実装または非公式ライブラリに依存する点、およびFirebase内にも独自のユーザーレコード(UID)が生成される点(=bloomの`system_id`と二重管理になる)は考慮が必要。

パターンB(完全自前)は、既存の`system_id`モデルに最も自然に統合できる(外部ID体系を持ち込まない)一方、OTPライフサイクル管理・不正利用対策を含む認証基盤をゼロから設計・実装・保守する必要があり、実装工数・セキュリティリスクの両面でパターンAより明確に大きい。

### 4.3 Firebase Phone Authの料金体系(確認できた範囲)

- Phone Authは**Blazeプラン(従量課金)専用**。Sparkプラン(無料枠)では利用不可。「Phone Auth - All regions: Billed per SMS sent. See current rates」と記載され、正確な単価はGoogle Cloud Identity Platformの料金ページを参照する形になっている。
  出典: [Firebase Pricing](https://firebase.google.com/pricing)
- 制限値(Firebase Authentication標準、Identity Platformにアップグレードしていない場合):
  - 検証SMS: 900通/分、3,000通/日
  - IPアドレスあたり: 50通/分、500通/時
  - サインイン操作: 1,600/分
  - 検証リクエスト: 150リクエスト/IPアドレス/時
  - 「Firebase Authentication with Identity Platform: No limit」(Identity Platformにアップグレードすると日次上限が撤廃される)
  出典: [Firebase Authentication Limits](https://firebase.google.com/docs/auth/limits)
- 新しい「Firebase Phone Number Verification」専用の料金ページでは、地域・ボリューム別のTier制(Tier1: 0〜99,999件、Tier2: 100,000〜999,999件、Tier3: 1,000,000件以上、Enterprise: 個別見積もり)の例としてFinland/France/Germany/Indonesia/Malaysia/Pakistan/Spainの単価例(例: Spain $0.0312、France $0.0533、Germany $0.0875 / verification)が掲載されているが、**日本(Japan)はこのページの掲載国リストに含まれておらず、日本向けの正確な単価は本調査の一次情報から確認できなかった**。
  出典: [Firebase Phone Number Verification pricing](https://firebase.google.com/docs/phone-number-verification/pricing)
- (参考/未検証)WebSearchの要約では「Google Cloud Identity Platform料金ページにおいて日本向けSMSは$0.03/通、1日10通までは無課金」という情報が見つかったが、該当ページ(`cloud.google.com/identity-platform/pricing`)は本調査のツールでは長大すぎて全文取得できず、この数値をページ本文から直接確認することはできなかった。**実装検討時には必ずFirebase ConsoleまたはGoogle Cloudの請求ページで最新の日本向け単価を確認すること。**

**開発・テスト用の無料機能**: Identity Platform/Firebaseにはテスト用電話番号を最大10件登録でき、実際にSMSを送信せずOTPフローの単体テストやアプリストア審査用のテストアカウントを用意できる仕組みがある(クォータも消費しない)。
出典: [Registering test phone numbers](https://docs.cloud.google.com/identity-platform/docs/test-phone-numbers)

---

## 5. 既知の落とし穴・注意点

### 5.1 SMS toll fraud(国際収益分配詐欺)・不正利用対策

- SMS OTPは「SMS pumping fraud」「toll fraud」の標的になりやすい。攻撃者が大量の検証リクエストを自動送信し、高額な国際SMS料金や割増料金番号への着信を発生させて収益を得る、あるいは単純にAPI利用料を消費させる攻撃。
- Twilioはこれに対し「Verify Fraud Guard」をデフォルト有効化しており、Basic/Standard/Maxの3段階で保護レベルを調整できる。
  出典: [Verify Fraud Guard | Twilio](https://www.twilio.com/docs/verify/preventing-toll-fraud/sms-fraud-guard)
- Twilioの「Programmable Rate Limits」機能は、電話番号・IP・国コード等を組み合わせた任意のレート制限をAPI層でかけられ、配信前にブロックできる。
  出典: [Programmable Rate Limits | Twilio](https://www.twilio.com/docs/verify/api/programmable-rate-limits)
- Firebaseは複数レイヤーの不正対策を持つ:
  - Android: **Play Integrity API**(Authentication SDK v21.2.0+, Firebase BoM v31.4.0+で利用可能)。Google Play services搭載端末でアプリの正当性を検証し、成立すればOTP検証を進める。それ以外(Google Play services非搭載端末、Playストア外配布アプリ等)は**reCAPTCHA検証にフォールバック**する。
    出典: [Authenticate Using Phone Numbers on Android](https://firebase.google.com/docs/auth/android/phone-auth)
  - iOS: 初回サインイン時は**サイレントAPNsプッシュ通知**でトークンを検証。バックグラウンドフェッチが無効/シミュレータ実行時等でプッシュが機能しない場合は**reCAPTCHAにフォールバック**する。
    出典: [Authenticate Using Phone Numbers on iOS](https://firebase.google.com/docs/auth/ios/phone-auth)
  - **SMSリージョンポリシー**: 「Set a policy on the regions to which you want to allow or deny SMS messages to be sent. Setting an SMS region policy can help protect your apps from SMS abuse.」新規プロジェクトのデフォルトポリシーは「no regions」(全リージョン拒否)であり、明示的に許可国を設定する必要がある。日本向けのみ許可する設計にすればリスク面積を大きく縮小できる。
    出典: [Authenticate Using Phone Numbers on Android](https://firebase.google.com/docs/auth/android/phone-auth)
- NIST SP 800-63Bもリプレイ防止(「accept a given authentication secret only once」)、有効期限(10分)を規範的要求としている。
  出典: [NIST SP 800-63B §5.1.3.2](https://pages.nist.gov/800-63-3/sp800-63b.html)
- AWS SNSのベストプラクティスも「Amazon SNS team routinely audits SMS campaigns」「mobile phone carriers continuously audit bulk SMS senders」と、不審な送信パターンはキャリア/AWS双方から監視・遮断され得ることを明記している。
  出典: [Best practices for Amazon SNS SMS messaging](https://docs.aws.amazon.com/sns/latest/dg/channels-sms-best-practices.html)

**完全自前実装(§4のパターンB)を選んだ場合、これらの不正対策(reCAPTCHA相当・レート制限・地域制限・異常検知)をすべて自前で設計・実装・継続チューニングする必要がある**点は、実装コストと運用リスクの両面で軽視できない。

### 5.2 国際電話番号対応の要否

- 主要プロバイダ(Twilio/AWS SNS/Firebase)はいずれもE.164形式(国番号+電話番号、例: `+81...`)を前提としたAPI設計になっている。日本国内ユーザーのみを対象とする場合でも、E.164正規化自体は必須の実装コストとして発生する。
  出典: [Sending SMS messages using Amazon SNS](https://docs.aws.amazon.com/sns/latest/dg/sms_sending-overview.html)
- Firebaseの「SMSリージョンポリシー」で日本のみに許可を絞ることは、国際対応をスコープアウトしつつ不正利用対策を強化する具体的な手段として利用できる(§5.1参照)。
- bloom側で国際展開の予定がなければ、日本国内番号(`+81`)のみを許可する設計がシンプルかつ不正対策上も有利。ただし将来的な国際化が視野にある場合、E.164ベースの設計にしておけば拡張は比較的容易。

### 5.3 電話番号の再割り当て(番号リサイクル)リスク

NIST SP 800-63Bは、電話番号ベースの認証について次のリスク指標の考慮を明示的に求めている: 「device swap, SIM change, number porting, or other abnormal behavior」。日本の携帯キャリア(docomo/au/SoftBank/楽天モバイル)も契約解除後一定期間を経て番号を再割り当てする運用が一般的であり、「電話番号=本人」という前提は永続的に正しいとは限らない点はアカウント復旧・不正防止の設計上考慮すべき。
出典: [NIST SP 800-63B §5.1.3.3](https://pages.nist.gov/800-63-3/sp800-63b.html)

### 5.4 その他の実務的な注意点

- **Firebase Phone AuthはBlazeプラン専用**(従量課金)。Sparkプラン(無料枠)のプロジェクトでは利用できない。
  出典: [Firebase Pricing](https://firebase.google.com/pricing)
- **Twilio日本向け送信は国内/国際ゲートウェイの選択が必要**。デフォルトの国際ゲートウェイではLong code経由になるが、真に国内キャリア直収を求める場合は事前にTwilioセールスへの問い合わせ・登録(Alphanumeric Sender IDは約5週間のプロビジョニング)が必要になる。
  出典: [Japan: SMS Guidelines | Twilio](https://www.twilio.com/en-us/guidelines/jp/sms)
- **AWS SNSは新規アカウントが「SMSサンドボックス」から開始**され、検証済み宛先にしか送信できない。本番運用にはサンドボックス脱却の申請が必要。
  出典: [Sending SMS messages using Amazon SNS](https://docs.aws.amazon.com/sns/latest/dg/sms_sending-overview.html)
- **日本の法規制**: AWSの公式ベストプラクティスページは「特定電子メール法(Act on Regulation of Transmission of Specific Electronic Mail)」が一部のSMSメッセージに適用され得ると明記している。OTPのようなトランザクショナルメッセージでも、送信者情報の明示やオプトアウト対応などキャリア/法令上の要求に留意する必要がある。
  出典: [Best practices for Amazon SNS SMS messaging](https://docs.aws.amazon.com/sns/latest/dg/channels-sms-best-practices.html), [特定電子メール法(日本語訳)](https://www.japaneselawtranslation.go.jp/en/laws/view/3767/en)
- **Firebase利用時のデータ送信先**: WebSearchの要約情報(secondary、本文一次確認はできず)によれば、Firebase Authentication phone auth利用時にエンドユーザーの電話番号がGoogle側に送信・保存され、Google全体のスパム/不正対策に利用されるとの記述がある。プライバシーポリシー上の開示・ユーザー同意設計が必要になる可能性がある点は留意。この点は一次ドキュメント本文を本調査では直接確認できておらず、実装前にFirebase公式のプライバシー関連ドキュメントを直接確認することを推奨する。

---

## 6. 結論の材料(意思決定は別チケットで行う)

このチケットは調査のみを目的とし、採否の意思決定は行わない([05-choose-auth-methods](../issues/05-choose-auth-methods.md)で決定)。調査から言えることの要約:

1. SMS OTP認証は一般的な設計パターン(6桁OTP・10分有効期限・レート制限・使い捨て)が確立しており、Twilio/OWASP/NISTいずれの一次情報とも整合する。
2. 日本向けSMS送信は選択肢が複数あり(Twilio/AWS/KDDI Message Cast/NTT Com等)、それぞれ料金体系・技術的制約(国内/国際ゲートウェイ、Long code非対応等)が異なる。正確な最新単価は実装直前に各社に確認する必要がある。
3. Flutter側の実装は、Firebase Authenticationを使えば`firebase_ui_auth`のプリビルドUIまで含めて大幅に工数を圧縮できる。完全自前の場合はUI・SMS API連携・不正対策のすべてを自前設計する必要がある。
4. bloomの`system_id`モデルとの統合は、Firebase委譲パターンであればbloom側の新規実装をJWT検証(PHP公式Admin SDK非対応のため手実装または非公式ライブラリが必要)に限定でき、完全自前実装よりも明確に実装コストが小さい。ただし二重ユーザー管理(Firebase UID + bloom system_id)という設計上の複雑さは残る。
5. 最大の落とし穴はSMS toll fraud/不正利用によるコスト急増リスクであり、これはFirebase委譲(Play Integrity/silent push/reCAPTCHA/リージョンポリシーをGoogleが提供)か、完全自前実装(全て自前で作り込む必要)かで対策の実装負担が大きく変わる。

---

## 出典一覧(一次情報)

- [Verify API | Twilio](https://www.twilio.com/docs/verify/api)
- [Verify SMS overview | Twilio](https://www.twilio.com/docs/verify/sms)
- [Verification and two-factor authentication best practices | Twilio](https://www.twilio.com/docs/verify/developer-best-practices)
- [SMS Pricing in Japan for Text Messaging | Twilio](https://www.twilio.com/en-us/sms/pricing/jp)
- [Verify Pricing | Twilio](https://www.twilio.com/en-us/verify/pricing)
- [Japan: SMS Guidelines | Twilio](https://www.twilio.com/en-us/guidelines/jp/sms)
- [Verify Fraud Guard | Twilio](https://www.twilio.com/docs/verify/preventing-toll-fraud/sms-fraud-guard)
- [Programmable Rate Limits | Twilio](https://www.twilio.com/docs/verify/api/programmable-rate-limits)
- [Sending SMS messages using Amazon SNS](https://docs.aws.amazon.com/sns/latest/dg/sms_sending-overview.html)
- [Best practices for Amazon SNS SMS messaging](https://docs.aws.amazon.com/sns/latest/dg/channels-sms-best-practices.html)
- [Amazon SNS SMS Pricing](https://aws.amazon.com/sns/sms-pricing/)
- [Supported countries and regions for SMS messaging with AWS End User Messaging SMS](https://docs.aws.amazon.com/sms-voice/latest/userguide/phone-numbers-sms-by-country.html)
- [空電プッシュ | NTTドコモビジネスX](https://www.karaden.jp/)
- [料金 - SMS送信サービス「KDDIメッセージキャスト」](https://kddimessagecast.jp/price/)
- [Firebase Pricing](https://firebase.google.com/pricing)
- [Firebase Authentication Limits](https://firebase.google.com/docs/auth/limits)
- [Firebase Phone Number Verification pricing](https://firebase.google.com/docs/phone-number-verification/pricing)
- [Authenticate Using Phone Numbers on Android | Firebase](https://firebase.google.com/docs/auth/android/phone-auth)
- [Authenticate Using Phone Numbers on iOS | Firebase](https://firebase.google.com/docs/auth/ios/phone-auth)
- [Authenticate with Firebase using phone numbers on Flutter](https://firebase.google.com/docs/auth/flutter/phone-auth)
- [Get started with Firebase Authentication on Flutter](https://firebase.google.com/docs/auth/flutter/start)
- [Verify ID Tokens | Firebase Admin SDK](https://firebase.google.com/docs/auth/admin/verify-id-tokens)
- [Registering test phone numbers | Identity Platform](https://docs.cloud.google.com/identity-platform/docs/test-phone-numbers)
- [firebase_ui_auth | Flutter package (pub.dev)](https://pub.dev/packages/firebase_ui_auth)
- [NIST Special Publication 800-63B](https://pages.nist.gov/800-63-3/sp800-63b.html)
- [Forgot Password Cheat Sheet - OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html)
- [Authentication Cheat Sheet - OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [Act on Regulation of Transmission of Specific Electronic Mail (Japanese Law Translation)](https://www.japaneselawtranslation.go.jp/en/laws/view/3767/en)

### secondary(参考・未検証、上記一次情報で裏取りできなかった箇所のみ)

- WebSearch要約による「NTT CPaaS SMS APIは1通8円〜」という価格情報(`nttcpaas.com`本体は403エラーで直接取得不可だったため未検証)
- WebSearch要約による「Google Cloud Identity Platformの日本向けSMSは$0.03/通、1日10通まで無課金」という価格情報(`cloud.google.com/identity-platform/pricing`本体はツール取得時に文字数超過で全文確認できなかったため未検証)
- WebSearch要約による「Firebase Authentication phone auth利用時、電話番号がGoogle全体のスパム対策目的で送信・保存される」という情報(該当一次ページ本文を本調査では直接確認できず)
