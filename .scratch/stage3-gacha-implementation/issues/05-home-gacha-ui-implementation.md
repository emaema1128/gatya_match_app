Type: task
Blocked by: 02
Status: resolved

## Question

[02-spin-endpoint-design](02-spin-endpoint-design.md)で確定したAPI契約を前提に、ホーム画面のガチャUIを実装する。[stage3-gacha-home/issues/03-ui-flow-design](../../stage3-gacha-home/issues/03-ui-flow-design.md)の決定(Flutter標準アニメーション、結果カードは抜粋版)を反映する。

含めるべき論点:

1. `home_tab_screen.dart`(現在プレースホルダー)を、ガチャを回すボタン中心のレイアウトに置き換える。
2. ポイント残高の表示(Stage3/Stage4で「ホーム画面限定」と決定済み)。
3. 通信中のローディング状態表示。
4. 結果カード(抜粋版、`matches`機能の`MatchProfileCard`と共通化できるか検討)。
5. 空状態・ポイント残高不足状態の表示([stage3-gacha-home/issues/01](../../stage3-gacha-home/issues/01-gacha-economy-model.md)/[02](../../stage3-gacha-home/issues/02-candidate-selection-logic.md)の決定通り)。

決定+実装(このマップの方針)。

## Answer

実装完了。新規`lib/features/gacha/`フィーチャーフォルダを作成(他タブと同じ`presentation`/`application`/`domain`構成)。

**再利用**(新規で作らなかったもの):
- `MatchProfileCard`(`features/matches/presentation/`)を結果カードにそのまま流用(抜粋版の仕様に既に合致)
- `MatchData`を候補の型としてそのまま使用。`fromMatchListEntry`のdocコメントが`getMatchList`特有の説明のため、意味的に正しく読めるよう`MatchData.fromGachaCandidate(entry)`という委譲コンストラクタを追加(`match_data.dart`)

**新規ファイル**:
- `domain/gacha_spin_status.dart` — `GachaSpinStatus` enum(`idle`/`revealed`/`recycled`/`empty`/`insufficientPoints`/`error`)+APIの`status`文字列パーサ
- `domain/gacha_home_state.dart` — 画面状態(`balance`/`status`/`candidate`)
- `application/gacha_controller.dart` — `GachaController`(`@riverpod`)。`build()`で`getUserData`から初期残高取得、`spin()`で`spinGacha`を呼ぶ(`ProfileController`と同じ`AsyncLoading.copyWithPrevious`+`AsyncValue.guard`パターン)、`likeCandidate()`は別途下記06参照
- `presentation/gacha_screen.dart` — 残高表示(常時)、`AnimatedSwitcher`+状態ごとの表示、`revealed`/`recycled`は`TweenAnimationBuilder`(`MatchCelebrationScreen`と同じeaseOutBack演出)+`MatchProfileCard`+いいねボタン。`recycled`はカード自体は変更せず外側に「以前見たお相手です」のバナーを表示。`insufficientPoints`はポイント購入画面が未実装のため遷移導線は作らずメッセージのみ

`home_tab_screen.dart`は`GachaScreen`への薄い委譲に置き換え。`app_routes.dart`/`home_shell_screen.dart`は変更不要(`HomeTabRoute`は既に`HomeTabScreen`を返す)。

**検証**: `dart analyze lib`はクリーン(新規エラーなし)。Flutter web-server + Playwrightで未ログイン状態の`/`→`/welcome`リダイレクトとコンソールエラー無しを確認。本番APIへの実疎通(実際にガチャを回す・残高が減る)は、有効な本番テストアカウントでの実機確認が必要——このセッションでは自動検証できないため、ユーザー側での実機確認を推奨する。
