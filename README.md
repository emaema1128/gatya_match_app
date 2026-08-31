# gatya_match_app

Flutter で作られたマッチングアプリ（開発コード名: bloom）です。このREADMEでは、初めてこのプロジェクトを読む人向けに「どこに何が書いてあるか」をできるだけ具体的に説明します。

## 使っている主な技術

| 分野 | パッケージ | 役割 |
|---|---|---|
| 状態管理 | `flutter_riverpod` / `riverpod_annotation` | 「今どんな状態か」（ログイン中か、読み込み中か等）を管理し、画面に反映する |
| 画面遷移 | `go_router` / `go_router_builder` | URLのような「ルート」で画面を管理し、認証状態に応じて自動で画面を切り替える |
| 通信 | `dio` | サーバー（bloom API）とHTTP通信を行う |
| 保存 | `flutter_secure_storage` | ログイントークンなど、端末に安全に保存したいデータを扱う |
| 音声 | `record` / `audioplayers` | チャットの音声メッセージの録音・再生 |

`riverpod_annotation` と `go_router_builder` は「コード生成」の仕組みです。`@riverpod` のような目印（アノテーション）を付けたクラス・関数から、`〇〇.g.dart` という名前のファイルが自動で作られます。これらは手で編集するファイルではありません（見つけたら中身を読まなくてOKです）。

## フォルダ構成の全体像

```
lib/
├── main.dart                … アプリの起動地点（本番用）
├── main_demo.dart           … デモ画面だけを起動する別の入口
│
├── core/                    … アプリ全体で共通して使う「土台」の部品
│   ├── auth/                … ログイン状態そのものを管理する
│   ├── network/              … サーバー通信の共通処理
│   ├── router/               … 画面遷移のルール
│   ├── storage/               … 端末への保存処理
│   ├── profile/               … プロフィール選択肢(年齢/年収など)の取得
│   └── region/                … 地域(都道府県・市区町村)データの取得
│
└── features/                … 画面ごとの機能。1つの機能フォルダの中は
    │                            さらに以下の3種類に分かれる
    │                            - presentation/ … 画面(見た目)
    │                            - application/  … 画面の裏側の処理
    │                            - domain/       … その機能で使うデータの形
    │
    ├── auth/                  … ログイン・新規登録・スプラッシュ画面
    ├── home/                  … ログイン後のホーム画面(タブ切り替え)
    ├── gacha/                  … ガチャ画面(ホームタブの中身)
    ├── matches/                … マッチ一覧・「マッチしました!」演出画面
    ├── chat/                    … トーク一覧・個別チャットスレッド画面
    ├── profile/                … プロフィール編集画面
    ├── welcome/                … 未ログイン時の入り口画面
    └── demo/                    … 開発中の実験・デモ画面(本番機能とは無関係)
```

### `core/` と `features/` の違い（たとえ話）

`core/` は「工具箱」、`features/` は「工具箱の道具を使って作る、それぞれの製品」だとイメージしてください。

- `core/` の中身（例: ログイン状態の管理、サーバー通信のやり方）は、**どの画面からも共通して使われる**ものです。1つの機能のためだけに存在するわけではありません。
- `features/` の中身は、**特定の画面・特定の機能のため**だけに存在します。例えば `features/profile/` はプロフィール編集画面のためだけのコードです。

### `features/◯◯/` の中の3分類

各機能フォルダの中は、役割ごとに次の3つに分けて置かれています（機能によっては一部だけ存在します）。

- **`presentation/`** … 画面そのもの（ボタンや文字など、目に見える部分）。Flutterの `Widget`（画面部品）が書かれています。
- **`application/`** … 画面の裏側の処理。「ボタンが押されたら何をするか」のロジックが書かれています（Riverpodの `Controller` クラスなど）。
- **`domain/`** … その機能で使う「データの形」の定義。サーバーから来たデータを、画面で使いやすい形に変換するクラスなどが置かれます。

これは「見た目」「処理」「データ」を混ぜて1つのファイルに書かず、役割ごとに分けて置いておく、という整理のルールです。

## `core/` の中身（ファイル単位）

| ファイル | 役割 |
|---|---|
| `core/auth/auth_controller.dart` | ログイン・ログアウト・新規登録のサーバー通信を行い、「今ログインしているか」という状態(`AuthState`)を保持する中心的なクラス |
| `core/auth/auth_state.dart` | ログイン状態を表す2種類のラベル `Authenticated`（ログイン済み）/ `Unauthenticated`（未ログイン）の定義 |
| `core/auth/sex.dart` | 性別を表す値の定義 |
| `core/network/dio_provider.dart` | サーバー通信を行う`Dio`（通信ライブラリ）本体の設定。認証トークンを自動でヘッダーに付ける処理もここ |
| `core/network/bloom_api_client.dart` | bloomサーバーのAPIを呼び出すための共通の窓口 |
| `core/network/bloom_api_exception.dart` | サーバーがエラーを返したときに投げられる例外(エラー)の型 |
| `core/network/bloom_field_parsers.dart` | bloomのAPIレスポンスによく出てくる値の変換処理（id文字列→int、未選択id→null、画像/音声の相対パス→表示・再生用URL）。複数の機能(`profile`/`matches`/`chat`)から共通で使われる |
| `core/router/app_router.dart` | 画面遷移の本体。ログイン状態を見て「この画面にいたら、別の画面に飛ばす」という判定(`_redirect`)をしている |
| `core/router/app_routes.dart` | 「このURLパスには、この画面を表示する」という一覧(ルート定義) |
| `core/router/router_refresh_notifier.dart` | ログイン状態が変わったことを、画面遷移の仕組みに知らせる橋渡し役 |
| `core/storage/token_storage.dart` | ログイントークンを端末に安全に保存・読み込みする処理 |
| `core/storage/device_id_provider.dart` / `device_type_provider.dart` | 端末固有のID・OS種別（iOS/Android）を取得する処理 |
| `core/profile/profile_option_list_provider.dart` | プロフィール編集で使う選択肢(年齢・年収など)をサーバーから取得する処理 |
| `core/region/area_list_provider.dart` | 都道府県・市区町村のデータをサーバーから取得する処理 |

## `features/` の中身（機能単位）

| フォルダ | 主なファイル | 役割 |
|---|---|---|
| `features/welcome/` | `presentation/welcome_screen.dart` | 未ログイン時に最初に表示される、ログイン/新規登録を選ぶ画面 |
| `features/auth/` | `presentation/login_screen.dart` | ログイン画面(ID・パスワード入力) |
| | `presentation/registration_screen.dart` | 新規登録画面 |
| | `presentation/splash_screen.dart` | 起動直後、ログイン状態を確認している間だけ表示される読み込み画面 |
| | `application/login_controller.dart` | ログインボタンが押された時の処理を`AuthController`に橋渡しする |
| | `application/registration_controller.dart` | 新規登録ボタンが押された時の処理を`AuthController`に橋渡しする |
| `features/home/` | `presentation/home_shell_screen.dart` | ログイン後のホーム画面の外枠。下側のタブ切り替え(ホーム/マッチ/マイページ)を担当 |
| | `presentation/home_tab_screen.dart` | ホームタブの中身。`features/gacha/`の`GachaScreen`への薄い委譲 |
| `features/gacha/` | `presentation/gacha_screen.dart` | ガチャ画面(ホームタブの中身)。残高表示、中央のガチャを回すボタン。回すとガチャ本体(`assets/images/gacha_machine.png`)からカプセルが排出され震えてバースト、候補の数(最大3人)だけカプセルが飛び出す演出の後、`GachaRevealRoute`へ自動遷移する |
| | `presentation/gacha_reveal_screen.dart` | ガチャの排出結果を1人ずつ見せる、写真メイン(カードの3/5)+プロフィール情報(2/5)のフルスクリーンスワイプカード画面。◀▶で候補間を移動、カードを上にスワイプで「いいね」送信(1スピンにつき1人まで)、タップで画面遷移せず`ProfileDetailsSheet`(写真ギャラリー+詳細プロフィール、`features/matches/`と共用)を開く。いいねの結果がマッチ成立なら`MatchCelebrationRoute`へ遷移する |
| | `application/gacha_controller.dart` | `spinGacha`(ガチャを回す、最大3人分の候補を一度に取得)/`sendLike`(いいね)のサーバー通信を行う処理 |
| | `domain/gacha_home_state.dart` / `gacha_spin_status.dart` | 画面の表示状態(残高・結果の種類・候補データのリスト)を表すデータクラス |
| `features/matches/` | `presentation/match_list_screen.dart` | 「Like」タブの中身。上部の`SegmentedButton`で「いいね(受け取った・未マッチ)」「マッチ」を切り替える。どちらも0件の場合は次の行動を促すメッセージを表示 |
| | `presentation/match_celebration_screen.dart` | 「マッチしました!」演出画面。`features/gacha/`のいいねボタンから、マッチ成立時に遷移してくる |
| | `presentation/match_profile_card.dart` | いいね一覧・マッチ一覧・マッチ成立画面で共通の、相手プロフィールの抜粋カード。タップで画面遷移せず`ProfileDetailsSheet`を開く |
| | `presentation/profile_details_sheet.dart` | カードタップで開く、写真ギャラリー+年齢/居住地/年収+自己紹介全文のボトムシート(`showProfileDetailsSheet`)。元は`GachaRevealScreen`専用だったものを共通化 |
| | `application/match_list_controller.dart` | マッチ一覧(「マッチ」セグメント)をサーバーから取得する処理 |
| | `application/received_like_list_controller.dart` | 受け取った・未マッチのいいね一覧(「いいね」セグメント)をサーバーから取得する処理 |
| | `domain/match_data.dart` | サーバーから取得したマッチ/いいね情報(写真最大3枚・年齢/居住地/年収・自己紹介)を、画面で使いやすい形にまとめたデータクラス。ガチャの候補データのパースにも共用される |
| `features/chat/` | `presentation/chat_tab_screen.dart` | トーク一覧画面(チャットタブの中身)。マッチした相手ごとに1行、直近のメッセージ・未読件数を表示。行をタップすると`ChatThreadRoute`へ遷移 |
| | `presentation/chat_thread_screen.dart` | 個別チャットスレッド画面(テキスト+画像+音声)。残高表示、数秒間隔のポーリングによる新着メッセージ取得、メッセージ/画像/音声送信、受信画像・音声のタップ課金閲覧・再生(初回のみ課金) |
| | `application/talk_list_controller.dart` | トーク一覧をサーバーから取得する処理(`TalkListController`)と、未読件数の合計を計算する`totalUnreadChatCountProvider`(ボトムナビのバッジに使用) |
| | `application/chat_thread_controller.dart` | 個別スレッドの履歴取得・ポーリング・メッセージ/画像/音声送信・受信画像/音声の課金閲覧を行う処理(相手のID単位のfamilyプロバイダ) |
| | `domain/talk_summary.dart` / `chat_message.dart` / `chat_thread_state.dart` | サーバーから取得したトーク一覧・メッセージ履歴を、画面で使いやすい形にまとめたデータクラス |
| `features/profile/` | `presentation/profile_screen.dart` | プロフィール編集画面。マイページタブの中身(この場合はこの画面に留まり続ける)と、新規登録直後の任意入力ステップ(`isOnboarding: true`。「あとで設定する」ボタンあり、保存後にホームへ遷移)の両方で使う共通画面。マイページタブの場合のみ右上に歯車アイコン(→設定画面)を表示 |
| | `presentation/settings_screen.dart` | 設定画面。`profile_screen.dart`の歯車アイコンからpushされる。現状は「ログアウト」ボタンのみ |
| | `application/profile_controller.dart` | プロフィール編集画面が開いた時に、サーバーからユーザー情報を取得する処理 |
| | `domain/profile_data.dart` | サーバーから取得したユーザー情報を、画面で使いやすい形にまとめたデータクラス |
| `features/demo/` | (複数ファイル) | 本番機能とは無関係の、見た目や表現方法の実験用画面(疑似3D表示など) |

## 自動生成ファイル(`*.g.dart`)について

`lib/` の中には、上の表に載っていない `〇〇.g.dart` というファイルがたくさんあります（例: `auth_controller.g.dart`, `app_router.g.dart`, `app_routes.g.dart`）。これらは人が書いたファイルではなく、`build_runner` というツールが自動で作るファイルです。

- 元になるファイル（例: `auth_controller.dart`）の中の `@riverpod` や `@Riverpod(...)` という目印から自動生成されます。
- ファイルの先頭に `// GENERATED CODE - DO NOT MODIFY BY HAND`（自動生成コードなので手で編集しないこと）と書かれています。
- コードを読むときは、基本的に元になった `.dart` ファイル（`.g.dart` が付いていない方）だけを見れば十分です。

## 具体例: ログイン後にマイページが表示されるまで、どのファイルが動くか

初めてこのプロジェクトを読むときの練習として、「ログインボタンを押してからマイページが表示されるまで」に実際に読まれるファイルの順番を載せておきます。

```
1. features/auth/presentation/login_screen.dart      … ボタンを押す
2. features/auth/application/login_controller.dart   … AuthControllerに処理を依頼
3. core/auth/auth_controller.dart                     … サーバーに通信し、ログイン状態を更新
4. core/router/router_refresh_notifier.dart            … ログイン状態の変化に気づく
5. core/router/app_router.dart                          … 自動でホーム画面へ切り替える判定を行う
6. features/profile/presentation/profile_screen.dart    … マイページ(プロフィール)画面が表示される
```

この流れのように、「画面(presentation)」→「処理(application)」→「共通の土台(core)」という順番でファイルをたどっていくのが、このプロジェクトを読むときの基本パターンです。
