Type: grilling
Status: resolved

## Question

Flutterの状態管理ライブラリを選定する。方向性として「将来の拡張性を優先」(Riverpod等が有力候補)が既に示されている。Stage 1〜8全体(認証・プロフィール・ガチャUI・マッチング・チャット・通知・設定)を見据えたスケーラビリティ、一人開発での学習コスト、bloom APIとの非同期通信(ローディング状態・エラー状態の表現)との相性を踏まえて決定する。

## Answer

1. **Riverpod** を採用する。2026年時点でも新規Flutterプロジェクトのデフォルト推奨であり、型安全・BuildContext非依存・非同期処理との相性が、一人開発かつStage 1〜8全体を見据えたスケーラビリティ要件に合致する。
2. **コード生成方式**(`@riverpod` アノテーション + `riverpod_generator` + `build_runner`)を使う。手書きProvider定義はしない。
3. 非同期状態(ローディング/データ/エラー)は Riverpod標準の **`AsyncValue<T>`** で表現する。bloom APIの `result='2'` は例外としてthrowし `AsyncValue.error` に自然に落とし込む方針とする(例外化の詳細設計は「bloom APIとの通信方法の型決め」チケットの管轄)。
4. **flutter_hooksは併用しない**。Riverpod単体(`ConsumerWidget`/`ConsumerStatefulWidget`)から開始し、必要になれば後から追加を検討する。

想定パッケージ: `flutter_riverpod`, `riverpod_annotation`(dependencies) / `riverpod_generator`, `build_runner`(dev_dependencies)。バージョン固定は実装時の `flutter pub add` に委ねる。
