Type: grilling
Status: resolved

## Question

bloom既存API(route_api.php: 単一エンドポイント`POST`+ `execute_function`ディスパッチ、`Authorization: Bearer <app_access_token>`認証、`{result, data, error_detail}`レスポンス形式)向けのHTTPクライアント設計を決定する。含めるべき論点: (1) 使用するHTTPパッケージ(http/dio等) (2) execute_function呼び出しを表現するリクエスト/レスポンスのラッパー設計 (3) app_access_tokenの端末内保存方法(flutter_secure_storage等) (4) result='2'時のエラーハンドリング方針(例外化するか、Result型で返すか)。本番APIのみを相手にする前提でよく、環境切り替えは対象外。

## Answer

事前調査でroute_api.php実物を確認: レスポンスは常にHTTP 200で成否は`result`(`'1'`/`'2'`)のみで判定、`result='2'`時は`data`キーなし・`error_detail`のみ。サーバー側にtry/catchはなくPHP致命的エラー時は不正なJSONが返り得る。既知のレガシーな不整合として、`sendMail`はポイント不足時に`result='1'`(成功)のまま`data.error_detail`にメッセージが返る。

1. HTTPパッケージ: **dio**。Interceptorで認証ヘッダー付与とエラー例外化を一元化できるため。
2. トークン保存: **flutter_secure_storage**(Keychain/Keystoreバックエンド)。
3. エラーハンドリング: `result='2'`時は共通例外`BloomApiException(errorDetail, executeFunction)`をdioのInterceptor(`onResponse`)がthrowする。JSONデコード失敗(不正なレスポンス)はdioの標準JSONデコードが自動的に`DioException`として投げるため追加実装不要。`sendMail`のような「`result='1'`なのに`data.error_detail`」のレガシー挙動は、共通ラッパー側では一切特別扱いせず、該当APIを呼ぶ個別コード側で対応する(誤検知リスクを避けるため)。
4. ラッパー粒度: 汎用ラッパー1つ `BloomApiClient.callApi(executeFunction, params)` を採用。エンドポイントごとの型付きモデル/メソッドは、Stage1以降で画面を作るタイミングで必要なAPIから個別に追加していく(Stage0時点で全APIぶんのモデルを作り切るのはオーバーエンジニアリング)。
5. `system_id`: ラッパー(`callApi`)がRiverpodの認証状態(`core/storage`のトークンストレージ)から自動的に読み取って毎回付与する。未ログイン時は`-1`を自動使用。

本番URLは `https://bloom-developer.com/app/api/route_api.php`。環境切り替えは対象外のためソースに直接ハードコード。

実装(スキャフォールド)は完了済み: `lib/core/network/`(`bloom_api_exception.dart`, `dio_provider.dart`, `bloom_api_client.dart`)、`lib/core/storage/token_storage.dart`。
