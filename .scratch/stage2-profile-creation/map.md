## Destination

Stage1で作成したAccountに対し、age/income/address/写真(最大3枚)のProfileデータを追加できる状態にする。新規登録直後に任意(スキップ可能)のステップとして提示し、スキップ後もマイページタブからいつでもアクセス・編集できるようにする。sex/地域(region/prefecture/city)/自己紹介文はStage1の登録画面で既にAccount作成時に収集されているため、CONTEXT.mdのProfile定義から外しAccount側の項目として扱う(Stage1実装と整合させる、下記Notes/Decisions参照)。他機能(マッチング・ガチャ等)がProfile完成度を要求するかどうかのゲーティングロジックはこのマップの対象外。マイページからのProfile編集導線と、Profile作成/編集画面(age/income/address/写真)がそれぞれ実装まで完了した時点でこのマップは完了とする。

## Notes

- サービス名: bloom。既存の婚活サービスの本番バックエンドをそのまま流用(新規バックエンド構築なし、ステージング環境なし)。
- 対象プラットフォーム: iOS + Android のみ。開発体制: 一人開発。
- 前提マップ: [stage0-foundation](../stage0-foundation/map.md)(Riverpod/go_router/dio等の技術基盤)、[stage1-auth-screens](../stage1-auth-screens/map.md)(ログイン/新規登録画面)。
- 用語は[CONTEXT.md](../../CONTEXT.md)を参照。このマップの過程でAccount/Profileの境界を実装に合わせて修正する(下記Decisions so far参照)。
- 確認済みのbloom Profile関連API(`route_api.php`のディスパッチ層のみから読み取れる範囲、実装クラス`Class_ProfileApi.php`は未入手):
  - 読み取り: `getAreaList`/`getAgeList`/`getIncomeList`/`getAddressList`
  - 書き込み: `updateProfile`(`$post_data`をそのまま`ProfileApi::updateProfile()`へ渡す不透明な設計、必須パラメータ不明)
  - 写真: `uploadProfileImg`(`image_1`/`image_2`/`image_3`、base64、最大3枚)、`deleteProfileImg`(`img_id`必須)
  - プロフィール完成度によるゲーティングはディスパッチャ層のコード(search/sendLike/getMatchList等)には見当たらなかった。
- 既存のUI: 「マイページ」タブ(`lib/features/home/presentation/settings_tab_screen.dart`)は現状ログアウトボタンのみのスタブ。Profile編集導線はここに追加する。
- 各チケットの解決には `/grilling` と `/domain-modeling` スキルを使うこと。
- **このマップは実装まで含む**(「Plan, don't do」のデフォルトを上書き、Stage0/1と同じ方針)。チケットの解決 = 決定 + その場でのスキャフォールド/実装、が期待値。

## Decisions so far

- [登録画面バグ修正+ドメインモデル更新](issues/01-registration-bugfix-domain-model.md) — ドメインモデル部分は完了。CONTEXT.mdを更新: Accountが`sex`/地域/自己紹介も収集する旨、および`login_id`/`password`はサーバー自動発行(変更API無し)である旨を明記し、Profileはage/income/address/photosに絞った。背景はADR([docs/adr/0001-account-collects-sex-area-comment.md](../../docs/adr/0001-account-collects-sex-area-comment.md))に記録。当初login_id/passwordの入力欄をregistUserに追加する実装をしたが、実ソース確認の結果バックエンドがそれらを無視すると判明しrevert済み——その扱いは新規マップ「認証方式の再検討」に委譲。
- [bloom Profile API仕様確認](issues/02-bloom-profile-api-spec-confirmation.md) — ユーザー共有の実ソース(`Class_ProfileApi.php`等)で確認完了。age/income/addressは`getAreaList`のような階層構造ではなくフラットな選択肢マップ(id→`{item, sex}`)。addressは詳細住所ではなく地域(region/prefecture/city)とは別のカテゴリカルな選択肢。`updateProfile`は`system_id`のみ必須で残りは部分更新可能、想定外だった`username`/`reject_matching_mail_flag`も対象と判明——[03-profile-screen](issues/03-profile-screen.md)のスコープに追加済み。写真の`img_id`は1/2/3のスロット番号。
- [プロフィール作成/編集画面](issues/03-profile-screen.md) — 実装完了。単一画面で作成/編集を兼用、写真は即時アップロード/削除、他フィールドは一括保存。登録成功後は`ref.listen`で明示的に`/profile`へ遷移(既存のredirectロジックとの競合を避けるため`app_router.dart`の`_redirect`も修正)。マイページに編集導線を追加。web-server+Playwrightでルーティング保護(未ログイン時のリダイレクト)を確認、Profile画面自体の本番API疎通は未確認(実機確認推奨)。

**これでstage2-profile-creationマップの全チケットが解決し、destinationに到達した。**

## Not yet specified

- 写真アップロードの詳細UX(並び替え、メイン写真指定の要否など)——「最大3枚」という制約以外は未確定。
- `login_id`/`password`(サーバー自動発行)をアプリがどう扱うか、LINE/Apple/Google/電話番号ログインを追加するか——別マップ「認証方式の再検討」で扱う(このマップのスコープ外)。

## Out of scope

- 他機能(マッチング・ガチャ等)がProfile完成度を要求するかどうかのゲーティングロジック。理由: それらの機能自体がまだ存在せず、それぞれの機能を作るステージの関心事のため。
- Profileスキップ後の再促し(リマインドバナー等のリマインダー機構)。理由: マイページからいつでも任意にアクセスできる導線で十分と判断したため。
