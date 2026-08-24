Type: grilling
Blocked by: 05
Status: resolved

## Question

[05-choose-auth-methods](05-choose-auth-methods.md)で決定した認証方式を前提に、外部アイデンティティ(Apple/Google/LINEのユーザーID、電話番号など)とbloomの`system_id`をどう紐付けるかのデータモデル、および現在`existsDeviceId`で強制している「1端末1アカウント」制約の見直し方針を決定する。

含めるべき論点:

1. 外部アイデンティティの保存方法(新しいテーブル、または`user`テーブルへのカラム追加——バックエンド変更を伴う設計判断)。
2. 1つのbloomアカウントに複数の認証方式(例: Apple + LINE)を紐付けられるようにするか。
3. 複数端末から同じアカウントにログインできるようにする場合、`existsDeviceId`の「重複登録ブロック」ロジックをどう変更するか(廃止/緩和/条件付き維持)。
4. 同じ人が誤って複数アカウントを作ってしまうケース(例: 一度Apple IDで登録した後、別端末でGoogleアカウントで登録してしまう)をどう防ぐ、または許容するか。
5. [stage2-profile-creation](../stage2-profile-creation/map.md)で確定した`sex`/`region`/`prefecture`/`city`/`comment`のAccount作成時収集は、新しい認証方式(Apple/Google/LINE経由の登録)でも同様に必要か、それとも認証方式によっては省略/簡略化できるか。

`/domain-modeling`スキルを使い、決定した内容をCONTEXT.mdに反映する。決定のみ(実装はしない、このマップの方針)。

## Answer

1. **データモデル**: `user`テーブルにプロバイダごとの列を追加(`apple_user_id`/`google_sub`/検証済み電話番号——既存の`tel_number`とは別)する方式を採用。既存の`line_user_id`パターンを踏襲し、新規`external_identity`テーブルは見送り。
2. **複数方式の紐付け**: 可能。1つの`user`行に複数のプロバイダ列を同時に埋められるため、1アカウントに複数の認証方式(login_id/password含む)を紐付けられる。
3. **1端末1アカウント制約の見直し**: 外部アイデンティティが既存アカウントと一致すればログイン扱いで`existsDeviceId`は適用しない。一致しなければ新規登録扱いで`existsDeviceId`を引き続き適用(ただし4の通り挙動を変更)。
4. **同一人物の複数アカウント化対策**: 新規登録扱いになったケースで`existsDeviceId`が既存アカウントとの端末一致を検出した場合、無条件ブロック(現行の`DeviceAlreadyRegisteredException`)でも無条件許容(サイレントに別アカウント作成)でもなく、「既存アカウントに新しい認証方式として紐付けるか、承知の上で別アカウントを作成するか」をユーザーに選ばせる方針とする。具体的なUX/エンドポイント設計は[07-registration-login-ux-flow](07-registration-login-ux-flow.md)に委譲。
5. **sex/region/prefecture/city/commentの扱い**: 認証方式によらず引き続き収集が必要。プロバイダから取得できる氏名・メールアドレス等は`username`の初期値程度にしか使えない。

**副次的な決定**: LINEモバイルログインは既存の`line_account_user_info`(LINE公式アカウント連携用)を経由せず、`user.line_user_id`を直接参照する(1のデータモデルとの一貫性のため)。既存のWeb版LINEログインフローはこのプロジェクトのスコープ外として変更しない——WebとMobileでLINE識別の参照先が異なる状態を許容する。

CONTEXT.mdを更新(Accountの説明文と新規「Linked Identity」の項目を追加)。背景は[ADR 0002](../../../docs/adr/0002-linked-identity-columns-not-table.md)(データモデル選定)と[ADR 0003](../../../docs/adr/0003-duplicate-account-offers-merge.md)(重複アカウント対策の方針)に記録。
