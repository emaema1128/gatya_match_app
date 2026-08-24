## Destination

bloom既存API(`login`/`registUser`)に実接続する認証画面(Stage 1)を完成させる。対象はログイン画面と新規登録(Registration)画面の2つのみ。Stage 0で作ったスタブ(`submitStubLogin`/`completeStubLogin`)を実際のbloom API呼び出しに置き換え、必要なら`AuthState`/`AuthController`のセッション設計更新も含めて実装まで行う——このマップは意思決定だけでなく実装も対象に含む(Stage 0と同じ扱い)。パスワードリセットはbloomバックエンドに該当APIが存在しないため対象外。退会(`withdrawn`)とプッシュ通知トークン登録は別ステージへ先送り。見た目はMaterial標準UIのまま機能を優先し、配色・ブランディングの方向性決定はこのマップの対象外。ログイン画面・新規登録画面がそれぞれ実装まで完了した時点でこのマップは完了とする。

## Notes

- サービス名: bloom。既存の婚活サービスの本番バックエンドをそのまま流用(新規バックエンド構築なし、ステージング環境なし)。
- 対象プラットフォーム: iOS + Android のみ。開発体制: 一人開発。
- 前提マップ: [stage0-foundation](../stage0-foundation/map.md) — Riverpod(コード生成)/go_router+go_router_builder/dio+flutter_secure_storage/フィーチャーファースト構成が確定・実装済み。
- 用語は[CONTEXT.md](../../CONTEXT.md)を参照(Account/Profile/Registration/Login/Sessionの定義と使い分け)。Profile(area/age/income/address等)はこのマップの対象外——Stage1が作るのはAccountの作成(Registration)のみ。
- 各チケットの解決には `/grilling` と `/domain-modeling` スキルを使うこと。
- **このマップは実装まで含む**(「Plan, don't do」のデフォルトを上書き)。チケットの解決 = 決定 + その場でのスキャフォールド/実装、が期待値。

## Decisions so far

- [bloom API仕様確認](issues/01-bloom-api-spec-confirmation.md) — `registUser`はログインID+パスワードのみ要求(Profile項目は登録時不要)。`verificationAfterLoginProcess`はログイン成功のたびに必須で呼ぶ。`existsDeviceId`/`existsAdjustId`も呼ぶ必要あり(登録フローでの利用が濃厚、正確なタイミングは02/03で確定)。
- [ログイン画面](issues/02-login-screen.md) — 実装完了。空欄チェックのみのバリデーション、`login`成功時に`TokenStorage`へ永続化しインラインエラー表示、`verificationAfterLoginProcess`をブロッキングで呼び失敗時はロールバック、`existsDeviceId`は含めない。`AuthState.Authenticated`に`systemId`を追加し、`AuthController.build()`は`getUserData`でサーバー側トークン検証まで実装。
- [新規登録画面](issues/03-registration-screen.md) — 実装完了。ログインID+パスワードのみのフォーム、`device_id`(iOS: `identifierForVendor` / Android: `android_id`パッケージ、当初のUUID方式から変更)による`existsDeviceId`事前チェック(重複時はブロック)、利用規約同意チェックボックス(URLは仮)、登録成功時は`login`と共通の`_completeSession()`経由で自動ログイン。ログイン画面⇄新規登録画面の相互導線とルーティングも追加。

Stage1の3チケット(bloom API仕様確認・ログイン画面・新規登録画面)がすべて完了。ログイン/新規登録の両画面ともbloom本番APIへの実装込みで完了し、`dart analyze`はクリーン、Flutter web + Playwrightで画面遷移・フォームバリデーション挙動を確認済み(実際のAPI送信は本番環境のため未実施——有効なテストアカウントでの実機確認はユーザー側推奨)。destinationの「ログイン画面・新規登録画面がそれぞれ実装まで完了」を満たしたため、このマップは完了。Stage2以降(プロフィール作成等)は別マップとして立ち上げる。

## Not yet specified

- セッション失効時の自動ログアウト方針(`result='2'`かつ`error_detail`がトークン無効由来の場合に、全画面共通でログイン画面へ強制遷移させるか)。ログイン単体では顕在化しないが、Stage1以降でAPIを呼ぶ画面が増えると必要になる可能性がある。まだ問いを鋭くできないため保留。
- 認証フローの自動テスト方針(widget test/integration testの要否、本番APIを叩くリスクとどう向き合うか)。

## Out of scope

- パスワードリセット/パスワード忘れ機能。理由: route_api.phpに該当するexecute_function(resetPassword等)が存在しないため。追加するならbloomバックエンド側の変更が必要で、それは別スコープ。
- 退会(アカウント削除、`withdrawn` API)。理由: 設定(Settings)ステージの機能と位置づけたため。
- プッシュ通知トークン(`fcm_device_token`)の実登録。理由: プッシュ通知ステージの機能と位置づけたため。Stage1のログイン呼び出しではnull/未送信でよい。
- 配色・ブランディングなど視覚デザインの方向性決定。理由: デザイン素材が未着手のため、Stage1はMaterial標準UIで機能を優先する。
- プロフィール作成(area/age/income/address等の入力・編集)。理由: stage0-foundationのOut of scopeを継承。Registration(Account作成)とProfile作成は別概念([CONTEXT.md](../../CONTEXT.md)参照)。
