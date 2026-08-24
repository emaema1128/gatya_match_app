Type: grilling
Blocked by: 02
Status: resolved

## Question

Profile作成/編集画面を実装する。対象フィールドはage/income/address/写真(最大3枚、`uploadProfileImg`/`deleteProfileImg`経由)に加え、[02-bloom-profile-api-spec-confirmation](02-bloom-profile-api-spec-confirmation.md)で`updateProfile`が扱うと判明した`username`(ニックネーム)と`reject_matching_mail_flag`(マッチングメール拒否設定)も対象とする。[02-bloom-profile-api-spec-confirmation](02-bloom-profile-api-spec-confirmation.md)で確定した実際のAPI形状を前提に設計する。

含めるべき論点:

1. フォーム構成(1画面、写真アップロードは独立したセクションとして分離——`/wayfinder`のQ7で確定)。
2. 各フィールドの入力方式(age/income/addressはいずれも`profile_age`/`profile_income`/`profile_address`由来のフラットな選択肢リストなのでドロップダウン等の選択式、usernameはテキスト入力、reject_matching_mail_flagはチェックボックス/スイッチ)。
3. 作成/編集の共通化(同じ画面で新規作成・既存編集の両方を扱うか)。
4. 新規登録直後の任意(スキップ可能)ステップとしての導線・ルーティング(`app_routes.dart`への新規ルート追加、登録完了後のredirect方針)——`/wayfinder`のQ2で「必須ではない任意ステップ」と確定。
5. 既存の「マイページ」タブ(`settings_tab_screen.dart`)への編集導線の追加——`/wayfinder`のQ9で確定、新規タブは追加しない。
6. 各フィールドの入力必須/任意の方針(bloomのAPIレベルではプロフィール完成度によるゲーティングは見つかっていない——`/wayfinder`のQ4でスコープ外と確定しているため、必須にするかは純粋にUX判断)。
7. `updateProfile`の呼び出しタイミング(フィールドごとの自動保存か、フォーム送信時の一括保存か)。

決定と実装を両方この場で完了させる(このマップの実装込みの方針)。

## Answer

実装完了。実装前に`Class_ProfileApi.php`の実ソースで`getAgeList`/`getIncomeList`/`getAddressList`が`{id: {age_item, sex}}`形式のフラットなマップを返すこと(ticket02の推測通り)、`updateProfile`が`system_id`のみ必須で残りは`?? $user_data[...]`による部分更新であることを再確認した。

1. **作成/編集の共通化**: 単一の`ProfileScreen`(`lib/features/profile/presentation/profile_screen.dart`)が両方を担う。表示時に`getUserData`を呼んで既存値をフォームに反映する(`ProfileController.build()`)。
2. **各フィールドの必須/任意**: 全項目任意。バリデーションによる送信ブロックなし(空欄でも保存可能)。age/income/addressは登録時に`tempRegist()`側でデフォルト値が割り当て済みのため、実際には常に何らかの値を持った状態でフォームが開く。
3. **保存タイミング**: 写真は選択/削除のたびに即時`uploadProfileImg`/`deleteProfileImg`を呼ぶ。age/income/address/username/reject_matching_mail_flagは「保存する」ボタン押下時に`updateProfile`へ一括送信(null-aware要素で未選択のidは送らず既存値を維持)。
4. **ルーティング**: `app_routes.dart`に`ProfileRoute`(`/profile`)を新規追加。`registration_screen.dart`は登録成功(loading→data遷移)を`ref.listen`で検知し、明示的に`ProfileRoute().go()`で遷移——リダイレクトロジックには任せない。これに伴い`app_router.dart`の`_redirect`を修正: 認証済み時に自動でホームへ送る対象(`isAuthScreen`)から登録画面を除外(未ログイン時にアクセス可能な`isPublicScreen`には引き続き含める)。これをしないと、登録成功でAuthStateが先にAuthenticatedになった瞬間に既存のredirectロジックがホームへ送ってしまい、明示的なプロフィール画面遷移と競合するため。
5. **マイページへの編集導線**: `settings_tab_screen.dart`に「プロフィールを編集」ボタンを追加(`ProfileRoute().push()`)。
6. **画面を離れる導線**: `Navigator.canPop()`で判定——登録直後(pushスタックなし)は「あとで設定する」ボタンでホームへ、マイページからの編集(pushあり)は標準の戻るボタンで戻る。

**実装ファイル(新規)**: `lib/core/profile/profile_option_list_provider.dart`(age/income/addressの選択肢プロバイダ、`sex`でのフィルタリングが必要)、`lib/features/profile/domain/profile_data.dart`、`lib/features/profile/application/profile_controller.dart`、`lib/features/profile/presentation/profile_screen.dart`。
**実装ファイル(変更)**: `lib/core/router/app_routes.dart`(`ProfileRoute`追加)、`lib/core/router/app_router.dart`(リダイレクト修正)、`lib/features/auth/presentation/registration_screen.dart`(登録成功時の明示的遷移)、`lib/features/home/presentation/settings_tab_screen.dart`(編集導線追加)。

**検証**: `dart analyze lib`はクリーン(既存の無関係な警告のみ)。Flutter web-server + Playwrightで、未ログイン状態から`/profile`・`/settings`へ直接アクセスした際に`/welcome`へ正しくリダイレクトされること、コンソールエラーが出ないことを確認済み(ルーティング変更が既存の保護ロジックを壊していないことの確認)。**Profile画面自体の表示・保存・写真アップロードは認証済み状態でのみ到達可能で、本番bloom APIへの実際の呼び出しは未実施——有効なテストアカウントでの実機確認をユーザー側で推奨する**(特に、画像配信ベースURLを`https://bloom-developer.com/`+保存パスと推測している点(`profile_data.dart`のTODOコメント参照)は要検証)。
