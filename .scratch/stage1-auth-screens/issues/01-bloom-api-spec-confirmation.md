Type: task
Status: resolved

## Question

ログイン画面・新規登録画面の実装方針を決める前に、bloomバックエンド側の未確認仕様を洗い出す。`route_api.php`(ディスパッチ層)からは以下が読み取れない:

1. `registUser`(`Class_UserApi::registUser($post_data)`)が要求する必須/任意パラメータは何か。少なくとも認証情報(ログインID相当・パスワード)は必要と推測されるが、それ以外(氏名・性別・生年月日など)を初回登録時点で要求するのか、Profile側(area/age/income/address)は本当に登録後の別フローなのかを確認する。
2. `verificationAfterLoginProcess`(`Common::verificationAfterLoginProcess($system_id)`)は何を行うAPIか。ログイン成功後にクライアントが呼ぶ必要があるものか、任意なのか。
3. `existsDeviceId`(`UserApi::existsDeviceId($post_data['device_id'])`, `UserApi::existsAdjustId($adjust_device_id)`)は何のためのチェックか。ログインまたは登録フローでクライアントが呼ぶ必要があるものか。

この情報は`route_api.php`の実物(このリポジトリに`route_api.php`としてコピー済み)からはディスパッチ部分しか分からず、実装クラス(`Class_UserApi.php`, `Class_Common.php`)はこのリポジトリにもファイルシステム上にも見当たらない(検索済み、不在確認済み)。バックエンドソースにアクセスできるユーザー自身が確認するか、該当ソースをこのリポジトリに共有する形で報告する。

## Answer

ユーザー確認済み:

1. **`registUser`の必須項目**: ログインID + パスワードのみ。氏名・性別・生年月日・area/age/income/addressといったProfile系項目は登録時点では要求しない([CONTEXT.md](../../../CONTEXT.md)のAccount/Profile区分どおり)。→ 新規登録画面は2フィールドの単純なフォームでよい。
2. **`verificationAfterLoginProcess`**: 必須の後処理。ログイン成功のたびにクライアントが呼ぶ必要がある(`app_version`/`app_build_number`もあわせて送るとバージョン情報が更新される、任意項目)。
3. **`existsDeviceId`/`existsAdjustId`**: クライアントが呼ぶ必要がある。`device_id`(+ 任意で`adjust_id`)を渡し、`status: exists/not_exists`を受け取る。具体的にどのフロー(登録のみ/ログインも)で呼ぶかは、`device_id`/`adjust_id`という引数の性質(端末・Adjust広告アトリビューションによる重複検知)から登録フローでの利用が濃厚だが、正確な呼び出しタイミングは各画面のチケット(02, 03)側で確定する。
