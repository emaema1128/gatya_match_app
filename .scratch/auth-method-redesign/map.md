## Destination

bloomクライアント(Flutter)の認証方式を再設計する意思決定を行う——Apple Sign-In/Googleログイン/LINEログイン/電話番号(SMS)認証の4方式それぞれの実現可能性(bloomバックエンドへの追加実装、Flutter側のSDK統合コスト)を調査し、どれを採用するか(複数可)を決定する。既存の「サーバー自動発行のlogin_id/password」の仕組みは廃止せず、内部的なセッション復旧用fallbackとして残す方針([stage2-profile-creation](../stage2-profile-creation/map.md)のticket01で判明・確定)。新方式導入に伴い「1端末1アカウント」制約(`existsDeviceId`)の見直しと、複数端末/複数認証方式からの同一アカウントへの紐付け方(アカウント統合モデル)もこのマップで検討する。実ユーザーがまだ少ないため既存アカウントの移行設計は不要。**このマップは決定のみを対象とし、実装は決定後に別マップ/チケットとして立ち上げる**(Stage0〜2とは異なる方針)。

## Notes

- サービス名: bloom。開発体制: 一人開発。ユーザーは本番バックエンドへのデプロイ権限を持っている——今回の意思決定次第でバックエンド変更を伴う実装が現実的な選択肢。
- 実ユーザーはまだ少ない/いないため、既存アカウントの移行設計は不要。
- 動機: ストア審査要件(Apple Sign-In関連)とユーザー獲得・利便性。
- bloomバックエンドの実ソースは`/Users/daichi/Documents/blooom関係/dream/`(ユーザー共有、以後「都度参考にして」とのこと)。LINEログインは`Class_Line.php`/`line/line_login/regist.php`に既存のWeb向けOAuth実装があり、モバイル向けAPI化の際に参考・再利用できる可能性がある。
- 現状確認済みの事実: `registUser`が発行する`login_id`(自動採番の整数)/`password`(ランダム生成文字列)はクライアントが選べず、変更用APIも存在しない。`login`はこの2つで認証する。Apple/Google Sign-Inとも実装ゼロ、電話番号認証もSMS/OTP検証ロジックが存在しない(詳細は[stage2-profile-creation/01](../stage2-profile-creation/issues/01-registration-bugfix-domain-model.md)参照)。
- 各チケットの解決には`/grilling`と`/domain-modeling`スキルを使うこと。research系チケットは`/research`スキルで解決する(このリポジトリはgitではないため、成果物はブランチではなく`.scratch/auth-method-redesign/research/<slug>.md`に保存する)。
- **このマップは決定のみ**(実装は含まない)。

## Decisions so far

- [Apple Sign-In実現可能性調査](issues/01-apple-sign-in-feasibility.md) — iOSはネイティブ対応、Androidは非ネイティブ(Web OAuthリダイレクト、bloomサーバーが中継必須)。App Store 4.8は「他のソーシャルログインを主要な認証手段にする場合」のみ発動。バックエンドに`apple_user_id`列追加+新規検証クラスで対応可能。
- [Google Sign-In実現可能性調査](issues/02-google-sign-in-feasibility.md) — iOS/Android双方公式対応、小〜中コスト(新規列1つ+execute_function1つ+Composer依存1つ)。バックエンド検証はWebクライアントIDをaudienceに使う点に注意。
- [LINEログインのモバイルAPI化実現可能性調査](issues/03-line-login-mobile-api-feasibility.md) — bloomの既存LINEインフラ(`Class_Line.php`)がほぼそのまま再利用可能、既存チャンネル流用可、LINE側審査不要。4方式中最小コスト。既存の`line_account_user_info`経由のログイン照合という変則設計は[06-account-linking-model](issues/06-account-linking-model.md)で要検討。
- [電話番号(SMS)認証実現可能性調査](issues/04-phone-sms-auth-feasibility.md) — 既存実装なし、ゼロからの構築が必要。Firebase委譲でも継続課金+PHP公式Admin SDK非対応という制約あり。4方式中最大コスト。
- [採用する認証方式の決定](issues/05-choose-auth-methods.md) — **4方式すべてを採用、LINE→Google→Apple→電話番号の順で段階導入**。電話番号認証はログイン手段と本人確認の両目的を持つ(後続チケットで設計に反映)。login_id/passwordの内部fallackは並行して維持。
- [アカウント紐付けモデル+1端末1アカウント制約の見直し](issues/06-account-linking-model.md) — 外部アイデンティティは`user`テーブルへのプロバイダ別列追加方式(`line_user_id`パターン踏襲、`external_identity`テーブルは見送り)。1アカウントに複数方式の紐付けを許可。既知の識別なら常にログイン扱い、未知なら新規登録+`existsDeviceId`適用。デバイス一致時は無条件ブロックでなく「既存アカウントへの紐付け or 別アカウント作成」をユーザーに選ばせる方針。sex/地域/自己紹介は方式によらず引き続き必須。CONTEXT.mdに「Linked Identity」を追加、[ADR 0002](../../docs/adr/0002-linked-identity-columns-not-table.md)/[ADR 0003](../../docs/adr/0003-duplicate-account-offers-merge.md)に記録。
- [登録/ログインUXフロー設計](issues/07-registration-login-ux-flow.md) — 「新規登録」「ログイン」を画面レベルで分けず、認証方式選択画面→サーバー側判定→(新規のみ)sex/地域/自己紹介フォーム、の単一導線に統合。既存のlogin_id/password手入力ログイン画面はUIから撤去(内部fallback専用に)。ボタン順はロールアウト優先順位(LINE→Google→Apple→電話番号)と連動。デバイス一致時の紐付けは追加確認なしで即座に実行。
- [login_id/passwordの内部fallback運用設計](issues/08-login-id-password-fallback-design.md) — アプリ起動時のトークン検証失敗時のみ、保存済みlogin_id/passwordで`login`を自動呼び出しして復旧を試みる(通常API呼び出し中の復旧はスコープ外)。`TokenStorage`に新キーとして「未保存なら保存」方式で追加。復旧も失敗すれば既存の`clearSession→Unauthenticated`パターンを踏襲。CONTEXT.mdの`Session`定義を更新。

**これでauth-method-redesignマップの全チケットが解決し、destinationに到達した。**

## Not yet specified

- 各方式の具体的な実装スケジュール(着手時期・担当割り等)——優先順位(LINE→Google→Apple→電話番号)は[05-choose-auth-methods](issues/05-choose-auth-methods.md)で決定済みだが、実装計画自体は決定後に別マップとして立ち上げる(このマップは決定のみ)。

## Out of scope

- 既存ユーザーのアカウント移行。理由: 実ユーザーがまだ少ない/いないため。
- バックエンド全体の認証基盤の抜本的な作り直し。理由: 既存の`user`/`system_id`モデルは維持し、その上に新しい認証方式を追加する設計のみを検討する。
