Type: grilling
Blocked by: 06
Status: resolved

## Question

[06-account-linking-model](06-account-linking-model.md)で決定したアカウント紐付けモデルを前提に、新規登録・ログイン画面のUXフローを決定する。

含めるべき論点:

1. 現在の新規登録画面(性別・地域・自己紹介文の入力フォーム)は、新しい認証方式のボタン(「Appleでサインイン」「Googleでログイン」等)に置き換わるのか、それとも認証方式選択の後にこのフォームが続く形になるのか。
2. ログイン画面(現在は`login_id`/`password`の手入力フォーム)は、新しい認証方式導入後どうなるか——[08-login-id-password-fallback-design](08-login-id-password-fallback-design.md)で決定する内部fallbackとの関係を含む。
3. 複数の認証方式を提示する場合の画面上の見せ方・優先順位(ボタンの並び順など)。
4. 認証方式ごとに初回登録時の情報取得量が異なる場合(例: Appleはメールアドレスが秘匿化される場合がある)、`sex`/地域/自己紹介文の入力フォームとの統合方法。

決定のみ(実装はしない、このマップの方針)。

## Answer

1. **全体構造**: 「新規登録」「ログイン」を画面レベルで分けない。認証方式選択画面(ボタン一覧)→ボタン押下→サーバー側が既存/新規を判定→(新規のみ)sex/地域/自己紹介の入力フォーム→ホーム、という単一導線に統合する。
2. **既存のlogin_id/password手入力ログイン画面**: UIから撤去。login_id/passwordは内部fallback専用(詳細は[08-login-id-password-fallback-design](08-login-id-password-fallback-design.md))とし、ユーザーに手入力させる画面としては使わない。
3. **ボタンの並び順**: [05-choose-auth-methods](05-choose-auth-methods.md)のロールアウト優先順位(LINE→Google→Apple→電話番号)と同じ順で表示。各方式は実装完了したステージから順次画面に追加する(段階導入と画面表示が連動)。
4. **プロフィール情報収集フォーム**: 認証方式によらず、初回登録時は必ず通るプロバイダ非依存の共通ステップとする。プロバイダから取得できる氏名・メールアドレス等の差は`username`の初期値に使う程度に留める([06-account-linking-model](06-account-linking-model.md)の決定5と一貫)。
5. **デバイス一致時の紐付け**: [ADR 0003](../../../docs/adr/0003-duplicate-account-offers-merge.md)の「既存アカウントへの紐付け or 別アカウント作成」の選択で、紐付けを選んだ場合は追加の本人確認なしで即座に紐付ける。既存の`existsDeviceId`が元々前提としていた「同じ端末=同じ人」という信頼モデルをそのまま踏襲する。
