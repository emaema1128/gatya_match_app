Type: grilling
Blocked by: 01, 02, 03
Status: resolved

## Question

プロジェクトのフォルダ構成(screens/, widgets/, models/, services/等)を決定する。状態管理・ルーティング・通信方法の決定内容を踏まえて、それらの置き場所も含めて設計する。

## Answer

1. 全体方針は**フィーチャーファースト**(`lib/features/<feature>/`)。Stage1〜8で機能が順次増えていく前提と、状態管理チケットで示された「将来の拡張性優先」という方針に合致するため。
2. 横断的な共通機能は**`lib/core/`**に集約する(`shared/`のような別レイヤーは作らない)。
3. 各featureフォルダの内部は `presentation/`(画面・widget)・`application/`(Riverpod provider)・`domain/`(モデル)・`data/`(APIラッパー経由のrepository)の4層テンプレートを、機能の複雑さによらず統一して適用する(単純な機能は空フォルダ/1ファイルのみでも可)。
4. feature間で共有するUIパーツは**`lib/core/widgets/`**に集約する。

**実装時に判明した派生決定**: `core/router`のredirectが認証状態を参照する必要があり、features→coreの依存方向(逆はNG)を守るため、当初の「4サブフォルダ」から実装時に**`core/auth/`を追加**し、`core/`配下は`network/router/storage/widgets/auth`の5サブフォルダとなった(`AuthState`/`AuthController`の置き場所)。features/auth側は薄いラッパー(`LoginController`)としてこの`core/auth`を呼ぶだけに留める。

実装(スキャフォールド)は完了済み: `lib/core/{storage,auth,network,router}/`、`lib/features/{auth,home}/`(4層テンプレート、`domain/`/`data/`はStage0時点では空)。`dart analyze`でエラーなし、Chrome(Playwright)で起動〜ログイン〜ログアウトの遷移を実地確認済み。
