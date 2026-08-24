Type: grilling
Blocked by: 01, 02, 03, 04
Status: resolved

## Question

[01-apple-sign-in-feasibility](01-apple-sign-in-feasibility.md)、[02-google-sign-in-feasibility](02-google-sign-in-feasibility.md)、[03-line-login-mobile-api-feasibility](03-line-login-mobile-api-feasibility.md)、[04-phone-sms-auth-feasibility](04-phone-sms-auth-feasibility.md)の調査結果を踏まえ、Apple Sign-In/Googleログイン/LINEログイン/電話番号(SMS)認証のうち、実際に採用する方式を決定する(複数採用も可)。

含めるべき論点:

1. 各方式の実装コスト(バックエンド新規実装量、Flutter側SDK統合の手間)と、動機(ストア審査要件、ユーザー獲得・利便性)への貢献度を突き合わせて優先順位をつける。
2. 複数方式を採用する場合、初期リリースで全部揃えるか、段階的に追加するか。
3. 採用しない方式がある場合、その理由を明記する(将来的な再検討の余地があるか、完全に見送りか)。

決定のみ(実装はしない、このマップの方針)。

## Answer

**4方式すべてを採用する。導入順序はLINE→Google→Apple→電話番号(SMS)の段階導入とする。**

1. **LINEログイン(最優先)**: 実装コストが最小(`Class_Line.php`の既存トークン検証・プロフィール取得ロジックがそのまま再利用可能、既存のLINEログインチャンネルもコンソール設定変更のみで流用可、LINE側の審査も不要)。日本のユーザー層への訴求力も4方式中最大と判断。
2. **Googleログイン(2番目)**: 実装コストは低〜中(新規カラム1つ+新規execute_function1つ+新規Composer依存1つ程度)。Android/iOS双方で広く使われており利便性への貢献度が高い。
3. **Apple Sign-In(3番目)**: 実装コストは中(iOSはネイティブで容易だが、**Androidはネイティブ対応がなくWeb OAuthリダイレクト**——bloomサーバーがApple側コールバックを受けてアプリへ302リダイレクトする新規エンドポイントが必要)。LINE/GoogleをAccountの主要な認証手段として提供する時点でApp Store審査ガイドライン4.8(Login Services)が実質的にトリガーされるため、LINE/Google導入後に必須級となる。この順序性から3番目に設定。
4. **電話番号(SMS)認証(最後)**: 実装コストが4方式中最大(OTP基盤をゼロから構築、継続的なSMS送信コストが発生、迷惑SMS対策が必須、日本キャリア向けゲートウェイ登録などの実務対応も必要)。目的は「ログイン手段としての利便性」と「本人確認・なりすまし対策」の**両方**(ユーザー確認済み)——後者は婚活/マッチングアプリで偽アカウント対策として独立の価値がある。この二重の目的により、[06-account-linking-model](06-account-linking-model.md)/[07-registration-login-ux-flow](07-registration-login-ux-flow.md)では「電話番号認証を主要ログイン方式としてだけでなく、他方式で作成済みのアカウントに対する追加の本人確認ステップとしても使えるようにする」設計を検討すること。

**段階導入の理由**: 4方式を一度に実装するとテスト・審査対応(特にAndroidのApple Sign-Inリダイレクト、Firebase/SMSプロバイダ選定)の負荷が大きい。コストが低く価値が高いものから着手し、各方式のリリース・検証サイクルを独立させる。

既存の「サーバー自動発行のlogin_id/password」機構は内部fallbackとして4方式と並行して残す([08-login-id-password-fallback-design](08-login-id-password-fallback-design.md)、既に方針確定済み・ブロックなしで並行着手可能)。

見送った方式はない(全採用のため)。実際の実装スケジュール(着手時期等)は本チケットのスコープ外——map.mdの「Not yet specified」の通り、決定後に別マップとして立ち上げる。
