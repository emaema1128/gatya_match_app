## Destination

Flutter側の技術的土台(Stage 0)に関する意思決定をロックする。具体的には (1) 状態管理ライブラリの選定 (2) 画面遷移(ルーティング)の仕組み (3) bloom既存API(route_api.php: 単一エンドポイント + execute_functionディスパッチ、Authorization: Bearer <app_access_token>認証、result/error_detail形式)との通信方法の型決め (4) プロジェクトのフォルダ構成、の4点。ここが固まり次第、Stage 1(認証画面)以降は別マップとして立ち上げる。

## Notes

- サービス名: bloom。既存の婚活サービスの本番バックエンドをそのまま流用する(新規バックエンド構築なし、ステージング環境なし)。
- 対象プラットフォーム: iOS + Android のみ(web/desktop対象外)。
- 開発体制: 一人開発。
- デザイン素材: なし、ゼロから決める。
- bloom APIの認証フロー: `registUser` 時に `generateToken()` で `app_access_token` を1回だけ発行 → `user` テーブルに保存 → login/registUserのレスポンス(`user_data`)に紛れて返る → クライアントは `Authorization: Bearer <token>` ヘッダーで毎回送信 → サーバーが `access_token_verification()` でDB照合。`system_id === -1` は登録前通信のみ例外。
- 状態管理は「将来の拡張性優先」の方向性が既に出ている(Riverpod等が有力候補)。チケットではこの方針を前提に検討する。
- 各チケットの解決には `/grilling` と `/domain-modeling` スキルを使うこと。

## Decisions so far

- [状態管理ライブラリの選定](issues/01-state-management.md) — Riverpod(コード生成方式)を採用。非同期状態は`AsyncValue<T>`で表現、flutter_hooksは併用しない
- [画面遷移の仕組み](issues/02-routing.md) — go_router + go_router_builder(型安全ルート)を採用。タブ形式ナビゲーション、スプラッシュ+redirectによる認証ガード
- [bloom APIとの通信方法](issues/03-api-communication.md) — dio + flutter_secure_storageを採用。`result='2'`を`BloomApiException`として例外化、汎用ラッパー`callApi`で`system_id`を自動注入
- [プロジェクトのフォルダ構成](issues/04-folder-structure.md) — フィーチャーファースト(`lib/features/`)+ 共通層`lib/core/`(network/router/storage/widgets/auth)、各featureは4層テンプレート(presentation/application/domain/data)

Stage0の4決定がすべて完了。技術的土台のスキャフォールド実装(`lib/core/`, `lib/features/auth/`, `lib/features/home/`, `lib/main.dart`)も完了し、Chrome(Playwright)で起動→スプラッシュ→ログイン→ホーム(タブ)→ログアウト→ログインの遷移を実地確認済み(コンソールエラーなし)。Stage1(認証画面等の本実装)以降は別マップとして立ち上げる。

## Not yet specified

- Stage 1(認証画面)以降の詳細仕様は、Stage 0の4決定が固まってから別マップとして立ち上げる(このマップの対象外)。

## Out of scope

- Stage 1〜Stage 8(認証画面・プロフィール作成・ガチャUI・マッチング・チャット・プッシュ通知・設定・仕上げ)の詳細仕様。理由: destinationをStage 0の技術的土台決定に限定したため。Stage 0完了後、新規マップとして再チャートする。
