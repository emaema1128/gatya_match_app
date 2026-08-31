Type: task
Blocked by: 01
Status: resolved

## Question

[01-match-detection-scope](01-match-detection-scope.md)の決定(同期ケースのみ)を前提に、「マッチしました!」演出画面とマッチ一覧画面を設計・実装する。

含めるべき論点:

1. 「マッチしました!」画面の次のアクション(チャット機能はStage5未着手のため、暫定実装をするかどうか)。
2. マッチ一覧画面のデータソースと空状態の表示。
3. ポイント残高表示(Stage3で「ホーム画面限定」と仮決定していたもの)の正式な適用範囲。
4. 演出アニメーションの実装方法(Stage3で「Flutter標準機能、Flameは使わない」と決めた方針を踏襲するか)。

決定+実装(このマップの方針)。

## Answer

1. **次のアクションは「マッチ一覧を見る」ボタンのみ。** メッセージ送信の暫定実装はしない——bloomの「チャット」は既存の`sendMail`(旧来のメール型のやり取り)である可能性が高く、Stage5でその設計をきちんと詰める前に暫定実装を作ると作り直しになるため。
2. **マッチ一覧画面は`getMatchList`をそのまま使う。** ホームシェルの3番目のタブ(Home/マッチ/マイページ)として追加。0件時は「まだマッチしたお相手がいません。ホームでガチャを回してみましょう」という次の行動を促すメッセージを表示する。
3. **ポイント残高表示はホーム画面限定のまま**(Stage3の仮決定を正式に確定)。Stage4の画面には追加しない——ポイントを使うのはガチャを回す時だけのため。
4. **Flutter標準のアニメーション機能(`TweenAnimationBuilder`)を使う。** Stage3で決めた「Flameは使わない」方針をそのまま踏襲。

### 実装

**新規ファイル**:
- `lib/core/network/bloom_field_parsers.dart` — `asBloomInt`/`nullableBloomId`/`resolveBloomPhotoUrl`。`ProfileData`が private staticとして持っていた同等ロジックを共有ヘルパーに切り出し、`MatchData`と共用。
- `lib/features/matches/domain/match_data.dart` — `getMatchList`の1件分を表すモデル。列名重複により`system_id`キーが相手側の値で上書きされる事実をコメントで明記。
- `lib/features/matches/application/match_list_controller.dart` — `getMatchList`を呼ぶRiverpod `AsyncNotifier`。
- `lib/features/matches/presentation/match_profile_card.dart` — マッチ一覧・マッチ成立画面で共通の、相手プロフィール抜粋カード(写真+ニックネーム+年齢+居住地+自己紹介冒頭)。年齢/居住地の表示名は`ageOptionListProvider`/`addressOptionListProvider`を相手の性別でフィルタして解決。
- `lib/features/matches/presentation/match_list_screen.dart` — マッチ一覧画面。pull-to-refresh対応、空状態/エラー状態を表示。
- `lib/features/matches/presentation/match_celebration_screen.dart` — 「マッチしました!」演出画面。`matchedSystemId`をルートパラメータとして受け取り、`matchListControllerProvider`から該当データを探して表示する。

**変更ファイル**:
- `lib/features/profile/domain/profile_data.dart` — 写真URL/id解決ロジックを`bloom_field_parsers.dart`の共有ヘルパーに置き換え。
- `lib/core/router/app_routes.dart` — `MatchesBranchData`/`MatchesTabRoute`(ホームシェルの3番目のタブ、`/matches`)、`MatchCelebrationRoute`(シェル外のフルスクリーンルート、`/matches/celebration/:matchedSystemId`)を追加。
- `lib/features/home/presentation/home_shell_screen.dart` — ボトムナビゲーションに「マッチ」タブを追加(Home/マッチ/マイページの3タブに)。

**未接続の注意点**: `MatchCelebrationRoute`へ実際に遷移させる呼び出し(ガチャで`sendLike`が`status: 'match'`を返した時)は、Stage3(ガチャ)の実装時に追加する。現時点ではガチャ画面自体が未実装のため、このルートへの実際の遷移経路はまだ存在しない。

**検証**: `dart analyze lib`はクリーン(新規エラーなし)。Flutter web-server + Playwrightで、未ログイン状態から`/`→`/welcome`へのリダイレクトが壊れていないこと、コンソールエラーが出ないことを確認済み(スクリーンショットで実際にウェルカム画面が描画されることも確認)。新規追加した`/matches`・`/matches/celebration/:id`への直接のディープリンクはこのdev-server環境では白画面になったが、同じ現象が変更前から存在する`/settings`への直接ディープリンクでも再現したため、Stage4の変更による回帰ではなく、この環境固有の既知の制約と判断した(通常のクリック遷移では発生しない)。マッチ一覧・マッチ成立画面自体の本番API疎通(認証済み状態での実際の表示)は未確認——有効なテストアカウントでの実機確認をユーザー側で推奨する。
