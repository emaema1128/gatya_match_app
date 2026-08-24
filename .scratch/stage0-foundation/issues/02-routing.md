Type: grilling
Status: resolved

## Question

画面遷移の仕組みを決定する(素のNavigator vs go_router等の宣言的ルーティングパッケージ)。認証状態によるガード(未ログイン時はログイン画面へリダイレクト等)、ディープリンク(プッシュ通知タップ時に特定のチャット画面へ遷移等、Stage 6で必要になる)への対応しやすさを踏まえて決定する。

## Answer

1. **go_router** を採用する。公式サポートで情報量が多く一人開発でも詰まりにくい、`redirect`で認証ガードを一元管理でき、path文字列で通知からのディープリンクも組み立てやすい。
2. ルート定義は **go_router_builder** によるコード生成(`@TypedGoRoute`/`@TypedStatefulShellRoute`)を使う。Riverpodのコード生成方針と統一するため、素の文字列pathは使わない。
   - 実装時の制約: `go_router_builder ^4.x`は`build`パッケージの新しいメジャーバージョンを要求し、既存の`riverpod_generator ^2.6.x`(build ^2.0.0)と衝突する。Riverpodのメジャーバージョンアップはスコープ外のため、`go_router_builder: ^3.0.0`にダウングレードして解決した。mixin名も`_$ClassName`規則(3.x系)になる。
3. ログイン後のナビゲーションは**タブ形式**(ボトムナビゲーション)。`TypedStatefulShellRoute`で実現する。
4. 起動時は**スプラッシュ画面**を挟み、`app_access_token`の有無・有効性確認中は`/`(スプラッシュ)に留める。確認完了後、有効ならホーム(タブ)、無効/なしならログイン画面へredirectする。ちらつき防止のため。
5. 認証ガードは、`GoRouter`インスタンス自体をRiverpodの`@Riverpod(keepAlive: true)`コード生成Providerとして定義し、トップレベル`redirect`コールバックが認証状態Provider(`AsyncValue<AuthState>`)を`ref.read`で参照して判定する。状態変化をルーターに伝えるため、`refreshListenable`に認証状態の変化を`ref.listen`経由で`notifyListeners()`する`Listenable`(`RouterRefreshNotifier`)を接続する。
6. ディープリンク(プッシュ通知タップ→特定チャット画面等)は、pathベースルーティングにより`@TypedGoRoute<ChatRoute>(path: '/messages/:threadId')`のようなルートを後から追加するだけで対応可能な設計。詳細実装はStage6。

実装(スキャフォールド)は完了済み: `lib/core/router/`(`app_routes.dart`, `app_router.dart`, `router_refresh_notifier.dart`)。Chrome(Playwright)で起動→スプラッシュ→ログイン→ホーム(タブ)→ログアウト→ログインの遷移を実地確認済み。
